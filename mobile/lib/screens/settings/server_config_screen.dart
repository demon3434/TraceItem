import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/lan_discovery_service.dart';
import '../../core/network_route_manager.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class ServerConfigScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const ServerConfigScreen({super.key, this.onSaved});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  late final TextEditingController _intranetController;
  late final TextEditingController _extranetController;
  final LanDiscoveryService _discovery = LanDiscoveryService();

  bool _testingIntra = false;
  bool _testingExtra = false;
  UrlTestResult? _intraResult;
  UrlTestResult? _extraResult;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final routeMgr = NetworkRouteManager.instance;
    _intranetController = TextEditingController(text: routeMgr.intranetUrl);
    _extranetController = TextEditingController(text: routeMgr.extranetUrl);
    _discovery.addListener(_onDiscoveryChanged);
  }

  void _onDiscoveryChanged() {
    if (!mounted) return;
    final found = _discovery.discoveredServer;
    if (found != null) {
      _intranetController.text = found.fullUrl;
      _intraResult = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _discovery.removeListener(_onDiscoveryChanged);
    _discovery.dispose();
    _intranetController.dispose();
    _extranetController.dispose();
    super.dispose();
  }

  Future<void> _testUrl(bool isIntranet) async {
    final raw = isIntranet ? _intranetController.text : _extranetController.text;
    setState(() {
      if (isIntranet) {
        _testingIntra = true;
        _intraResult = null;
      } else {
        _testingExtra = true;
        _extraResult = null;
      }
    });
    final res = await NetworkRouteManager.instance.testUrlLatency(raw);
    if (!mounted) return;
    setState(() {
      if (isIntranet) {
        _testingIntra = false;
        _intraResult = res;
      } else {
        _testingExtra = false;
        _extraResult = res;
      }
    });
  }

  Future<void> _saveRoutes() async {
    final intra = NetworkRouteManager.normalizeUrl(_intranetController.text);
    final extra = NetworkRouteManager.normalizeUrl(_extranetController.text);
    if (intra.isEmpty && extra.isEmpty) {
      CustomDialogs.showToast(context, '请至少配置一个服务地址', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    await _discovery.stopDiscovery();
    await NetworkRouteManager.instance.saveRoutes(
      intranet: intra,
      extranet: extra,
      probeAfterSave: true,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    CustomDialogs.showToast(
      context,
      '服务地址已保存并完成选线',
      description: NetworkRouteManager.instance.probeStatusMessage,
    );
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.lightBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.lightBorder),
            ),
            child: Text(
              '💡 在家庭 WiFi 环境下优先连接内网地址以极速上传高清实景照片与视频；外出切换移动网络时将自动秒切外网云端地址。',
              style: TextStyle(
                fontSize: 13,
                color: theme.darkText,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 内网卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏠 家庭内网服务器地址 (WiFi)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ShadInput(
                  controller: _intranetController,
                  placeholder: const Text(
                    '例如: http://192.168.7.186:8085',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() => _intraResult = null),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ShadButton(
                        onPressed: () {
                          if (_discovery.isScanning) {
                            _discovery.stopDiscovery();
                          } else {
                            _discovery.startDiscovery();
                          }
                        },
                        leading: Icon(
                          _discovery.isScanning
                              ? LucideIcons.loader
                              : LucideIcons.radar,
                          size: 15,
                        ),
                        child: Text(
                          _discovery.isScanning ? '扫描中(点击停止)' : '自动发现内网服务',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ShadButton.outline(
                        onPressed: _testingIntra ? null : () => _testUrl(true),
                        leading: const Icon(LucideIcons.zap, size: 15),
                        child: Text(
                          _testingIntra ? '探测中...' : '测试连接',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_discovery.statusMessage != null) ...[
                  const SizedBox(height: 10),
                  _RouteHintBox(
                    ok: _discovery.state == LanDiscoveryState.success,
                    text: _discovery.statusMessage!,
                  ),
                ],
                if (_intraResult != null) ...[
                  const SizedBox(height: 10),
                  _RouteHintBox(
                    ok: _intraResult!.ok,
                    text: _intraResult!.message,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 外网卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: theme.ambientShadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🌍 外网云端服务器地址 (移动网络 / 公网)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                ShadInput(
                  controller: _extranetController,
                  placeholder: const Text(
                    '例如: https://trace.example.com',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() => _extraResult = null),
                ),
                const SizedBox(height: 10),
                ShadButton.outline(
                  onPressed: _testingExtra ? null : () => _testUrl(false),
                  leading: const Icon(LucideIcons.globe, size: 15),
                  child: Text(
                    _testingExtra ? '探测中...' : '测试外网连通性',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_extraResult != null) ...[
                  const SizedBox(height: 10),
                  _RouteHintBox(
                    ok: _extraResult!.ok,
                    text: _extraResult!.message,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ShadButton(
              onPressed: _saving ? null : _saveRoutes,
              child: Text(
                _saving ? '正在保存并探测选线...' : '保存配置并立即选线',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHintBox extends StatelessWidget {
  final bool ok;
  final String text;
  const _RouteHintBox({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ok ? const Color(0xFF166534) : const Color(0xFF9A3412),
        ),
      ),
    );
  }
}

