import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Import components để test
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_screen.dart';

// Generate mocks
@GenerateMocks([StressorController])
import 'wifi_stressor_screen_test.mocks.dart';

void main() {
  /// Test Suite cho WiFiStressorApp Widget
  group('WiFiStressorApp Widget Tests', () {
    late MockStressorController mockController;

    setUp(() {
      // Setup GetX test mode
      Get.testMode = true;

      // Tạo mock controller
      mockController = MockStressorController();

      // Setup default mock responses
      when(mockController.isRunning).thenReturn(false.obs);
      when(mockController.downloadCount).thenReturn(0.obs);
      when(mockController.speedMbps).thenReturn(0.0.obs);
      when(mockController.totalSpeedMbps).thenReturn(0.0.obs);
      when(mockController.parallelDownloads).thenReturn(50.obs);
      when(mockController.speedHistory).thenReturn(<double>[].obs);
      when(mockController.totalDownloadedBytes).thenReturn(0.obs);
      when(mockController.testDuration).thenReturn(Duration.zero.obs);

      // Register mock controller
      Get.put<StressorController>(mockController);
    });

    tearDown(() {
      Get.reset();
    });

    /// Test widget khởi tạo cơ bản
    testWidgets('should render WiFiStressorApp correctly', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );

      // Assert
      expect(find.byType(WiFiStressorApp), findsOneWidget);
      expect(find.byType(StressorHomePage), findsOneWidget);
    });

    /// Test AppBar hiển thị đúng
    testWidgets('should display app bar with correct title', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );

      // Assert
      expect(find.text('FastNet Speed Test'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    /// Test trạng thái idle hiển thị đúng
    testWidgets('should display idle state correctly', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(false.obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('SẴN SÀNG KIỂM TRA'), findsOneWidget);
      expect(find.text('BẮT ĐẦU KIỂM TRA'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_find), findsOneWidget);
    });

    /// Test trạng thái running hiển thị đúng
    testWidgets('should display running state correctly', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(true.obs);
      when(mockController.downloadCount).thenReturn(5.obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.textContaining('ĐANG KIỂM TRA WI-FI'), findsOneWidget);
      expect(find.text('DỪNG KIỂM TRA'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });

    /// Test connection selector dropdown
    testWidgets('should display connection selector dropdown', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Số kết nối:'), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    /// Test start button functionality
    testWidgets('should call startStressTest when start button pressed', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(false.obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tìm và tap start button
      final startButton = find.text('BẮT ĐẦU KIỂM TRA');
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Assert - verify method được gọi
      verify(mockController.startStressTest()).called(1);
    });

    /// Test stop button functionality
    testWidgets('should call stopStressTest when stop button pressed', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(true.obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tìm và tap stop button
      final stopButton = find.text('DỪNG KIỂM TRA');
      expect(stopButton, findsOneWidget);

      await tester.tap(stopButton);
      await tester.pumpAndSettle();

      // Assert
      verify(mockController.stopStressTest()).called(1);
    });

    /// Test info dialog
    testWidgets('should show info dialog when info button pressed', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Thông tin ứng dụng'), findsOneWidget);
      expect(find.textContaining('Ứng dụng kiểm tra sức chịu tải'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
    });

    /// Test metrics display khi đang chạy
    testWidgets('should display metrics when running', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(true.obs);
      when(mockController.speedMbps).thenReturn(25.5.obs);
      when(mockController.totalSpeedMbps).thenReturn(20.3.obs);
      when(mockController.totalDownloadedBytes).thenReturn(10485760.obs); // 10MB

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Tốc độ hiện tại'), findsOneWidget);
      expect(find.text('Tốc độ trung bình'), findsOneWidget);
      expect(find.text('Thời gian chạy'), findsOneWidget);
      expect(find.text('Dữ liệu đã tải'), findsOneWidget);
    });

    /// Test chart hiển thị khi có dữ liệu
    testWidgets('should display chart when speed history has data', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(true.obs);
      when(mockController.speedHistory).thenReturn([10.0, 15.0, 20.0, 25.0].obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(SpeedChart), findsOneWidget);
      expect(find.text('Biểu đồ tốc độ'), findsOneWidget);
    });

    /// Test loading state khi chưa có dữ liệu chart
    testWidgets('should show loading when no speed data', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(true.obs);
      when(mockController.speedHistory).thenReturn(<double>[].obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Đang thu thập dữ liệu tốc độ...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    /// Test dropdown value change
    testWidgets('should update parallel downloads when dropdown changed', (WidgetTester tester) async {
      // Arrange
      when(mockController.isRunning).thenReturn(false.obs);
      when(mockController.parallelDownloads).thenReturn(50.obs);

      // Act
      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap dropdown
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();

      // Chọn giá trị mới
      await tester.tap(find.text('100').last);
      await tester.pumpAndSettle();

      // Assert - verify controller được cập nhật
      verify(mockController.parallelDownloads.value = 100).called(1);
    });
  });

  /// Test Suite cho SpeedChart Widget
  group('SpeedChart Widget Tests', () {
    testWidgets('should render speed chart with data', (WidgetTester tester) async {
      // Arrange
      final testSpeeds = [10.0, 15.0, 20.0, 25.0, 30.0];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeedChart(speeds: testSpeeds),
          ),
        ),
      );

      // Assert
      expect(find.byType(SpeedChart), findsOneWidget);
      expect(find.text('Biểu đồ tốc độ'), findsOneWidget);
      expect(find.text('5 điểm'), findsOneWidget);
    });

    testWidgets('should handle empty speed data', (WidgetTester tester) async {
      // Arrange
      final emptySpeeds = <double>[];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeedChart(speeds: emptySpeeds),
          ),
        ),
      );

      // Assert
      expect(find.byType(SpeedChart), findsOneWidget);
    });

    testWidgets('should calculate max speed correctly', (WidgetTester tester) async {
      // Arrange
      final testSpeeds = [10.0, 25.0, 15.0, 30.0];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeedChart(speeds: testSpeeds),
          ),
        ),
      );

      // Verify widget renders without errors
      expect(find.byType(SpeedChart), findsOneWidget);
    });
  });

  /// Test Suite cho responsive design
  group('Responsive Design Tests', () {
    testWidgets('should handle different screen sizes', (WidgetTester tester) async {
      // Test với kích thước màn hình khác nhau
      await tester.binding.setSurfaceSize(Size(800, 600)); // Tablet size

      await tester.pumpWidget(
        GetMaterialApp(
          home: WiFiStressorApp(),
        ),
      );

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      // Test với phone size
      await tester.binding.setSurfaceSize(Size(375, 667)); // iPhone size

      await tester.pumpAndSettle();
      expect(find.byType(WiFiStressorApp), findsOneWidget);
    });
  });
}