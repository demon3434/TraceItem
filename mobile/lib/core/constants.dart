import 'package:flutter/material.dart';
import 'generated/shared_media_limits.g.dart';

class AppConstants {
  // 186 测试服务器地址（源自 shared/media_limits.json）
  static const String defaultBaseUrl = SharedMediaLimits.defaultBaseUrl;
  static const String apiPrefix = SharedMediaLimits.apiPrefix;

  // 温润大圆角规范 (Squircle 18px ~ 24px)
  static const double squircleRadius = SharedMediaLimits.squircleRadius;
  static const double squircleRadiusSm = SharedMediaLimits.squircleRadiusSm;
  static const BorderRadius squircleBorder =
      BorderRadius.all(Radius.circular(squircleRadius));
  static const BorderRadius squircleBorderSm =
      BorderRadius.all(Radius.circular(squircleRadiusSm));

  // 儿童友好活力多巴胺色板
  static const Color dopamineOrange = Color(0xFFF97316);
  static const Color dopamineAmber = Color(0xFFF59E0B);
  static const Color dopamineStrawberry = Color(0xFFF43F5E);
  static const Color dopamineMint = Color(0xFF10B981);
  static const Color dopamineLime = Color(0xFF84CC16);
  static const Color dopamineSky = Color(0xFF0EA5E9);
  static const Color dopamineLavender = Color(0xFF8B5CF6);
  static const Color dopamineWarmBg = Color(0xFFFAF9F6);

  // 多媒体压缩规格约束 (ADR 0003，源自 shared/media_limits.json)
  static const int imageMaxLongEdge = SharedMediaLimits.imageMaxLongEdge;
  static const int imageJpegQuality = SharedMediaLimits.imageJpegQuality;
  static const int thumbMaxLongEdge = SharedMediaLimits.thumbMaxLongEdge;
  static const int audioMaxDurationSeconds =
      SharedMediaLimits.audioMaxDurationSeconds;
  static const int videoMaxDurationSeconds =
      SharedMediaLimits.videoMaxDurationSeconds;
  static const int thumbJpegQuality = SharedMediaLimits.thumbJpegQuality;
  static const int maxImageAttachments = SharedMediaLimits.maxImageAttachments;
  static const int maxVideoAttachments = SharedMediaLimits.maxVideoAttachments;
  static const int maxAudioAttachments = SharedMediaLimits.maxAudioAttachments;
  static const int mediaCacheDefaultMaxMb =
      SharedMediaLimits.mediaCacheDefaultMaxMb;
  static const String defaultVideoProfile =
      SharedMediaLimits.defaultVideoProfile;
  static const Map<String, VideoProfileConfig> videoProfiles =
      SharedMediaLimits.videoProfiles;

  /// 格式化多媒体文件大小展示（统一保留 0 位小数，如 269 KB, 17 MB）
  static String formatFileSize(int? bytes) => formatFileSizeInt(bytes);

  /// 格式化整数文件大小展示（无小数，用于编辑页缩略图左下角紧凑展示）
  static String formatFileSizeInt(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round().clamp(1, 999999)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).round().clamp(1, 9999)} GB';
  }

  /// 格式化秒数为 MM:SS (如 5 -> 00:05, 120 -> 02:00)
  static String formatDurationMMSS(int? totalSeconds) {
    final safe = (totalSeconds == null || totalSeconds < 0) ? 0 : totalSeconds;
    final minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final seconds = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 格式化限长文案 (整分钟显示 "x分钟"，否则显示 "x秒")
  static String formatDurationLimitLabel(int totalSeconds) {
    if (totalSeconds >= 60 && totalSeconds % 60 == 0) {
      return '${totalSeconds ~/ 60}分钟';
    }
    return '$totalSeconds秒';
  }
}
