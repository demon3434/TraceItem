import 'package:flutter/material.dart';

enum MobileDestination {
  itemsHome('查找物品', '搜索与浏览已收纳物品', '🏠'),
  quickAdd('登记收纳', '拍照记录物品与存放位置', '📸'),
  spaceManage('房屋与房间', '管理房屋与房间', '🏘️'),
  categoryManage('物品分类', '管理物品分类与排序', '🏷️'),
  settings('系统设置', '账号、网络与模型设置', '⚙️');

  final String title;
  final String subtitle;
  final String emoji;

  const MobileDestination(this.title, this.subtitle, this.emoji);
}

class SubLevelState {
  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;

  const SubLevelState({
    required this.title,
    required this.onBack,
    this.actions = const [],
  });
}

