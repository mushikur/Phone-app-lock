import 'package:flutter/material.dart';

import '../../application/app_list_controller.dart';
import '../../application/permissions_controller.dart';
import 'home_screen.dart';
import 'permissions_screen.dart';

/// Decides whether to show onboarding or the app list.
///
/// The decision is made once, on the first successful permission read of the
/// launch: with every required permission already granted the app list opens
/// straight away, otherwise setup is shown until the user continues. Latching it
/// this way means granting the last permission does not yank the screen out from
/// under the user — the Continue button becomes enabled and they move on when
/// they are ready.
class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.permissionsController,
    required this.appListController,
  });

  final PermissionsController permissionsController;
  final AppListController appListController;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _showHome = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    widget.permissionsController.addListener(_onPermissionsChanged);
    widget.permissionsController.refresh();
  }

  @override
  void dispose() {
    widget.permissionsController.removeListener(_onPermissionsChanged);
    super.dispose();
  }

  void _onPermissionsChanged() {
    if (_decided) return;

    final state = widget.permissionsController.state;
    if (state.status != PermissionsStatus.ready) return;

    _decided = true;
    if (state.isReady && mounted) {
      setState(() => _showHome = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _showHome
          ? HomeScreen(
              key: const ValueKey('home'),
              controller: widget.appListController,
            )
          : PermissionsScreen(
              key: const ValueKey('permissions'),
              controller: widget.permissionsController,
              onContinue: () => setState(() => _showHome = true),
            ),
    );
  }
}
