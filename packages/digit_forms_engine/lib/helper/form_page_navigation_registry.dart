import 'package:flutter/widgets.dart';

class FormPageNavigationBlocked implements Exception {
  final String message;
  const FormPageNavigationBlocked(this.message);
}

/// Callback invoked when transitioning between form pages, allowing external
/// handlers to generate IDs or enrich navigation params based on form values.
typedef FormPageNavigationInterceptor = Future<Map<String, dynamic>?> Function({
  required BuildContext context,
  required String currentSchemaKey,
  required String fromPageName,
  required String toPageName,
  required Map<String, dynamic> formValues,
  required Map<String, dynamic>? currentNavParams,
});

/// Callback that resolves a `fn:functionName(arg1, arg2, ...)` template
/// expression used in display-only fields. The app layer registers a concrete
/// implementation that delegates to [FunctionRegistry.call] so the forms engine
/// doesn't need to know about domain-specific function mappings.
///
/// - [fnExpression]: the full `fn:…(…)` string (e.g.
///   `fn:getDiscrepancyReasonDisplayCode(navigation.discrepancyReason)`)
/// - [resolveContext]: the context map used to resolve argument paths.
///
/// Returns the resolved display value, or `null` if the function is unknown.
typedef DisplayFieldResolver = String? Function(
  String fnExpression,
  Map<String, dynamic> resolveContext,
);

/// Singleton registry that stores page transition interceptors.
///
/// Uses a stack internally so that overlapping [ScreenBuilder] lifecycles
/// (e.g. during a push-transition where both the outgoing and incoming routes
/// are mounted) don't silently clobber each other. Each [register] pushes a
/// new entry; [clearIfOwner] pops only the entry belonging to that owner.
class FormPageNavigationRegistry {
  static final FormPageNavigationRegistry _instance =
      FormPageNavigationRegistry._internal();
  factory FormPageNavigationRegistry() => _instance;
  FormPageNavigationRegistry._internal();

  final List<_InterceptorEntry> _stack = [];

  /// Optional resolver for `fn:` template expressions in display-only fields.
  /// Registered once by the app layer; not owner-scoped.
  DisplayFieldResolver? displayFieldResolver;

  /// The currently active interceptor (top of stack), or `null`.
  FormPageNavigationInterceptor? get interceptor =>
      _stack.isNotEmpty ? _stack.last.interceptor : null;

  void register({
    required Object owner,
    required FormPageNavigationInterceptor interceptor,
  }) {
    // Prevent the same owner from registering twice (e.g. hot-reload).
    _stack.removeWhere((e) => e.owner == owner);
    _stack.add(_InterceptorEntry(owner: owner, interceptor: interceptor));
  }

  void clearIfOwner(Object owner) {
    _stack.removeWhere((e) => e.owner == owner);
  }
}

class _InterceptorEntry {
  final Object owner;
  final FormPageNavigationInterceptor interceptor;
  const _InterceptorEntry({required this.owner, required this.interceptor});
}
