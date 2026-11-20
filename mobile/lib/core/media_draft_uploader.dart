import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'media_cache_manager.dart';
import 'media_pipeline.dart';
import 'offline_draft_storage.dart';

/// 媒体上传与离线草稿回退适配器：在线优先上传，断网/超时自动落盘至独立草稿目录
class MediaDraftUploader {
  static Future<({Map<String, dynamic> att, bool isOffline})> uploadOrDraftImage({
    required Uint8List bytes,
    required String filename,
    required int width,
    required int height,
  }) async {
    try {
      final att = await ApiService.instance.uploadImageBytes(bytes, filename);
      return (att: att, isOffline: false);
    } catch (e) {
      final userId = ApiService.instance.currentUser?.id;
      if (userId == null || !ApiService.isNetworkError(e)) rethrow;
      final localPath =
          await OfflineDraftStorage.saveBytes(userId, '.jpg', bytes);
      return (
        att: <String, dynamic>{
          'media_type': 'image',
          'file_path': '',
          'local_path': localPath,
          'file_size': bytes.length,
          'duration_seconds': 0,
          'width': width,
          'height': height,
          'is_offline_draft': true,
        },
        isOffline: true,
      );
    }
  }

  static Future<({Map<String, dynamic> att, bool isOffline})> uploadOrDraftVideo({
    required String filePath,
    required String filename,
    required int durationSeconds,
    String? posterPath,
    int width = 0,
    int height = 0,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final att = await ApiService.instance.uploadVideoFile(
        filePath,
        filename,
        durationSeconds,
        posterPath: posterPath,
        onSendProgress: onSendProgress,
      );
      try {
        final src = File(filePath);
        if (src.existsSync()) {
          await MediaCacheManager.instance.putFile(att['file_path'], src);
        }
      } catch (_) {}
      return (att: att, isOffline: false);
    } catch (e) {
      final userId = ApiService.instance.currentUser?.id;
      if (userId == null || !ApiService.isNetworkError(e)) rethrow;
      final localVideo =
          await OfflineDraftStorage.copyFile(userId, filePath, '.mp4');
      String? localPoster;
      if (posterPath != null &&
          posterPath.isNotEmpty &&
          File(posterPath).existsSync()) {
        localPoster =
            await OfflineDraftStorage.copyFile(userId, posterPath, '.jpg');
      }
      final fileSize = await File(localVideo).length();
      return (
        att: <String, dynamic>{
          'media_type': 'video',
          'file_path': '',
          'local_path': localVideo,
          if (localPoster != null) 'local_poster_path': localPoster,
          'file_size': fileSize,
          'duration_seconds': durationSeconds,
          'width': width,
          'height': height,
          'is_offline_draft': true,
        },
        isOffline: true,
      );
    }
  }

  static Future<({Map<String, dynamic> att, bool isOffline})> uploadOrDraftAudio({
    required Uint8List bytes,
    required String filename,
    required int durationSeconds,
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final att = await ApiService.instance.uploadAudioBytes(
        bytes,
        filename,
        durationSeconds,
        onSendProgress: onSendProgress,
      );
      return (att: att, isOffline: false);
    } catch (e) {
      final userId = ApiService.instance.currentUser?.id;
      if (userId == null || !ApiService.isNetworkError(e)) rethrow;
      final localPath =
          await OfflineDraftStorage.saveBytes(userId, '.m4a', bytes);
      return (
        att: <String, dynamic>{
          'media_type': 'audio',
          'file_path': '',
          'local_path': localPath,
          'file_size': bytes.length,
          'duration_seconds': durationSeconds,
          'width': 0,
          'height': 0,
          'is_offline_draft': true,
        },
        isOffline: true,
      );
    }
  }

  static Future<({Map<String, dynamic> att, bool isOffline})?> rotateOrDraftImage({
    required String filePath,
    required String url,
    required int quarterTurns,
  }) async {
    Uint8List? rawBytes;
    final key = filePath.isNotEmpty ? filePath : url;
    if (key.isNotEmpty && File(key).existsSync()) {
      rawBytes = await File(key).readAsBytes();
    } else {
      final cached = await MediaCacheManager.instance.get(key);
      if (cached != null) {
        rawBytes = await cached.readAsBytes();
      } else {
        final resolved = ApiService.instance.resolveMediaUrl(url);
        final resp = await Dio().get<List<int>>(
          resolved,
          options: Options(
            responseType: ResponseType.bytes,
            headers: ApiService.instance.authHeaders,
          ),
        );
        if (resp.data != null) rawBytes = Uint8List.fromList(resp.data!);
      }
    }
    if (rawBytes == null || rawBytes.isEmpty) return null;

    final rotated = await MediaPipeline.rotateImageBytes(rawBytes, quarterTurns);
    final filename = 'rot_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return uploadOrDraftImage(
      bytes: rotated.mainBytes,
      filename: filename,
      width: rotated.width,
      height: rotated.height,
    );
  }
}
