import 'package:flutter/material.dart';

import 'application/app_list_controller.dart';
import 'application/permissions_controller.dart';
import 'application/protection_controller.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/app_inventory_repository.dart';
import 'domain/repositories/permission_repository.dart';
import 'domain/repositories/protection_repository.dart';
import 'presentation/screens/permission_gate.dart';

/// Root of the Samir Lock app.
///
/// Owns the long-lived controllers and hands them to the gate; repositories are
/// injected so tests can swap in a fake native layer.
class SamirLockApp extends StatefulWidget {
  const SamirLockApp({
    super.key,
    required this.inventoryRepository,
    required this.permissionRepository,
    required this.protectionRepository,
  });

  final AppInventoryRepository inventoryRepository;
  final PermissionRepository permissionRepository;
  final ProtectionRepository protectionRepository;

  @override
  State<SamirLockApp> createState() => _SamirLockAppState();
}

class _SamirLockAppState extends State<SamirLockApp> {
  late final AppListController _appListController =
      AppListController(widget.inventoryRepository);
  late final PermissionsController _permissionsController =
      PermissionsController(widget.permissionRepository);
  late final ProtectionController _protectionController =
      ProtectionController(widget.protectionRepository);

  @override
  void dispose() {
    _appListController.dispose();
    _permissionsController.dispose();
    _protectionController.dispose();
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
      home: PermissionGate(
        permissionsController: _permissionsController,
        appListController: _appListController,
        protectionController: _protectionController,
      ),
    );
  }
}
