import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../core/theme_controller.dart';
import '../models/models.dart';

class ItemDetailHeaderCard extends StatelessWidget {
  final Item item;

  const ItemDetailHeaderCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance.current;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: theme.ambientShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部核心标识行：Emoji 图腾、名称、品牌与数量胶囊
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.lightBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  item.category?.icon ?? '📦',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.brand.isNotEmpty ? item.brand : "无品牌规格"} · ${item.category?.name ?? "未分类"}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.lightBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.lightBorder),
                ),
                child: Text(
                  'x${item.quantity}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.darkText,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // 所在空间全路径
          _buildInfoRow(
            icon: LucideIcons.mapPin,
            iconColor: theme.primary,
            label: '所在空间',
            content: Text(
              item.pathDisplay ?? '未分配空间',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // 具体存放位置
          if (item.locationDetail.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: LucideIcons.compass,
              iconColor: const Color(0xFF0EA5E9),
              label: '具体位置',
              content: Text(
                item.locationDetail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],

          // 备忘详细说明
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: LucideIcons.fileText,
              iconColor: const Color(0xFF64748B),
              label: '详细备注',
              content: Text(
                item.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],

          // 标签列表
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.lightBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.lightBorder),
                      ),
                      child: Text(
                        '# ${t.name}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.darkText,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

