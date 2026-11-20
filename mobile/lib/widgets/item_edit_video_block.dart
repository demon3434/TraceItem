import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import 'dopamine_video_player.dart';
import 'media_section_header.dart';

class ItemEditVideoBlock extends StatelessWidget {
  final List<Map<String, dynamic>> videos;
  final bool uploading;
  final String? statusText;
  final String? buttonLabel;
  final double? progress;
  final VoidCallback onAddTap;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  const ItemEditVideoBlock({
    super.key,
    required this.videos,
    required this.uploading,
    this.statusText,
    this.buttonLabel,
    this.progress,
    required this.onAddTap,
    required this.onRemove,
    required this.onReorder,
  });

  void _openPreview(BuildContext context, Map<String, dynamic> v) {
    final localPath = v['local_path'] as String?;
    final path = (localPath != null && localPath.isNotEmpty)
        ? localPath
        : (v['file_path'] as String?)?.isNotEmpty == true
            ? v['file_path'] as String
            : (v['url'] as String? ?? '');
    final localPoster = v['local_poster_path'] as String?;
    final thumb = (localPoster != null && localPoster.isNotEmpty)
        ? localPoster
        : (v['thumbnail_path'] as String?)?.isNotEmpty == true
            ? v['thumbnail_path'] as String
            : v['thumbnail_url'] as String?;
    final dur = v['duration_seconds'] as int?;
    final size = v['file_size'] as int?;

    DopamineVideoPlayer.showFullscreen(
      context,
      videoUrl: path,
      posterUrl: thumb,
      initialDurationSeconds: dur ?? 0,
      fileSize: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFull = videos.length >= AppConstants.maxVideoAttachments;
    final limitLabel = AppConstants.formatDurationLimitLabel(
      AppConstants.videoMaxDurationSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaSectionHeader(
          icon: LucideIcons.video,
          title: '寻路短视频',
          count: videos.length,
          maxCount: AppConstants.maxVideoAttachments,
          accentColor: const Color(0xFF0EA5E9),
        ),
        if (videos.isNotEmpty) ...[
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: videos.length,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderItem: onReorder,
            proxyDecorator: (child, _, __) => Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
            itemBuilder: (context, idx) {
              final v = videos[idx];
              final dur = v['duration_seconds'] as int? ?? 0;
              final size = v['file_size'] as int?;
              final sizeLabel = AppConstants.formatFileSize(size);
              final thumb = (v['thumbnail_path'] as String?)?.isNotEmpty == true
                  ? v['thumbnail_path'] as String
                  : v['thumbnail_url'] as String?;

              return Padding(
                key: ValueKey('video_${v['file_path'] ?? idx}_$idx'),
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _openPreview(context, v);
                  },
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            if (videos.length >= 2)
                              ReorderableDragStartListener(
                                index: idx,
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    LucideIcons.gripVertical,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (v['local_poster_path'] != null &&
                                        v['local_poster_path']
                                            .toString()
                                            .isNotEmpty)
                                      Image.file(
                                        File(v['local_poster_path'].toString()),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _videoFallbackCover(),
                                      )
                                    else if (thumb != null && thumb.isNotEmpty)
                                      Image.network(
                                        ApiService.instance.resolveMediaUrl(thumb),
                                        headers: ApiService.instance.authHeaders,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _videoFallbackCover(),
                                      )
                                    else
                                      _videoFallbackCover(),
                                    Center(
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.55),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      child: MediaThumbnailSizeBadge(fileSize: size),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '寻路视频 #${idx + 1}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        '时长 ${AppConstants.formatDurationMMSS(dur)}',
                                        if (sizeLabel.isNotEmpty) sizeLabel,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: MediaCardDeleteButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onRemove(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 10),
        if (uploading)
          MediaStageProgressCard(
            statusText: statusText ?? '正在处理视频...',
            progress: progress,
            accentColor: const Color(0xFF0EA5E9),
          ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onAddTap,
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  isFull ? const Color(0xFFF1F5F9) : const Color(0xFFF0F9FF),
              side: BorderSide(
                color:
                    isFull ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
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
                    LucideIcons.video,
                    size: 17,
                    color: isFull
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0284C7),
                  ),
            label: Text(
              uploading
                  ? (buttonLabel ?? '压缩进度 0%')
                  : (isFull
                      ? '短视频已达上限 (${videos.length}/${AppConstants.maxVideoAttachments})'
                      : '$limitLabel短视频'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isFull
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0284C7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
