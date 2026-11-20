// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: shared/media_limits.json (sync via scripts/sync_shared.py)

class VideoProfileConfig {
  final String key;
  final String label;
  final int width;
  final int height;
  final int targetBitrateKbps;
  final int fps;
  final String description;

  const VideoProfileConfig({
    required this.key,
    required this.label,
    required this.width,
    required this.height,
    required this.targetBitrateKbps,
    required this.fps,
    required this.description,
  });
}

class SharedMediaLimits {
  static const String defaultBaseUrl = 'http://192.168.7.186:8085';
  static const String apiPrefix = '/api';
  static const double squircleRadius = 22.0;
  static const double squircleRadiusSm = 14.0;
  static const int imageMaxLongEdge = 1600;
  static const int imageJpegQuality = 82;
  static const int thumbMaxLongEdge = 300;
  static const int thumbJpegQuality = 75;
  static const int audioMaxDurationSeconds = 120;
  static const int videoMaxDurationSeconds = 60;
  static const int maxImageAttachments = 9;
  static const int maxVideoAttachments = 3;
  static const int maxAudioAttachments = 3;
  static const int mediaCacheDefaultMaxMb = 200;
  static const String defaultVideoProfile = '720p';

  static const Map<String, VideoProfileConfig> videoProfiles = {
    '360p': VideoProfileConfig(
      key: '360p',
      label: '极速省流',
      width: 640,
      height: 360,
      targetBitrateKbps: 450,
      fps: 24,
      description: '极速省流 (适合公网弱网)',
    ),
    '480p': VideoProfileConfig(
      key: '480p',
      label: '流畅标清',
      width: 854,
      height: 480,
      targetBitrateKbps: 800,
      fps: 25,
      description: '流畅省流 (兼顾细节与加载速度)',
    ),
    '720p': VideoProfileConfig(
      key: '720p',
      label: '高清标准',
      width: 1280,
      height: 720,
      targetBitrateKbps: 1400,
      fps: 30,
      description: '高清推荐 (系统默认)',
    ),
    '1080p': VideoProfileConfig(
      key: '1080p',
      label: '超清细腻',
      width: 1920,
      height: 1080,
      targetBitrateKbps: 2800,
      fps: 30,
      description: '超清细腻 (精密物件与文字特写)',
    ),
  };
}
