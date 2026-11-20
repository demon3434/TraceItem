import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/navigation_models.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';

class MainDrawerContent extends StatelessWidget {
  final User? user;
  final MobileDestination currentDestination;
  final ValueChanged<MobileDestination> onSelectDestination;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onCloseDrawer;

  const MainDrawerContent({
    super.key,
    required this.user,
    required this.currentDestination,
    required this.onSelectDestination,
    required this.onNavigateToSettings,
    required this.onCloseDrawer,
  });

  List<MobileDestination> _visibleDestinations() {
    // 预留未来扩展 admin 手机端导航的接缝；当前仅开放非 admin 用户业务菜单
    return const [
      MobileDestination.itemsHome,
      MobileDestination.quickAdd,
      MobileDestination.spaceManage,
      MobileDestination.categoryManage,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final nickname = (user?.nickname.isNotEmpty == true)
        ? user!.nickname
        : (user?.username ?? '家庭成员');
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';
    final destinations = _visibleDestinations();

    return Drawer(
      width: 292,
      backgroundColor: theme.pageBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部用户个人名片 + 右上角系统设置齿轮入口
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '系统设置',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onCloseDrawer();
                      onNavigateToSettings();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(42, 42),
                    ),
                    icon: Icon(
                      LucideIcons.settings,
                      size: 20,
                      color: currentDestination == MobileDestination.settings
                          ? theme.primary
                          : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),

            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '我的收纳空间',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),

            // 业务菜单列表（仅放置用户数据功能，软件设置由右上角齿轮进入）
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final dest = destinations[index];
                  final selected = dest == currentDestination;
                  return Material(
                    color: selected ? theme.lightBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onCloseDrawer();
                        onSelectDestination(dest);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? theme.lightBorder
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              dest.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dest.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: selected
                                          ? theme.darkText
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dest.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? theme.primary
                                          : const Color(0xFF64748B),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

