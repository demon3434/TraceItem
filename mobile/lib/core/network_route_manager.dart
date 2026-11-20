import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ActiveRouteType {
  unconfigured,
  intranet,
  extranet,
  custom,
}

class UrlTestResult {
  final bool ok;
  final int latencyMs;
  final String message;

  const UrlTestResult({
    required this.ok,
    required this.latencyMs,
    required this.message,
  });
}

/// 智能内外网双路由自适应管理器 (参考 NutHollow NetworkRouteManager)
class NetworkRouteManager extends ChangeNotifier {
  static final NetworkRouteManager instance = NetworkRouteManager._internal();

  static const String _keyIntranet = 'intranet_url';
  static const String _keyExtranet = 'extranet_url';
  static const String _keyActive = 'active_server_url';
  static const String _keyLegacy = 'custom_base_url';

  late Dio _probeDio;
  final Connectivity _connectivity = Connectivity();
  Future<List<ConnectivityResult>> Function()? _connectivityCheckerForTest;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _debounceTimer;
  Future<String>? _inflightProbe;
  DateTime? _lastProbeCompletedAt;
  String? _lastConnectivityKey;

  String _intranetUrl = '';
  String _extranetUrl = '';
  String _activeBaseUrl = '';
  bool _isProbing = false;
  String? _probeStatusMessage;
  bool _isOffline = false;

  NetworkRouteManager._internal() {
    _probeDio = _createDefaultProbeDio();
  }

