import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'item_detail_gallery.dart';
import 'media_section_header.dart';

class ItemEditImageBlock extends StatelessWidget {
  final List<Map<String, dynamic>> images;
  final bool uploading;
  final VoidCallback onAddTap;
  final ValueChanged<Map<String, dynamic>> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Future<Attachment?> Function(
    int imageIndex,
    Attachment current,
    int quarterTurns,
  )? onRotateImage;

  const ItemEditImageBlock({
    super.key,
    required this.images,
    required this.uploading,
    required this.onAddTap,
    required this.onRemove,
    required this.onReorder,
    this.onRotateImage,
  });

  List<Attachment> _toGalleryAttachments() {
    return images.map((m) {
      final localPath = m['local_path'] as String?;
      final filePath = (localPath != null && localPath.isNotEmpty)
          ? localPath
          : (m['file_path'] as String? ?? '');
      final url = (localPath != null && localPath.isNotEmpty)
          ? localPath
          : (m['url'] as String?)?.isNotEmpty == true
              ? m['url'] as String
              : filePath;
      final thumb = (localPath != null && localPath.isNotEmpty)
          ? localPath
          : (m['thumbnail_url'] as String?)?.isNotEmpty == true
              ? m['thumbnail_url'] as String
              : m['thumbnail_path'] as String?;
      return Attachment(
        id: m['id'] as int? ?? 0,
        itemId: m['item_id'] as int? ?? 0,
        mediaType: 'image',
        filePath: filePath,
        url: url,
        thumbnailUrl: thumb,
        fileSize: m['file_size'] as int? ?? 0,
        durationSeconds: 0,
        width: m['width'] as int? ?? 0,
        height: m['height'] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final isFull = images.length >= AppConstants.maxImageAttachments;
    final itemCount = isFull ? images.length : images.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MediaSectionHeader(
          icon: LucideIcons.camera,
          title: '实景照片 *',
          count: images.length,
          maxCount: AppConstants.maxImageAttachments,
          accentColor: theme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          images.length >= 2
              ? '第 1 张将作为物品封面，长按照片可拖拽调整顺序'
              : '至少上传 1 张照片，第 1 张将作为物品封面',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            if (index == images.length) {
              return _AddPhotoTile(
                uploading: uploading,
                theme: theme,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAddTap();
                },
              );
            }
            final img = images[index];
            final tile = _buildImageTile(context, theme, img, index);
            if (images.length < 2) return tile;

            return DragTarget<int>(
              onWillAcceptWithDetails: (details) => details.data != index,
              onAcceptWithDetails: (details) {
                HapticFeedback.mediumImpact();
                onReorder(details.data, index);
              },
              builder: (context, candidateData, _) {
                final isHovered = candidateData.isNotEmpty;
                return LongPressDraggable<int>(
                  data: index,
                  onDragStarted: () => HapticFeedback.mediumImpact(),
                  feedback: SizedBox(
                    width: 96,
                    height: 96,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      child: tile,
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.35, child: tile),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: isHovered
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.primary, width: 2.2),
                          )
                        : null,
                    child: tile,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildImageTile(
    BuildContext context,
    dynamic theme,
    Map<String, dynamic> img,
    int index,
  ) {
    final path = (img['thumbnail_path'] as String?)?.isNotEmpty == true
        ? img['thumbnail_path'] as String
        : (img['thumbnail_url'] as String?)?.isNotEmpty == true
            ? img['thumbnail_url'] as String
            : (img['file_path'] as String? ?? img['url'] as String? ?? '');
    final fileSize = img['file_size'] as int?;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ItemDetailGallery.show(
          context,
          _toGalleryAttachments(),
          initialIndex: index,
          onRotateSave: onRotateImage,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.lightBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img['local_path'] != null &&
                img['local_path'].toString().isNotEmpty)
              Image.file(
                File(img['local_path'].toString()),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(
                    LucideIcons.imageOff,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              )
            else
              Image.network(
                ApiService.instance.resolveMediaUrl(path),
                headers: ApiService.instance.authHeaders,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Icon(
                    LucideIcons.imageOff,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            if (index == 0)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '封面',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (fileSize != null && fileSize > 0)
              Positioned(
                left: 0,
                bottom: 0,
                child: MediaThumbnailSizeBadge(fileSize: fileSize),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: MediaCardDeleteButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onRemove(img);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final bool uploading;
  final dynamic theme;
  final VoidCallback onTap;

  const _AddPhotoTile({
    required this.uploading,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.lightBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.primary.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
        child: uploading
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.primary,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.camera, size: 22, color: theme.primary),
                  const SizedBox(height: 6),
                  Text(
                    '添加照片',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.darkText,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
