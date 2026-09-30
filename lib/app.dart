import 'package:flutter/material.dart';

import 'application/app_list_controller.dart';
import 'application/permissions_controller.dart';
import 'application/protection_controller.dart';
import 'application/security_controller.dart';
import 'application/setup_controller.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/app_inventory_repository.dart';
import 'domain/repositories/permission_repository.dart';
import 'domain/repositories/protection_repository.dart';
import 'domain/repositories/device_repository.dart';
import 'domain/repositories/security_repository.dart';
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
    required this.securityRepository,
    required this.deviceRepository,
  });

  final AppInventoryRepository inventoryRepository;
  final PermissionRepository permissionRepository;
  final ProtectionRepository protectionRepository;
  final SecurityRepository securityRepository;
  final DeviceRepository deviceRepository;

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
  late final SecurityController _securityController =
      SecurityController(widget.securityRepository);
  late final SetupController _setupController = SetupController(
    permissions: widget.permissionRepository,
    security: widget.securityRepository,
    device: widget.deviceRepository,
  );

  @override
  void dispose() {
    _appListController.dispose();
    _permissionsController.dispose();
    _protectionController.dispose();
    _securityController.dispose();
    _setupController.dispose();
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
        securityController: _securityController,
        setupController: _setupController,
      ),
    );
  }
}
