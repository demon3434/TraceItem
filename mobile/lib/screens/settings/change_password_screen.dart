import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/api_service.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class ChangePasswordScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const ChangePasswordScreen({super.key, required this.onSuccess});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _pwdController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pwdController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pwd = _pwdController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pwd.length < 6) {
      CustomDialogs.showToast(
        context,
        '密码长度至少为 6 位',
        isError: true,
      );
      return;
    }
    if (pwd != confirm) {
      CustomDialogs.showToast(
        context,
        '两次输入的密码不一致',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateMe(password: pwd);
      if (!mounted) return;
      CustomDialogs.showToast(context, '密码修改成功');
      widget.onSuccess();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: theme.ambientShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '新密码 (至少 6 位) *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ShadInput(
              controller: _pwdController,
              obscureText: true,
              placeholder: const Text(
                '请输入新密码',
                style: TextStyle(fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            const Text(
              '确认新密码 *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ShadInput(
              controller: _confirmController,
              obscureText: true,
              placeholder: const Text(
                '请再次输入新密码',
                style: TextStyle(fontSize: 13),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: ShadButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  _saving ? '正在修改密码...' : '确认修改并返回',
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
    );
  }
}

