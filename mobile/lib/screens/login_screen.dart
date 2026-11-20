import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/lan_discovery_service.dart';
import '../core/network_route_manager.dart';
import '../core/theme_controller.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/login_server_status_card.dart';
import '../widgets/server_config_dialog.dart';
import 'main_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regNicknameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();

  final LanDiscoveryService _discovery = LanDiscoveryService();

  bool _isRegisterTab = false;
  bool _allowPublicRegistration = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    NetworkRouteManager.instance.addListener(_onRouteUpdated);
    _discovery.addListener(_onLanDiscovered);
    _bootstrapConnection();
  }

  Future<void> _bootstrapConnection() async {
    final routeMgr = NetworkRouteManager.instance;
    if (routeMgr.isConfigured) {
      await routeMgr.detectAndSwitchBestRoute();
      await _refreshAuthConfig();
    } else {
      await _discovery.startDiscovery(timeout: const Duration(seconds: 6));
    }
  }

  void _onRouteUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _onLanDiscovered() async {
    final found = _discovery.discoveredServer;
    if (found != null && !NetworkRouteManager.instance.isConfigured) {
      await NetworkRouteManager.instance.applyDiscoveredIntranet(found.fullUrl);
      await _refreshAuthConfig();
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshAuthConfig() async {
    final allowed = await ApiService.instance.getAllowPublicRegistration();
    if (!mounted) return;
    setState(() {
      _allowPublicRegistration = allowed;
      if (!allowed && _isRegisterTab) _isRegisterTab = false;
    });
  }

  @override
  void dispose() {
    NetworkRouteManager.instance.removeListener(_onRouteUpdated);
    _discovery.removeListener(_onLanDiscovered);
    _discovery.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _regUsernameController.dispose();
    _regNicknameController.dispose();
    _regPasswordController.dispose();
    _regConfirmController.dispose();
    super.dispose();
  }

  Future<void> _openServerConfig() async {
    final updated = await ServerConfigDialog.show(context);
    if (updated == true) await _refreshAuthConfig();
  }

  Future<void> _handleLogin() async {
    if (!NetworkRouteManager.instance.isConfigured) {
      setState(() => _errorMsg = '请先点击下方按钮配置服务网址');
      return;
    }
    final u = _usernameController.text.trim();
    final p = _passwordController.text.trim();
    if (u.isEmpty || p.isEmpty) {
      setState(() => _errorMsg = '请输入登录账号和密码');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await NetworkRouteManager.instance.detectAndSwitchBestRoute();
      final user = await ApiService.instance.login(u, p);
      if (!mounted) return;

      if (user.role == 'admin') {
        setState(() => _loading = false);
        await CustomDialogs.showNotice(
          context: context,
          title: '管理员请使用 Web 端',
          message: '系统管理员控制台包含用户治理、全局上帝视角与 TAR 备份恢复等功能，请使用电脑浏览器访问 Web 端管理后台。',
          isWarning: true,
        );
        return;
      }

      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMsg = ApiService.formatDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!NetworkRouteManager.instance.isConfigured) {
      setState(() => _errorMsg = '请先点击下方按钮配置服务网址');
      return;
    }
    final u = _regUsernameController.text.trim();
    final nick = _regNicknameController.text.trim();
    final p = _regPasswordController.text.trim();
    final p2 = _regConfirmController.text.trim();

    if (u.isEmpty || nick.isEmpty) {
      setState(() => _errorMsg = '请输入登录账号和用户昵称');
      return;
    }
    if (p.length < 6) {
      setState(() => _errorMsg = '登录密码至少需要 6 位');
      return;
    }
    if (p != p2) {
      setState(() => _errorMsg = '两次输入的密码不一致');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await NetworkRouteManager.instance.detectAndSwitchBestRoute();
      await ApiService.instance.register(
        username: u,
        nickname: nick,
        password: p,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShellScreen()),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMsg = ApiService.formatDioError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return Scaffold(
      backgroundColor: theme.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: theme.ambientShadows,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogoHeader(theme),
                      if (_allowPublicRegistration) ...[
                        _buildModeTabs(theme),
                        const SizedBox(height: 18),
                      ],
                      if (!_isRegisterTab)
                        ..._buildLoginInputs()
                      else
                        ..._buildRegisterInputs(),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorBox(),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ShadButton(
                          onPressed: _loading
                              ? null
                              : (_isRegisterTab
                                  ? _handleRegister
                                  : _handleLogin),
                          child: Text(
                            _loading
                                ? (_isRegisterTab ? '正在创建账号...' : '正在进入空间...')
                                : (_isRegisterTab ? '立即注册并进入' : '进入空间账本'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                LoginServerStatusCard(
                  isScanning: _discovery.isScanning,
                  onTap: _openServerConfig,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoHeader(DopamineThemeConfig theme) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.primary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/logo.png',
              width: 68,
              height: 68,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '图觅',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TraceItem · 家庭视觉收纳与空间寻物',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildModeTabs(DopamineThemeConfig theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: LoginTabButton(
              label: '账号登录',
              selected: !_isRegisterTab,
              theme: theme,
              onTap: () => setState(() {
                _isRegisterTab = false;
                _errorMsg = null;
              }),
            ),
          ),
          Expanded(
            child: LoginTabButton(
              label: '注册新账号',
              selected: _isRegisterTab,
              theme: theme,
              onTap: () => setState(() {
                _isRegisterTab = true;
                _errorMsg = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLoginInputs() => [
        ShadInput(
          controller: _usernameController,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.user, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder: const Text('请输入登录账号', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        ShadInput(
          controller: _passwordController,
          obscureText: true,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.lock, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder: const Text('请输入登录密码', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
          onSubmitted: (_) => _handleLogin(),
        ),
      ];

  List<Widget> _buildRegisterInputs() => [
        ShadInput(
          controller: _regUsernameController,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.userPlus, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder:
              const Text('登录账号（字母或数字）', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        ShadInput(
          controller: _regNicknameController,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.smile, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder:
              const Text('用户昵称（界面显示此称呼）', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        ShadInput(
          controller: _regPasswordController,
          obscureText: true,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(LucideIcons.lock, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder:
              const Text('登录密码（至少 6 位）', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        ShadInput(
          controller: _regConfirmController,
          obscureText: true,
          leading: const Padding(
            padding: EdgeInsets.only(right: 6),
            child:
                Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF64748B)),
          ),
          placeholder: const Text('确认登录密码', style: TextStyle(fontSize: 14)),
          style: const TextStyle(fontSize: 14),
          onSubmitted: (_) => _handleRegister(),
        ),
      ];

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Text(
        _errorMsg!,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFBE123C),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
