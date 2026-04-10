// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bednet_distribution.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BednetDistributionEvent {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(HouseholdModel school) updateSelectedSchool,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(HouseholdModel school)? updateSelectedSchool,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(HouseholdModel school)? updateSelectedSchool,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BednetDistributionInitializeEvent value)
        initialize,
    required TResult Function(BednetDistributionReloadEvent value) reload,
    required TResult Function(BednetDistributionSelectSchoolEvent value)
        selectSchool,
    required TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)
        updateSelectedSchool,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BednetDistributionEventCopyWith<$Res> {
  factory $BednetDistributionEventCopyWith(BednetDistributionEvent value,
          $Res Function(BednetDistributionEvent) then) =
      _$BednetDistributionEventCopyWithImpl<$Res, BednetDistributionEvent>;
}

/// @nodoc
class _$BednetDistributionEventCopyWithImpl<$Res,
        $Val extends BednetDistributionEvent>
    implements $BednetDistributionEventCopyWith<$Res> {
  _$BednetDistributionEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;
}

/// @nodoc
abstract class _$$BednetDistributionInitializeEventImplCopyWith<$Res> {
  factory _$$BednetDistributionInitializeEventImplCopyWith(
          _$BednetDistributionInitializeEventImpl value,
          $Res Function(_$BednetDistributionInitializeEventImpl) then) =
      __$$BednetDistributionInitializeEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({String boundaryCode});
}

