import 'package:flutter/widgets.dart';

import '../models/property_schema/property_schema.dart';

/// What the caller should do with a submission after a dedup check.
enum DedupCheckOutcome {
  /// Nothing similar was found, or the user chose to register anyway.
  proceed,

  /// The user backed out of the duplicate warning; abandon the submission.
  abort,
}

/// Everything a dedup check needs to score the form against existing records.
class DedupCheckRequest {
  /// The page's dedup config, straight from the form schema.
  final DedupCheck config;

  /// The page's dialog config, when it declares one. Null means the renderer
  /// should fall back to its own built-in dialog.
  final DedupAlertPopUp? alert;

  /// Key of the schema being filled (e.g. `HOUSEHOLD`).
  final String schemaKey;

  /// Name of the page whose submit button was pressed.
  final String pageName;

  /// Current values of the page's form controls.
  final Map<String, dynamic> formValues;

  /// Navigation data for the flow, used to resolve `{{...}}` filter templates.
  final Map<String, dynamic> navigationParams;

  /// Whether the form is editing an existing record.
  final bool isEdit;

  const DedupCheckRequest({
    required this.config,
    this.alert,
    required this.schemaKey,
    required this.pageName,
    required this.formValues,
    required this.navigationParams,
    required this.isEdit,
  });
}

/// Runs the similarity search and, when it finds something, asks the user how
/// to proceed. Implemented outside this package because the search needs
/// database access.
typedef DedupCheckCallback = Future<DedupCheckOutcome> Function(
  DedupCheckRequest request,
);

/// Singleton registry that stores the pre-submit dedup check callback.
/// This survives across route pushes (unlike InheritedWidget).
///
/// Tracks the owning [State] so that a disposing provider only clears
/// the registry when it still owns it, preventing a newer provider's
/// callback from being wiped by an older provider's dispose.
class DedupCheckRegistry {
  static final DedupCheckRegistry _instance = DedupCheckRegistry._internal();
  factory DedupCheckRegistry() => _instance;
  DedupCheckRegistry._internal();

  /// The [State] that last registered a callback. Used to guard [clearIfOwner].
  Object? _owner;

  DedupCheckCallback? checkFn;

  /// Registers [checkFn] and records [owner] as the current owner.
  void register({
    required Object owner,
    required DedupCheckCallback? checkFn,
  }) {
    _owner = owner;
    this.checkFn = checkFn;
  }

  /// Clears the callback only if [owner] is still the current owner.
  void clearIfOwner(Object owner) {
    if (_owner == owner) {
      _owner = null;
      checkFn = null;
    }
  }
}

/// Provides the pre-submit duplicate check used by pages carrying a
/// [DedupCheck].
///
/// Registers the callback in [DedupCheckRegistry] on mount so it is reachable
/// from child routes pushed via auto_route, and clears it on dispose so a
/// stale callback cannot leak into a later flow.
class DedupCheckProvider extends StatefulWidget {
  final DedupCheckCallback? checkFn;

  final Widget child;

  const DedupCheckProvider({
    super.key,
    required this.child,
    this.checkFn,
  });

  @override
  State<DedupCheckProvider> createState() => _DedupCheckProviderState();
}

class _DedupCheckProviderState extends State<DedupCheckProvider> {
  @override
  void initState() {
    super.initState();
    _registerCallback();
  }

  @override
  void didUpdateWidget(DedupCheckProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkFn != oldWidget.checkFn) {
      _registerCallback();
    }
  }

  void _registerCallback() {
    DedupCheckRegistry().register(owner: this, checkFn: widget.checkFn);
  }

  @override
  void dispose() {
    DedupCheckRegistry().clearIfOwner(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
