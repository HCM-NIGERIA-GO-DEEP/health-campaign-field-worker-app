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
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
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
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return initialize(boundaryCode);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return initialize?.call(boundaryCode);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return initialize(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return initialize?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
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
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return reload();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return reload?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return reload(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return reload?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
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
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return selectSchool(school);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return selectSchool?.call(school);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return selectSchool(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return selectSchool?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
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
abstract class _$$BednetDistributionSaveTeacherInfoEventImplCopyWith<$Res> {
  factory _$$BednetDistributionSaveTeacherInfoEventImplCopyWith(
          _$BednetDistributionSaveTeacherInfoEventImpl value,
          $Res Function(_$BednetDistributionSaveTeacherInfoEventImpl) then) =
      __$$BednetDistributionSaveTeacherInfoEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int classIndex, ClassTeacherInfoModel info});
}

/// @nodoc
class __$$BednetDistributionSaveTeacherInfoEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionSaveTeacherInfoEventImpl>
    implements _$$BednetDistributionSaveTeacherInfoEventImplCopyWith<$Res> {
  __$$BednetDistributionSaveTeacherInfoEventImplCopyWithImpl(
      _$BednetDistributionSaveTeacherInfoEventImpl _value,
      $Res Function(_$BednetDistributionSaveTeacherInfoEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? classIndex = null,
    Object? info = null,
  }) {
    return _then(_$BednetDistributionSaveTeacherInfoEventImpl(
      classIndex: null == classIndex
          ? _value.classIndex
          : classIndex // ignore: cast_nullable_to_non_nullable
              as int,
      info: null == info
          ? _value.info
          : info // ignore: cast_nullable_to_non_nullable
              as ClassTeacherInfoModel,
    ));
  }
}

/// @nodoc

class _$BednetDistributionSaveTeacherInfoEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionSaveTeacherInfoEvent {
  const _$BednetDistributionSaveTeacherInfoEventImpl(
      {required this.classIndex, required this.info});

  @override
  final int classIndex;
  @override
  final ClassTeacherInfoModel info;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.saveTeacherInfo(classIndex: $classIndex, info: $info)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty(
          'type', 'BednetDistributionEvent.saveTeacherInfo'))
      ..add(DiagnosticsProperty('classIndex', classIndex))
      ..add(DiagnosticsProperty('info', info));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionSaveTeacherInfoEventImpl &&
            (identical(other.classIndex, classIndex) ||
                other.classIndex == classIndex) &&
            (identical(other.info, info) || other.info == info));
  }

  @override
  int get hashCode => Object.hash(runtimeType, classIndex, info);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionSaveTeacherInfoEventImplCopyWith<
          _$BednetDistributionSaveTeacherInfoEventImpl>
      get copyWith =>
          __$$BednetDistributionSaveTeacherInfoEventImplCopyWithImpl<
              _$BednetDistributionSaveTeacherInfoEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return saveTeacherInfo(classIndex, info);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return saveTeacherInfo?.call(classIndex, info);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
    required TResult orElse(),
  }) {
    if (saveTeacherInfo != null) {
      return saveTeacherInfo(classIndex, info);
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return saveTeacherInfo(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return saveTeacherInfo?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
    required TResult orElse(),
  }) {
    if (saveTeacherInfo != null) {
      return saveTeacherInfo(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionSaveTeacherInfoEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionSaveTeacherInfoEvent(
          {required final int classIndex,
          required final ClassTeacherInfoModel info}) =
      _$BednetDistributionSaveTeacherInfoEventImpl;

  int get classIndex;
  ClassTeacherInfoModel get info;
  @JsonKey(ignore: true)
  _$$BednetDistributionSaveTeacherInfoEventImplCopyWith<
          _$BednetDistributionSaveTeacherInfoEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BednetDistributionSaveClassDetailsEventImplCopyWith<$Res> {
  factory _$$BednetDistributionSaveClassDetailsEventImplCopyWith(
          _$BednetDistributionSaveClassDetailsEventImpl value,
          $Res Function(_$BednetDistributionSaveClassDetailsEventImpl) then) =
      __$$BednetDistributionSaveClassDetailsEventImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int classIndex, ClassDetailsModel details});
}

/// @nodoc
class __$$BednetDistributionSaveClassDetailsEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionSaveClassDetailsEventImpl>
    implements _$$BednetDistributionSaveClassDetailsEventImplCopyWith<$Res> {
  __$$BednetDistributionSaveClassDetailsEventImplCopyWithImpl(
      _$BednetDistributionSaveClassDetailsEventImpl _value,
      $Res Function(_$BednetDistributionSaveClassDetailsEventImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? classIndex = null,
    Object? details = null,
  }) {
    return _then(_$BednetDistributionSaveClassDetailsEventImpl(
      classIndex: null == classIndex
          ? _value.classIndex
          : classIndex // ignore: cast_nullable_to_non_nullable
              as int,
      details: null == details
          ? _value.details
          : details // ignore: cast_nullable_to_non_nullable
              as ClassDetailsModel,
    ));
  }
}

/// @nodoc

class _$BednetDistributionSaveClassDetailsEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionSaveClassDetailsEvent {
  const _$BednetDistributionSaveClassDetailsEventImpl(
      {required this.classIndex, required this.details});

  @override
  final int classIndex;
  @override
  final ClassDetailsModel details;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.saveClassDetails(classIndex: $classIndex, details: $details)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty(
          'type', 'BednetDistributionEvent.saveClassDetails'))
      ..add(DiagnosticsProperty('classIndex', classIndex))
      ..add(DiagnosticsProperty('details', details));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionSaveClassDetailsEventImpl &&
            (identical(other.classIndex, classIndex) ||
                other.classIndex == classIndex) &&
            (identical(other.details, details) || other.details == details));
  }

  @override
  int get hashCode => Object.hash(runtimeType, classIndex, details);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionSaveClassDetailsEventImplCopyWith<
          _$BednetDistributionSaveClassDetailsEventImpl>
      get copyWith =>
          __$$BednetDistributionSaveClassDetailsEventImplCopyWithImpl<
              _$BednetDistributionSaveClassDetailsEventImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return saveClassDetails(classIndex, details);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return saveClassDetails?.call(classIndex, details);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
    required TResult orElse(),
  }) {
    if (saveClassDetails != null) {
      return saveClassDetails(classIndex, details);
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return saveClassDetails(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return saveClassDetails?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
    required TResult orElse(),
  }) {
    if (saveClassDetails != null) {
      return saveClassDetails(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionSaveClassDetailsEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionSaveClassDetailsEvent(
          {required final int classIndex,
          required final ClassDetailsModel details}) =
      _$BednetDistributionSaveClassDetailsEventImpl;

  int get classIndex;
  ClassDetailsModel get details;
  @JsonKey(ignore: true)
  _$$BednetDistributionSaveClassDetailsEventImplCopyWith<
          _$BednetDistributionSaveClassDetailsEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BednetDistributionCompleteClassAdministrationEventImplCopyWith<
    $Res> {
  factory _$$BednetDistributionCompleteClassAdministrationEventImplCopyWith(
          _$BednetDistributionCompleteClassAdministrationEventImpl value,
          $Res Function(
                  _$BednetDistributionCompleteClassAdministrationEventImpl)
              then) =
      __$$BednetDistributionCompleteClassAdministrationEventImplCopyWithImpl<
          $Res>;
  @useResult
  $Res call({int classIndex});
}

/// @nodoc
class __$$BednetDistributionCompleteClassAdministrationEventImplCopyWithImpl<
        $Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionCompleteClassAdministrationEventImpl>
    implements
        _$$BednetDistributionCompleteClassAdministrationEventImplCopyWith<
            $Res> {
  __$$BednetDistributionCompleteClassAdministrationEventImplCopyWithImpl(
      _$BednetDistributionCompleteClassAdministrationEventImpl _value,
      $Res Function(_$BednetDistributionCompleteClassAdministrationEventImpl)
          _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? classIndex = null,
  }) {
    return _then(_$BednetDistributionCompleteClassAdministrationEventImpl(
      classIndex: null == classIndex
          ? _value.classIndex
          : classIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$BednetDistributionCompleteClassAdministrationEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionCompleteClassAdministrationEvent {
  const _$BednetDistributionCompleteClassAdministrationEventImpl(
      {required this.classIndex});

  @override
  final int classIndex;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.completeClassAdministration(classIndex: $classIndex)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty(
          'type', 'BednetDistributionEvent.completeClassAdministration'))
      ..add(DiagnosticsProperty('classIndex', classIndex));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionCompleteClassAdministrationEventImpl &&
            (identical(other.classIndex, classIndex) ||
                other.classIndex == classIndex));
  }

  @override
  int get hashCode => Object.hash(runtimeType, classIndex);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BednetDistributionCompleteClassAdministrationEventImplCopyWith<
          _$BednetDistributionCompleteClassAdministrationEventImpl>
      get copyWith =>
          __$$BednetDistributionCompleteClassAdministrationEventImplCopyWithImpl<
                  _$BednetDistributionCompleteClassAdministrationEventImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return completeClassAdministration(classIndex);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return completeClassAdministration?.call(classIndex);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
    required TResult orElse(),
  }) {
    if (completeClassAdministration != null) {
      return completeClassAdministration(classIndex);
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return completeClassAdministration(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return completeClassAdministration?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
    required TResult orElse(),
  }) {
    if (completeClassAdministration != null) {
      return completeClassAdministration(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionCompleteClassAdministrationEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionCompleteClassAdministrationEvent(
          {required final int classIndex}) =
      _$BednetDistributionCompleteClassAdministrationEventImpl;

  int get classIndex;
  @JsonKey(ignore: true)
  _$$BednetDistributionCompleteClassAdministrationEventImplCopyWith<
          _$BednetDistributionCompleteClassAdministrationEventImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BednetDistributionClearNavIntentEventImplCopyWith<$Res> {
  factory _$$BednetDistributionClearNavIntentEventImplCopyWith(
          _$BednetDistributionClearNavIntentEventImpl value,
          $Res Function(_$BednetDistributionClearNavIntentEventImpl) then) =
      __$$BednetDistributionClearNavIntentEventImplCopyWithImpl<$Res>;
}

/// @nodoc
class __$$BednetDistributionClearNavIntentEventImplCopyWithImpl<$Res>
    extends _$BednetDistributionEventCopyWithImpl<$Res,
        _$BednetDistributionClearNavIntentEventImpl>
    implements _$$BednetDistributionClearNavIntentEventImplCopyWith<$Res> {
  __$$BednetDistributionClearNavIntentEventImplCopyWithImpl(
      _$BednetDistributionClearNavIntentEventImpl _value,
      $Res Function(_$BednetDistributionClearNavIntentEventImpl) _then)
      : super(_value, _then);
}

/// @nodoc

class _$BednetDistributionClearNavIntentEventImpl
    with DiagnosticableTreeMixin
    implements BednetDistributionClearNavIntentEvent {
  const _$BednetDistributionClearNavIntentEventImpl();

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionEvent.clearNavIntent()';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty('type', 'BednetDistributionEvent.clearNavIntent'));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BednetDistributionClearNavIntentEventImpl);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String boundaryCode) initialize,
    required TResult Function() reload,
    required TResult Function(HouseholdModel school) selectSchool,
    required TResult Function(int classIndex, ClassTeacherInfoModel info)
        saveTeacherInfo,
    required TResult Function(int classIndex, ClassDetailsModel details)
        saveClassDetails,
    required TResult Function(int classIndex) completeClassAdministration,
    required TResult Function() clearNavIntent,
  }) {
    return clearNavIntent();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String boundaryCode)? initialize,
    TResult? Function()? reload,
    TResult? Function(HouseholdModel school)? selectSchool,
    TResult? Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult? Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult? Function(int classIndex)? completeClassAdministration,
    TResult? Function()? clearNavIntent,
  }) {
    return clearNavIntent?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String boundaryCode)? initialize,
    TResult Function()? reload,
    TResult Function(HouseholdModel school)? selectSchool,
    TResult Function(int classIndex, ClassTeacherInfoModel info)?
        saveTeacherInfo,
    TResult Function(int classIndex, ClassDetailsModel details)?
        saveClassDetails,
    TResult Function(int classIndex)? completeClassAdministration,
    TResult Function()? clearNavIntent,
    required TResult orElse(),
  }) {
    if (clearNavIntent != null) {
      return clearNavIntent();
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
    required TResult Function(BednetDistributionSaveTeacherInfoEvent value)
        saveTeacherInfo,
    required TResult Function(BednetDistributionSaveClassDetailsEvent value)
        saveClassDetails,
    required TResult Function(
            BednetDistributionCompleteClassAdministrationEvent value)
        completeClassAdministration,
    required TResult Function(BednetDistributionClearNavIntentEvent value)
        clearNavIntent,
  }) {
    return clearNavIntent(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BednetDistributionInitializeEvent value)? initialize,
    TResult? Function(BednetDistributionReloadEvent value)? reload,
    TResult? Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult? Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult? Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult? Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult? Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
  }) {
    return clearNavIntent?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BednetDistributionInitializeEvent value)? initialize,
    TResult Function(BednetDistributionReloadEvent value)? reload,
    TResult Function(BednetDistributionSelectSchoolEvent value)? selectSchool,
    TResult Function(BednetDistributionSaveTeacherInfoEvent value)?
        saveTeacherInfo,
    TResult Function(BednetDistributionSaveClassDetailsEvent value)?
        saveClassDetails,
    TResult Function(BednetDistributionCompleteClassAdministrationEvent value)?
        completeClassAdministration,
    TResult Function(BednetDistributionClearNavIntentEvent value)?
        clearNavIntent,
    required TResult orElse(),
  }) {
    if (clearNavIntent != null) {
      return clearNavIntent(this);
    }
    return orElse();
  }
}

