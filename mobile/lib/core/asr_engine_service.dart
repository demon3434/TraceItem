import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'app_logger.dart';
import 'asr_model_manager.dart';

class AsrEngineService {
  AsrEngineService._internal();
  static final AsrEngineService instance = AsrEngineService._internal();

  bool _bindingsInited = false;
  String? _loadedModelId;
  sherpa.OfflineRecognizer? _offlineRecognizer;
  sherpa.OnlineRecognizer? _onlineRecognizer;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;
  final List<double> _pcmBuffer = [];
  sherpa.OnlineStream? _onlineStream;

  stt.SpeechToText? _sysSpeech;
  bool _sysInited = false;
  String? _sysLocaleId;
  String _latestSysText = '';

  bool get isStreamingActive {
    final active = AsrModelManager.instance.activeOfflineModel;
    if (active == null) return true; // system STT is streaming
    return active.engineType == 'streaming_zipformer';
  }

  void _ensureBindings() {
    if (_bindingsInited) return;
    sherpa.initBindings();
    _bindingsInited = true;
    AppLogger.instance.voice('ASR', 'sherpa_onnx 原生绑定初始化完成');
  }

  void disposeRecognizer() {
    _offlineRecognizer?.free();
    _offlineRecognizer = null;
    _onlineRecognizer?.free();
    _onlineRecognizer = null;
    _loadedModelId = null;
  }

  Future<String?> _findFile(Directory dir, List<String> patterns) async {
    await for (final f in dir.list()) {
      if (f is! File) continue;
      final name = f.uri.pathSegments.last.toLowerCase();
      for (final p in patterns) {
        if (name.contains(p) && name.endsWith('.onnx')) return f.path;
      }
    }
    return null;
  }

  Future<bool> prepareActiveEngine() async {
    await AsrModelManager.instance.init();
    final active = AsrModelManager.instance.activeOfflineModel;
    if (active == null) {
      return _prepareSystemStt();
    }

    if (_loadedModelId == active.id &&
        (_offlineRecognizer != null || _onlineRecognizer != null)) {
      return true;
    }

    disposeRecognizer();
    _ensureBindings();
    final dir = await AsrModelManager.instance.getModelDirectory(active.id);
    if (dir == null) {
      AppLogger.instance.e('ASR', '本地未找到模型目录: ${active.id}');
      return false;
    }
    final tokensPath = '${dir.path}/tokens.txt';
    final sw = Stopwatch()..start();

    try {
      if (active.engineType == 'offline_sensevoice') {
        final modelPath = await _findFile(dir, ['model.int8', 'model']);
        if (modelPath == null) throw Exception('缺少 model.onnx');
        AppLogger.instance.voice('ASR', '准备加载 SenseVoice: $modelPath');
        _offlineRecognizer = sherpa.OfflineRecognizer(
          sherpa.OfflineRecognizerConfig(
            model: sherpa.OfflineModelConfig(
              senseVoice: sherpa.OfflineSenseVoiceModelConfig(
                model: modelPath,
                language: 'auto',
                useInverseTextNormalization: true,
              ),
              tokens: tokensPath,
              numThreads: 2,
              debug: false,
            ),
          ),
        );
      } else {
        final enc = await _findFile(dir, ['encoder']);
        final dec = await _findFile(dir, ['decoder']);
        final jnr = await _findFile(dir, ['joiner']);
        if (enc == null || dec == null || jnr == null) {
          throw Exception('缺少 Zipformer encoder/decoder/joiner 文件');
        }
        AppLogger.instance.voice('ASR', '准备加载 Zipformer: enc=$enc');
        _onlineRecognizer = sherpa.OnlineRecognizer(
          sherpa.OnlineRecognizerConfig(
            model: sherpa.OnlineModelConfig(
              transducer: sherpa.OnlineTransducerModelConfig(
                encoder: enc,
                decoder: dec,
                joiner: jnr,
              ),
              tokens: tokensPath,
              modelType: '',
              numThreads: 2,
              debug: false,
            ),
          ),
        );
      }
      _loadedModelId = active.id;
      AppLogger.instance.voice(
        'ASR',
        '加载模型 ${active.id} 成功 (${sw.elapsedMilliseconds}ms)',
      );
      return true;
    } catch (e) {
      AppLogger.instance.e('ASR', '加载模型 ${active.id} 失败: $e');
      disposeRecognizer();
      return false;
    }
  }

