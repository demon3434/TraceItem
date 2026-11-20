part of 'api_service.dart';

extension ApiServiceMedia on ApiService {
  Future<Map<String, dynamic>> uploadImageBytes(
    Uint8List bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/media/upload/image', data: formData);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadAudioBytes(
    Uint8List bytes,
    String filename,
    int durationSeconds, {
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      '/media/upload/audio',
      data: formData,
      queryParameters: {'duration_seconds': durationSeconds},
      onSendProgress: onSendProgress,
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadVideoFile(
    String filePath,
    String filename,
    int durationSeconds, {
    String? posterPath,
    ProgressCallback? onSendProgress,
  }) async {
    final map = <String, dynamic>{
      'video': await MultipartFile.fromFile(filePath, filename: filename),
    };
    if (posterPath != null && posterPath.isNotEmpty) {
      map['poster'] = await MultipartFile.fromFile(
        posterPath,
        filename: 'poster.jpg',
      );
    }
    final formData = FormData.fromMap(map);
    final res = await _dio.post(
      '/media/upload/video',
      data: formData,
      queryParameters: {'duration_seconds': durationSeconds},
      onSendProgress: onSendProgress,
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> cleanupTempMedia(List<Map<String, String?>> items) async {
    if (items.isEmpty) return;
    try {
      await _dio.post('/media/cleanup-temp', data: {'items': items});
    } catch (_) {}
  }
}
