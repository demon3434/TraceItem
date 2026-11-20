import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/media_cache_manager.dart';

class DopamineAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String? title;
  final int? initialDurationSeconds;
  final int? fileSize;
  final Widget? trailing;

  const DopamineAudioPlayer({
    super.key,
    required this.audioUrl,
    this.title,
    this.initialDurationSeconds,
    this.fileSize,
    this.trailing,
  });

  @override
  State<DopamineAudioPlayer> createState() => _DopamineAudioPlayerState();
}

class _DopamineAudioPlayerState extends State<DopamineAudioPlayer> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isSeeking = false;
  bool _isCached = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialDurationSeconds != null && widget.initialDurationSeconds! > 0) {
      _duration = Duration(seconds: widget.initialDurationSeconds!);
    }
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      if (mounted && !_isSeeking) {
        setState(() => _position = p);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });

    _checkCacheStatus();
  }

  Future<void> _checkCacheStatus() async {
    final cached = await MediaCacheManager.instance.get(widget.audioUrl);
    if (cached != null && mounted) {
      setState(() => _isCached = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      final cached = await MediaCacheManager.instance.get(widget.audioUrl);
      if (cached != null) {
        if (!_isCached && mounted) setState(() => _isCached = true);
        await _player.play(DeviceFileSource(cached.path));
      } else {
        final resolved = ApiService.instance.resolveMediaUrl(widget.audioUrl);
        if (resolved.startsWith('http')) {
          final authUrl =
              ApiService.instance.resolveAuthenticatedMediaUrl(widget.audioUrl);
          await _player.play(UrlSource(authUrl));
          MediaCacheManager.instance
              .downloadAndCache(
            widget.audioUrl,
            resolved,
            headers: ApiService.instance.authHeaders,
          )
              .then((file) {
            if (file != null && mounted) {
              setState(() => _isCached = true);
            }
          });
        } else {
          await _player.play(DeviceFileSource(widget.audioUrl));
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = _playerState == PlayerState.playing;
    final maxSec = _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final curSec = _position.inSeconds.toDouble().clamp(0.0, maxSec);
    final sizeStr = AppConstants.formatFileSize(widget.fileSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 播放/暂停圆形按钮
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? '现场语音指引备忘录',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (sizeStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _isCached ? '$sizeStr · 本地秒开' : sizeStr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: const Color(0xFFD97706),
              inactiveTrackColor: const Color(0xFFFDE68A),
              thumbColor: const Color(0xFFB45309),
            ),
            child: Slider(
              value: curSec,
              min: 0.0,
              max: maxSec,
              onChangeStart: (_) => _isSeeking = true,
              onChanged: (val) {
                setState(() => _position = Duration(seconds: val.round()));
              },
              onChangeEnd: (val) async {
                _isSeeking = false;
                await _player.seek(Duration(seconds: val.round()));
              },
            ),
          ),
        ],
      ),
    );
  }
}