abstract class BednetDistributionClearNavIntentEvent
    implements BednetDistributionEvent {
  const factory BednetDistributionClearNavIntentEvent() =
      _$BednetDistributionClearNavIntentEventImpl;
}

/// @nodoc
mixin _$BednetDistributionState {
  bool get loading => throw _privateConstructorUsedError;
  String? get boundaryCode => throw _privateConstructorUsedError;
  List<HouseholdModel> get schools => throw _privateConstructorUsedError;
  List<IndividualModel> get classIndividuals =>
      throw _privateConstructorUsedError;
  HouseholdModel? get selectedSchool => throw _privateConstructorUsedError;
  int get currentClassIndex => throw _privateConstructorUsedError;
  List<ClassTeacherInfoModel?> get teacherInfoByClass =>
      throw _privateConstructorUsedError;
  List<ClassDetailsModel?> get classDetailsByClass =>
      throw _privateConstructorUsedError;
  List<DistributionSummaryModel?> get summariesByClass =>
      throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;
  BednetNavIntent get navIntent => throw _privateConstructorUsedError;

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
      List<IndividualModel> classIndividuals,
      HouseholdModel? selectedSchool,
      int currentClassIndex,
      List<ClassTeacherInfoModel?> teacherInfoByClass,
      List<ClassDetailsModel?> classDetailsByClass,
      List<DistributionSummaryModel?> summariesByClass,
      String? error,
      BednetNavIntent navIntent,
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
    Object? classIndividuals = null,
    Object? selectedSchool = freezed,
    Object? currentClassIndex = null,
    Object? teacherInfoByClass = null,
    Object? classDetailsByClass = null,
    Object? summariesByClass = null,
    Object? error = freezed,
    Object? navIntent = null,
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
      classIndividuals: null == classIndividuals
          ? _value.classIndividuals
          : classIndividuals // ignore: cast_nullable_to_non_nullable
              as List<IndividualModel>,
      selectedSchool: freezed == selectedSchool
          ? _value.selectedSchool
          : selectedSchool // ignore: cast_nullable_to_non_nullable
              as HouseholdModel?,
      currentClassIndex: null == currentClassIndex
          ? _value.currentClassIndex
          : currentClassIndex // ignore: cast_nullable_to_non_nullable
              as int,
      teacherInfoByClass: null == teacherInfoByClass
          ? _value.teacherInfoByClass
          : teacherInfoByClass // ignore: cast_nullable_to_non_nullable
              as List<ClassTeacherInfoModel?>,
      classDetailsByClass: null == classDetailsByClass
          ? _value.classDetailsByClass
          : classDetailsByClass // ignore: cast_nullable_to_non_nullable
              as List<ClassDetailsModel?>,
      summariesByClass: null == summariesByClass
          ? _value.summariesByClass
          : summariesByClass // ignore: cast_nullable_to_non_nullable
              as List<DistributionSummaryModel?>,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      navIntent: null == navIntent
          ? _value.navIntent
          : navIntent // ignore: cast_nullable_to_non_nullable
              as BednetNavIntent,
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
      List<IndividualModel> classIndividuals,
      HouseholdModel? selectedSchool,
      int currentClassIndex,
      List<ClassTeacherInfoModel?> teacherInfoByClass,
      List<ClassDetailsModel?> classDetailsByClass,
      List<DistributionSummaryModel?> summariesByClass,
      String? error,
      BednetNavIntent navIntent,
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
    Object? classIndividuals = null,
    Object? selectedSchool = freezed,
    Object? currentClassIndex = null,
    Object? teacherInfoByClass = null,
    Object? classDetailsByClass = null,
    Object? summariesByClass = null,
    Object? error = freezed,
    Object? navIntent = null,
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
      classIndividuals: null == classIndividuals
          ? _value._classIndividuals
          : classIndividuals // ignore: cast_nullable_to_non_nullable
              as List<IndividualModel>,
      selectedSchool: freezed == selectedSchool
          ? _value.selectedSchool
          : selectedSchool // ignore: cast_nullable_to_non_nullable
              as HouseholdModel?,
      currentClassIndex: null == currentClassIndex
          ? _value.currentClassIndex
          : currentClassIndex // ignore: cast_nullable_to_non_nullable
              as int,
      teacherInfoByClass: null == teacherInfoByClass
          ? _value._teacherInfoByClass
          : teacherInfoByClass // ignore: cast_nullable_to_non_nullable
              as List<ClassTeacherInfoModel?>,
      classDetailsByClass: null == classDetailsByClass
          ? _value._classDetailsByClass
          : classDetailsByClass // ignore: cast_nullable_to_non_nullable
              as List<ClassDetailsModel?>,
      summariesByClass: null == summariesByClass
          ? _value._summariesByClass
          : summariesByClass // ignore: cast_nullable_to_non_nullable
              as List<DistributionSummaryModel?>,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      navIntent: null == navIntent
          ? _value.navIntent
          : navIntent // ignore: cast_nullable_to_non_nullable
              as BednetNavIntent,
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
      final List<IndividualModel> classIndividuals = const [],
      this.selectedSchool,
      this.currentClassIndex = 0,
      final List<ClassTeacherInfoModel?> teacherInfoByClass = const [],
      final List<ClassDetailsModel?> classDetailsByClass = const [],
      final List<DistributionSummaryModel?> summariesByClass = const [],
      this.error,
      this.navIntent = BednetNavIntent.none,
      this.schoolSelectionSeq = 0})
      : _schools = schools,
        _classIndividuals = classIndividuals,
        _teacherInfoByClass = teacherInfoByClass,
        _classDetailsByClass = classDetailsByClass,
        _summariesByClass = summariesByClass,
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

  final List<IndividualModel> _classIndividuals;
  @override
  @JsonKey()
  List<IndividualModel> get classIndividuals {
    if (_classIndividuals is EqualUnmodifiableListView)
      return _classIndividuals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_classIndividuals);
  }

  @override
  final HouseholdModel? selectedSchool;
  @override
  @JsonKey()
  final int currentClassIndex;
  final List<ClassTeacherInfoModel?> _teacherInfoByClass;
  @override
  @JsonKey()
  List<ClassTeacherInfoModel?> get teacherInfoByClass {
    if (_teacherInfoByClass is EqualUnmodifiableListView)
      return _teacherInfoByClass;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_teacherInfoByClass);
  }

  final List<ClassDetailsModel?> _classDetailsByClass;
  @override
  @JsonKey()
  List<ClassDetailsModel?> get classDetailsByClass {
    if (_classDetailsByClass is EqualUnmodifiableListView)
      return _classDetailsByClass;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_classDetailsByClass);
  }

  final List<DistributionSummaryModel?> _summariesByClass;
  @override
  @JsonKey()
  List<DistributionSummaryModel?> get summariesByClass {
    if (_summariesByClass is EqualUnmodifiableListView)
      return _summariesByClass;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_summariesByClass);
  }

  @override
  final String? error;
  @override
  @JsonKey()
  final BednetNavIntent navIntent;

  /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
  @override
  @JsonKey()
  final int schoolSelectionSeq;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'BednetDistributionState(loading: $loading, boundaryCode: $boundaryCode, schools: $schools, classIndividuals: $classIndividuals, selectedSchool: $selectedSchool, currentClassIndex: $currentClassIndex, teacherInfoByClass: $teacherInfoByClass, classDetailsByClass: $classDetailsByClass, summariesByClass: $summariesByClass, error: $error, navIntent: $navIntent, schoolSelectionSeq: $schoolSelectionSeq)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'BednetDistributionState'))
      ..add(DiagnosticsProperty('loading', loading))
      ..add(DiagnosticsProperty('boundaryCode', boundaryCode))
      ..add(DiagnosticsProperty('schools', schools))
      ..add(DiagnosticsProperty('classIndividuals', classIndividuals))
      ..add(DiagnosticsProperty('selectedSchool', selectedSchool))
      ..add(DiagnosticsProperty('currentClassIndex', currentClassIndex))
      ..add(DiagnosticsProperty('teacherInfoByClass', teacherInfoByClass))
      ..add(DiagnosticsProperty('classDetailsByClass', classDetailsByClass))
      ..add(DiagnosticsProperty('summariesByClass', summariesByClass))
      ..add(DiagnosticsProperty('error', error))
      ..add(DiagnosticsProperty('navIntent', navIntent))
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
            const DeepCollectionEquality()
                .equals(other._classIndividuals, _classIndividuals) &&
            (identical(other.selectedSchool, selectedSchool) ||
                other.selectedSchool == selectedSchool) &&
            (identical(other.currentClassIndex, currentClassIndex) ||
                other.currentClassIndex == currentClassIndex) &&
            const DeepCollectionEquality()
                .equals(other._teacherInfoByClass, _teacherInfoByClass) &&
            const DeepCollectionEquality()
                .equals(other._classDetailsByClass, _classDetailsByClass) &&
            const DeepCollectionEquality()
                .equals(other._summariesByClass, _summariesByClass) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.navIntent, navIntent) ||
                other.navIntent == navIntent) &&
            (identical(other.schoolSelectionSeq, schoolSelectionSeq) ||
                other.schoolSelectionSeq == schoolSelectionSeq));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      loading,
      boundaryCode,
      const DeepCollectionEquality().hash(_schools),
      const DeepCollectionEquality().hash(_classIndividuals),
      selectedSchool,
      currentClassIndex,
      const DeepCollectionEquality().hash(_teacherInfoByClass),
      const DeepCollectionEquality().hash(_classDetailsByClass),
      const DeepCollectionEquality().hash(_summariesByClass),
      error,
      navIntent,
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
      final List<IndividualModel> classIndividuals,
      final HouseholdModel? selectedSchool,
      final int currentClassIndex,
      final List<ClassTeacherInfoModel?> teacherInfoByClass,
      final List<ClassDetailsModel?> classDetailsByClass,
      final List<DistributionSummaryModel?> summariesByClass,
      final String? error,
      final BednetNavIntent navIntent,
      final int schoolSelectionSeq}) = _$BednetDistributionStateImpl;
  const _BednetDistributionState._() : super._();

  @override
  bool get loading;
  @override
  String? get boundaryCode;
  @override
  List<HouseholdModel> get schools;
  @override
  List<IndividualModel> get classIndividuals;
  @override
  HouseholdModel? get selectedSchool;
  @override
  int get currentClassIndex;
  @override
  List<ClassTeacherInfoModel?> get teacherInfoByClass;
  @override
  List<ClassDetailsModel?> get classDetailsByClass;
  @override
  List<DistributionSummaryModel?> get summariesByClass;
  @override
  String? get error;
  @override
  BednetNavIntent get navIntent;
  @override

  /// Incremented on each successful [BednetDistributionEvent.selectSchool] for UI navigation.
  int get schoolSelectionSeq;
  @override
  @JsonKey(ignore: true)
  _$$BednetDistributionStateImplCopyWith<_$BednetDistributionStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}
