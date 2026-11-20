import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import 'dopamine_audio_player.dart';
import 'media_section_header.dart';

class ItemEditAudioBlock extends StatelessWidget {
  final List<Map<String, dynamic>> audios;
  final bool uploading;
  final String? statusText;
  final String? buttonLabel;
  final double? progress;
  final VoidCallback onAddTap;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ItemEditAudioBlock({
    super.key,
    required this.audios,
    required this.uploading,
    this.statusText,
    this.buttonLabel,
    this.progress,
    required this.onAddTap,
    required this.onRemove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final isFull = audios.length >= AppConstants.maxAudioAttachments;
    final limitLabel = AppConstants.formatDurationLimitLabel(
      AppConstants.audioMaxDurationSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaSectionHeader(
          icon: LucideIcons.mic,
          title: '语音指引',
          count: audios.length,
          maxCount: AppConstants.maxAudioAttachments,
          accentColor: theme.primary,
        ),
        if (audios.isNotEmpty) ...[
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: audios.length,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderItem: onReorder,
            proxyDecorator: (child, _, __) => Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
            itemBuilder: (context, idx) {
              final a = audios[idx];
              final localPath = a['local_path'] as String?;
              final path = (localPath != null && localPath.isNotEmpty)
                  ? localPath
                  : (a['file_path'] as String?)?.isNotEmpty == true
                      ? a['file_path'] as String
                      : (a['url'] as String? ?? '');
              final dur = a['duration_seconds'] as int? ?? 0;
              final size = a['file_size'] as int?;

              return Padding(
                key: ValueKey('audio_${path}_$idx'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (audios.length >= 2)
                      ReorderableDragStartListener(
                        index: idx,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(
                            LucideIcons.gripVertical,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          DopamineAudioPlayer(
                            audioUrl: path,
                            title: '语音备忘 #${idx + 1}',
                            initialDurationSeconds: dur,
                            fileSize: size,
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: MediaCardDeleteButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onRemove(a);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 10),
        if (uploading)
          MediaStageProgressCard(
            statusText: statusText ?? '正在处理并上传语音...',
            progress: progress,
            accentColor: const Color(0xFFF43F5E),
          ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onAddTap,
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  isFull ? const Color(0xFFF1F5F9) : theme.lightBg,
              side: BorderSide(
                color: isFull ? const Color(0xFFE2E8F0) : theme.lightBorder,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    LucideIcons.mic,
                    size: 17,
                    color: isFull ? const Color(0xFF94A3B8) : theme.primary,
                  ),
            label: Text(
              uploading
                  ? (buttonLabel ?? '上传进度 0%')
                  : (isFull
                      ? '语音已达上限 (${audios.length}/${AppConstants.maxAudioAttachments})'
                      : '$limitLabel录音'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isFull ? const Color(0xFF94A3B8) : theme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
