import 'package:flutter/material.dart';

import 'presentation/screens/home_screen.dart';

/// Root of the Samir Lock app.
///
/// Holds nothing but theming and the initial route for now; app-lock features
/// are introduced in later phases.
class SamirLockApp extends StatelessWidget {
  const SamirLockApp({super.key});

  static const _seedColor = Color(0xFF3F51B5);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samir Lock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
