import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';

class MobileItemCard extends StatefulWidget {
  final Item item;
  final VoidCallback onTap;

  const MobileItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<MobileItemCard> createState() => _MobileItemCardState();
}

class _MobileItemCardState extends State<MobileItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    String? thumbUrl;
    final imgAtt = widget.item.attachments
        .where((a) => a.mediaType == 'image')
        .firstOrNull;
    if (imgAtt != null) {
      final path = imgAtt.thumbnailUrl ?? imgAtt.url;
      final resolved = ApiService.instance.resolveMediaUrl(path);
      if (resolved.isNotEmpty) thumbUrl = resolved;
    }

    final bool hasAudio =
        widget.item.attachments.any((a) => a.mediaType == 'audio');
    final bool hasVideo =
        widget.item.attachments.any((a) => a.mediaType == 'video');

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: theme.ambientShadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 4:3 封面与胶囊徽标（无内边距留白，至少两边贴边）
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF1F5F9),
                      child: thumbUrl != null
                          ? CachedNetworkImage(
                              imageUrl: thumbUrl,
                              httpHeaders: ApiService.instance.authHeaders,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              memCacheWidth: 400,
                              placeholder: (_, __) => Center(
                                child: Text(
                                  widget.item.category?.icon ?? '📦',
                                  style: const TextStyle(fontSize: 38),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  widget.item.category?.icon ?? '📦',
                                  style: const TextStyle(fontSize: 38),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                widget.item.category?.icon ?? '📦',
                                style: const TextStyle(fontSize: 38),
                              ),
                            ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.04),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.32),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 数量角标（贴紧右上角，减少遮挡封面）
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          '${widget.item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    // 分类角标（贴紧左上角，减少遮挡封面）
                    if (widget.item.category != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            '${widget.item.category!.icon} ${widget.item.category!.name}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    // 多模态实景纯图标徽标（贴紧右下角，尽量少遮挡封面）
                    if (hasAudio || hasVideo)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAudio)
                              Container(
                                margin: EdgeInsets.only(right: hasVideo ? 4 : 0),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.14),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.mic,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            if (hasVideo)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.14),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.video,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // 文字与空间位置
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin,
                            size: 13,
                            color: theme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.item.pathDisplay ?? '未归档空间',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.darkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
