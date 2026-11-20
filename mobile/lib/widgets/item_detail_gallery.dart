import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'media_section_header.dart';

class ItemDetailGallery extends StatefulWidget {
  final List<Attachment> images;
  final int initialIndex;
  final Future<Attachment?> Function(
    int index,
    Attachment current,
    int quarterTurns,
  )? onRotateSave;

  const ItemDetailGallery({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onRotateSave,
  });

  static void show(
    BuildContext context,
    List<Attachment> images, {
    int initialIndex = 0,
    Future<Attachment?> Function(
      int index,
      Attachment current,
      int quarterTurns,
    )? onRotateSave,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => ItemDetailGallery(
          images: images,
          initialIndex: initialIndex,
          onRotateSave: onRotateSave,
        ),
      ),
    );
  }

  @override
  State<ItemDetailGallery> createState() => _ItemDetailGalleryState();
}

class _ItemDetailGalleryState extends State<ItemDetailGallery>
    with SingleTickerProviderStateMixin {
  late List<Attachment> _images;
  late int _selectedImgIdx;
  late final PageController _pageController;
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _zoomAnimController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  double _currentScale = 1.0;
  int _pointerCount = 0;
  bool _savingRotate = false;

  @override
  void initState() {
    super.initState();
    _images = List<Attachment>.from(widget.images);
    _selectedImgIdx = widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _selectedImgIdx);
    _zoomAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });
    _transformController.addListener(() {
      final scale = _transformController.value.getMaxScaleOnAxis();
      if (mounted && (scale - _currentScale).abs() > 0.01) {
        setState(() => _currentScale = scale);
      }
    });
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final Matrix4 targetMatrix;
    if (_currentScale > 1.2) {
      targetMatrix = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition;
      const double scale = 2.5;
      if (pos != null) {
        // 以手指双击坐标为中心放大，保持点击点在屏幕原位置不动
        targetMatrix = Matrix4.identity()
          ..translateByDouble(
            -pos.dx * (scale - 1),
            -pos.dy * (scale - 1),
            0.0,
            1.0,
          )
          ..scaleByDouble(scale, scale, scale, 1.0);
      } else {
        targetMatrix = Matrix4.identity()..scaleByDouble(scale, scale, scale, 1.0);
      }
    }
    _zoomAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _zoomAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _zoomAnimController.forward(from: 0);
  }

  Future<void> _rotateAndSave() async {
    if (widget.onRotateSave == null || _savingRotate) return;
    setState(() => _savingRotate = true);
    try {
      final updated = await widget.onRotateSave!(
        _selectedImgIdx,
        _images[_selectedImgIdx],
        1,
      );
      if (updated != null && mounted) {
        setState(() {
          _images[_selectedImgIdx] = updated;
          _transformController.value = Matrix4.identity();
        });
      }
    } finally {
      if (mounted) setState(() => _savingRotate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();
    final theme = ThemeController.instance.current;
    final currentImg = _images[_selectedImgIdx.clamp(0, _images.length - 1)];
    final sizeStr = AppConstants.formatFileSize(currentImg.fileSize);
    final dimenStr = currentImg.width > 0 && currentImg.height > 0
        ? '${currentImg.width}x${currentImg.height}'
        : '';
    final lockSwipe = _pointerCount >= 2 || _currentScale > 1.02;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            onPointerDown: (_) {
              if (_pointerCount < 2) setState(() => _pointerCount++);
            },
            onPointerUp: (_) {
              if (_pointerCount > 0) setState(() => _pointerCount--);
            },
            onPointerCancel: (_) {
              if (_pointerCount > 0) setState(() => _pointerCount--);
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              physics: lockSwipe
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (idx) {
                setState(() {
                  _selectedImgIdx = idx;
                  _transformController.value = Matrix4.identity();
                });
              },
              itemBuilder: (_, idx) {
                final img = _images[idx];
                return GestureDetector(
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    transformationController:
                        idx == _selectedImgIdx ? _transformController : null,
                    minScale: 1.0,
                    maxScale: 4.0,
                    panEnabled: _currentScale > 1.02,
                    scaleEnabled: true,
                    child: SizedBox.expand(
                      child: Center(
                        child: Image.network(
                          ApiService.instance.resolveMediaUrl(img.url),
                          headers: ApiService.instance.authHeaders,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: theme.primary,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 顶部安全区：页码计数 + 尺寸信息 + 右上角红叉关闭按钮
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                FullscreenInfoPill(
                  text: '${_selectedImgIdx + 1} / ${_images.length}'
                      '${dimenStr.isNotEmpty || sizeStr.isNotEmpty ? ' · ${[if (dimenStr.isNotEmpty) dimenStr, if (sizeStr.isNotEmpty) sizeStr].join(' · ')}' : ''}',
                ),
                const Spacer(),
                FullscreenCloseButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // 底部操作区：缩放提示 / 旋转纠偏 / 缩略图切换条
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _currentScale > 1.05
                            ? '${(_currentScale * 100).round()}% · 双击还原'
                            : '双指捏合缩放 · 左右滑动切换',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (widget.onRotateSave != null)
                      GestureDetector(
                        onTap: _savingRotate ? null : _rotateAndSave,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_savingRotate)
                                const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.rotate_90_degrees_cw_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _savingRotate ? '保存中...' : '旋转',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (_images.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final img = _images[idx];
                        final isSel = idx == _selectedImgIdx;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              idx,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    isSel ? theme.primary : Colors.white24,
                                width: isSel ? 2.2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ApiService.instance.resolveMediaUrl(
                                  img.thumbnailUrl ?? img.url,
                                ),
                                headers: ApiService.instance.authHeaders,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
