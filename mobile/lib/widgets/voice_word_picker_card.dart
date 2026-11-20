import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/constants.dart';
import '../core/theme_controller.dart';
import '../core/voice_query_tokenizer.dart';
import 'custom_dialogs.dart';

class VoiceWordPickerCard extends StatefulWidget {
  final VoiceTokenizeResult result;
  final VoidCallback onRetry;
  final ValueChanged<String> onConfirm;

  const VoiceWordPickerCard({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onConfirm,
  });

  @override
  State<VoiceWordPickerCard> createState() => _VoiceWordPickerCardState();
}

class _VoiceWordPickerCardState extends State<VoiceWordPickerCard> {
  late final TextEditingController _previewController;
  final List<String> _selectedWords = [];

  @override
  void initState() {
    super.initState();
    final candidates = widget.result.candidates;
    final domainHits = candidates.where((c) => c.isDomainHit).toList();
    if (domainHits.isNotEmpty) {
      _selectedWords.addAll(domainHits.map((c) => c.word));
    } else if (candidates.isNotEmpty) {
      _selectedWords.add(candidates.first.word);
    }
    _previewController = TextEditingController(text: _selectedWords.join(' '));
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  void _toggleWord(String word) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedWords.contains(word)) {
        _selectedWords.remove(word);
      } else {
        _selectedWords.add(word);
      }
      _previewController.text = _selectedWords.join(' ');
    });
  }

  void _handleConfirm() {
    FocusManager.instance.primaryFocus?.unfocus();
    final text = _previewController.text.trim();
    if (text.isEmpty) {
      CustomDialogs.showToast(context, '请至少选择一个关键词');
      return;
    }
    HapticFeedback.mediumImpact();
    widget.onConfirm(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final candidates = widget.result.candidates;

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppConstants.squircleBorder,
          boxShadow: theme.ambientShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.sparkles,
                    size: 16,
                    color: theme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '识别：“${widget.result.cleanedSentence}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            if (candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 156),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: candidates.map((c) {
                      final selected = _selectedWords.contains(c.word);
                      return GestureDetector(
                        onTap: () => _toggleWord(c.word),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: selected ? theme.primaryGradient : null,
                            color: selected ? null : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? theme.primary
                                  : (c.isDomainHit
                                      ? theme.lightBorder
                                      : const Color(0xFFCBD5E1)),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(
                                  LucideIcons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                              ] else if (c.isDomainHit) ...[
                                Icon(
                                  LucideIcons.star,
                                  size: 13,
                                  color: theme.primary,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                c.word,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _previewController,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: '已选关键词（可点选或微调）',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedWords.clear();
                        _previewController.clear();
                      });
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ShadButton.outline(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      widget.onRetry();
                    },
                    leading: const Icon(LucideIcons.rotateCcw, size: 15),
                    child: const Text(
                      '重说',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: ShadButton(
                    onPressed: _handleConfirm,
                    leading: const Icon(LucideIcons.search, size: 15),
                    child: const Text(
                      '确认搜索',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
