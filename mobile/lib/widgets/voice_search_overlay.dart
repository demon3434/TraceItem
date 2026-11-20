import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/asr_engine_service.dart';
import '../core/asr_model_manager.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../core/voice_query_tokenizer.dart';
import 'custom_dialogs.dart';
import 'voice_model_download_sheet.dart';
import 'voice_word_picker_card.dart';

enum _VoiceModeState { idle, recording, cancelling, finishing, picking }

class VoiceSearchOverlay extends StatefulWidget {
  final List<String> domainVocabulary;
  final ValueChanged<String> onRecognized;
  final VoidCallback onCancel;
  final VoidCallback onUnavailable;

  const VoiceSearchOverlay({
    super.key,
    this.domainVocabulary = const [],
    required this.onRecognized,
    required this.onCancel,
    required this.onUnavailable,
  });

  static Future<void> openWithEngineCheck(
    BuildContext context, {
    required VoidCallback onReadyOpen,
  }) async {
    final mgr = AsrModelManager.instance;
    await mgr.init();
    if (!context.mounted) return;
    if (mgr.selectedEngineId == AsrModelManager.systemEngineId ||
        mgr.activeOfflineModel != null) {
      onReadyOpen();
      return;
    }
    final ready = await showVoiceModelDownloadSheet(context);
    if (ready && context.mounted) {
      onReadyOpen();
    }
  }

