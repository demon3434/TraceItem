import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';

/// 抽屉内统一无 Material 依赖的高质感选项行，兼容 ShadApp / ShadSheet 路由上下文。
class ShadSheetOptionTile extends StatefulWidget {
  final Widget leading;
  final String title;
  final Color? titleColor;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  const ShadSheetOptionTile({
    super.key,
    required this.leading,
    required this.title,
    this.titleColor,
    this.selected = false,
    this.trailing,
    required this.onTap,
    this.margin = const EdgeInsets.only(bottom: 6),
  });

  @override
  State<ShadSheetOptionTile> createState() => _ShadSheetOptionTileState();
}

class _ShadSheetOptionTileState extends State<ShadSheetOptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final effectiveColor = widget.titleColor ??
        (widget.selected ? theme.darkText : const Color(0xFF0F172A));

    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? theme.lightBg
                  : (_pressed ? const Color(0xFFF1F5F9) : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? theme.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                widget.leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          widget.selected ? FontWeight.bold : FontWeight.w600,
                      color: effectiveColor,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ] else if (widget.selected) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.check, color: theme.primary, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

