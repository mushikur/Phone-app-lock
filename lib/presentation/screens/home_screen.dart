import 'package:flutter/material.dart';

import '../../application/app_list_controller.dart';
import '../../application/protection_controller.dart';
import '../../application/security_controller.dart';
import '../../domain/entities/installed_app.dart';
import '../widgets/app_list_tile.dart';
import '../widgets/app_search_field.dart';
import '../widgets/lock_summary_card.dart';
import '../widgets/protection_card.dart';
import '../widgets/security_card.dart';
import '../widgets/state_views.dart';

/// Main screen: the installed-app inventory with a lock toggle per app.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.protectionController,
    required this.securityController,
  });

  final AppListController controller;
  final ProtectionController protectionController;
  final SecurityController securityController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
    widget.protectionController.refresh();
    widget.securityController.refresh();
    // A permission revoked in Android Settings can stop the guard behind the
    // app's back, and the PIN is created on a native screen, so both are re-read
    // whenever the app comes forward.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        widget.protectionController.refresh(showSpinner: false);
        widget.securityController.refresh(showSpinner: false);
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSetUpPin() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.securityController.openPinSetup();
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _onProtectionChanged(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.protectionController.setEnabled(enabled);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _onToggle(InstalledApp app) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await widget.controller.toggleLock(app);
    if (error == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  void _clearFilters() {
    _searchController.clear();
    widget.controller
      ..setQuery('')
      ..setFilter(AppFilter.all);
  }

  /// Identity of the current body, so [AnimatedSwitcher] only crossfades when
  /// the kind of content changes rather than on every list update.
  String _bodyKey(AppListState state) {
    if (state.status != AppListStatus.ready) return state.status.name;
    if (state.apps.isEmpty) return 'empty';
    if (state.hasNoMatches) return 'no-matches';
    return 'list';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samir Lock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload apps',
            onPressed: () => widget.controller.load(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: LockSummaryCard(
                    lockedCount: state.lockedCount,
                    totalCount: state.totalCount,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListenableBuilder(
                    listenable: widget.securityController,
                    builder: (context, _) => SecurityCard(
                      state: widget.securityController.state,
                      onSetUpPin: _onSetUpPin,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ListenableBuilder(
                    listenable: widget.protectionController,
                    builder: (context, _) => ProtectionCard(
                      state: widget.protectionController.state,
                      lockedCount: state.lockedCount,
                      onChanged: _onProtectionChanged,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppSearchField(
                    controller: _searchController,
                    onChanged: widget.controller.setQuery,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _FilterChips(
                      filter: state.filter,
                      lockedCount: state.lockedCount,
                      onChanged: widget.controller.setFilter,
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _Body(
                      key: ValueKey(_bodyKey(state)),
                      state: state,
                      onToggle: _onToggle,
                      onRetry: () => widget.controller.load(),
                      onClearFilters: _clearFilters,
                      onRefresh: () =>
                          widget.controller.load(showSpinner: false),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onRetry,
    required this.onClearFilters,
    required this.onRefresh,
  });

  final AppListState state;
  final ValueChanged<InstalledApp> onToggle;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 16);

    switch (state.status) {
      case AppListStatus.loading:
        return const Padding(
          padding: padding,
          child: AppListLoadingView(),
        );

      case AppListStatus.error:
        return AppListMessageView(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: state.errorMessage ?? 'The app list could not be loaded.',
          actionLabel: 'Try again',
          onAction: onRetry,
        );

      case AppListStatus.ready:
        if (state.apps.isEmpty) {
          return const AppListMessageView(
            icon: Icons.apps_outlined,
            title: 'No apps found',
            message:
                'Samir Lock could not find any launchable apps on this device.',
          );
        }

        if (state.hasNoMatches) {
          return AppListMessageView(
            icon: Icons.search_off,
            title: 'No matching apps',
            message: state.filter == AppFilter.locked
                ? 'You have not locked any apps that match this search yet.'
                : 'Try a different search term.',
            actionLabel: 'Clear filters',
            onAction: onClearFilters,
          );
        }

        final apps = state.visibleApps;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: apps.length,
            itemExtent: 72,
            itemBuilder: (context, index) {
              final app = apps[index];
              return AppListTile(
                key: ValueKey(app.packageName),
                app: app,
                isLocked: state.isLocked(app),
                onToggle: () => onToggle(app),
              );
            },
          ),
        );
    }
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.lockedCount,
    required this.onChanged,
  });

  final AppFilter filter;
  final int lockedCount;
  final ValueChanged<AppFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All apps'),
          selected: filter == AppFilter.all,
          onSelected: (_) => onChanged(AppFilter.all),
        ),
        ChoiceChip(
          label: Text('Locked ($lockedCount)'),
          selected: filter == AppFilter.locked,
          onSelected: (_) => onChanged(AppFilter.locked),
        ),
      ],
    );
  }
}
