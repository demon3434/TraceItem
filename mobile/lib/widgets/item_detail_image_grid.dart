import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'item_detail_gallery.dart';
import 'media_section_header.dart';

class ItemDetailImageGrid extends StatelessWidget {
  final List<Attachment> images;

  const ItemDetailImageGrid({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
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
            icon: LucideIcons.camera,
            title: '实景照片',
            count: images.length,
            maxCount: AppConstants.maxImageAttachments,
            accentColor: theme.primary,
          ),
          const SizedBox(height: 12),
          if (images.length == 1)
            _buildSingleImage(context, images.first)
          else
            _buildGridImages(context),
        ],
      ),
    );
  }

  Widget _buildSingleImage(BuildContext context, Attachment img) {
    return GestureDetector(
      onTap: () => ItemDetailGallery.show(context, images, initialIndex: 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 160,
          width: double.infinity,
          color: const Color(0xFFF1F5F9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                ApiService.instance.resolveMediaUrl(img.thumbnailUrl ?? img.url),
                headers: ApiService.instance.authHeaders,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(LucideIcons.image, color: Colors.grey),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: MediaThumbnailSizeBadge(fileSize: img.fileSize),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridImages(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (ctx, idx) {
        final img = images[idx];

        return GestureDetector(
          onTap: () => ItemDetailGallery.show(context, images, initialIndex: idx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ApiService.instance.resolveMediaUrl(
                      img.thumbnailUrl ?? img.url,
                    ),
                    headers: ApiService.instance.authHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(LucideIcons.image, color: Colors.grey, size: 20),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: MediaThumbnailSizeBadge(fileSize: img.fileSize),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