  Future<bool> _prepareSystemStt() async {
    _sysSpeech ??= stt.SpeechToText();
    if (_sysInited) return true;
    try {
      _sysInited = await _sysSpeech!.initialize(
        onError: (err) => AppLogger.instance.w('SysSTT', '错误: $err'),
        onStatus: (st) => AppLogger.instance.voice('SysSTT', '状态: $st'),
      );
      if (!_sysInited) {
        AppLogger.instance.w('SysSTT', '系统语音引擎 initialize 返回 false');
        return false;
      }
      final locales = await _sysSpeech!.locales();
      for (final loc in locales) {
        if (loc.localeId.toLowerCase().replaceAll('-', '_') == 'zh_cn') {
          _sysLocaleId = loc.localeId;
          break;
        }
      }
      AppLogger.instance.voice(
        'SysSTT',
        '系统语音引擎就绪 (locale=$_sysLocaleId, 可用=${locales.length})',
      );
      return true;
    } catch (e) {
      AppLogger.instance.e('SysSTT', '初始化异常: $e');
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String partial) onPartialResult,
  }) async {
    final ready = await prepareActiveEngine();
    if (!ready) return false;

    final active = AsrModelManager.instance.activeOfflineModel;
    if (active == null) {
      _latestSysText = '';
      await _sysSpeech!.listen(
        onResult: (res) {
          _latestSysText = res.recognizedWords;
          onPartialResult(_latestSysText);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
          localeId: _sysLocaleId,
        ),
      );
      return true;
    }

    _recorder ??= AudioRecorder();
    if (!await _recorder!.hasPermission()) {
      AppLogger.instance.w('ASR', '用户未授予麦克风权限');
      return false;
    }

    _pcmBuffer.clear();
    _onlineStream?.free();
    _onlineStream = active.engineType == 'streaming_zipformer'
        ? _onlineRecognizer?.createStream()
        : null;

    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen((bytes) {
      final samples = _pcm16BytesToFloats(bytes);
      if (_onlineStream != null && _onlineRecognizer != null) {
        _onlineStream!.acceptWaveform(samples: samples, sampleRate: 16000);
        while (_onlineRecognizer!.isReady(_onlineStream!)) {
          _onlineRecognizer!.decode(_onlineStream!);
        }
        final txt = _onlineRecognizer!.getResult(_onlineStream!).text.trim();
        if (txt.isNotEmpty) onPartialResult(txt);
      } else {
        _pcmBuffer.addAll(samples);
      }
    });
    AppLogger.instance.voice('ASR', '开始 16kHz PCM 采集 (${active.id})');
    return true;
  }

  Future<String> stopAndTranscribe() async {
    final active = AsrModelManager.instance.activeOfflineModel;
    if (active == null) {
      await _sysSpeech?.stop();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final res = _latestSysText.trim();
      AppLogger.instance.voice('SysSTT', '识别完成: "$res"');
      return res;
    }

    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();

    final sw = Stopwatch()..start();
    String text = '';
    if (active.engineType == 'streaming_zipformer' &&
        _onlineRecognizer != null &&
        _onlineStream != null) {
      _onlineStream!.inputFinished();
      while (_onlineRecognizer!.isReady(_onlineStream!)) {
        _onlineRecognizer!.decode(_onlineStream!);
      }
      text = _onlineRecognizer!.getResult(_onlineStream!).text.trim();
      _onlineStream!.free();
      _onlineStream = null;
    } else if (_offlineRecognizer != null && _pcmBuffer.isNotEmpty) {
      final stream = _offlineRecognizer!.createStream();
      stream.acceptWaveform(
        samples: Float32List.fromList(_pcmBuffer),
        sampleRate: 16000,
      );
      _offlineRecognizer!.decode(stream);
      text = _offlineRecognizer!.getResult(stream).text.trim();
      stream.free();
    }
    _pcmBuffer.clear();
    AppLogger.instance.voice(
      'ASR',
      '解码完成 (${active.id}, ${sw.elapsedMilliseconds}ms): "$text"',
    );
    return text;
  }

  Future<void> cancelListening() async {
    final active = AsrModelManager.instance.activeOfflineModel;
    if (active == null) {
      await _sysSpeech?.cancel();
    } else {
      await _audioSub?.cancel();
      _audioSub = null;
      await _recorder?.stop();
      _onlineStream?.free();
      _onlineStream = null;
      _pcmBuffer.clear();
    }
    AppLogger.instance.voice('ASR', '已取消本次语音识别');
  }

  Float32List _pcm16BytesToFloats(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final floats = Float32List(count);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      floats[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return floats;
  }
}

