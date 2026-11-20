import 'generated/shared_category_emojis.g.dart';

typedef CategoryEmojiGroup = SharedCategoryEmojiGroup;

/// 6 大主题分组 × 32 款 = 192 款精选分类 Emoji 图标库（源自 shared/category_emojis.json）。
const List<CategoryEmojiGroup> kCategoryEmojiGroups = kSharedCategoryEmojiGroups;

/// 14 套预设分类名称与 Emoji 图标映射（源自 shared/category_emojis.json）。
const Map<String, String> kCategoryPresetMappings =
    kSharedCategoryPresetMappings;

/// 返回全部分类图标总数（192 款）。
int get kCategoryEmojiTotalCount =>
    kCategoryEmojiGroups.fold<int>(0, (sum, g) => sum + g.emojis.length);

/// 根据当前 Emoji 查找其所属分组名称；若不在库中则回退首个分组。
String findCategoryEmojiGroupName(String emoji) {
  for (final group in kCategoryEmojiGroups) {
    if (group.emojis.contains(emoji)) return group.name;
  }
  return kCategoryEmojiGroups.first.name;
}
