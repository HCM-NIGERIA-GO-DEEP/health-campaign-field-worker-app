import 'package:dart_mappable/dart_mappable.dart';

import '../data_model.dart';

/// Resolved model names, cached per runtime [Type].
///
/// A [Type] object is a stable map key under obfuscation - only the name it
/// prints is rewritten - so caching by type is safe.
final Map<Type, String> _entityTypeNameCache = {};

/// Returns the canonical class name of [entity]'s model, e.g. `HouseholdModel`.
///
/// Flow configs coming from MDMS address models by their Dart class name
/// (`models`, `entity`, `entityTypes`, `fallbackFormData`, interpolation keys
/// like `{{HouseholdModel.address.locality}}`), and the model factory
/// registries are keyed by those same names. `runtimeType.toString()` must not
/// be used to resolve them: `flutter build --obfuscate` renames classes, so it
/// returns a mangled name and every config lookup silently misses.
///
/// `dart_mappable` keeps the real name as a string literal in `MapperBase.id`,
/// which obfuscation leaves untouched, so the name is read from the model's
/// mapper instead.
String entityTypeName(EntityModel entity) {
  final type = entity.runtimeType;
  final cached = _entityTypeNameCache[type];
  if (cached != null) return cached;

  final name = _nameFromMapper(type) ??
      _nameFromStringify(entity) ??
      type.toString();
  _entityTypeNameCache[type] = name;

  return name;
}

/// Reads the id off the mapper registered for [type], if there is one.
String? _nameFromMapper(Type type) {
  try {
    return MapperContainer.globals.get(type)?.id;
  } catch (_) {
    return null;
  }
}

/// A mappable model's `toString()` is generated as `'<id>(field: value, ...)'`
/// and initializes its own mapper on the way through, so it recovers the name
/// even when the mapper has not been registered globally yet.
String? _nameFromStringify(EntityModel entity) {
  try {
    final stringified = entity.toString();
    final end = stringified.indexOf('(');

    return end > 0 ? stringified.substring(0, end) : null;
  } catch (_) {
    return null;
  }
}
