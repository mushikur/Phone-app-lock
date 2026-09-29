import 'package:flutter/material.dart';

import '../../application/app_list_controller.dart';
import '../../application/permissions_controller.dart';
import '../../application/protection_controller.dart';
import '../../application/security_controller.dart';
import '../widgets/app_background.dart';
import 'apps_screen.dart';
import 'dashboard_screen.dart';
import 'permissions_screen.dart';
import 'security_settings_screen.dart';

/// The three tabs of the app, and the state they share.
///
/// Uses an [IndexedStack] rather than swapping screens: the app list and its
/// decoded icons are built once and survive tab changes, so moving between tabs
/// costs nothing and never reloads the inventory.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.appListController,
    required this.protectionController,
    required this.securityController,
    required this.permissionsController,
  });

  final AppListController appListController;
  final ProtectionController protectionController;
  final SecurityController securityController;
  final PermissionsController permissionsController;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final AppLifecycleListener _lifecycleListener;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.appListController.load();
    widget.protectionController.refresh();
    widget.securityController.refresh();

    // Permissions can be revoked in Android Settings, the PIN is created on a
    // native screen, and the guard can be stopped behind the app's back, so
    // everything the UI reports is re-read whenever the app comes forward.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        widget.protectionController.refresh(showSpinner: false);
        widget.securityController.refresh(showSpinner: false);
        widget.permissionsController.refresh(showSpinner: false);
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _goToTab(int index) => setState(() => _index = index);

  Future<void> _openPermissions() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PermissionsScreen(
          controller: widget.permissionsController,
          onContinue: () => Navigator.of(context).pop(),
        ),
      ),
    );
    if (!mounted) return;
    // Coming back is the moment a newly granted permission should take effect.
    await widget.protectionController.refresh(showSpinner: false);
  }

  /// Switching protection off is the one action here that reduces security, so
  /// it asks first. Switching it on does not.
  Future<void> _onProtectionChanged(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Turn protection off?'),
          content: const Text(
            'Your locked apps will open without asking for your PIN until you '
            'turn it back on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it on'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final error = await widget.protectionController.setEnabled(enabled);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              appListController: widget.appListController,
              protectionController: widget.protectionController,
              securityController: widget.securityController,
              permissionsController: widget.permissionsController,
              onManageApps: () => _goToTab(1),
              onOpenSecurity: () => _goToTab(2),
              onOpenPermissions: _openPermissions,
              onProtectionChanged: _onProtectionChanged,
            ),
            AppsScreen(controller: widget.appListController),
            SecuritySettingsScreen(
              securityController: widget.securityController,
              protectionController: widget.protectionController,
              permissionsController: widget.permissionsController,
              onOpenPermissions: _openPermissions,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'Security',
          ),
        ],
      ),
    );
  }
}
