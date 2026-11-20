import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/network_route_manager.dart';
import '../core/theme_controller.dart';

class LoginTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final DopamineThemeConfig theme;
  final VoidCallback onTap;

  const LoginTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: selected ? theme.primary : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class LoginServerStatusCard extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onTap;

  const LoginServerStatusCard({
    super.key,
    required this.isScanning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final routeMgr = NetworkRouteManager.instance;
    final isConfigured = routeMgr.isConfigured;
    final isIntranet = routeMgr.currentRouteType == ActiveRouteType.intranet;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isConfigured ? Colors.white : theme.lightBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isConfigured ? const Color(0xFFE2E8F0) : theme.primary,
            width: isConfigured ? 1 : 1.5,
          ),
        ),
        child: !isConfigured
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.settings, size: 18, color: theme.primary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚙️ 配置服务网址 (首次使用请先配置)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isScanning
                            ? '正在局域网自动发现服务端...'
                            : '点击设置家庭内网或云端服务器地址',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(
                    isIntranet ? LucideIcons.router : LucideIcons.globe,
                    size: 17,
                    color: isIntranet
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${isIntranet ? "🏠 局域网" : "🌍 互联网"}: ${routeMgr.activeBaseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '更改 ⚙️',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

