import 'package:flutter/widgets.dart';

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

/// Singleton registry that stores page transition interceptors.
class FormPageNavigationRegistry {
  static final FormPageNavigationRegistry _instance =
      FormPageNavigationRegistry._internal();
  factory FormPageNavigationRegistry() => _instance;
  FormPageNavigationRegistry._internal();

  Object? _owner;
  FormPageNavigationInterceptor? interceptor;

  void register({
    required Object owner,
    required FormPageNavigationInterceptor interceptor,
  }) {
    _owner = owner;
    this.interceptor = interceptor;
  }

  void clearIfOwner(Object owner) {
    if (_owner == owner) {
      _owner = null;
      interceptor = null;
    }
  }
}
