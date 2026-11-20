import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'app_logger.dart';

class AsrModelInfo {
  final String id;
  final String name;
  final String engineType;
  final String badge;
  final String description;
  final String archiveName;
  final int approxSizeMb;
  final int sizeBytes;
  final String sha256;
  final bool recommended;
  final bool availableOnServer;
  final String downloadPath;
  final bool isDownloaded;
  final int localSizeBytes;

  const AsrModelInfo({
    required this.id,
    required this.name,
    required this.engineType,
    required this.badge,
    required this.description,
    required this.archiveName,
    required this.approxSizeMb,
    required this.sizeBytes,
    required this.sha256,
    required this.recommended,
    required this.availableOnServer,
    required this.downloadPath,
    this.isDownloaded = false,
    this.localSizeBytes = 0,
  });

  factory AsrModelInfo.fromJson(
    Map<String, dynamic> json, {
    bool isDownloaded = false,
    int localSizeBytes = 0,
  }) {
    return AsrModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      engineType: json['engine_type'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      description: json['description'] as String? ?? '',
      archiveName: json['archive_name'] as String? ?? '',
      approxSizeMb: (json['approx_size_mb'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      recommended: json['recommended'] as bool? ?? false,
      availableOnServer: json['available_on_server'] as bool? ?? false,
      downloadPath: json['download_path'] as String? ?? '',
      isDownloaded: isDownloaded,
      localSizeBytes: localSizeBytes,
    );
  }

  AsrModelInfo copyWith({bool? isDownloaded, int? localSizeBytes}) {
    return AsrModelInfo(
      id: id,
      name: name,
      engineType: engineType,
      badge: badge,
      description: description,
      archiveName: archiveName,
      approxSizeMb: approxSizeMb,
      sizeBytes: sizeBytes,
      sha256: sha256,
      recommended: recommended,
      availableOnServer: availableOnServer,
      downloadPath: downloadPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localSizeBytes: localSizeBytes ?? this.localSizeBytes,
    );
  }
}

class AsrModelManager extends ChangeNotifier {
  AsrModelManager._internal();
  static final AsrModelManager instance = AsrModelManager._internal();

  static const String systemEngineId = 'system_stt';
  static const String _prefSelectedKey = 'asr_selected_engine_id';

  static const List<Map<String, dynamic>> _fallbackCatalog = [
    {
      'id': 'sensevoice_small_int8',
      'name': 'SenseVoiceSmall (int8)',
      'engine_type': 'offline_sensevoice',
      'badge': '中文高精度',
      'description': '松手整句识别，普通话、方言与中英混杂准确率极高，自带标点',
      'archive_name': 'sensevoice_small_int8.tar.gz',
      'approx_size_mb': 230,
      'recommended': true,
      'available_on_server': false,
      'download_path': '/asr/models/sensevoice_small_int8/download',
    },
    {
      'id': 'streaming_zipformer_zh_en_int8',
      'name': 'Streaming Zipformer (int8)',
      'engine_type': 'streaming_zipformer',
      'badge': '轻量实时流式',
      'description': '边说边实时出字，内存占用极低（约 100MB），适合低配机型',
      'archive_name': 'streaming_zipformer_zh_en_int8.tar.gz',
      'approx_size_mb': 95,
      'recommended': false,
      'available_on_server': false,
      'download_path': '/asr/models/streaming_zipformer_zh_en_int8/download',
    },
  ];

  String _selectedEngineId = 'sensevoice_small_int8';
  List<AsrModelInfo> _models = [];
  String? _downloadingModelId;
  double _downloadProgress = 0.0;
  String _downloadStage = '';
  bool _initialized = false;

  String get selectedEngineId => _selectedEngineId;
  List<AsrModelInfo> get models => List.unmodifiable(_models);
  String? get downloadingModelId => _downloadingModelId;
  double get downloadProgress => _downloadProgress;
  String get downloadStage => _downloadStage;
  bool get isDownloading => _downloadingModelId != null;

  bool get hasAnyDownloadedModel => _models.any((m) => m.isDownloaded);

  AsrModelInfo? get activeOfflineModel {
    if (_selectedEngineId == systemEngineId) return null;
    for (final m in _models) {
      if (m.id == _selectedEngineId && m.isDownloaded) return m;
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _selectedEngineId =
        prefs.getString(_prefSelectedKey) ?? 'sensevoice_small_int8';
    _models = await _mergeLocalState(_fallbackCatalog);
    _initialized = true;
    AppLogger.instance.voice(
      'ModelMgr',
      '初始化完成: 当前引擎=$_selectedEngineId, 本地已就绪=${_models.where((m) => m.isDownloaded).map((m) => m.id).toList()}',
    );
    notifyListeners();
  }

  Future<Directory> _modelsRootDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/asr_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory?> getModelDirectory(String modelId) async {
    final root = await _modelsRootDir();
    final dir = Directory('${root.path}/$modelId');
    if (!await dir.exists()) return null;
    if (await File('${dir.path}/tokens.txt').exists()) return dir;
    await for (final entity in dir.list()) {
      if (entity is Directory &&
          await File('${entity.path}/tokens.txt').exists()) {
        return entity;
      }
    }
    return null;
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<List<AsrModelInfo>> _mergeLocalState(
    List<Map<String, dynamic>> rawList,
  ) async {
    final res = <AsrModelInfo>[];
    for (final raw in rawList) {
      final id = raw['id'] as String? ?? '';
      final modelDir = await getModelDirectory(id);
      final downloaded = modelDir != null;
      final size = downloaded ? await _dirSize(modelDir) : 0;
      res.add(
        AsrModelInfo.fromJson(
          raw,
          isDownloaded: downloaded,
          localSizeBytes: size,
        ),
      );
    }
    return res;
  }

  Future<List<AsrModelInfo>> fetchModels() async {
    await init();
    try {
      final resp = await ApiService.instance.dio.get('/asr/models');
      final list = (resp.data['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      _models = await _mergeLocalState(list);
      AppLogger.instance.voice(
        'ModelMgr',
        '拉取服务端模型清单成功: ${list.length} 项',
      );
    } catch (e) {
      _models = await _mergeLocalState(_fallbackCatalog);
      AppLogger.instance.w('ModelMgr', '拉取服务端模型清单失败，使用本地状态: $e');
    }
    notifyListeners();
    return _models;
  }

  Future<void> selectEngine(String engineId) async {
    await init();
    _selectedEngineId = engineId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelectedKey, engineId);
    AppLogger.instance.voice('ModelMgr', '切换语音识别引擎为: $engineId');
    notifyListeners();
  }

  Future<void> downloadAndInstallModel(AsrModelInfo model) async {
    await init();
    if (_downloadingModelId != null) return;
    _downloadingModelId = model.id;
    _downloadProgress = 0.0;
    _downloadStage = '正在从家庭服务器下载...';
    notifyListeners();

    final root = await _modelsRootDir();
    final tempFile = File('${root.path}/${model.id}.download.tmp');
    final targetDir = Directory('${root.path}/${model.id}');

    try {
      final apiPath = model.downloadPath.startsWith('/api/')
          ? model.downloadPath.substring(4)
          : model.downloadPath;
      AppLogger.instance.voice(
        'ModelMgr',
        '开始下载模型 ${model.id} ($apiPath)',
      );
      await ApiService.instance.dio.download(
        apiPath,
        tempFile.path,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = (received / total).clamp(0.0, 0.92);
            notifyListeners();
          }
        },
      );

      _downloadProgress = 0.94;
      _downloadStage = '正在校验并解压模型...';
      notifyListeners();

      final args = <String, Object>{
        'tempPath': tempFile.path,
        'destPath': targetDir.path,
        'expectedSha256': model.sha256,
        'isBz2': model.archiveName.toLowerCase().endsWith('.bz2'),
      };
      await compute(_verifyAndExtractArchiveEntry, args);

      if (await tempFile.exists()) await tempFile.delete();
      await selectEngine(model.id);
      await fetchModels();
      AppLogger.instance.voice('ModelMgr', '模型 ${model.id} 安装并激活成功');
    } catch (e) {
      AppLogger.instance.e('ModelMgr', '模型 ${model.id} 下载或解压失败: $e');
      if (await tempFile.exists()) await tempFile.delete();
      rethrow;
    } finally {
      _downloadingModelId = null;
      _downloadProgress = 0.0;
      _downloadStage = '';
      notifyListeners();
    }
  }

  Future<void> deleteModel(String modelId) async {
    await init();
    final root = await _modelsRootDir();
    final dir = Directory('${root.path}/$modelId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _models = _models
        .map((m) =>
            m.id == modelId ? m.copyWith(isDownloaded: false, localSizeBytes: 0) : m)
        .toList();
    if (_selectedEngineId == modelId) {
      final fallback = _models.where((m) => m.isDownloaded).firstOrNull?.id ??
          systemEngineId;
      await selectEngine(fallback);
    }
    AppLogger.instance.voice('ModelMgr', '已清理本地模型缓存: $modelId');
    notifyListeners();
  }
}

void _verifyAndExtractArchiveEntry(Map<String, Object> args) {
  final tempPath = args['tempPath'] as String;
  final destPath = args['destPath'] as String;
  final expectedSha256 = args['expectedSha256'] as String;
  final isBz2 = args['isBz2'] as bool;
  _verifyAndExtractArchive(
    tempPath: tempPath,
    destPath: destPath,
    expectedSha256: expectedSha256,
    isBz2: isBz2,
  );
}

void _verifyAndExtractArchive({
  required String tempPath,
  required String destPath,
  required String expectedSha256,
  required bool isBz2,
}) {
  final file = File(tempPath);
  final bytes = file.readAsBytesSync();
  if (expectedSha256.isNotEmpty) {
    final actual = sha256.convert(bytes).toString();
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      throw Exception('模型文件 SHA256 校验失败');
    }
  }

  final destDir = Directory(destPath);
  if (destDir.existsSync()) destDir.deleteSync(recursive: true);
  destDir.createSync(recursive: true);

  final tarBytes = isBz2
      ? BZip2Decoder().decodeBytes(bytes)
      : GZipDecoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tarBytes);
  for (final entry in archive) {
    final outPath = '$destPath/${entry.name}';
    if (entry.isFile) {
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(entry.content as List<int>);
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}

