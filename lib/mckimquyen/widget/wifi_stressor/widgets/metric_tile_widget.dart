import 'package:flutter/material.dart';

/// Widget hiển thị một metric item
class MetricTileWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget valueWidget;

  const MetricTileWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.valueWidget,
  });

  // Constructor cũ để backward compatibility
  factory MetricTileWidget.text({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return MetricTileWidget(
      icon: icon,
      title: title,
      valueWidget: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: const Color(0xFF10B981)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
      ),
      trailing: valueWidget,
    );
  }
}
