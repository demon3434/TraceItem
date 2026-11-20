import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/api_service.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class UserProfileScreen extends StatefulWidget {
  final VoidCallback onNavigateToChangePassword;
  final VoidCallback onProfileUpdated;

  const UserProfileScreen({
    super.key,
    required this.onNavigateToChangePassword,
    required this.onProfileUpdated,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final TextEditingController _nicknameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: ApiService.instance.currentUser?.nickname ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    final nextName = _nicknameController.text.trim();
    if (nextName.isEmpty) {
      CustomDialogs.showToast(context, '昵称不能为空', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateMe(nickname: nextName);
      if (!mounted) return;
      CustomDialogs.showToast(context, '昵称已更新为「$nextName」');
      widget.onProfileUpdated();
    } catch (e) {
      if (mounted) {
        CustomDialogs.showToast(
          context,
          '修改失败',
          description: ApiService.formatDioError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final user = ApiService.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '登录账号: ${user?.username ?? "-"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '显示昵称 *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                ShadInput(
                  controller: _nicknameController,
                  placeholder: const Text(
                    '请输入您的家庭成员昵称',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ShadButton(
                    onPressed: _saving ? null : _saveNickname,
                    child: Text(
                      _saving ? '正在保存昵称...' : '保存修改并返回',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onNavigateToChangePassword,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: theme.ambientShadows,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.lightBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      LucideIcons.keyRound,
                      color: theme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '修改登录密码',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '定期更新密码保护私有家庭账本安全',
                          style: TextStyle(
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
        ],
      ),
    );
  }
}

