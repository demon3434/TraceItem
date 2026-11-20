import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/api_service.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';
import 'custom_dialogs.dart';

/// 纯房屋单层长按拖拽排序抽屉（ShadSheet）
class HouseOrderSheet extends StatefulWidget {
  final List<House> houses;
  final Map<int, int> roomCounts;
  final ValueChanged<List<House>> onReordered;

  const HouseOrderSheet({
    super.key,
    required this.houses,
    required this.roomCounts,
    required this.onReordered,
  });

  static Future<void> show(
    BuildContext context, {
    required List<House> houses,
    required Map<int, int> roomCounts,
    required ValueChanged<List<House>> onReordered,
  }) {
    return CustomDialogs.showModalSheet<void>(
      context: context,
      builder: (_) => HouseOrderSheet(
        houses: houses,
        roomCounts: roomCounts,
        onReordered: onReordered,
      ),
    );
  }

  @override
  State<HouseOrderSheet> createState() => _HouseOrderSheetState();
}

class _HouseOrderSheetState extends State<HouseOrderSheet> {
  late List<House> _orderedHouses;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _orderedHouses = List<House>.from(widget.houses);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_saving) return;
    if (oldIndex == newIndex) return;

    final snapshot = List<House>.from(_orderedHouses);
    setState(() {
      final moved = _orderedHouses.removeAt(oldIndex);
      _orderedHouses.insert(newIndex, moved);
      _saving = true;
    });

    try {
      final updated = await ApiService.instance.reorderHouses(
        _orderedHouses.map((h) => h.id).toList(),
      );
      if (!mounted) return;
      setState(() => _orderedHouses = updated);
      widget.onReordered(updated);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() => _orderedHouses = snapshot);
      CustomDialogs.showToast(
        context,
        '房屋排序保存失败',
        description: ApiService.formatDioError(e),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;
    final listHeight = math.min(
      MediaQuery.of(context).size.height * 0.56,
      math.max(160.0, _orderedHouses.length * 76.0),
    );

    return ShadSheet(
      radius: const BorderRadius.vertical(top: Radius.circular(24)),
      title: const Text(
        '调整房屋展示顺序',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      description: const Text(
        '长按卡片上下拖拽；排在第一的房屋将作为默认首屏空间',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '完成',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: SizedBox(
          height: listHeight,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: _orderedHouses.length,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderItem: _onReorder,
            proxyDecorator: (child, _, animation) => Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: child,
            ),
            itemBuilder: (_, idx) {
              final house = _orderedHouses[idx];
              final count = widget.roomCounts[house.id] ?? 0;
              return ReorderableDelayedDragStartListener(
                key: ValueKey('order_house_${house.id}'),
                index: idx,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: theme.ambientShadows,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: idx == 0 ? theme.primary : theme.lightBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: idx == 0 ? Colors.white : theme.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(house.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              house.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '$count 个功能房间',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.gripVertical,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
