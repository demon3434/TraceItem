import 'api_service.dart';

/// 追踪编辑会话期间新上传或旋转产生的未入库临时附件，并在移除、替换或放弃编辑时静默回收
class SessionTempMediaTracker {
  final Map<String, String?> _pending = {};

  bool get isEmpty => _pending.isEmpty;

  void track(Map<String, dynamic> attachment) {
    final fp = attachment['file_path'] as String?;
    if (fp != null && fp.isNotEmpty) {
      _pending[fp] = attachment['thumbnail_path'] as String?;
    }
  }

  void cleanupIfTracked(String? filePath) {
    if (filePath == null || !_pending.containsKey(filePath)) return;
    final thumb = _pending.remove(filePath);
    ApiService.instance.cleanupTempMedia([
      {'file_path': filePath, 'thumbnail_path': thumb},
    ]);
  }

  void clearSaved() => _pending.clear();

  void cleanupAllRemaining() {
    if (_pending.isEmpty) return;
    final items = _pending.entries
        .map((e) => {'file_path': e.key, 'thumbnail_path': e.value})
        .toList();
    _pending.clear();
    ApiService.instance.cleanupTempMedia(items);
  }
}

