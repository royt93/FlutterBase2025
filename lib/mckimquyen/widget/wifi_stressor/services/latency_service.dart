import 'dart:io';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart'; // SafeLogger
import 'package:dio/dio.dart';

/// Đo độ trễ (round-trip latency) và tính jitter.
///
/// Dùng 1 request HTTP nhỏ tới endpoint nhanh/ổn định toàn cầu (Cloudflare trace)
/// và đo thời gian khứ hồi. Khi đo trong lúc stress test, latency phản ánh độ trễ
/// dưới tải (bufferbloat) — đúng mục tiêu chẩn đoán mạng.
class LatencyService {
  final Dio _dio;

  LatencyService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
              sendTimeout: const Duration(seconds: 3),
              // Trace endpoint trả text ~200 bytes.
              responseType: ResponseType.plain,
            ));

  static const _probeUrl = 'https://www.cloudflare.com/cdn-cgi/trace';

  /// Đo round-trip latency (ms). Trả `null` nếu lỗi/timeout.
  Future<double?> probe() async {
    final sw = Stopwatch()..start();
    try {
      await _dio.get(_probeUrl);
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (e) {
      sw.stop();
      SafeLogger.d('Latency', 'probe failed: $e');
      return null;
    }
  }

  static const _dnsHost = 'www.cloudflare.com';

  /// Đo thời gian phân giải DNS (ms). Trả `null` nếu lỗi.
  /// Lưu ý: OS cache DNS → lần sau nhanh, phản ánh DNS thực tế người dùng gặp.
  Future<double?> dnsLookup() async {
    final sw = Stopwatch()..start();
    try {
      final res = await InternetAddress.lookup(_dnsHost)
          .timeout(const Duration(seconds: 3));
      sw.stop();
      if (res.isEmpty) return null;
      return sw.elapsedMicroseconds / 1000.0;
    } catch (e) {
      sw.stop();
      SafeLogger.d('Latency', 'dns lookup failed: $e');
      return null;
    }
  }

  /// Jitter = trung bình trị tuyệt đối hiệu các mẫu liên tiếp (ms).
  /// Pure — dễ unit-test. Trả 0 nếu < 2 mẫu.
  static double jitter(List<double> samples) {
    if (samples.length < 2) return 0;
    double sum = 0;
    for (int i = 1; i < samples.length; i++) {
      sum += (samples[i] - samples[i - 1]).abs();
    }
    return sum / (samples.length - 1);
  }

  /// Trung bình (ms). Trả 0 nếu rỗng.
  static double average(List<double> samples) {
    if (samples.isEmpty) return 0;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  void close() => _dio.close();
}
