import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/media_cache_manager.dart';
import 'media_section_header.dart';

class DopamineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? posterUrl;
  final int? initialDurationSeconds;
  final int? fileSize;
  final bool autoPlay;
  final bool showTopBadge;

  const DopamineVideoPlayer({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.initialDurationSeconds,
    this.fileSize,
    this.autoPlay = false,
    this.showTopBadge = true,
  });

  /// 打开全屏沉浸式视频预览（屏幕右上角固定红叉关闭按钮，左上角对齐图片全屏信息胶囊）
  static void showFullscreen(
    BuildContext context, {
    required String videoUrl,
    String? posterUrl,
    int initialDurationSeconds = 0,
    int? fileSize,
  }) {
    final durStr = initialDurationSeconds > 0
        ? AppConstants.formatDurationMMSS(initialDurationSeconds)
        : '';
    final sizeStr = AppConstants.formatFileSize(fileSize);
    final infoText = [
      if (durStr.isNotEmpty) durStr,
      if (sizeStr.isNotEmpty) sizeStr,
    ].join(' · ');

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (ctx, _, __) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: DopamineVideoPlayer(
                  videoUrl: videoUrl,
                  posterUrl: posterUrl,
                  initialDurationSeconds: initialDurationSeconds,
                  fileSize: fileSize,
                  autoPlay: true,
                  showTopBadge: false,
                ),
              ),
              Positioned(
                top: MediaQuery.viewPaddingOf(ctx).top + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    if (infoText.isNotEmpty) FullscreenInfoPill(text: infoText),
                    const Spacer(),
                    FullscreenCloseButton(
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<DopamineVideoPlayer> createState() => _DopamineVideoPlayerState();
}

class _DopamineVideoPlayerState extends State<DopamineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = true;
  bool _isCached = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final cached = await MediaCacheManager.instance.get(widget.videoUrl);
    if (!mounted) return;

    if (cached != null) {
      _isCached = true;
      _controller = VideoPlayerController.file(cached);
    } else {
      final resolved = ApiService.instance.resolveMediaUrl(widget.videoUrl);
      if (resolved.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(resolved),
          httpHeaders: ApiService.instance.authHeaders,
        );
        // 后台异步缓存
        MediaCacheManager.instance
            .downloadAndCache(
          widget.videoUrl,
          resolved,
          headers: ApiService.instance.authHeaders,
        )
            .then((file) {
          if (file != null && mounted) {
            setState(() => _isCached = true);
          }
        });
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }
    }

    try {
      await _controller!.initialize();
      if (widget.autoPlay) {
        await _controller!.play();
      }
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('[DopamineVideoPlayer] init error: $e');
    }

    _controller!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppConstants.dopamineSky, strokeWidth: 2),
              SizedBox(height: 10),
              Text(
                '正在秒开加载寻路短视频 (MOOV FastStart)...',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final val = _controller!.value;
    final pos = val.position;
    final dur = val.duration;
    final isPlaying = val.isPlaying;
    final sizeStr = AppConstants.formatFileSize(widget.fileSize);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : 16 / 9,
              child: VideoPlayer(_controller!),
            ),

            // 点击切换控制器显示
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showControls = !_showControls),
                child: Container(color: Colors.transparent),
              ),
            ),

            // 右上角多巴胺半透明磨砂药丸徽章（非全屏模式展示）
            if (widget.showTopBadge && (sizeStr.isNotEmpty || _isCached))
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isCached) ...[
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _isCached
                            ? (sizeStr.isNotEmpty ? '$sizeStr · 本地秒开' : '本地秒开')
                            : (sizeStr.isNotEmpty ? '云端 $sizeStr' : '云端拉流'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 中间大播放按钮
            if (_showControls || !isPlaying)
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),

            // 底部控制与进度条
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: AppConstants.dopamineSky,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: pos.inMilliseconds.toDouble().clamp(0.0, dur.inMilliseconds.toDouble()),
                            min: 0.0,
                            max: dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0,
                            onChanged: (v) {
                              _controller!.seekTo(Duration(milliseconds: v.round()));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
