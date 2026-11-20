import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'dopamine_audio_player.dart';
import 'media_section_header.dart';

class ItemDetailAudioSection extends StatelessWidget {
  final List<Attachment> audios;

  const ItemDetailAudioSection({super.key, required this.audios});

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) return const SizedBox.shrink();
    final theme = ThemeController.instance.current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: theme.ambientShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MediaSectionHeader(
            icon: LucideIcons.mic,
            title: '语音指引',
            count: audios.length,
            maxCount: AppConstants.maxAudioAttachments,
            accentColor: theme.primary,
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: audios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final audio = audios[idx];
              return DopamineAudioPlayer(
                audioUrl: audio.url,
                title: '语音指引备忘 ${idx + 1}',
                initialDurationSeconds: audio.durationSeconds,
                fileSize: audio.fileSize,
              );
            },
          ),
        ],
      ),
    );
  }
}

