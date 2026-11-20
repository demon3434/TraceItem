import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'core/api_service.dart';
import 'core/constants.dart';
import 'core/theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 收紧全局位图内存池上限（150张 / 40MB），避免千件物品连续下滑时内存持续膨胀
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20;
  await ThemeController.instance.initFromStorage();
  await ApiService.instance.initFromStorage();
  runApp(const TraceItemApp());
}

class TraceItemApp extends StatelessWidget {
  const TraceItemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (_, __) {
        final dopamine = ThemeController.instance.current;
        return ShadApp(
          title: '图觅',
          debugShowCheckedModeBanner: false,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: dopamine.toShadColorScheme(),
            radius: AppConstants.squircleBorder,
            inputTheme: ShadInputTheme(
              decoration: ShadDecoration(
                border: ShadBorder.all(
                  radius: const BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: ShadBorder.all(
                  radius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ),
          home: (ApiService.instance.isAuthenticated &&
                  !ApiService.instance.isAdmin)
              ? const MainShellScreen()
              : const LoginScreen(),
        );
      },
    );
  }
}
