import 'package:flutter/foundation.dart';

class LogEntry {
  final int id;
  final String timestamp;
  final String level; // INIT, INFO, WARN, ERROR, NET, MEDIA
  final String tag;
  final String message;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });
}

/// 轻量级运行时诊断日志收集器（内存保留最近 300 条，支持一键复制诊断）
class AppLogger extends ChangeNotifier {
  AppLogger._internal() {
    _entries.add(
      LogEntry(
        id: 0,
        timestamp: _nowTime(),
        level: 'INIT',
        tag: 'System',
        message: 'TraceItem 运行时诊断日志收集器已激活',
      ),
    );
  }

  static final AppLogger instance = AppLogger._internal();
  static const int _maxLogs = 300;
  int _seq = 0;
  final List<LogEntry> _entries = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  String _nowTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void log(String level, String tag, String message) {
    final entry = LogEntry(
      id: ++_seq,
      timestamp: _nowTime(),
      level: level,
      tag: tag,
      message: message,
    );
    if (_entries.length >= _maxLogs) {
      _entries.removeRange(0, _entries.length - _maxLogs + 1);
    }
    _entries.add(entry);
    debugPrint('[${entry.timestamp}] [${entry.level}] [${entry.tag}] ${entry.message}');
    notifyListeners();
  }

  void i(String tag, String message) => log('INFO', tag, message);
  void w(String tag, String message) => log('WARN', tag, message);
  void e(String tag, String message) => log('ERROR', tag, message);
  void net(String tag, String message) => log('NET', tag, message);
  void media(String tag, String message) => log('MEDIA', tag, message);
  void voice(String tag, String message) => log('VOICE', tag, message);

  List<LogEntry> getFilteredEntries(String? level) {
    if (level == null || level == 'ALL') return entries;
    return _entries.where((e) => e.level == level).toList(growable: false);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String getFormattedLogs({String? level}) {
    return getFilteredEntries(level)
        .map((e) => '[${e.timestamp}] [${e.level}] [${e.tag}] ${e.message}')
        .join('\n');
  }
}

