import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';

class TagAutocompleteField extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  const TagAutocompleteField({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  @override
  State<TagAutocompleteField> createState() => _TagAutocompleteFieldState();
}

class _TagAutocompleteFieldState extends State<TagAutocompleteField> {
  final TextEditingController _inputController = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    if (val.endsWith(' ') || val.endsWith('，') || val.endsWith(',')) {
      _addTag(val.substring(0, val.length - 1));
      return;
    }

    _debounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 240), () async {
      try {
        final list = await ApiService.instance.suggestTags(q);
        if (!mounted) return;
        setState(() {
          _suggestions =
              list.where((s) => !widget.tags.contains(s)).toList();
        });
      } catch (_) {}
    });
  }

  void _addTag(String raw) {
    final clean = raw.trim().replaceAll('#', '');
    _inputController.clear();
    setState(() => _suggestions = []);
    if (clean.isEmpty || widget.tags.contains(clean)) return;
    widget.onChanged([...widget.tags, clean]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '特征标签 (输入触发智能联想)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags
                .map(
                  (t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.lightBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.lightBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '# $t',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.darkText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            widget.onChanged(
                              widget.tags.where((e) => e != t).toList(),
                            );
                          },
                          child: Icon(
                            LucideIcons.x,
                            size: 14,
                            color: theme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: ShadInput(
                controller: _inputController,
                placeholder: const Text(
                  '常用、应急、儿童（空格添加）',
                  style: TextStyle(fontSize: 13),
                ),
                style: const TextStyle(fontSize: 14),
                onChanged: _onTextChanged,
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            ShadButton.outline(
              onPressed: () => _addTag(_inputController.text),
              child: const Text('添加', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions
                .map(
                  (s) => GestureDetector(
                    onTap: () => _addTag(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '+ $s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

