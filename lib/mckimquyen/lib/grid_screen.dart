import 'package:flutter/material.dart';

const int gridSpace = 20;

class GridPainter extends CustomPainter {
  // final bool isShowGrid;
  final Function(
    double widthCell,
    double heightCell,
  ) callback;

  GridPainter({
    // required this.isShowGrid,
    required this.callback,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // debugPrint("paint");
    // Color c;
    // if (isShowGrid) {
    //   c = Colors.red.withOpacity(0.25);
    // } else {
    //   c = Colors.transparent;
    // }

    final c = Colors.red.withValues(alpha: 0.25);
    final paint = Paint()
      ..color = c // Màu đỏ với độ trong suốt 50%
      ..strokeWidth = 1; // Độ dày của các đường kẻ

    // Chia kích thước của màn hình cho $gridSpace để có khoảng cách đều nhau
    final double columnWidth = size.width / gridSpace;
    final double rowHeight = size.height / gridSpace;

    // Vẽ các đường ngang
    for (int i = 0; i <= gridSpace; i++) {
      final y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Vẽ các đường dọc
    for (int i = 0; i <= gridSpace; i++) {
      final x = i * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // debugPrint("columnWidth x rowHeight $columnWidth x $rowHeight");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callback.call(columnWidth, rowHeight);
    });
    // callback.call(columnWidth, rowHeight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // debugPrint("shouldRepaint");
    return false; // Không cần vẽ lại nếu không có thay đổi
  }
}

class GridScreen extends StatelessWidget {
  final Function(
    double widthCell,
    double heightCell,
  ) callback;

  const GridScreen(this.callback, {super.key});

  @override
  Widget build(BuildContext context) {
    // debugPrint("GridScreen build");
    return IgnorePointer(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Nền trong suốt
        body: CustomPaint(
          size: Size.infinite, // Lấp đầy toàn bộ màn hình
          painter: GridPainter(
            // isShowGrid: isShowGrid,
            callback: callback,
          ), // Sử dụng GridPainter để vẽ lưới
        ),
      ),
    );
  }
}
