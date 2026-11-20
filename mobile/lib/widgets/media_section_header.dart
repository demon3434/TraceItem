import 'package:flutter/material.dart';
import '../core/constants.dart';

/// 多媒体区块统一头部组件（编辑页与详情页共用）
class MediaSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final int? maxCount;
  final String? unitLabel;
  final Color accentColor;

  const MediaSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    this.maxCount,
    this.unitLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = maxCount != null
        ? '$count/$maxCount'
        : '$count${unitLabel ?? ''}';

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: accentColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// 工业级分阶段媒体处理进度卡片（压缩转码 / 上传传输共用）
class MediaStageProgressCard extends StatelessWidget {
  final String statusText;
  final double? progress;
  final Color accentColor;

  const MediaStageProgressCard({
    super.key,
    required this.statusText,
    this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress?.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: accentColor.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑页多媒体卡片右上角紧贴边角的微缩红叉删除按钮
class MediaCardDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const MediaCardDeleteButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 缩略图左下角贴边无小数体积角标（尽量减少对缩略图主体的遮挡）
class MediaThumbnailSizeBadge extends StatelessWidget {
  final int? fileSize;

  const MediaThumbnailSizeBadge({super.key, required this.fileSize});

  @override
  Widget build(BuildContext context) {
    final label = AppConstants.formatFileSizeInt(fileSize);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.15,
        ),
      ),
    );
  }
}

/// 全屏图片/视频预览右上角红叉关闭按钮
class FullscreenCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const FullscreenCloseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

/// 全屏图片/视频预览顶栏统一信息胶囊（位置、尺寸、样式、字号双端全屏一致）
class FullscreenInfoPill extends StatelessWidget {
  final String text;

  const FullscreenInfoPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

