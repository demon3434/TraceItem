import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/app_logger.dart';
import '../../core/theme_controller.dart';
import '../../widgets/custom_dialogs.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  static const List<String> _filterLevels = [
    'ALL',
    'VOICE',
    'ERROR',
    'WARN',
    'NET',
    'MEDIA',
  ];

  final ScrollController _scrollController = ScrollController();
  String _selectedLevel = 'ALL';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyLogs() async {
    final text = AppLogger.instance.getFormattedLogs(level: _selectedLevel);
    if (text.isEmpty) {
      CustomDialogs.showToast(context, '当前筛选暂无日志可复制');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      CustomDialogs.showToast(context, '已复制诊断日志到剪贴板');
    }
  }

  Color _levelColor(String level) {
    return switch (level) {
      'ERROR' => const Color(0xFFE11D48),
      'WARN' => const Color(0xFFD97706),
      'VOICE' => const Color(0xFFF97316),
      'MEDIA' => const Color(0xFF8B5CF6),
      'NET' => const Color(0xFF0284C7),
      _ => const Color(0xFF059669),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return ListenableBuilder(
      listenable: AppLogger.instance,
      builder: (context, _) {
        final logs = AppLogger.instance.getFilteredEntries(_selectedLevel);

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ShadButton(
                      onPressed: _copyLogs,
                      leading: const Icon(LucideIcons.copy, size: 16),
                      child: Text(
                        '复制日志 (${logs.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShadButton.outline(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      AppLogger.instance.clear();
                    },
                    leading: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    child: const Text(
                      '清空',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterLevels.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, idx) {
                    final lvl = _filterLevels[idx];
                    final selected = _selectedLevel == lvl;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedLevel = lvl);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: selected ? theme.primaryGradient : null,
                          color: selected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? theme.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          lvl == 'ALL' ? '全部' : lvl,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: theme.ambientShadows,
                  ),
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无诊断日志记录',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(14),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFF1E293B),
                            height: 14,
                          ),
                          itemBuilder: (_, idx) {
                            final log = logs[logs.length - 1 - idx];
                            final lvlColor = _levelColor(log.level);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      log.timestamp,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: lvlColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        log.level,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: lvlColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        log.tag,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  log.message,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Color(0xFFF8FAFC),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

