import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveredLanServer {
  final String serviceName;
  final String host;
  final int port;
  final String fullUrl;

  const DiscoveredLanServer({
    required this.serviceName,
    required this.host,
    required this.port,
    required this.fullUrl,
  });
}

enum LanDiscoveryState {
  idle,
  scanning,
  success,
  timeout,
  failed,
}

/// 局域网 mDNS 服务自动发现控制器 (_traceitem._tcp)
class LanDiscoveryService extends ChangeNotifier {
  static const String serviceType = '_traceitem._tcp';

  nsd.Discovery? _discovery;
  Timer? _timeoutTimer;

  LanDiscoveryState _state = LanDiscoveryState.idle;
  DiscoveredLanServer? _discoveredServer;
  String? _statusMessage;

  LanDiscoveryState get state => _state;
  bool get isScanning => _state == LanDiscoveryState.scanning;
  DiscoveredLanServer? get discoveredServer => _discoveredServer;
  String? get statusMessage => _statusMessage;

  Future<void> startDiscovery({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await stopDiscovery();
    _discoveredServer = null;
    _state = LanDiscoveryState.scanning;
    _statusMessage = '正在扫描局域网中的图觅服务端...';
    notifyListeners();

    _timeoutTimer = Timer(timeout, () async {
      if (_state == LanDiscoveryState.scanning) {
        await _closeDiscoveryHandle();
        _state = LanDiscoveryState.timeout;
        _statusMessage = '未在当前 WiFi 局域网发现服务端，请确认在同一局域网或手动输入地址';
        notifyListeners();
      }
    });

    try {
      final discovery = await nsd.startDiscovery(
        serviceType,
        autoResolve: true,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery = discovery;
      discovery.addServiceListener(_onServiceEvent);
    } catch (e) {
      _timeoutTimer?.cancel();
      _state = LanDiscoveryState.failed;
      _statusMessage = '局域网扫描初始化失败: $e';
      notifyListeners();
    }
  }

  void _onServiceEvent(nsd.Service service, nsd.ServiceStatus status) {
    if (status != nsd.ServiceStatus.found) return;
    final resolved = _extractServerInfo(service);
    if (resolved == null) return;

    _timeoutTimer?.cancel();
    _discoveredServer = resolved;
    _state = LanDiscoveryState.success;
    _statusMessage = '✅ 已发现局域网服务: ${resolved.fullUrl}';
    notifyListeners();
    _closeDiscoveryHandle();
  }

  DiscoveredLanServer? _extractServerInfo(nsd.Service service) {
    final txt = service.txt;
    if (txt != null) {
      final rawUrlBytes = txt['url'];
      if (rawUrlBytes != null && rawUrlBytes.isNotEmpty) {
        final rawUrl = utf8.decode(rawUrlBytes, allowMalformed: true).trim();
        final uri = Uri.tryParse(rawUrl);
        if (uri != null &&
            uri.host.isNotEmpty &&
            uri.host != '127.0.0.1' &&
            uri.host != 'localhost') {
          final port = uri.hasPort ? uri.port : (service.port ?? 8085);
          return DiscoveredLanServer(
            serviceName: service.name ?? 'TraceItem-Server',
            host: uri.host,
            port: port,
            fullUrl: 'http://${uri.host}:$port',
          );
        }
      }
    }

    String? ipHost;
    final addresses = service.addresses;
    if (addresses != null && addresses.isNotEmpty) {
      final v4 = addresses
          .where((a) => a.type == InternetAddressType.IPv4 && !a.isLoopback)
          .firstOrNull;
      ipHost = v4?.address ?? addresses.first.address;
    } else if (service.host != null && service.host!.isNotEmpty) {
      ipHost = service.host!.replaceAll(RegExp(r'\.$'), '');
    }

    final port = service.port;
    if (ipHost == null || ipHost.isEmpty || port == null || port <= 0) {
      return null;
    }

    return DiscoveredLanServer(
      serviceName: service.name ?? 'TraceItem-Server',
      host: ipHost,
      port: port,
      fullUrl: 'http://$ipHost:$port',
    );
  }

  Future<void> stopDiscovery() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _closeDiscoveryHandle();
    if (_state == LanDiscoveryState.scanning) {
      _state = LanDiscoveryState.idle;
      notifyListeners();
    }
  }

  Future<void> _closeDiscoveryHandle() async {
    final active = _discovery;
    _discovery = null;
    if (active != null) {
      try {
        active.removeServiceListener(_onServiceEvent);
        await nsd.stopDiscovery(active);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _closeDiscoveryHandle();
    super.dispose();
  }
}

