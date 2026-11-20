import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';

class CustomDialogs {
  /// 统一美学确认对话框 (严格使用 ShadDialog，严禁原生 alert/confirm)
  static Future<bool> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDanger = false,
  }) async {
    final theme = ThemeController.instance.current;
    final result = await showShadDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return ShadDialog.alert(
          radius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(22),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDanger ? const Color(0xFFFFF1F2) : theme.lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDanger
                      ? LucideIcons.triangleAlert
                      : LucideIcons.circleHelp,
                  color: isDanger ? const Color(0xFFE11D48) : theme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          description: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                cancelText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            if (isDanger)
              ShadButton.destructive(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  confirmText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              )
            else
              ShadButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  confirmText,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// 单按钮提示框 (ShadDialog)
  static Future<void> showNotice({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = '我知道了',
    bool isWarning = false,
  }) async {
    final theme = ThemeController.instance.current;
    await showShadDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ShadDialog.alert(
        radius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(22),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isWarning ? const Color(0xFFFFFBEB) : theme.lightBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isWarning ? LucideIcons.shieldAlert : LucideIcons.info,
                color: isWarning ? const Color(0xFFD97706) : theme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        description: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 统一美学半屏抽屉 (严格避让系统通知栏与安全区，严禁与状态栏重叠)
  static Future<T?> showModalSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    Color barrierColor = const Color(0x80000000),
    bool isDismissible = true,
    RouteSettings? routeSettings,
  }) {
    return showShadSheet<T>(
      context: context,
      side: ShadSheetSide.bottom,
      barrierColor: barrierColor,
      isDismissible: isDismissible,
      routeSettings: routeSettings,
      builder: (ctx) {
        return SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: builder(ctx),
          ),
        );
      },
    );
  }

  static OverlayEntry? _activeToastEntry;

  static void showToast(
    BuildContext context,
    String title, {
    String? description,
    bool isError = false,
  }) {
    if (isError) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    _activeToastEntry?.remove();
    _activeToastEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bgColor =
        isError ? const Color(0xFFBE123C) : const Color(0xFF0F172A);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 24,
        right: 24,
        bottom: bottomInset + 20,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _activeToastEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (_activeToastEntry == entry) {
        entry.remove();
        _activeToastEntry = null;
      }
    });
  }
}
