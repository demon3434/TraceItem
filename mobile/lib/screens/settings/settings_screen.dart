import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/api_service.dart';
import '../../core/navigation_models.dart';
import '../../core/network_route_manager.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';
import 'change_password_screen.dart';
import 'debug_log_screen.dart';
import 'media_storage_screen.dart';
import 'server_config_screen.dart';
import 'theme_settings_screen.dart';
import 'user_profile_screen.dart';
import 'voice_model_settings_screen.dart';

enum SettingsSubPage {
  main('系统设置 ⚙️'),
  userProfile('个人资料与安全 👤'),
  changePassword('修改登录密码 🔒'),
  serverConfig('内外网地址与发现 🌐'),
  themeSettings('多巴胺主题配色 🎨'),
  mediaStorage('多媒体存储与缓存 📦'),
  voiceModels('语音识别模型 🎙️'),
  debugLogs('系统诊断日志 🛠️');

  final String title;
  const SettingsSubPage(this.title);
}

class SettingsScreen extends StatefulWidget {
  final ValueChanged<SubLevelState?> onSubLevelChange;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLoggedOut;

  const SettingsScreen({
    super.key,
    required this.onSubLevelChange,
    required this.onProfileUpdated,
    required this.onLoggedOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<SettingsSubPage> _stack = [SettingsSubPage.main];

  SettingsSubPage get _current => _stack.last;

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSubLevelChange(null);
    });
    super.dispose();
  }

  void _push(SettingsSubPage page) {
    setState(() => _stack = [..._stack, page]);
    _syncSubLevel();
  }

  void _pop() {
    if (_stack.length > 1) {
      setState(() => _stack = _stack.sublist(0, _stack.length - 1));
      _syncSubLevel();
    }
  }

  void _syncSubLevel() {
    if (_current == SettingsSubPage.main) {
      widget.onSubLevelChange(null);
    } else {
      widget.onSubLevelChange(
        SubLevelState(
          title: _current.title,
          onBack: _pop,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await CustomDialogs.showConfirm(
      context: context,
      title: '退出登录确认',
      message: '确定要退出当前家庭账本账号吗？退出后需重新输入账号密码登录。',
      confirmText: '确认退出',
      isDanger: true,
    );
    if (!confirmed) return;
    await ApiService.instance.logout();
    if (mounted) {
      widget.onLoggedOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_current) {
            SettingsSubPage.main => _buildMainHub(),
            SettingsSubPage.userProfile => UserProfileScreen(
                onNavigateToChangePassword: () =>
                    _push(SettingsSubPage.changePassword),
                onProfileUpdated: () {
                  _pop();
                  setState(() {});
                  widget.onProfileUpdated();
                },
              ),
            SettingsSubPage.changePassword => ChangePasswordScreen(
                onSuccess: _pop,
              ),
            SettingsSubPage.serverConfig => ServerConfigScreen(
                onSaved: () => setState(() {}),
              ),
            SettingsSubPage.themeSettings => const ThemeSettingsScreen(),
            SettingsSubPage.mediaStorage => const MediaStorageScreen(),
            SettingsSubPage.voiceModels => const VoiceModelSettingsScreen(),
            SettingsSubPage.debugLogs => const DebugLogScreen(),
          },
        );
      },
    );
  }

  Widget _buildMainHub() {
    final theme = ThemeController.instance.current;
    final user = ApiService.instance.currentUser;
    final routeMgr = NetworkRouteManager.instance;
    final nickname = (user?.nickname.isNotEmpty == true)
        ? user!.nickname
        : (user?.username ?? '家庭成员');
    final initial = nickname.isNotEmpty ? nickname.substring(0, 1) : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 账号信息卡片
          GestureDetector(
            onTap: () => _push(SettingsSubPage.userProfile),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: theme.ambientShadows,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: theme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '登录账号: ${user?.username ?? "-"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              '软件与连接设置',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          _SettingsTile(
            icon: LucideIcons.server,
            iconColor: const Color(0xFF0EA5E9),
            title: '内外网地址与局域网发现',
            subtitle: routeMgr.activeBaseUrl.isEmpty
                ? '尚未配置服务地址，点击设置或扫描发现'
                : '当前线路: ${routeMgr.activeBaseUrl}',
            onTap: () => _push(SettingsSubPage.serverConfig),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: LucideIcons.palette,
            iconColor: theme.primary,
            title: '多巴胺主题配色',
            subtitle: '7 套活力多巴胺色系切换 (${theme.icon} ${theme.name})',
            onTap: () => _push(SettingsSubPage.themeSettings),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: LucideIcons.hardDrive,
            iconColor: const Color(0xFF8B5CF6),
            title: '多媒体存储与缓存',
            subtitle: '类 Telegram LRU 缓存池与 360p~1080p 视频画质设置',
            onTap: () => _push(SettingsSubPage.mediaStorage),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: LucideIcons.mic,
            iconColor: const Color(0xFFF97316),
            title: '语音识别模型',
            subtitle: '下载与切换离线中文模型 (SenseVoice / Zipformer / 系统)',
            onTap: () => _push(SettingsSubPage.voiceModels),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: LucideIcons.terminal,
            iconColor: const Color(0xFF0F172A),
            title: '系统诊断日志',
            subtitle: '查看并一键复制网络请求与多媒体上传异常日志',
            onTap: () => _push(SettingsSubPage.debugLogs),
          ),
          const SizedBox(height: 22),

          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.logOut,
                    size: 18,
                    color: Color(0xFFE11D48),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '退出当前账号',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: theme.ambientShadows,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

