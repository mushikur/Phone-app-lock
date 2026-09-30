/// One thing the user may need to do before Samir Lock can protect their apps.
///
/// Everything the setup screen shows is one of these, so a new user has a single
/// list to work through rather than settings spread across the app.
enum SetupItemId {
  usageAccess,
  displayOverOtherApps,
  notifications,
  notificationAccess,
  notificationPopups,
  background,
}

/// Where an item sits in the list.
enum SetupImportance {
  /// Samir Lock cannot lock anything without it.
  required_,

  /// Improves things, but protection works without it.
  recommended,
}

/// What still needs doing, if anything.
enum SetupItemStatus {
  /// Nothing to do.
  done,

  /// The user needs to act.
  actionNeeded,

  /// Does not apply to this phone or this configuration.
  notApplicable,
}

/// A single row on the setup screen.
class SetupItem {
  const SetupItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.importance,
    required this.actionLabel,
    this.detail,
  });

  final SetupItemId id;

  /// Plain language, no Android terminology.
  final String title;
  final String description;

  final SetupItemStatus status;
  final SetupImportance importance;

  /// Wording for the button, when there is something to do.
  final String actionLabel;

  /// Extra guidance shown under the row, such as where a setting lives on this
  /// particular phone.
  final String? detail;

  bool get needsAction => status == SetupItemStatus.actionNeeded;

  bool get isRequired => importance == SetupImportance.required_;
}

/// The whole setup picture.
class SetupState {
  const SetupState({this.items = const [], this.isLoading = true});

  final List<SetupItem> items;
  final bool isLoading;

  List<SetupItem> get visibleItems => items
      .where((item) => item.status != SetupItemStatus.notApplicable)
      .toList(growable: false);

  List<SetupItem> get requiredItems =>
      visibleItems.where((item) => item.isRequired).toList(growable: false);

  List<SetupItem> get recommendedItems =>
      visibleItems.where((item) => !item.isRequired).toList(growable: false);

  /// Everything outstanding, required or not.
  int get outstandingCount =>
      visibleItems.where((item) => item.needsAction).length;

  /// Whether the required items are all done.
  ///
  /// Recommended items deliberately do not block: the app should be usable
  /// without them, and saying "action required" for something optional trains
  /// people to ignore the warning that matters.
  bool get isReady =>
      !isLoading && requiredItems.every((item) => !item.needsAction);
}