/// @nodoc
class __$$BednetDistributionInitializeEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionInitializeEventImpl>
    implements _$$BednetDistributionInitializeEventImplCopyWith<$Res> {
  __$$BednetDistributionInitializeEventImplCopyWithImpl(
      _$BednetDistributionInitializeEventImpl _value,
      $Res Function(_$BednetDistributionInitializeEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? boundaryCode = null,
  }) {
    return _then(_$BednetDistributionInitializeEventImpl(
      boundaryCode: null == boundaryCode
          ? _value.boundaryCode
          : boundaryCode // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BednetDistributionInitializeEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionInitializeEvent {
  const _$BednetDistributionInitializeEventImpl({required this.boundaryCode});

  @override
  final String boundaryCode;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.initialize(boundaryCode: $boundaryCode)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'BednetDistributionEvent.initialize'))
      ..add(DiagnosticsProperty('boundaryCode', boundaryCode));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionInitializeEventImpl &&
            (identical(other.boundaryCode, boundaryCode) ||
                other.boundaryCode == boundaryCode));
  }

  @override
  int get hashCode => Object.hash(runtimeType, boundaryCode);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionInitializeEventImplCopyWith<
          _$BednetDistributionInitializeEventImpl>
      get copyWith => __$$BednetDistributionInitializeEventImplCopyWithImpl<
          _$BednetDistributionInitializeEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(HouseholdModel school) updateSelectedSchool,
  }) {
    return initialize(boundaryCode);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(HouseholdModel school)? updateSelectedSchool,
  }) {
    return initialize?.call(boundaryCode);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(HouseholdModel school)? updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (initialize != null) {
      return initialize(boundaryCode);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BednetDistributionInitializeEvent value)
        initialize,
    required TResult Function(BednetDistributionReloadEvent value) reload,
    required TResult Function(BednetDistributionSelectSchoolEvent value)
        selectSchool,
    required TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)
        updateSelectedSchool,
  }) {
    return initialize(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
  }) {
    return initialize?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (initialize != null) {
      return initialize(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionInitializeEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionInitializeEvent(
          {required final String boundaryCode}) =
      _$BednetDistributionInitializeEventImpl;

  String get boundaryCode;
  @JsonKey(ignore: true)
  _$$BednetDistributionInitializeEventImplCopyWith<
          _$BednetDistributionInitializeEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BednetDistributionReloadEventImplCopyWith<$Res> {
  factory _$$BednetDistributionReloadEventImplCopyWith(
          _$BednetDistributionReloadEventImpl value,
          $Res Function(_$BednetDistributionReloadEventImpl) then) =
      __$$BednetDistributionReloadEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$BednetDistributionReloadEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionReloadEventImpl>
    implements _$$BednetDistributionReloadEventImplCopyWith<$Res> {
  __$$BednetDistributionReloadEventImplCopyWithImpl(
      _$BednetDistributionReloadEventImpl _value,
      $Res Function(_$BednetDistributionReloadEventImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$BednetDistributionReloadEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionReloadEvent {
  const _$BednetDistributionReloadEventImpl();

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.reload()';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(DiagnosticsProperty('type', 'BednetDistributionEvent.reload'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionReloadEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(HouseholdModel school) updateSelectedSchool,
  }) {
    return reload();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(HouseholdModel school)? updateSelectedSchool,
  }) {
    return reload?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(HouseholdModel school)? updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (reload != null) {
      return reload();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BednetDistributionInitializeEvent value)
        initialize,
    required TResult Function(BednetDistributionReloadEvent value) reload,
    required TResult Function(BednetDistributionSelectSchoolEvent value)
        selectSchool,
    required TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)
        updateSelectedSchool,
  }) {
    return reload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
  }) {
    return reload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (reload != null) {
      return reload(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionReloadEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionReloadEvent() =
      _$BednetDistributionReloadEventImpl;
}

/// @nodoc
abstract class _$$BednetDistributionSelectSchoolEventImplCopyWith<$Res> {
  factory _$$BednetDistributionSelectSchoolEventImplCopyWith(
          _$BednetDistributionSelectSchoolEventImpl value,
          $Res Function(_$BednetDistributionSelectSchoolEventImpl) then) =
      __$$BednetDistributionSelectSchoolEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({HouseholdModel school});
}

/// @nodoc
class __$$BednetDistributionSelectSchoolEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionSelectSchoolEventImpl>
    implements _$$BednetDistributionSelectSchoolEventImplCopyWith<$Res> {
  __$$BednetDistributionSelectSchoolEventImplCopyWithImpl(
      _$BednetDistributionSelectSchoolEventImpl _value,
      $Res Function(_$BednetDistributionSelectSchoolEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? school = null,
  }) {
    return _then(_$BednetDistributionSelectSchoolEventImpl(
      school: null == school
          ? _value.school
          : school // ignore: cast_nullable_to_non_nullable
              as HouseholdModel,
    ));
  }
}

/// @nodoc

class _$BednetDistributionSelectSchoolEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionSelectSchoolEvent {
  const _$BednetDistributionSelectSchoolEventImpl({required this.school});

  @override
  final HouseholdModel school;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.selectSchool(school: $school)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'BednetDistributionEvent.selectSchool'))
      ..add(DiagnosticsProperty('school', school));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionSelectSchoolEventImpl &&
            (identical(other.school, school) || other.school == school));
  }

  @override
  int get hashCode => Object.hash(runtimeType, school);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionSelectSchoolEventImplCopyWith<
          _$BednetDistributionSelectSchoolEventImpl>
      get copyWith => __$$BednetDistributionSelectSchoolEventImplCopyWithImpl<
          _$BednetDistributionSelectSchoolEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(HouseholdModel school) updateSelectedSchool,
  }) {
    return selectSchool(school);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(HouseholdModel school)? updateSelectedSchool,
  }) {
    return selectSchool?.call(school);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(HouseholdModel school)? updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (selectSchool != null) {
      return selectSchool(school);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BednetDistributionInitializeEvent value)
        initialize,
    required TResult Function(BednetDistributionReloadEvent value) reload,
    required TResult Function(BednetDistributionSelectSchoolEvent value)
        selectSchool,
    required TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)
        updateSelectedSchool,
  }) {
    return selectSchool(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
  }) {
    return selectSchool?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (selectSchool != null) {
      return selectSchool(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionSelectSchoolEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionSelectSchoolEvent(
          {required final HouseholdModel school}) =
      _$BednetDistributionSelectSchoolEventImpl;

  HouseholdModel get school;
  @JsonKey(ignore: true)
  _$$BednetDistributionSelectSchoolEventImplCopyWith<
          _$BednetDistributionSelectSchoolEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BednetDistributionUpdateSelectedSchoolEventImplCopyWith<
    $Res> {
  factory _$$BednetDistributionUpdateSelectedSchoolEventImplCopyWith(
          _$BednetDistributionUpdateSelectedSchoolEventImpl value,
          $Res Function(_$BednetDistributionUpdateSelectedSchoolEventImpl)
              then) =
      __$$BednetDistributionUpdateSelectedSchoolEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({HouseholdModel school});
}

/// @nodoc
class __$$BednetDistributionUpdateSelectedSchoolEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionUpdateSelectedSchoolEventImpl>
    implements
        _$$BednetDistributionUpdateSelectedSchoolEventImplCopyWith<$Res> {
  __$$BednetDistributionUpdateSelectedSchoolEventImplCopyWithImpl(
      _$BednetDistributionUpdateSelectedSchoolEventImpl _value,
      $Res Function(_$BednetDistributionUpdateSelectedSchoolEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? school = null,
  }) {
    return _then(_$BednetDistributionUpdateSelectedSchoolEventImpl(
      school: null == school
          ? _value.school
          : school // ignore: cast_nullable_to_non_nullable
              as HouseholdModel,
    ));
  }
}

/// @nodoc

class _$BednetDistributionUpdateSelectedSchoolEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionUpdateSelectedSchoolEvent {
  const _$BednetDistributionUpdateSelectedSchoolEventImpl(
      {required this.school});

  @override
  final HouseholdModel school;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.updateSelectedSchool(school: $school)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty(
          'type', 'BednetDistributionEvent.updateSelectedSchool'))
      ..add(DiagnosticsProperty('school', school));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionUpdateSelectedSchoolEventImpl &&
            (identical(other.school, school) || other.school == school));
  }

  @override
  int get hashCode => Object.hash(runtimeType, school);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionUpdateSelectedSchoolEventImplCopyWith<
          _$BednetDistributionUpdateSelectedSchoolEventImpl>
      get copyWith =>
          __$$BednetDistributionUpdateSelectedSchoolEventImplCopyWithImpl<
                  _$BednetDistributionUpdateSelectedSchoolEventImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(HouseholdModel school) updateSelectedSchool,
  }) {
    return updateSelectedSchool(school);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(HouseholdModel school)? updateSelectedSchool,
  }) {
    return updateSelectedSchool?.call(school);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(HouseholdModel school)? updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (updateSelectedSchool != null) {
      return updateSelectedSchool(school);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BednetDistributionInitializeEvent value)
        initialize,
    required TResult Function(BednetDistributionReloadEvent value) reload,
    required TResult Function(BednetDistributionSelectSchoolEvent value)
        selectSchool,
    required TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)
        updateSelectedSchool,
  }) {
    return updateSelectedSchool(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
  }) {
    return updateSelectedSchool?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionUpdateSelectedSchoolEvent value)?
        updateSelectedSchool,
    required TResult orElse(),
  }) {
    if (updateSelectedSchool != null) {
      return updateSelectedSchool(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionUpdateSelectedSchoolEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionUpdateSelectedSchoolEvent(
          {required final HouseholdModel school}) =
      _$BednetDistributionUpdateSelectedSchoolEventImpl;

  HouseholdModel get school;
  @JsonKey(ignore: true)
  _$$BednetDistributionUpdateSelectedSchoolEventImplCopyWith<
          _$BednetDistributionUpdateSelectedSchoolEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BednetDistributionState {
  bool get loading => throw _privateConstructorUsedError;
  String? get boundaryCode => throw _privateConstructorUsedError;
  List<HouseholdModel> get schools => throw _privateConstructorUsedError;
  HouseholdModel? get selectedSchool => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
  int get schoolSelectionSeq => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $BednetDistributionStateCopyWith<BednetDistributionState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BednetDistributionStateCopyWith<$Res> {
  factory $BednetDistributionStateCopyWith(BednetDistributionState value,
          $Res Function(BednetDistributionState) then) =
      _$BednetDistributionStateCopyWithImpl<$Res, BednetDistributionState>;
  @useResult
  $Res call(
      {bool loading,
      String? boundaryCode,
      List<HouseholdModel> schools,
      HouseholdModel? selectedSchool,
      String? error,
      int schoolSelectionSeq});
}

/// @nodoc
class _$BednetDistributionStateCopyWithImpl<$Res,
        $Val extends BednetDistributionState>
    implements $BednetDistributionStateCopyWith<$Res> {
  _$BednetDistributionStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? boundaryCode = freezed,
    Object? schools = null,
    Object? selectedSchool = freezed,
    Object? error = freezed,
    Object? schoolSelectionSeq = null,
  }) {
    return _then(_value.copyWith(
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
      boundaryCode: freezed == boundaryCode
          ? _value.boundaryCode
          : boundaryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      schools: null == schools
          ? _value.schools
          : schools // ignore: cast_nullable_to_non_nullable
              as List<HouseholdModel>,
      selectedSchool: freezed == selectedSchool
          ? _value.selectedSchool
          : selectedSchool // ignore: cast_nullable_to_non_nullable
              as HouseholdModel?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      schoolSelectionSeq: null == schoolSelectionSeq
          ? _value.schoolSelectionSeq
          : schoolSelectionSeq // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BednetDistributionStateImplCopyWith<$Res>
    implements $BednetDistributionStateCopyWith<$Res> {
  factory _$$BednetDistributionStateImplCopyWith(
          _$BednetDistributionStateImpl value,
          $Res Function(_$BednetDistributionStateImpl) then) =
      __$$BednetDistributionStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool loading,
      String? boundaryCode,
      List<HouseholdModel> schools,
      HouseholdModel? selectedSchool,
      String? error,
      int schoolSelectionSeq});
}

/// @nodoc
class __$$BednetDistributionStateImplCopyWithImpl<$Res>
    extends _$BednetDistributionStateCopyWithImpl<$Res,
        _$BednetDistributionStateImpl>
    implements _$$BednetDistributionStateImplCopyWith<$Res> {
  __$$BednetDistributionStateImplCopyWithImpl(
      _$BednetDistributionStateImpl _value,
      $Res Function(_$BednetDistributionStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? loading = null,
    Object? boundaryCode = freezed,
    Object? schools = null,
    Object? selectedSchool = freezed,
    Object? error = freezed,
    Object? schoolSelectionSeq = null,
  }) {
    return _then(_$BednetDistributionStateImpl(
      loading: null == loading
          ? _value.loading
          : loading // ignore: cast_nullable_to_non_nullable
              as bool,
      boundaryCode: freezed == boundaryCode
          ? _value.boundaryCode
          : boundaryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      schools: null == schools
          ? _value._schools
          : schools // ignore: cast_nullable_to_non_nullable
              as List<HouseholdModel>,
      selectedSchool: freezed == selectedSchool
          ? _value.selectedSchool
          : selectedSchool // ignore: cast_nullable_to_non_nullable
              as HouseholdModel?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      schoolSelectionSeq: null == schoolSelectionSeq
          ? _value.schoolSelectionSeq
          : schoolSelectionSeq // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$BednetDistributionStateImpl extends _BednetDistributionState
    with DiagnosticableTreeMixin {
  const _$BednetDistributionStateImpl(
      {this.loading = false,
      this.boundaryCode,
      final List<HouseholdModel> schools = const [],
      this.selectedSchool,
      this.error,
      this.schoolSelectionSeq = 0})
      : _schools = schools,
        super._();

  @override
  @JsonKey()
  final bool loading;
  @override
  final String? boundaryCode;
  final List<HouseholdModel> _schools;
  @override
  @JsonKey()
  List<HouseholdModel> get schools {
    if (_schools is EqualUnmodifiableListView) return _schools;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_schools);
  }

  @override
  final HouseholdModel? selectedSchool;
  @override
  final String? error;

  /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
  @override
  @JsonKey()
  final int schoolSelectionSeq;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionState(loading: $loading, boundaryCode: $boundaryCode, schools: $schools, selectedSchool: $selectedSchool, error: $error, schoolSelectionSeq: $schoolSelectionSeq)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'BednetDistributionState'))
      ..add(DiagnosticsProperty('loading', loading))
      ..add(DiagnosticsProperty('boundaryCode', boundaryCode))
      ..add(DiagnosticsProperty('schools', schools))
      ..add(DiagnosticsProperty('selectedSchool', selectedSchool))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('schoolSelectionSeq', schoolSelectionSeq));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionStateImpl &&
            (identical(other.loading, loading) || other.loading == loading) &&
            (identical(other.boundaryCode, boundaryCode) ||
                other.boundaryCode == boundaryCode) &&
            const DeepCollectionEquality().equals(other._schools, _schools) &&
            (identical(other.selectedSchool, selectedSchool) ||
                other.selectedSchool == selectedSchool) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.schoolSelectionSeq, schoolSelectionSeq) ||
                other.schoolSelectionSeq == schoolSelectionSeq));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      loading,
      boundaryCode,
      const DeepCollectionEquality().hash(_schools),
      selectedSchool,
      error,
      schoolSelectionSeq);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionStateImplCopyWith<_$BednetDistributionStateImpl>
      get copyWith => __$$BednetDistributionStateImplCopyWithImpl<
          _$BednetDistributionStateImpl>(this, _$identity);
}

abstract class _BednetDistributionState extends BednetDistributionState {
  const factory _BednetDistributionState(
      {final bool loading,
      final String? boundaryCode,
      final List<HouseholdModel> schools,
      final HouseholdModel? selectedSchool,
      final String? error,
      final int schoolSelectionSeq}) = _$BednetDistributionStateImpl;
  const _BednetDistributionState._() : super._();

  @override
  bool get loading;
  @override
  String? get boundaryCode;
  @override
  List<HouseholdModel> get schools;
  @override
  HouseholdModel? get selectedSchool;
  @override
  String? get error;
  @override

  /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
  int get schoolSelectionSeq;
  @override
  @JsonKey(ignore: true)
  _$$BednetDistributionStateImplCopyWith<_$BednetDistributionStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
