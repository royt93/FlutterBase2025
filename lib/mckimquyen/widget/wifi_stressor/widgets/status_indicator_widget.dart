import 'package:flutter/material.dart';

/// Widget hiển thị trạng thái test với animation
class StatusIndicatorWidget extends StatelessWidget {
  final bool isRunning;

  const StatusIndicatorWidget({
    super.key,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: CircleAvatar(
        key: ValueKey(isRunning),
        radius: 64,
        backgroundColor: isRunning ? Colors.green : Colors.grey,
        child: Icon(
          isRunning ? Icons.wifi : Icons.wifi_find,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }
}
