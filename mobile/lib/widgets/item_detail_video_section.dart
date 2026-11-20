import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../models/models.dart';
import 'dopamine_video_player.dart';
import 'media_section_header.dart';
import '../core/theme_controller.dart';

class ItemDetailVideoSection extends StatefulWidget {
  final List<Attachment> videos;

  const ItemDetailVideoSection({super.key, required this.videos});

  @override
  State<ItemDetailVideoSection> createState() => _ItemDetailVideoSectionState();
}

class _ItemDetailVideoSectionState extends State<ItemDetailVideoSection> {
  void _openPreview(BuildContext context, Attachment video) {
    DopamineVideoPlayer.showFullscreen(
      context,
      videoUrl: video.url,
      posterUrl: video.thumbnailUrl,
      initialDurationSeconds: video.durationSeconds,
      fileSize: video.fileSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) return const SizedBox.shrink();
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
            icon: LucideIcons.video,
            title: '寻路短视频',
            count: widget.videos.length,
            maxCount: AppConstants.maxVideoAttachments,
            accentColor: const Color(0xFF0EA5E9),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.videos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (ctx, idx) {
              final video = widget.videos[idx];
              return GestureDetector(
                onTap: () => _openPreview(context, video),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: const Color(0xFF0F172A),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (video.thumbnailUrl != null)
                          Image.network(
                            ApiService.instance.resolveMediaUrl(video.thumbnailUrl!),
                            headers: ApiService.instance.authHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(LucideIcons.film, color: Colors.white24, size: 28),
                            ),
                          )
                        else
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(LucideIcons.film, color: Colors.white24, size: 28),
                            ),
                          ),
                        Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: MediaThumbnailSizeBadge(fileSize: video.fileSize),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