  static void handleUnavailableFallback(
    BuildContext context,
    FocusNode searchFocusNode,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) searchFocusNode.requestFocus();
    });
    CustomDialogs.showToast(
      context,
      '语音识别引擎不可用',
      description: '已为您打开键盘，可使用键盘语音或前往「设置 → 语音识别模型」下载离线模型',
    );
  }

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  _VoiceModeState _modeState = _VoiceModeState.idle;
  String _recognizedWords = '';
  String _hintSubtext = '例如：“指甲刀放在哪了”、“去年的红围巾”';
  VoiceTokenizeResult? _tokenizeResult;
  bool _hasNotifiedUnavailable = false;
  Future<bool>? _prepareFuture;
  double? _pressStartY;
  int _sessionToken = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _prepareFuture = AsrEngineService.instance.prepareActiveEngine();
  }

  @override
  void dispose() {
    _sessionToken++;
    _animController.dispose();
    AsrEngineService.instance.cancelListening();
    super.dispose();
  }

  void _notifyUnavailable() {
    if (_hasNotifiedUnavailable || !mounted) return;
    _hasNotifiedUnavailable = true;
    _animController.stop();
    widget.onUnavailable();
  }

  Future<void> _startListening() async {
    final token = ++_sessionToken;
    final streaming = AsrEngineService.instance.isStreamingActive;
    setState(() {
      _modeState = _VoiceModeState.recording;
      _recognizedWords = '';
      _tokenizeResult = null;
      _hintSubtext = streaming ? '松开立即查找 · 上滑取消' : '正在聆听，松开即刻整句识别';
    });
    _animController.repeat(reverse: true);

    final prepared = await (_prepareFuture ?? Future.value(false));
    if (!prepared) {
      _notifyUnavailable();
      return;
    }
    if (!mounted ||
        token != _sessionToken ||
        _modeState != _VoiceModeState.recording) {
      return;
    }

    final started = await AsrEngineService.instance.startListening(
      onPartialResult: (partial) {
        if (mounted && token == _sessionToken) {
          setState(() => _recognizedWords = partial);
        }
      },
    );
    if (!started) _notifyUnavailable();
  }

  void _handlePointerMove(double globalY) {
    if (_modeState != _VoiceModeState.recording &&
        _modeState != _VoiceModeState.cancelling) {
      return;
    }
    final startY = _pressStartY;
    if (startY == null) return;
    final next = (globalY - startY) < -60
        ? _VoiceModeState.cancelling
        : _VoiceModeState.recording;
    if (next != _modeState) {
      HapticFeedback.selectionClick();
      setState(() => _modeState = next);
    }
  }

  Future<void> _handlePointerUp() async {
    _pressStartY = null;
    if (_modeState == _VoiceModeState.idle ||
        _modeState == _VoiceModeState.finishing ||
        _modeState == _VoiceModeState.picking) {
      return;
    }
    if (_modeState == _VoiceModeState.cancelling) {
      await _cancelCurrentRecording(hint: '已取消本次录音，可再次按住说话');
      return;
    }

    final token = _sessionToken;
    setState(() {
      _modeState = _VoiceModeState.finishing;
      _hintSubtext = '正在识别...';
    });
    _animController.stop();
    _animController.reset();

    final text = await AsrEngineService.instance.stopAndTranscribe();
    if (!mounted || token != _sessionToken) return;

    final tokenized = VoiceQueryTokenizer.tokenize(
      text,
      domainVocabulary: widget.domainVocabulary,
    );
    if (tokenized.candidates.isNotEmpty) {
      setState(() {
        _tokenizeResult = tokenized;
        _modeState = _VoiceModeState.picking;
      });
    } else {
      widget.onCancel();
      CustomDialogs.showToast(context, '未识别到有效语音，请重试');
    }
  }

  Future<void> _cancelCurrentRecording({
    String hint = '例如：“指甲刀放在哪了”、“去年的红围巾”',
  }) async {
    _pressStartY = null;
    _sessionToken++;
    _animController.stop();
    _animController.reset();
    await AsrEngineService.instance.cancelListening();
    if (!mounted) return;
    setState(() {
      _modeState = _VoiceModeState.idle;
      _recognizedWords = '';
      _tokenizeResult = null;
      _hintSubtext = hint;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final isIdle = _modeState == _VoiceModeState.idle;
    final isCancelling = _modeState == _VoiceModeState.cancelling;
    final isFinishing = _modeState == _VoiceModeState.finishing;
    final isPicking = _modeState == _VoiceModeState.picking;

    final activeGradient = isCancelling
        ? const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFF43F5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : theme.primaryGradient;
    final glowColor = isCancelling ? const Color(0xFFEF4444) : theme.primary;

    final cardTitle = isCancelling
        ? '松开手指 取消录音'
        : isIdle
            ? '按住下方按钮说话'
            : (_recognizedWords.isEmpty
                ? (isFinishing ? '正在识别...' : '正在聆听，请说话...')
                : _recognizedWords);
    final cardSub = isCancelling ? '已进入取消区域，松手将放弃本次录音' : _hintSubtext;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (isIdle || isPicking) ? widget.onCancel : null,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16),
                  child: GestureDetector(
                    onTap: () {
                      AsrEngineService.instance.cancelListening();
                      widget.onCancel();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.x,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (isPicking && _tokenizeResult != null)
                VoiceWordPickerCard(
                  result: _tokenizeResult!,
                  onRetry: () => _cancelCurrentRecording(),
                  onConfirm: widget.onRecognized,
                )
              else
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppConstants.squircleBorder,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          cardTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isCancelling
                                ? const Color(0xFFEF4444)
                                : (isIdle || _recognizedWords.isEmpty
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF0F172A)),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cardSub,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (!isPicking) ...[
                Listener(
                  onPointerDown: (event) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    if (_modeState != _VoiceModeState.idle) return;
                    _pressStartY = event.position.dy;
                    HapticFeedback.mediumImpact();
                    _startListening();
                  },
                  onPointerMove: (event) =>
                      _handlePointerMove(event.position.dy),
                  onPointerUp: (_) => _handlePointerUp(),
                  onPointerCancel: (_) => _cancelCurrentRecording(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (ctx, child) {
                          final scale = (isIdle || isFinishing)
                              ? 1.0
                              : (isCancelling ? 0.94 : _scaleAnimation.value);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: activeGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: glowColor.withValues(
                                      alpha: isIdle ? 0.35 : 0.48,
                                    ),
                                    blurRadius: isIdle ? 20 : 30 * scale,
                                    spreadRadius:
                                        isIdle ? 2 : 8 * (scale - 1.0),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isCancelling ? LucideIcons.x : LucideIcons.mic,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isCancelling
                              ? const Color(0xFFEF4444).withValues(alpha: 0.28)
                              : Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCancelling
                              ? '松开手指 取消录音'
                              : isIdle
                                  ? '按住说话 · 轻点空白处退出'
                                  : isFinishing
                                      ? '正在识别...'
                                      : '松开立即搜索 · 上滑取消',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
