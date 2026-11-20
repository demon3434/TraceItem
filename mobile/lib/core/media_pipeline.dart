import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';
import 'app_logger.dart';
import 'constants.dart';
import 'mp4_faststart.dart';

class CompressedImageResult {
  final Uint8List mainBytes;
  final Uint8List thumbBytes;
  final int width;
  final int height;
  final int sizeBytes;

  CompressedImageResult({
    required this.mainBytes,
    required this.thumbBytes,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });
}

class CompressedVideoResult {
  final String filePath;
  final String? posterPath;
  final int durationSeconds;
  final int sizeBytes;

  CompressedVideoResult({
    required this.filePath,
    this.posterPath,
    required this.durationSeconds,
    required this.sizeBytes,
  });
}

CompressedImageResult _processImageInIsolate(Uint8List rawBytes) {
  img.Image? decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw Exception('无法解析所选图片 (bytes=${rawBytes.length})');
  }
  decoded = img.bakeOrientation(decoded);

  final int origW = decoded.width;
  final int origH = decoded.height;
  final int longEdge = origW > origH ? origW : origH;

  img.Image resizedMain;
  if (longEdge > AppConstants.imageMaxLongEdge) {
    final double ratio = AppConstants.imageMaxLongEdge / longEdge;
    final int newW =
        (origW * ratio).round().clamp(1, AppConstants.imageMaxLongEdge);
    final int newH =
        (origH * ratio).round().clamp(1, AppConstants.imageMaxLongEdge);
    resizedMain = img.copyResize(
      decoded,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );
  } else {
    resizedMain = decoded;
  }

  final Uint8List mainJpeg = Uint8List.fromList(
    img.encodeJpg(resizedMain, quality: AppConstants.imageJpegQuality),
  );

  final int mainLong = resizedMain.width > resizedMain.height
      ? resizedMain.width
      : resizedMain.height;
  final double thumbRatio = AppConstants.thumbMaxLongEdge / mainLong;
  final int thumbW =
      (resizedMain.width * thumbRatio).round().clamp(1, AppConstants.thumbMaxLongEdge);
  final int thumbH =
      (resizedMain.height * thumbRatio).round().clamp(1, AppConstants.thumbMaxLongEdge);
  final img.Image thumbImg = img.copyResize(
    resizedMain,
    width: thumbW,
    height: thumbH,
    interpolation: img.Interpolation.linear,
  );

  final Uint8List thumbJpeg = Uint8List.fromList(
    img.encodeJpg(thumbImg, quality: AppConstants.thumbJpegQuality),
  );

  return CompressedImageResult(
    mainBytes: mainJpeg,
    thumbBytes: thumbJpeg,
    width: resizedMain.width,
    height: resizedMain.height,
    sizeBytes: mainJpeg.lengthInBytes,
  );
}

class MediaPipeline {
  static const String _kVideoProfilePrefKey = 'traceitem_pref_video_profile';

  /// 端侧图片压缩流水线 (相机与相册统一执行，后台 Isolate 处理避免阻塞 UI)
  static Future<CompressedImageResult> processImageBytes(
    Uint8List rawBytes,
  ) async {
    return compute(_processImageInIsolate, rawBytes);
  }

  static Future<CompressedImageResult> processXFile(XFile file) async {
    final Uint8List rawBytes = await file.readAsBytes();
    AppLogger.instance.media(
      'Image',
      '准备压缩图片: name=${file.name}, rawSize=${AppConstants.formatFileSize(rawBytes.length)} (${rawBytes.length}B)',
    );
    final res = await processImageBytes(rawBytes);
    AppLogger.instance.media(
      'Image',
      '图片压缩完成: ${res.width}x${res.height}, compressedSize=${AppConstants.formatFileSize(res.sizeBytes)}',
    );
    return res;
  }

