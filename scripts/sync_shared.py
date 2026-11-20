"""从仓库根目录 shared/*.json 同步生成 Mobile (Dart) 与 Server (Python) 共享常量。

用法：
  python scripts/sync_shared.py          # 生成/更新目标文件
  python scripts/sync_shared.py --check  # 仅校验生成文件是否与 shared/*.json 严格一致
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHARED_DIR = ROOT / "shared"
MOBILE_GEN_DIR = ROOT / "mobile" / "lib" / "core" / "generated"
SERVER_CONSTANTS_PATH = ROOT / "server" / "app" / "db" / "constants.py"


def _load_json(filename: str) -> object:
    return json.loads((SHARED_DIR / filename).read_text(encoding="utf-8"))


def _dart_str(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return f"'{escaped}'"


def _dart_color(hex_color: str) -> str:
    clean = hex_color.strip().lstrip("#").upper()
    if len(clean) == 6:
        clean = "FF" + clean
    return f"Color(0x{clean})"


def _render_category_emojis_dart(data: dict) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: shared/category_emojis.json (sync via scripts/sync_shared.py)",
        "",
        "class SharedCategoryEmojiGroup {",
        "  final String name;",
        "  final String icon;",
        "  final String label;",
        "  final List<String> emojis;",
        "",
        "  const SharedCategoryEmojiGroup({",
        "    required this.name,",
        "    required this.icon,",
        "    required this.label,",
        "    required this.emojis,",
        "  });",
        "}",
        "",
        "const List<SharedCategoryEmojiGroup> kSharedCategoryEmojiGroups = [",
    ]
    for grp in data["groups"]:
        lines.append("  SharedCategoryEmojiGroup(")
        lines.append(f"    name: {_dart_str(grp['name'])},")
        lines.append(f"    icon: {_dart_str(grp['icon'])},")
        lines.append(f"    label: {_dart_str(grp['label'])},")
        lines.append("    emojis: [")
        emojis = grp["emojis"]
        for i in range(0, len(emojis), 8):
            chunk = ", ".join(_dart_str(e) for e in emojis[i : i + 8])
            lines.append(f"      {chunk},")
        lines.append("    ],")
        lines.append("  ),")
    lines.extend(["];", "", "const List<String> kSharedCategoryQuickEmojis = ["])
    quick = data["quickEmojis"]
    for i in range(0, len(quick), 8):
        chunk = ", ".join(_dart_str(e) for e in quick[i : i + 8])
        lines.append(f"  {chunk},")
    lines.extend(["];", "", "const Map<String, String> kSharedCategoryPresetMappings = {"])
    for name, icon in data["presetMappings"].items():
        lines.append(f"  {_dart_str(name)}: {_dart_str(icon)},")
    lines.extend(["};", ""])
    return "\n".join(lines)


def _render_space_emojis_dart(data: dict) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: shared/space_emojis.json (sync via scripts/sync_shared.py)",
        "",
        "class SharedSpaceEmojiOption {",
        "  final String icon;",
        "  final String label;",
        "",
        "  const SharedSpaceEmojiOption({",
        "    required this.icon,",
        "    required this.label,",
        "  });",
        "}",
        "",
        "const List<SharedSpaceEmojiOption> kSharedHouseEmojis = [",
    ]
    for item in data["houses"]:
        lines.append(
            f"  SharedSpaceEmojiOption(icon: {_dart_str(item['icon'])}, label: {_dart_str(item['label'])}),"
        )
    lines.extend(["];", "", "const List<SharedSpaceEmojiOption> kSharedRoomEmojis = ["])
    for item in data["rooms"]:
        lines.append(
            f"  SharedSpaceEmojiOption(icon: {_dart_str(item['icon'])}, label: {_dart_str(item['label'])}),"
        )
    lines.extend(["];", ""])
    return "\n".join(lines)


def _render_themes_dart(data: dict) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: shared/themes.json (sync via scripts/sync_shared.py)",
        "",
        "import 'package:flutter/material.dart';",
        "",
        "class SharedDopamineThemeData {",
        "  final String id;",
        "  final String name;",
        "  final String icon;",
        "  final String desc;",
        "  final Color primary;",
        "  final Color secondary;",
        "  final Color lightBg;",
        "  final Color lightBorder;",
        "  final Color darkText;",
        "  final Color pageBg;",
        "",
        "  const SharedDopamineThemeData({",
        "    required this.id,",
        "    required this.name,",
        "    required this.icon,",
        "    required this.desc,",
        "    required this.primary,",
        "    required this.secondary,",
        "    required this.lightBg,",
        "    required this.lightBorder,",
        "    required this.darkText,",
        "    required this.pageBg,",
        "  });",
        "}",
        "",
        "const List<SharedDopamineThemeData> kSharedDopamineThemes = [",
    ]
    for t in data["dopamine"]:
        lines.extend(
            [
                "  SharedDopamineThemeData(",
                f"    id: {_dart_str(t['id'])},",
                f"    name: {_dart_str(t['name'])},",
                f"    icon: {_dart_str(t['icon'])},",
                f"    desc: {_dart_str(t['desc'])},",
                f"    primary: {_dart_color(t['primary'])},",
                f"    secondary: {_dart_color(t['secondary'])},",
                f"    lightBg: {_dart_color(t['lightBg'])},",
                f"    lightBorder: {_dart_color(t['lightBorder'])},",
                f"    darkText: {_dart_color(t['darkText'])},",
                f"    pageBg: {_dart_color(t['pageBg'])},",
                "  ),",
            ]
        )
    lines.extend(["];", ""])
    return "\n".join(lines)


def _render_media_limits_dart(data: dict) -> str:
    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "// Source: shared/media_limits.json (sync via scripts/sync_shared.py)",
        "",
        "class VideoProfileConfig {",
        "  final String key;",
        "  final String label;",
        "  final int width;",
        "  final int height;",
        "  final int targetBitrateKbps;",
        "  final int fps;",
        "  final String description;",
        "",
        "  const VideoProfileConfig({",
        "    required this.key,",
        "    required this.label,",
        "    required this.width,",
        "    required this.height,",
        "    required this.targetBitrateKbps,",
        "    required this.fps,",
        "    required this.description,",
        "  });",
        "}",
        "",
        "class SharedMediaLimits {",
        f"  static const String defaultBaseUrl = {_dart_str(data['defaultBaseUrl'])};",
        f"  static const String apiPrefix = {_dart_str(data['apiPrefix'])};",
        f"  static const double squircleRadius = {float(data['squircleRadius'])};",
        f"  static const double squircleRadiusSm = {float(data['squircleRadiusSm'])};",
        f"  static const int imageMaxLongEdge = {int(data['imageMaxLongEdge'])};",
        f"  static const int imageJpegQuality = {int(data['imageJpegQuality'])};",
        f"  static const int thumbMaxLongEdge = {int(data['thumbMaxLongEdge'])};",
        f"  static const int thumbJpegQuality = {int(data.get('thumbJpegQuality', 75))};",
        f"  static const int audioMaxDurationSeconds = {int(data['audioMaxDurationSeconds'])};",
        f"  static const int videoMaxDurationSeconds = {int(data['videoMaxDurationSeconds'])};",
        f"  static const int maxImageAttachments = {int(data.get('maxImageAttachments', 9))};",
        f"  static const int maxVideoAttachments = {int(data.get('maxVideoAttachments', 3))};",
        f"  static const int maxAudioAttachments = {int(data.get('maxAudioAttachments', 3))};",
        f"  static const int mediaCacheDefaultMaxMb = {int(data.get('mediaCacheDefaultMaxMb', 200))};",
        f"  static const String defaultVideoProfile = {_dart_str(data.get('defaultVideoProfile', '720p'))};",
        "",
        "  static const Map<String, VideoProfileConfig> videoProfiles = {",
    ]
    for key, p in data.get("videoProfiles", {}).items():
        lines.append(f"    {_dart_str(key)}: VideoProfileConfig(")
        lines.append(f"      key: {_dart_str(key)},")
        lines.append(f"      label: {_dart_str(p['label'])},")
        lines.append(f"      width: {int(p['width'])},")
        lines.append(f"      height: {int(p['height'])},")
        lines.append(f"      targetBitrateKbps: {int(p['targetBitrateKbps'])},")
        lines.append(f"      fps: {int(p['fps'])},")
        lines.append(f"      description: {_dart_str(p['description'])},")
        lines.append("    ),")
    lines.extend([
        "  };",
        "}",
        "",
    ])
    return "\n".join(lines)


def _render_server_constants_py(preset_categories: list[dict], media_limits: dict) -> str:
    lines = [
        '"""物迹 (TraceItem) 全局常量与预设模板（由 shared/ 自动同步生成）"""',
        "",
        "# GENERATED CODE - DO NOT MODIFY BY HAND.",
        "# Source: shared/*.json (sync via scripts/sync_shared.py)",
        "",
        "# 多模态附件配额与限制参数",
        f"MAX_IMAGE_ATTACHMENTS = {int(media_limits.get('maxImageAttachments', 9))}",
        f"MAX_VIDEO_ATTACHMENTS = {int(media_limits.get('maxVideoAttachments', 3))}",
        f"MAX_AUDIO_ATTACHMENTS = {int(media_limits.get('maxAudioAttachments', 3))}",
        f"AUDIO_MAX_DURATION_SECONDS = {int(media_limits.get('audioMaxDurationSeconds', 120))}",
        f"VIDEO_MAX_DURATION_SECONDS = {int(media_limits.get('videoMaxDurationSeconds', 60))}",
        "",
        "# 14 套居家日常全场景预设分类模板库 (名称, Emoji图标, 默认排序)",
        "DEFAULT_CATEGORY_TEMPLATES = [",
    ]
    for item in preset_categories:
        lines.append(
            f'    ("{item["name"]}", "{item["icon"]}", {int(item["sortOrder"])}),'
        )
    lines.extend(["]", ""])
    return "\n".join(lines)


def build_targets() -> dict[Path, str]:
    category_emojis = _load_json("category_emojis.json")
    space_emojis = _load_json("space_emojis.json")
    themes = _load_json("themes.json")
    preset_categories = _load_json("preset_categories.json")
    media_limits = _load_json("media_limits.json")

    return {
        MOBILE_GEN_DIR / "shared_category_emojis.g.dart": _render_category_emojis_dart(category_emojis),
        MOBILE_GEN_DIR / "shared_space_emojis.g.dart": _render_space_emojis_dart(space_emojis),
        MOBILE_GEN_DIR / "shared_themes.g.dart": _render_themes_dart(themes),
        MOBILE_GEN_DIR / "shared_media_limits.g.dart": _render_media_limits_dart(media_limits),
        SERVER_CONSTANTS_PATH: _render_server_constants_py(preset_categories, media_limits),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="同步 shared/*.json 至 Mobile 与 Server")
    parser.add_argument("--check", action="store_true", help="仅校验是否一致，不写入文件")
    args = parser.parse_args()

    targets = build_targets()
    drifted: list[Path] = []

    for path, expected in targets.items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != expected:
            drifted.append(path)
            if not args.check:
                path.parent.mkdir(parents=True, exist_ok=True)
                with path.open("w", encoding="utf-8", newline="\n") as fh:
                    fh.write(expected)

    if args.check:
        if drifted:
            print("[sync_shared] 检测到未同步的生成文件:", file=sys.stderr)
            for p in drifted:
                print(f"  - {p.relative_to(ROOT)}", file=sys.stderr)
            return 1
        print(f"[sync_shared] 校验通过，共 {len(targets)} 个目标文件与 shared/*.json 完全一致。")
        return 0

    print(f"[sync_shared] 同步完成，共处理 {len(targets)} 个目标文件（更新 {len(drifted)} 个）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

