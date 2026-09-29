import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'views/home_screen.dart';
import 'widgets/chat_dock.dart';
import 'app_navigator.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.restoreSession();
  runApp(const FoodReviewApp());
}

class FoodReviewApp extends StatefulWidget {
  const FoodReviewApp({super.key});

  @override
  State<FoodReviewApp> createState() => _FoodReviewAppState();
}

class _FoodReviewAppState extends State<FoodReviewApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodieSpot - Minimalist Food Review',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      builder: (context, child) =>
          ChatOverlay(child: child ?? const SizedBox.shrink()),
      home: HomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}
