import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/native_app_inventory_repository.dart';
import 'data/repositories/native_permission_repository.dart';

void main() {
  runApp(
    const SamirLockApp(
      inventoryRepository: NativeAppInventoryRepository(),
      permissionRepository: NativePermissionRepository(),
    ),
  );
}
