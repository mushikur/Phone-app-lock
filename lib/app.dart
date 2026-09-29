import 'package:flutter/material.dart';

import 'application/app_list_controller.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/app_inventory_repository.dart';
import 'presentation/screens/home_screen.dart';

/// Root of the Samir Lock app.
///
/// Owns the single [AppListController] and hands it to the screen; the
/// repository is injected so tests can swap in a fake native layer.
class SamirLockApp extends StatefulWidget {
  const SamirLockApp({super.key, required this.repository});

  final AppInventoryRepository repository;

  @override
  State<SamirLockApp> createState() => _SamirLockAppState();
}

class _SamirLockAppState extends State<SamirLockApp> {
  late final AppListController _controller =
      AppListController(widget.repository);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Samir Lock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(controller: _controller),
    );
  }
}