  /// 端侧视频压缩流水线 (相机与相册统一按用户画质档位压缩、限制最大时长并提取首帧缩略图)
  static Future<CompressedVideoResult> compressVideoFile(
    String sourcePath, {
    void Function(double progress)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profile =
        prefs.getString(_kVideoProfilePrefKey) ?? AppConstants.defaultVideoProfile;

    final quality = switch (profile) {
      '360p' => VideoQuality.LowQuality,
      '480p' => VideoQuality.MediumQuality,
      '1080p' => VideoQuality.Res1920x1080Quality,
      _ => VideoQuality.Res1280x720Quality,
    };

    final origFile = File(sourcePath);
    final origBytes = origFile.existsSync() ? origFile.lengthSync() : 0;
    final srcInfo = await VideoCompress.getMediaInfo(sourcePath);
    final srcDurSec = ((srcInfo.duration ?? 0) / 1000).round();

    AppLogger.instance.media(
      'Video',
      '开始压缩视频: profile=$profile, origSize=${AppConstants.formatFileSize(origBytes)}, origDur=${srcDurSec}s',
    );

    final sub = VideoCompress.compressProgress$.subscribe((p) {
      onProgress?.call((p / 100.0).clamp(0.0, 1.0));
    });

    try {
      // 仅当原视频超过最大时长上限时才传 duration 截断，避免短视频触发部分机型 Mp4Composer 异常返回空
      final int? trimDuration = srcDurSec > AppConstants.videoMaxDurationSeconds
          ? AppConstants.videoMaxDurationSeconds
          : null;

      MediaInfo? compressed = await _tryCompressVideo(
        sourcePath,
        quality: quality,
        trimDuration: trimDuration,
      );

      // 部分机型硬编解码器不支持指定分辨率（如竖屏/4K/HDR 强制 720p），自动降级为自适应画质重试
      if ((compressed == null || compressed.file == null) &&
          quality != VideoQuality.MediumQuality) {
        AppLogger.instance.media(
          'Video',
          '主画质 ($profile) 压缩返回空，自动降级为 MediumQuality 重试',
        );
        compressed = await _tryCompressVideo(
          sourcePath,
          quality: VideoQuality.MediumQuality,
          trimDuration: trimDuration,
        );
      }

      if (compressed == null || compressed.file == null) {
        AppLogger.instance.media(
          'Video',
          'MediumQuality 压缩仍返回空，尝试 DefaultQuality',
        );
        compressed = await _tryCompressVideo(
          sourcePath,
          quality: VideoQuality.DefaultQuality,
          trimDuration: trimDuration,
        );
      }

      // 若全部转码档位均受限于系统硬解返回空，且原视频在允许时长与合理体积（<= 50MB）内，直传原视频兜底
      late File outFile;
      late final int outDurSec;
      if (compressed != null && compressed.file != null) {
        outFile = compressed.file!;
        outDurSec = ((compressed.duration ?? srcInfo.duration ?? 0) / 1000)
            .round()
            .clamp(1, AppConstants.videoMaxDurationSeconds);
      } else if (origFile.existsSync() &&
          origBytes > 0 &&
          origBytes <= 50 * 1024 * 1024 &&
          srcDurSec <= AppConstants.videoMaxDurationSeconds) {
        AppLogger.instance.media(
          'Video',
          '端侧转码器均返回空，且视频在安全范围内，降级直传原文件',
        );
        outFile = origFile;
        outDurSec = srcDurSec.clamp(1, AppConstants.videoMaxDurationSeconds);
      } else {
        throw Exception('端侧视频压缩返回空文件');
      }

      // 上传前确保 moov atom 位于 mdat 之前 (+faststart)，实现公网/局域网秒开起播
      final isOrigFallback = outFile.path == origFile.path;
      try {
        final fastPath = await Mp4Faststart.ensureMoovFirst(
          outFile.path,
          inPlace: !isOrigFallback,
        );
        if (fastPath != outFile.path) {
          outFile = File(fastPath);
        }
      } catch (e) {
        AppLogger.instance.media('Video', 'moov 前置重排跳过: $e');
      }

      final outBytes = outFile.existsSync() ? outFile.lengthSync() : 0;

      String? posterPath;
      try {
        final thumbFile = await VideoCompress.getFileThumbnail(
          outFile.path,
          quality: 75,
        );
        if (thumbFile.existsSync()) {
          posterPath = thumbFile.path;
        }
      } catch (_) {}

      AppLogger.instance.media(
        'Video',
        '视频压缩完成: outSize=${AppConstants.formatFileSize(outBytes)}, outDur=${outDurSec}s, poster=${posterPath != null}',
      );

      return CompressedVideoResult(
        filePath: outFile.path,
        posterPath: posterPath,
        durationSeconds: outDurSec,
        sizeBytes: outBytes,
      );
    } finally {
      sub.unsubscribe();
    }
  }

  /// 在后台 Isolate 中顺时针旋转图片 (quarterTurns * 90°) 并重新编码为 JPEG
  static Future<CompressedImageResult> rotateImageBytes(
    Uint8List rawBytes,
    int quarterTurns,
  ) {
    return compute(
      _rotateImageInIsolate,
      _RotateImageArgs(rawBytes, quarterTurns),
    );
  }

  static Future<MediaInfo?> _tryCompressVideo(
    String sourcePath, {
    required VideoQuality quality,
    int? trimDuration,
  }) async {
    try {
      return await VideoCompress.compressVideo(
        sourcePath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
        duration: trimDuration,
      );
    } catch (_) {
      return null;
    }
  }
}

class _RotateImageArgs {
  final Uint8List rawBytes;
  final int quarterTurns;
  const _RotateImageArgs(this.rawBytes, this.quarterTurns);
}

CompressedImageResult _rotateImageInIsolate(_RotateImageArgs args) {
  img.Image? decoded = img.decodeImage(args.rawBytes);
  if (decoded == null) {
    throw Exception('无法解析图片进行旋转');
  }
  final turns = args.quarterTurns % 4;
  final rotated =
      turns == 0 ? decoded : img.copyRotate(decoded, angle: turns * 90);
  final Uint8List mainJpeg = Uint8List.fromList(
    img.encodeJpg(rotated, quality: AppConstants.imageJpegQuality),
  );
  final int longEdge =
      rotated.width > rotated.height ? rotated.width : rotated.height;
  final double thumbRatio = AppConstants.thumbMaxLongEdge / longEdge;
  final int thumbW =
      (rotated.width * thumbRatio).round().clamp(1, AppConstants.thumbMaxLongEdge);
  final int thumbH =
      (rotated.height * thumbRatio).round().clamp(1, AppConstants.thumbMaxLongEdge);
  final img.Image thumbImg = img.copyResize(
    rotated,
    width: thumbW,
    height: thumbH,
    interpolation: img.Interpolation.linear,
  );
  final Uint8List thumbJpeg = Uint8List.fromList(
    img.encodeJpg(thumbImg, quality: AppConstants.thumbJpegQuality),
  );
  return CompressedImageResult(
    mainBytes: mainJpeg,
    thumbBytes: thumbJpeg,
    width: rotated.width,
    height: rotated.height,
    sizeBytes: mainJpeg.length,
  );
}
