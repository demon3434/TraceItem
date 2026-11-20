import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/lan_discovery_service.dart';
import '../core/network_route_manager.dart';
import '../core/theme_controller.dart';
import 'custom_dialogs.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showShadDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
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
    final discovered = _discovery.discoveredServer;
    if (discovered != null) {
      _intranetController.text = discovered.fullUrl;
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

  Future<void> _testRoute(bool isIntranet) async {
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

    final result = await NetworkRouteManager.instance.testUrlLatency(raw);
    if (!mounted) return;

    setState(() {
      if (isIntranet) {
        _testingIntra = false;
        _intraResult = result;
      } else {
        _testingExtra = false;
        _extraResult = result;
      }
    });
  }

  Future<void> _handleSave() async {
    final intra = NetworkRouteManager.normalizeUrl(_intranetController.text);
    final extra = NetworkRouteManager.normalizeUrl(_extranetController.text);
    if (intra.isEmpty && extra.isEmpty) {
      CustomDialogs.showToast(
        context,
        '请至少填写一个服务器地址',
        description: '可填写家庭内网地址、外网地址，或点击自动发现内网服务',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    await _discovery.stopDiscovery();
    await NetworkRouteManager.instance.saveRoutes(
      intranet: intra,
      extranet: extra,
      probeAfterSave: true,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return ShadDialog(
      radius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 440),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.lightBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.server, color: theme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '配置内外网服务地址',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      description: const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          '在家庭 WiFi 优先走内网极速通道，出门切换移动网络时自动切至外网地址',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
        ),
      ),
      actions: [
        ShadButton.outline(
          onPressed: _saving
              ? null
              : () async {
                  await _discovery.stopDiscovery();
                  if (context.mounted) Navigator.of(context).pop(false);
                },
          child: const Text('取消', style: TextStyle(fontSize: 14)),
        ),
        ShadButton(
          onPressed: _saving ? null : _handleSave,
          child: Text(
            _saving ? '测速保存中...' : '保存并选线',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.56,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏠 内网地址 (家庭 WiFi 局域网)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              ShadInput(
                controller: _intranetController,
                placeholder: const Text(
                  '例如: http://192.168.7.186:8085',
                  style: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() => _intraResult = null),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ShadButton.secondary(
                    size: ShadButtonSize.sm,
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
                      size: 14,
                    ),
                    child: Text(
                      _discovery.isScanning ? '停止扫描' : '自动发现内网服务',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: _testingIntra ? null : () => _testRoute(true),
                    leading: const Icon(LucideIcons.zap, size: 14),
                    child: Text(
                      _testingIntra ? '探测中...' : '测试内网',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _buildPresetChip('192.168.7.186:8085', 'http://192.168.7.186:8085'),
                  _buildPresetChip('模拟器 10.0.2.2', 'http://10.0.2.2:8085'),
                ],
              ),
              if (_discovery.statusMessage != null) ...[
                const SizedBox(height: 8),
                _StatusBanner(
                  ok: _discovery.state == LanDiscoveryState.success,
                  message: _discovery.statusMessage!,
                ),
              ],
              if (_intraResult != null) ...[
                const SizedBox(height: 8),
                _StatusBanner(
                  ok: _intraResult!.ok,
                  message: _intraResult!.message,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '🌍 外网地址 (移动网络 / 公网域名)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              ShadInput(
                controller: _extranetController,
                placeholder: const Text(
                  '例如: https://home.example.com',
                  style: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: (_) => setState(() => _extraResult = null),
              ),
              const SizedBox(height: 8),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: _testingExtra ? null : () => _testRoute(false),
                leading: const Icon(LucideIcons.globe, size: 14),
                child: Text(
                  _testingExtra ? '探测中...' : '测试外网',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_extraResult != null) ...[
                const SizedBox(height: 8),
                _StatusBanner(
                  ok: _extraResult!.ok,
                  message: _extraResult!.message,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _intranetController.text = url;
          _intraResult = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool ok;
  final String message;

  const _StatusBanner({required this.ok, required this.message});

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
        message,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ok ? const Color(0xFF166534) : const Color(0xFF9A3412),
        ),
      ),
    );
  }
}
