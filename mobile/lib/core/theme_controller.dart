import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/shared_themes.g.dart';

class DopamineThemeConfig {
  final String id;
  final String name;
  final String icon;
  final String desc;
  final Color primary;
  final Color secondary;
  final Color lightBg;
  final Color lightBorder;
  final Color darkText;
  final Color pageBg;

  const DopamineThemeConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.desc,
    required this.primary,
    required this.secondary,
    required this.lightBg,
    required this.lightBorder,
    required this.darkText,
    required this.pageBg,
  });

  LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  List<BoxShadow> get ambientShadows => [
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  ShadColorScheme toShadColorScheme() {
    return ShadSlateColorScheme.light(
      primary: primary,
      primaryForeground: Colors.white,
      background: pageBg,
      ring: primary,
      secondary: lightBg,
      secondaryForeground: darkText,
      accent: lightBg,
      accentForeground: darkText,
    );
  }
}

final List<DopamineThemeConfig> kDopamineThemes = kSharedDopamineThemes
    .map(
      (t) => DopamineThemeConfig(
        id: t.id,
        name: t.name,
        icon: t.icon,
        desc: t.desc,
        primary: t.primary,
        secondary: t.secondary,
        lightBg: t.lightBg,
        lightBorder: t.lightBorder,
        darkText: t.darkText,
        pageBg: t.pageBg,
      ),
    )
    .toList(growable: false);

class ThemeController extends ChangeNotifier {
  static const String storageKey = 'traceitem_theme';
  static final ThemeController instance = ThemeController._internal();

  ThemeController._internal();

  DopamineThemeConfig _current = kDopamineThemes.first;
  int? _activeUserId;

  DopamineThemeConfig get current => _current;
  String get currentId => _current.id;

  String _keyForUser(int? userId) =>
      userId != null ? '${storageKey}_u_$userId' : storageKey;

  Future<void> initFromStorage([int? userId]) async {
    _activeUserId = userId;
    if (userId == null) {
      if (_current.id != kDopamineThemes.first.id) {
        _current = kDopamineThemes.first;
        notifyListeners();
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedId =
        prefs.getString(_keyForUser(userId)) ?? prefs.getString(storageKey);
    final found = savedId != null
        ? kDopamineThemes.where((t) => t.id == savedId).firstOrNull
        : null;
    final target = found ?? kDopamineThemes.first;
    if (target.id != _current.id) {
      _current = target;
      notifyListeners();
    }
  }

  Future<void> switchUser(int? userId) => initFromStorage(userId);

  Future<void> selectTheme(String themeId) async {
    final found = kDopamineThemes.where((t) => t.id == themeId).firstOrNull;
    if (found == null || found.id == _current.id) return;
    _current = found;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForUser(_activeUserId), themeId);
  }
}

