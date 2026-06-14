import 'dart:async';
import 'dart:math' as math;

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/const/ad_keys.dart';
import '../../core/base_stateful_state.dart';
import 'vip_keys.dart';

const String _kFirstInstallKey = '__FIRST_INSTALL__';
const String _kLegacyKeyPrefix = 'LEGACY_';

class VipScreen extends StatefulWidget {
  static const String screenName = '/VipScreen';

  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends BaseStatefulState<VipScreen>
    with TickerProviderStateMixin {
  final TextEditingController _keyController = TextEditingController();
  final FocusNode _keyFocus = FocusNode();
  final ValueNotifier<bool> _isProcessing = ValueNotifier<bool>(false);
  final ValueNotifier<List<VipEntry>> _entriesNotifier =
      ValueNotifier<List<VipEntry>>(const []);

  AnimationController? _shimmerController;
  AnimationController? _entryController;
  AnimationController? _pulseController;
  ConfettiController? _confettiController;
  StreamSubscription<bool>? _activeSubscription;
  // Re-render entries (icons, expiry strings) every 30 s — slow channel.
  Timer? _tickTimer;
  // Drives the per-second countdown text (`12d 03h 24m 15s`). Separate from
  // `_tickTimer` so the high-frequency rebuilds only repaint the countdown
  // widget, not the whole entries list.
  Timer? _countdownTimer;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Staggered entrance: 3 section dùng chung 1 controller, mỗi section
    // chiếm 1 Interval khác nhau → fade-slide vào tuần tự.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    // Pulse glow cho activate button khi user đã nhập key.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // Confetti on successful VIP activation (Q18A).
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 1200));

    _refreshEntries();

    final vip = AdManager().vip;
    if (vip != null) {
      _activeSubscription = vip.activeStream.listen((_) => _refreshEntries());
    }

    // Slow channel: re-fetch entries every 30 s (catches external add/revoke).
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshEntries();
    });

    // Fast channel: per-second countdown text. Only the countdown widget
    // rebuilds on each tick (it's the only listener on `_now`).
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _activeSubscription?.cancel();
    _tickTimer?.cancel();
    _countdownTimer?.cancel();
    _shimmerController?.dispose();
    _entryController?.dispose();
    _pulseController?.dispose();
    _confettiController?.dispose();
    _keyController.dispose();
    _keyFocus.dispose();
    _isProcessing.dispose();
    _entriesNotifier.dispose();
    _now.dispose();
    super.dispose();
  }

  void _refreshEntries() {
    if (!mounted) return;
    final vip = AdManager().vip;
    if (vip == null) {
      _entriesNotifier.value = const [];
      return;
    }
    _entriesNotifier.value = List<VipEntry>.from(vip.entries);
  }

  Future<void> _onActivate() async {
    // Hide keyboard NGAY trước khi check — user yêu cầu rõ. Phải gọi đầu tiên
    // để nếu validate fail thì keyboard vẫn không bám lại.
    FocusScope.of(context).unfocus();

    final raw = _keyController.text;
    if (raw.trim().isEmpty) {
      _showSnack('vip_enter_key_first'.tr);
      return;
    }

    final vip = AdManager().vip;
    if (vip == null) {
      _showSnack('vip_sdk_not_ready'.tr);
      return;
    }

    final norm = VipManager.normaliseKey(raw);
    // For unknown keys, the validator will reject so the duration value here
    // is irrelevant. We still pass a non-zero placeholder because addVip is
    // not invoked until validation passes.
    final duration = lookupVipKeyDuration(norm) ?? const Duration(seconds: 1);
    // Re-fetch translations at action time (not init time) — user may have
    // changed locale between splash init and now via the language selector.
    final dialogStrings = VipDialogStrings(
      verifyingTitle: 'vip_verifying_title'.tr,
      verifyingMessage: 'vip_verifying_message'.tr,
      successTitle: 'vip_success_title'.tr,
      successMessageBuilder: (until) =>
          'vip_success_message'.trParams({'until': until}),
      failedTitle: 'vip_failed_title'.tr,
      failedMessage: 'vip_failed_message'.tr,
      networkErrorMessage: 'vip_network_error'.tr,
      confirmButton: 'vip_confirm'.tr,
    );

    _isProcessing.value = true;
    try {
      final ok = await vip.redeemVip(
        context,
        key: norm,
        duration: duration,
        validator: vipKeyValidator,
        strings: dialogStrings,
      );
      // Widget có thể đã unmount trong khi await — guard mọi thao tác state.
      if (!mounted) return;
      if (ok) {
        _keyController.clear();
        unawaited(HapticFeedback.heavyImpact());
        _confettiController?.play();
      }
      _refreshEntries();
    } finally {
      if (mounted) _isProcessing.value = false;
    }
  }

  /// "Watch ad → 3 days VIP" flow.
  ///
  /// Policy: a reward may ONLY be granted after the user completes a **rewarded**
  /// ad (`earned == true`). We do NOT fall back to an interstitial as a reward —
  /// granting VIP for merely viewing an interstitial blurs the rewarded /
  /// interstitial boundary and is against Google/AppLovin rewarded policy. If no
  /// rewarded ad is available, we ask the user to try again later.
  ///
  /// **No artificial timeout on the rewarded callback.** The SDK guarantees the
  /// callback fires (it has its own 90 s hard cap).
  Future<void> _onWatchAdForVip() async {
    if (_isProcessing.value) return;
    final vip = AdManager().vip;
    if (vip == null) {
      _showSnack('vip_sdk_not_ready'.tr);
      return;
    }

    _isProcessing.value = true;
    try {
      // Rewarded ad — the ONLY path that grants. NO timeout (SDK guarantees the
      // callback fires).
      final rewardCompleter = Completer<bool>();
      AdManager().showRewardedAd(
        onEarnedReward: (earned) {
          if (!rewardCompleter.isCompleted) rewardCompleter.complete(earned);
        },
      );
      final earned = await rewardCompleter.future;
      if (!mounted) return;

      if (earned) {
        final key = 'REWARDED_${DateTime.now().millisecondsSinceEpoch}';
        await vip.addVip(key: key, duration: const Duration(days: 3));
        if (!mounted) return;
        _confettiController?.play();
        unawaited(HapticFeedback.heavyImpact());
        _showSnack('vip_watch_ad_success'.tr);
        _refreshEntries();
      } else {
        // Rewarded not available or dismissed early — do NOT grant via any
        // other ad format. Ask the user to retry.
        _showSnack('vip_watch_ad_failed'.tr);
      }
    } finally {
      if (mounted) _isProcessing.value = false;
    }
  }

  Future<void> _onRevoke(VipEntry entry) async {
    final confirmed = await _confirmDialog(
      'vip_revoke'.tr,
      'vip_revoke_confirm'.tr,
    );
    if (!mounted || !confirmed) return;
    final vip = AdManager().vip;
    if (vip == null) return;
    await vip.revokeVip(entry.key);
    if (!mounted) return;
    unawaited(HapticFeedback.lightImpact());
    _refreshEntries();
  }

  Future<void> _onRevokeAll() async {
    final confirmed = await _confirmDialog(
      'vip_revoke_all'.tr,
      'vip_revoke_all_confirm'.tr,
    );
    if (!mounted || !confirmed) return;
    final vip = AdManager().vip;
    if (vip == null) return;
    await vip.revokeAll();
    if (!mounted) return;
    unawaited(HapticFeedback.heavyImpact());
    _refreshEntries();
  }

  Future<bool> _confirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252540),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr,
                style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AdKey.privacyPolicyUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showSnack('error'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final vip = AdManager().vip;
    if (vip == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: Text('vip_title'.tr,
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'vip_sdk_not_ready'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'vip_title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: vip.activeListenable,
        builder: (context, active, _) {
          return ValueListenableBuilder<List<VipEntry>>(
            valueListenable: _entriesNotifier,
            builder: (context, entries, __) {
              final topInset = MediaQuery.of(context).padding.top;
              // Pick the active entry that owns the latest expiry — the
              // hero card / progress bar / countdown all reference this one.
              final primaryEntry = _pickPrimaryActiveEntry(entries);
              return Stack(
                children: [
                  _buildBackdrop(active),
                  ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topInset + kToolbarHeight + 8,
                      16,
                      32,
                    ),
                    children: [
                      _staggered(0, _buildHeroCard(active, primaryEntry)),
                      const SizedBox(height: 24),
                      _staggered(1, _buildRedeemSection()),
                      // Watch-ad section is hidden when VIP is already
                      // active — both rewarded and interstitial slots
                      // short-circuit on VIP guard so the button would
                      // silent-fail. Showing it would just confuse users.
                      if (!active) ...[
                        const SizedBox(height: 24),
                        _staggered(2, _buildWatchAdSection()),
                      ],
                      const SizedBox(height: 24),
                      _staggered(3, _buildEntriesSection(entries)),
                      const SizedBox(height: 24),
                      _staggered(4, _buildBuyVipSection()),
                      const SizedBox(height: 24),
                      _staggered(5, _buildFooter()),
                    ],
                  ),
                  // Confetti — fired in `_onActivate` on success. Anchored
                  // top-center so paper falls down across the hero card.
                  _buildConfettiOverlay(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBackdrop(bool active) {
    final shimmer = _shimmerController;
    if (!active || shimmer == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        return Positioned(
          top: -120,
          right: -120,
          child: Transform.rotate(
            angle: shimmer.value * 2 * math.pi,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB200).withValues(alpha: 0.18),
                    const Color(0xFFFFB200).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(bool active, VipEntry? primaryEntry) {
    final expiresAt = primaryEntry?.expiresAt;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? const [
                    Color(0xFFFFD60A),
                    Color(0xFFFFB200),
                    Color(0xFFFF6B00),
                  ]
                : const [
                    Color(0xFF3A3A5E),
                    Color(0xFF252540),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB200).withValues(alpha: 0.45),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          children: [
            _buildCrownIcon(active),
            const SizedBox(height: 18),
            Text(
              active ? 'vip_status_active'.tr : 'vip_status_inactive'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              active && expiresAt != null
                  ? 'vip_expires_at'
                      .trParams({'date': _fmtDateTime(expiresAt)})
                  : 'vip_status_inactive_tagline'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (active && primaryEntry != null) ...[
              const SizedBox(height: 18),
              _buildRemainingBadge(primaryEntry.expiresAt),
              const SizedBox(height: 14),
              // Per-second countdown text "12d 03h 24m 15s" — listens only
              // to `_now`, so it's the only widget that rebuilds every tick.
              _buildCountdownText(primaryEntry.expiresAt),
              const SizedBox(height: 14),
              _buildProgressBar(primaryEntry),
            ],
          ],
        ),
      ),
    );
  }

  /// Format the gap between [now] and [expiresAt] as `12d 03h 24m 15s`.
  /// Trims leading zero-units (e.g., shows `03h 24m 15s` once `days == 0`).
  String _fmtCountdown(Duration remaining) {
    if (remaining.isNegative || remaining == Duration.zero) {
      return '0s';
    }
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (d > 0) return '${d}d ${_pad2(h)}h ${_pad2(m)}m ${_pad2(s)}s';
    if (h > 0) return '${_pad2(h)}h ${_pad2(m)}m ${_pad2(s)}s';
    if (m > 0) return '${_pad2(m)}m ${_pad2(s)}s';
    return '${s}s';
  }

  String _pad2(int v) => v.toString().padLeft(2, '0');

  Widget _buildCountdownText(DateTime expiresAt) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _now,
      builder: (context, now, _) {
        final remaining = expiresAt.difference(now);
        return Text(
          _fmtCountdown(remaining),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFeatures: [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        );
      },
    );
  }

  /// Elapsed-time progress bar.
  ///
  /// 3 marks on a horizontal timeline:
  ///   - **start** = `entry.grantedAt` (left edge, 0.0)
  ///   - **end**   = `entry.expiresAt` (right edge, 1.0)
  ///   - **current** = `now` (the fill position)
  ///
  /// `progress = (now - grantedAt) / (expiresAt - grantedAt)`. Bar starts
  /// empty when VIP is just granted and fills toward 1.0 as the entry
  /// approaches expiry.
  ///
  /// We clamp to `[0, 1]` so a clock skew or already-expired entry
  /// doesn't break the visual.
  ///
  /// Renders directly with `LinearProgressIndicator` — the value changes
  /// per second from `_now`, but for typical VIP windows (24 h–1 year)
  /// the per-second delta is < 0.001 % so smoothing animation is
  /// unnecessary and only hides the actual progression.
  Widget _buildProgressBar(VipEntry entry) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _now,
      builder: (context, now, _) {
        final total = entry.expiresAt.difference(entry.grantedAt);
        final elapsed = now.difference(entry.grantedAt);
        final progress = total.inMilliseconds <= 0
            ? 1.0
            : (elapsed.inMilliseconds / total.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.95),
            ),
          ),
        );
      },
    );
  }

  /// Pick the active entry whose `expiresAt` is the latest — that's the
  /// one driving the hero card / progress bar / countdown.
  VipEntry? _pickPrimaryActiveEntry(List<VipEntry> entries) {
    VipEntry? primary;
    for (final e in entries) {
      if (!e.isActive) continue;
      if (primary == null || e.expiresAt.isAfter(primary.expiresAt)) {
        primary = e;
      }
    }
    return primary;
  }

  Widget _buildConfettiOverlay() {
    final c = _confettiController;
    if (c == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: c,
        blastDirectionality: BlastDirectionality.explosive,
        maxBlastForce: 18,
        minBlastForce: 8,
        emissionFrequency: 0.04,
        numberOfParticles: 18,
        gravity: 0.4,
        shouldLoop: false,
        colors: const [
          Color(0xFFFFD60A),
          Color(0xFFFFB200),
          Color(0xFFFF6B00),
          Colors.white,
        ],
      ),
    );
  }

  Widget _buildCrownIcon(bool active) {
    final shimmer = _shimmerController;
    if (!active || shimmer == null) {
      return Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.workspace_premium,
          size: 50,
          color: Colors.white,
        ),
      );
    }
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        return SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: shimmer.value * 2 * math.pi,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.7),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE066), Color(0xFFFFB200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 46,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemainingBadge(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final label = days > 0
        ? 'vip_remaining_days'.trParams({'days': '$days'})
        : 'vip_remaining_hours'.trParams({'hours': '${remaining.inHours}'});
    final subLabel = days > 0 && hours > 0
        ? 'vip_remaining_extra_hours'.trParams({'hours': '$hours'})
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            subLabel == null ? label : '$label · $subLabel',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedeemSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_outlined,
                  color: Color(0xFFFFB200), size: 20),
              const SizedBox(width: 8),
              Text(
                'vip_redeem_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'vip_redeem_subtitle'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _keyController,
            builder: (context, value, _) {
              return TextField(
                controller: _keyController,
                focusNode: _keyFocus,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _onActivate(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'vip_key_hint'.tr,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.0,
                  ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(
                    Icons.confirmation_number_outlined,
                    color: Color(0xFFFFB200),
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white70, size: 20),
                          onPressed: _keyController.clear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFB200),
                      width: 1.6,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          ValueListenableBuilder<bool>(
            valueListenable: _isProcessing,
            builder: (context, processing, _) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _keyController,
                builder: (context, value, __) {
                  final hasKey = value.text.trim().isNotEmpty;
                  final enabled = !processing && hasKey;
                  return _buildActivateButton(
                    enabled: enabled,
                    processing: processing,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Activate button.
  /// - `enabled = false` khi user chưa nhập key → disabled visual + onTap=null.
  /// - `enabled = true` → pulse glow để thu hút mắt user.
  /// - `processing = true` → spinner thay text, vẫn giữ visual enabled.
  Widget _buildActivateButton({
    required bool enabled,
    required bool processing,
  }) {
    final pulseCtrl = _pulseController;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedBuilder(
        animation: pulseCtrl ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          // Pulse: 0..1 sin wave; chỉ áp khi enabled & không processing.
          final p = (enabled && !processing && pulseCtrl != null)
              ? pulseCtrl.value
              : 0.0;
          final glowAlpha = enabled ? (0.32 + 0.28 * p) : 0.0;
          final blur = enabled ? (16.0 + 14.0 * p) : 0.0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: enabled
                    ? const [Color(0xFFFFD60A), Color(0xFFFFB200)]
                    : [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: enabled
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFB200)
                            .withValues(alpha: glowAlpha),
                        blurRadius: blur,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: enabled ? _onActivate : null,
                child: Center(
                  child: processing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.black,
                          ),
                        )
                      : Text(
                          'vip_activate_button'.tr.toUpperCase(),
                          style: TextStyle(
                            color: enabled
                                ? Colors.black
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntriesSection(List<VipEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyEntriesCard();
    }
    final visible = entries.where((e) => e.isActive).toList();
    if (visible.isEmpty) return _buildEmptyEntriesCard();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'vip_active_entries'
                      .trParams({'count': '${visible.length}'}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (visible.length > 1)
                TextButton.icon(
                  onPressed: _onRevokeAll,
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    'vip_revoke_all'.tr,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
        for (final e in visible) _buildEntryCard(e),
      ],
    );
  }

  Widget _buildEmptyEntriesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            color: Colors.white.withValues(alpha: 0.35),
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            'vip_no_entries'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(VipEntry entry) {
    final isFirstInstall = entry.key == _kFirstInstallKey;
    final isLegacy = entry.key.startsWith(_kLegacyKeyPrefix);
    final remaining = entry.remaining;
    final daysLeft = remaining.inDays;
    final hoursLeft = remaining.inHours;

    final IconData icon;
    final String displayName;
    if (isFirstInstall) {
      icon = Icons.celebration_outlined;
      displayName = 'vip_first_install'.tr;
    } else if (isLegacy) {
      icon = Icons.devices_other_outlined;
      displayName = 'vip_legacy_device'.tr;
    } else {
      icon = Icons.confirmation_number_outlined;
      // Che giấu key: 3 ký tự đầu plaintext, phần còn lại thay bằng `*`.
      displayName = _maskKey(entry.key);
    }

    final remainingLabel = daysLeft > 0
        ? 'vip_remaining_days'.trParams({'days': '$daysLeft'})
        : 'vip_remaining_hours'.trParams({'hours': '$hoursLeft'});

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB200).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFFB200), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$remainingLabel · ${_fmtDateShort(entry.expiresAt)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            tooltip: 'vip_revoke'.tr,
            onPressed: () => _onRevoke(entry),
          ),
        ],
      ),
    );
  }

  /// "Watch ad → 3 days VIP" — free way for non-paying users to get a VIP
  /// window. Implements the rewarded → interstitial fallback flow from
  /// `AD_PROMPT_FLUTTER.MD` Step 4.7 + 10.3 #7. The button pulses (Step
  /// 10.4 #1) to draw attention.
  Widget _buildWatchAdSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFB200).withValues(alpha: 0.18),
            const Color(0xFFFF6B00).withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFB200).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline,
                  color: Color(0xFFFFB200), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'vip_watch_ad_title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB200),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'vip_watch_ad_badge_free'.tr,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'vip_watch_ad_subtitle'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: _isProcessing,
            builder: (context, processing, _) {
              return _buildWatchAdButton(processing: processing);
            },
          ),
        ],
      ),
    );
  }

  /// Watch-ad CTA button with pulse animation (reuses `_pulseController`).
  /// Disabled while another ad/redeem flow is in flight.
  Widget _buildWatchAdButton({required bool processing}) {
    final pulseCtrl = _pulseController;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedBuilder(
        animation: pulseCtrl ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          final p = (pulseCtrl != null && !processing) ? pulseCtrl.value : 0.0;
          final glowAlpha = processing ? 0.0 : (0.32 + 0.28 * p);
          final blur = processing ? 0.0 : (16.0 + 14.0 * p);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD60A), Color(0xFFFFB200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB200).withValues(alpha: glowAlpha),
                  blurRadius: blur,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: processing ? null : _onWatchAdForVip,
                child: Center(
                  child: processing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: Colors.black,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'vip_watch_ad_button'.tr.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// In-app purchase placeholders. All buttons are disabled — wiring real
  /// IAP is a follow-up. The list is here to give the VIP screen its full
  /// merchandising surface and to make the "VIP" feature feel commercial
  /// even before billing is integrated.
  Widget _buildBuyVipSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  color: Color(0xFFFFB200), size: 20),
              const SizedBox(width: 8),
              Text(
                'vip_buy_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBuyOption(
            icon: Icons.calendar_today_outlined,
            label: 'vip_buy_30d'.tr,
            price: '\$0.5',
          ),
          _buildBuyOption(
            icon: Icons.event_outlined,
            label: 'vip_buy_90d'.tr,
            price: '\$1',
          ),
          _buildBuyOption(
            icon: Icons.event_available_outlined,
            label: 'vip_buy_1y'.tr,
            price: '\$2',
          ),
          _buildBuyOption(
            icon: Icons.all_inclusive,
            label: 'vip_buy_lifetime'.tr,
            price: '\$3',
          ),
          const SizedBox(height: 6),
          // Restore-purchase row — also disabled until IAP is wired.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              // Disabled — IAP not integrated yet.
              onTap: null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.restore,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'vip_restore_locked'.tr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyOption({
    required IconData icon,
    required String label,
    required String price,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Disabled placeholder — `onTap: null` makes the row visually
          // greyed out via Material's built-in disabled state.
          onTap: null,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB200).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFFB200).withValues(alpha: 0.6),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'vip_buy_locked'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: TextButton.icon(
        onPressed: _openPrivacyPolicy,
        icon: const Icon(
          Icons.privacy_tip_outlined,
          size: 16,
          color: Colors.white70,
        ),
        label: Text(
          'vip_privacy_policy'.tr,
          style: const TextStyle(
            color: Colors.white70,
            decoration: TextDecoration.underline,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  /// Stagger fade + slide-up entrance cho section thứ `index` (0..N-1).
  /// Mỗi section delay 120ms so với section trước, duration 520ms.
  Widget _staggered(int index, Widget child) {
    final ctrl = _entryController;
    if (ctrl == null) return child;
    final start = (index * 0.15).clamp(0.0, 1.0);
    final end = (start + 0.55).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 28),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  /// Giữ 3 ký tự đầu plaintext, phần còn lại thay bằng dấu `*`.
  String _maskKey(String key) {
    if (key.length <= 3) return key;
    return key.substring(0, 3) + '*' * (key.length - 3);
  }

  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $h:$m';
  }

  String _fmtDateShort(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }
}
