import 'package:flutter/material.dart';
import '../../models/test_result.dart';

/// Widget cho mỗi item trong timeline list
class TimelineItem extends StatelessWidget {
  final TestResult result;
  final VoidCallback onTap;

  /// Khi `true`, item ở chế độ chọn để so sánh (hiện check thay vì mũi tên).
  final bool selectionMode;
  final bool selected;

  const TimelineItem({
    super.key,
    required this.result,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            )
          : null,
      child: ListTile(
        leading: _buildLeadingIcon(),
        title: Text(
          '${result.avgSpeed.toStringAsFixed(1)} Mbps',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${result.durationFormatted} • ${_formatTime(result.startTime)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: selectionMode
            ? Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? const Color(0xFF3B82F6) : Colors.white38,
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  /// Build leading icon với color coding
  Widget _buildLeadingIcon() {
    final color = _getStatusColor();
    return CircleAvatar(
      backgroundColor: color,
      child: Icon(
        _getStatusIcon(),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  /// Get color dựa trên speed quality
  Color _getStatusColor() {
    if (!result.isSuccessful) {
      return Colors.red;
    }

    switch (result.speedQuality) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.orange;
      case 'poor':
      default:
        return Colors.red;
    }
  }

  /// Get icon dựa trên status
  IconData _getStatusIcon() {
    if (result.isFailed) {
      return Icons.error;
    }
    if (!result.isSuccessful) {
      return Icons.warning;
    }
    return Icons.check_circle;
  }

  /// Format time (HH:MM AM/PM)
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
