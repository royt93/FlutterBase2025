import 'dart:typed_data';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart'; // SafeLogger
import 'package:dio/dio.dart';

/// Đo tốc độ upload bằng cách POST một khối dữ liệu lên endpoint nhận-và-bỏ
/// (Cloudflare `__up`) và tính throughput. Đo trong lúc stress test → upload
/// dưới tải, đúng mục tiêu chẩn đoán.
class UploadSpeedService {
  final Dio _dio;

  UploadSpeedService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
            ));

  static const _url = 'https://speed.cloudflare.com/__up';
  static const _chunkBytes = 1024 * 1024; // 1 MB mỗi lần đo

  /// Upload `bytes` byte, trả tốc độ (Mbps). `null` nếu lỗi/timeout.
  Future<double?> measure({int bytes = _chunkBytes}) async {
    final data = Uint8List(bytes);
    final sw = Stopwatch()..start();
    try {
      await _dio.post(_url, data: data);
      sw.stop();
      final secs = sw.elapsedMicroseconds / 1000000.0;
      if (secs <= 0) return null;
      return (bytes * 8) / (secs * 1000000.0); // Mbps
    } catch (e) {
      sw.stop();
      SafeLogger.d('Upload', 'measure failed: $e');
      return null;
    }
  }

  void close() => _dio.close();
}
