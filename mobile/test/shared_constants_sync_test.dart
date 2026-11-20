import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traceitem_mobile/core/category_emojis.dart';
import 'package:traceitem_mobile/core/constants.dart';
import 'package:traceitem_mobile/core/generated/shared_space_emojis.g.dart';
import 'package:traceitem_mobile/core/theme_controller.dart';

void main() {
  test('shared/*.json 与 Mobile 端生成常量 100% 一致', () {
    final sharedDir = Directory('../shared');
    expect(sharedDir.existsSync(), isTrue, reason: '必须存在仓库根目录 shared/ 目录');

    // 1. 分类 Emoji 与预设映射校验
    final catJson = jsonDecode(
      File('../shared/category_emojis.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final groups = catJson['groups'] as List<dynamic>;
    expect(kCategoryEmojiGroups.length, groups.length);
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i] as Map<String, dynamic>;
      expect(kCategoryEmojiGroups[i].name, g['name']);
      expect(kCategoryEmojiGroups[i].icon, g['icon']);
      expect(kCategoryEmojiGroups[i].label, g['label']);
      expect(kCategoryEmojiGroups[i].emojis, List<String>.from(g['emojis'] as List));
    }
    final presetMappings = Map<String, String>.from(
      catJson['presetMappings'] as Map<String, dynamic>,
    );
    expect(kCategoryPresetMappings, presetMappings);

    // 2. 空间图腾 Emoji 校验
    final spaceJson = jsonDecode(
      File('../shared/space_emojis.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final houses = spaceJson['houses'] as List<dynamic>;
    final rooms = spaceJson['rooms'] as List<dynamic>;
    expect(kSharedHouseEmojis.length, houses.length);
    expect(kSharedRoomEmojis.length, rooms.length);
    for (var i = 0; i < houses.length; i++) {
      final h = houses[i] as Map<String, dynamic>;
      expect(kSharedHouseEmojis[i].icon, h['icon']);
      expect(kSharedHouseEmojis[i].label, h['label']);
    }
    for (var i = 0; i < rooms.length; i++) {
      final r = rooms[i] as Map<String, dynamic>;
      expect(kSharedRoomEmojis[i].icon, r['icon']);
      expect(kSharedRoomEmojis[i].label, r['label']);
    }

    // 3. 多巴胺主题校验
    final themesJson = jsonDecode(
      File('../shared/themes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final dopamine = themesJson['dopamine'] as List<dynamic>;
    expect(kDopamineThemes.length, dopamine.length);
    for (var i = 0; i < dopamine.length; i++) {
      final t = dopamine[i] as Map<String, dynamic>;
      expect(kDopamineThemes[i].id, t['id']);
      expect(kDopamineThemes[i].name, t['name']);
      expect(kDopamineThemes[i].icon, t['icon']);
      expect(kDopamineThemes[i].desc, t['desc']);
    }

    // 4. 媒体规格常量校验
    final mediaJson = jsonDecode(
      File('../shared/media_limits.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(AppConstants.defaultBaseUrl, mediaJson['defaultBaseUrl']);
    expect(AppConstants.imageMaxLongEdge, mediaJson['imageMaxLongEdge']);
    expect(AppConstants.imageJpegQuality, mediaJson['imageJpegQuality']);
    expect(
      AppConstants.audioMaxDurationSeconds,
      mediaJson['audioMaxDurationSeconds'],
    );
    expect(
      AppConstants.videoMaxDurationSeconds,
      mediaJson['videoMaxDurationSeconds'],
    );
  });
}