  static Dio _createDefaultProbeDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 3500),
        receiveTimeout: const Duration(milliseconds: 3500),
        sendTimeout: const Duration(milliseconds: 3500),
      ),
    );
  }

  @visibleForTesting
  void configureForTest({
    Dio? probeDio,
    Future<List<ConnectivityResult>> Function()? connectivityChecker,
  }) {
    _probeDio = probeDio ?? _createDefaultProbeDio();
    _connectivityCheckerForTest = connectivityChecker;
  }

  Future<List<ConnectivityResult>> _getConnectivity() {
    final checker = _connectivityCheckerForTest;
    if (checker != null) return checker();
    return _connectivity.checkConnectivity();
  }

  String get intranetUrl => _intranetUrl;
  String get extranetUrl => _extranetUrl;
  String get activeBaseUrl => _activeBaseUrl;
  bool get isConfigured =>
      _activeBaseUrl.isNotEmpty ||
      _intranetUrl.isNotEmpty ||
      _extranetUrl.isNotEmpty;
  bool get isProbing => _isProbing;
  bool get isOffline => _isOffline;
  String? get probeStatusMessage => _probeStatusMessage;

  ActiveRouteType get currentRouteType {
    if (_activeBaseUrl.isEmpty) return ActiveRouteType.unconfigured;
    if (_intranetUrl.isNotEmpty && _activeBaseUrl == _intranetUrl) {
      return ActiveRouteType.intranet;
    }
    if (_extranetUrl.isNotEmpty && _activeBaseUrl == _extranetUrl) {
      return ActiveRouteType.extranet;
    }
    return isPrivateNetwork(_activeBaseUrl)
        ? ActiveRouteType.intranet
        : ActiveRouteType.custom;
  }

  static String normalizeUrl(String raw) {
    var trimmed = raw.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static bool isPrivateNetwork(String rawUrl) {
    final lower = rawUrl.toLowerCase();
    if (lower.isEmpty) return false;
    final uri = Uri.tryParse(lower);
    final host = uri?.host ?? lower;
    if (host == 'localhost' ||
        host.endsWith('.local') ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.')) {
      return true;
    }
    final parts = host.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? -1;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }

  Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _intranetUrl = normalizeUrl(prefs.getString(_keyIntranet) ?? '');
    _extranetUrl = normalizeUrl(prefs.getString(_keyExtranet) ?? '');
    final savedActive = normalizeUrl(prefs.getString(_keyActive) ?? '');
    final legacy = normalizeUrl(prefs.getString(_keyLegacy) ?? '');

    if (_intranetUrl.isEmpty && _extranetUrl.isEmpty && legacy.isNotEmpty) {
      if (isPrivateNetwork(legacy)) {
        _intranetUrl = legacy;
        await prefs.setString(_keyIntranet, legacy);
      } else {
        _extranetUrl = legacy;
        await prefs.setString(_keyExtranet, legacy);
      }
    }

    if (savedActive.isNotEmpty) {
      _activeBaseUrl = savedActive;
    } else if (_intranetUrl.isNotEmpty) {
      _activeBaseUrl = _intranetUrl;
    } else if (_extranetUrl.isNotEmpty) {
      _activeBaseUrl = _extranetUrl;
    } else if (legacy.isNotEmpty) {
      _activeBaseUrl = legacy;
    }
    notifyListeners();
  }

  Future<void> saveRoutes({
    required String intranet,
    required String extranet,
    bool probeAfterSave = true,
  }) async {
    _intranetUrl = normalizeUrl(intranet);
    _extranetUrl = normalizeUrl(extranet);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIntranet, _intranetUrl);
    await prefs.setString(_keyExtranet, _extranetUrl);

    if (_intranetUrl.isNotEmpty) {
      await _applyActiveUrl(_intranetUrl, '已保存家庭内网地址');
    } else if (_extranetUrl.isNotEmpty) {
      await _applyActiveUrl(_extranetUrl, '已保存云端外网地址');
    } else {
      _activeBaseUrl = '';
      await prefs.remove(_keyActive);
      _probeStatusMessage = '未配置服务器地址';
      notifyListeners();
    }

    if (probeAfterSave && (_intranetUrl.isNotEmpty || _extranetUrl.isNotEmpty)) {
      await detectAndSwitchBestRoute(isManualTrigger: true);
    }
  }

  Future<void> applyDiscoveredIntranet(String url) async {
    final clean = normalizeUrl(url);
    if (clean.isEmpty) return;
    _intranetUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIntranet, clean);
    await _applyActiveUrl(clean, '📡 已通过局域网自动发现并连接');
  }

  void startAutoRouting() {
    _connSub?.cancel();
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      _onConnectivityChanged(results);
    });
    // 启动时主动检查一次当前网络拓扑，避免冷启动错过拓扑事件
    unawaited(_syncInitialConnectivity());
  }

  Future<void> _syncInitialConnectivity() async {
    try {
      final results = await _getConnectivity();
      final hasNet = results.any((r) => r != ConnectivityResult.none);
      if (!hasNet) {
        _isOffline = true;
        _probeStatusMessage = '网络已断开';
        notifyListeners();
        return;
      }
      _isOffline = false;
      if (_isCellularOnly(results) &&
          isPrivateNetwork(_intranetUrl) &&
          _extranetUrl.isNotEmpty) {
        await _applyActiveUrl(_extranetUrl, '🚀 蜂窝网络快轨：已秒切外网线路');
      }
    } catch (_) {}
  }

  bool _isCellularOnly(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) &&
        !results.contains(ConnectivityResult.wifi) &&
        !results.contains(ConnectivityResult.ethernet) &&
        !results.contains(ConnectivityResult.vpn);
  }

  void stopAutoRouting() {
    _connSub?.cancel();
    _connSub = null;
    _debounceTimer?.cancel();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _debounceTimer?.cancel();
    final hasNet = results.any((r) => r != ConnectivityResult.none);
    if (!hasNet) {
      _isOffline = true;
      _probeStatusMessage = '网络已断开';
      notifyListeners();
      return;
    }

    _isOffline = false;
    final connKey = results.map((e) => e.name).toList()..sort();
    final keyStr = connKey.join(',');
    final recentlyProbed = _lastProbeCompletedAt != null &&
        DateTime.now().difference(_lastProbeCompletedAt!) <
            const Duration(seconds: 2);
    if (recentlyProbed && _lastConnectivityKey == keyStr) {
      return;
    }
    _lastConnectivityKey = keyStr;

    if (_isCellularOnly(results) &&
        isPrivateNetwork(_intranetUrl) &&
        _extranetUrl.isNotEmpty) {
      _applyActiveUrl(_extranetUrl, '🚀 蜂窝网络快轨：已秒切外网线路');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      detectAndSwitchBestRoute(isManualTrigger: false);
    });
  }

  Future<String> detectAndSwitchBestRoute({bool isManualTrigger = false}) {
    if (_inflightProbe != null) return _inflightProbe!;
    _inflightProbe = _runBestRouteProbe(isManualTrigger: isManualTrigger)
        .whenComplete(() => _inflightProbe = null);
    return _inflightProbe!;
  }

  Future<String> _runBestRouteProbe({required bool isManualTrigger}) async {
    if (_intranetUrl.isEmpty && _extranetUrl.isEmpty) {
      return _activeBaseUrl;
    }

    // 蜂窝网络快轨
    try {
      final results = await _getConnectivity();
      if (_isCellularOnly(results) &&
          isPrivateNetwork(_intranetUrl) &&
          _extranetUrl.isNotEmpty) {
        await _applyActiveUrl(_extranetUrl, '🚀 蜂窝网络快轨：已切换外网通道');
        return _extranetUrl;
      }
    } catch (_) {}

    _isProbing = true;
    _probeStatusMessage = '正在探测最佳线路...';
    notifyListeners();

    try {
      if (_intranetUrl.isNotEmpty && _extranetUrl.isNotEmpty) {
        final intraFuture = checkUrlHealthy(_intranetUrl, timeoutMs: 600);
        final extraFuture = checkUrlHealthy(_extranetUrl, timeoutMs: 3500);
        final intraOk = await intraFuture;
        if (intraOk) {
          await _applyActiveUrl(_intranetUrl, '✨ 已连接家庭局域网极速通道');
          return _intranetUrl;
        }
        final extraOk = await extraFuture;
        if (extraOk) {
          await _applyActiveUrl(_extranetUrl, '☁️ 已连接互联网外网通道');
          return _extranetUrl;
        }
      } else if (_intranetUrl.isNotEmpty) {
        if (await checkUrlHealthy(_intranetUrl, timeoutMs: 800)) {
          await _applyActiveUrl(_intranetUrl, '✨ 家庭局域网连通正常');
          return _intranetUrl;
        }
      } else if (_extranetUrl.isNotEmpty) {
        if (await checkUrlHealthy(_extranetUrl, timeoutMs: 3500)) {
          await _applyActiveUrl(_extranetUrl, '☁️ 互联网外网连通正常');
          return _extranetUrl;
        }
      }

      _probeStatusMessage =
          isManualTrigger ? '内外网通道均不可达，请检查地址或网络' : '当前线路暂不可达';
      notifyListeners();
      return _activeBaseUrl;
    } finally {
      _lastProbeCompletedAt = DateTime.now();
      _isProbing = false;
      notifyListeners();
    }
  }

  Future<bool> trySwitchToIntranet() async {
    if (_intranetUrl.isEmpty) {
      _probeStatusMessage = '尚未配置家庭内网地址';
      notifyListeners();
      return false;
    }
    _isProbing = true;
    _probeStatusMessage = '正在探测家庭内网通道...';
    notifyListeners();
    try {
      final ok = await checkUrlHealthy(_intranetUrl, timeoutMs: 1500);
      if (ok) {
        await _applyActiveUrl(_intranetUrl, '✅ 已成功切换至家庭内网极速通道');
        return true;
      }
      _probeStatusMessage = '家庭内网不可达';
      if (_extranetUrl.isNotEmpty &&
          await checkUrlHealthy(_extranetUrl, timeoutMs: 3500)) {
        await _applyActiveUrl(_extranetUrl, '内网不可达，已保持云端外网通道');
      } else {
        notifyListeners();
      }
      return false;
    } finally {
      _isProbing = false;
      notifyListeners();
    }
  }

  Future<bool> fallbackToExtranetIfNeeded(String failedUrl) async {
    final cleanFailed = normalizeUrl(failedUrl);
    if (_extranetUrl.isEmpty) return false;
    if (cleanFailed == _activeBaseUrl && isPrivateNetwork(cleanFailed)) {
      await _applyActiveUrl(_extranetUrl, '⚠️ 内网超时，已自动容灾切换至外网');
      return true;
    }
    return false;
  }

  Future<bool> checkUrlHealthy(String rawUrl, {int timeoutMs = 800}) async {
    final clean = normalizeUrl(rawUrl);
    if (clean.isEmpty) return false;
    final timeout = Duration(milliseconds: timeoutMs);
    for (final path in const ['/api/health', '/health', '/']) {
      try {
        final res = await _probeDio.get(
          '$clean$path',
          options: Options(
            connectTimeout: timeout,
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        );
        if (res.statusCode != null &&
            res.statusCode! >= 200 &&
            res.statusCode! < 300) {
          return true;
        }
      } on DioException catch (e) {
        // TCP 连接超时或不可达时直接快速失败，避免对 /health 和 / 重复等待 3 倍超时
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<UrlTestResult> testUrlLatency(String rawUrl) async {
    final clean = normalizeUrl(rawUrl);
    if (clean.isEmpty) {
      return const UrlTestResult(
        ok: false,
        latencyMs: 0,
        message: '地址不能为空',
      );
    }
    final sw = Stopwatch()..start();
    for (final path in const ['/api/health', '/health']) {
      try {
        final res = await _probeDio.get(
          '$clean$path',
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );
        sw.stop();
        if (res.statusCode != null &&
            res.statusCode! >= 200 &&
            res.statusCode! < 300) {
          return UrlTestResult(
            ok: true,
            latencyMs: sw.elapsedMilliseconds,
            message: '连通正常 (${sw.elapsedMilliseconds}ms)',
          );
        }
      } catch (_) {}
    }
    sw.stop();
    return const UrlTestResult(
      ok: false,
      latencyMs: 0,
      message: '无法连接服务器，请检查 IP/域名或端口',
    );
  }

  String resolveMediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final clean = path.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    String normalized = clean;
    if (normalized.startsWith('images/') ||
        normalized.startsWith('thumbnails/') ||
        normalized.startsWith('audios/') ||
        normalized.startsWith('videos/')) {
      normalized = '/api/media/file/$normalized';
    } else if (normalized.startsWith('file/')) {
      normalized = '/api/media/$normalized';
    }
    if (_activeBaseUrl.isEmpty) return normalized;
    final prefix = normalized.startsWith('/') ? '' : '/';
    return '$_activeBaseUrl$prefix$normalized';
  }

  Future<void> _applyActiveUrl(String url, String statusMsg) async {
    _activeBaseUrl = normalizeUrl(url);
    _probeStatusMessage = statusMsg;
    _isOffline = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActive, _activeBaseUrl);
    notifyListeners();
  }
}

