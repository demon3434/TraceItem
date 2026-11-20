import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../core/constants.dart';
import 'dopamine_audio_player.dart';

class AudioRecordResult {
  final Uint8List bytes;
  final String path;
  final int durationSeconds;

  AudioRecordResult({
    required this.bytes,
    required this.path,
    required this.durationSeconds,
  });
}

class AudioRecordSheet extends StatefulWidget {
  const AudioRecordSheet({super.key});

  static Future<AudioRecordResult?> show(BuildContext context) {
    return showModalBottomSheet<AudioRecordResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(top: 10),
          child: AudioRecordSheet(),
        ),
      ),
    );
  }

  @override
  State<AudioRecordSheet> createState() => _AudioRecordSheetState();
}

enum _RecordState { idle, recording, done }

class _AudioRecordSheetState extends State<AudioRecordSheet> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  _RecordState _state = _RecordState.idle;

  Timer? _timer;
  int _seconds = 0;
  String? _recordedFilePath;
  Uint8List? _recordedBytes;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/memo_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 48000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: filePath,
    );

    setState(() {
      _state = _RecordState.recording;
      _seconds = 0;
      _recordedFilePath = filePath;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds >= AppConstants.audioMaxDurationSeconds) {
        _stopRecording();
      } else {
        setState(() => _seconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _recordedFilePath = path;
          _recordedBytes = bytes;
          _state = _RecordState.done;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _state = _RecordState.idle;
      _seconds = 0;
      _recordedFilePath = null;
      _recordedBytes = null;
    });
  }

  void _confirm() {
    if (_recordedBytes != null && _recordedFilePath != null) {
      Navigator.of(context).pop(
        AudioRecordResult(
          bytes: _recordedBytes!,
          path: _recordedFilePath!,
          durationSeconds: _seconds > 0 ? _seconds : 1,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部小手柄
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          const Text(
            '录制语音指引备忘录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          const Text(
            '单声道 AAC 48kbps · 限长 ${AppConstants.audioMaxDurationSeconds} 秒 · 方便老人孩子即点即听',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),

          if (_state == _RecordState.idle) ...[
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppConstants.dopamineOrange, AppConstants.dopamineAmber],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppConstants.dopamineOrange.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
              ),
            ),
            const SizedBox(height: 14),
            const Text('轻触开始录音', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ] else if (_state == _RecordState.recording) ...[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE11D48), width: 3),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFE11D48), size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              '${AppConstants.formatDurationMMSS(_seconds)} / ${AppConstants.formatDurationMMSS(AppConstants.audioMaxDurationSeconds)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: const Text('完成录音', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ] else if (_state == _RecordState.done && _recordedFilePath != null) ...[
            DopamineAudioPlayer(
              audioUrl: _recordedFilePath!,
              title: '录制完成备忘录预览',
              initialDurationSeconds: _seconds,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('重新录制', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.dopamineOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('确认使用', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

