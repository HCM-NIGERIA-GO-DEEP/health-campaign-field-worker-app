// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'beneficiary_info.dart';

class BeneficiaryInfoSearchModelMapper
    extends SubClassMapperBase<BeneficiaryInfoSearchModel> {
  BeneficiaryInfoSearchModelMapper._();

  static BeneficiaryInfoSearchModelMapper? _instance;
  static BeneficiaryInfoSearchModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals
          .use(_instance = BeneficiaryInfoSearchModelMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BeneficiaryInfoSearchModel';

  static List<String>? _$id(BeneficiaryInfoSearchModel v) => v.id;
  static const Field<BeneficiaryInfoSearchModel, List<String>> _f$id =
      Field('id', _$id, opt: true);
  static String? _$householdClientReferenceId(BeneficiaryInfoSearchModel v) =>
      v.householdClientReferenceId;
  static const Field<BeneficiaryInfoSearchModel, String>
      _f$householdClientReferenceId = Field(
          'householdClientReferenceId', _$householdClientReferenceId,
          opt: true);
  static String? _$givenName(BeneficiaryInfoSearchModel v) => v.givenName;
  static const Field<BeneficiaryInfoSearchModel, String> _f$givenName =
      Field('givenName', _$givenName, opt: true);
  static String? _$clientReferenceId(BeneficiaryInfoSearchModel v) =>
      v.clientReferenceId;
  static const Field<BeneficiaryInfoSearchModel, String> _f$clientReferenceId =
      Field('clientReferenceId', _$clientReferenceId, opt: true);
  static String? _$tenantId(BeneficiaryInfoSearchModel v) => v.tenantId;
  static const Field<BeneficiaryInfoSearchModel, String> _f$tenantId =
      Field('tenantId', _$tenantId, opt: true);
  static double? _$latitude(BeneficiaryInfoSearchModel v) => v.latitude;
  static const Field<BeneficiaryInfoSearchModel, double> _f$latitude =
      Field('latitude', _$latitude, opt: true);
  static double? _$longitude(BeneficiaryInfoSearchModel v) => v.longitude;
  static const Field<BeneficiaryInfoSearchModel, double> _f$longitude =
      Field('longitude', _$longitude, opt: true);
  static String? _$boundaryCode(BeneficiaryInfoSearchModel v) => v.boundaryCode;
  static const Field<BeneficiaryInfoSearchModel, String> _f$boundaryCode =
      Field('boundaryCode', _$boundaryCode, opt: true);
  static AuditDetails? _$auditDetails(BeneficiaryInfoSearchModel v) =>
      v.auditDetails;
  static const Field<BeneficiaryInfoSearchModel, AuditDetails> _f$auditDetails =
      Field('auditDetails', _$auditDetails, mode: FieldMode.member);
  static AdditionalFields? _$additionalFields(BeneficiaryInfoSearchModel v) =>
      v.additionalFields;
  static const Field<BeneficiaryInfoSearchModel, AdditionalFields>
      _f$additionalFields =
      Field('additionalFields', _$additionalFields, mode: FieldMode.member);

  @override
  final MappableFields<BeneficiaryInfoSearchModel> fields = const {
    #id: _f$id,
    #householdClientReferenceId: _f$householdClientReferenceId,
    #givenName: _f$givenName,
    #clientReferenceId: _f$clientReferenceId,
    #tenantId: _f$tenantId,
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #boundaryCode: _f$boundaryCode,
    #auditDetails: _f$auditDetails,
    #additionalFields: _f$additionalFields,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = MappableClass.useAsDefault;
  @override
  late final ClassMapperBase superMapper =
      EntitySearchModelMapper.ensureInitialized();

  static BeneficiaryInfoSearchModel _instantiate(DecodingData data) {
    return BeneficiaryInfoSearchModel.ignoreDeleted(
        id: data.dec(_f$id),
        householdClientReferenceId: data.dec(_f$householdClientReferenceId),
        givenName: data.dec(_f$givenName),
        clientReferenceId: data.dec(_f$clientReferenceId),
        tenantId: data.dec(_f$tenantId),
        latitude: data.dec(_f$latitude),
        longitude: data.dec(_f$longitude),
        boundaryCode: data.dec(_f$boundaryCode));
  }

  @override
  final Function instantiate = _instantiate;

  static BeneficiaryInfoSearchModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BeneficiaryInfoSearchModel>(map);
  }

  static BeneficiaryInfoSearchModel fromJson(String json) {
    return ensureInitialized().decodeJson<BeneficiaryInfoSearchModel>(json);
  }
}

mixin BeneficiaryInfoSearchModelMappable {
  String toJson() {
    return BeneficiaryInfoSearchModelMapper.ensureInitialized()
        .encodeJson<BeneficiaryInfoSearchModel>(
            this as BeneficiaryInfoSearchModel);
  }

  Map<String, dynamic> toMap() {
    return BeneficiaryInfoSearchModelMapper.ensureInitialized()
        .encodeMap<BeneficiaryInfoSearchModel>(
            this as BeneficiaryInfoSearchModel);
  }

  BeneficiaryInfoSearchModelCopyWith<BeneficiaryInfoSearchModel,
          BeneficiaryInfoSearchModel, BeneficiaryInfoSearchModel>
      get copyWith => _BeneficiaryInfoSearchModelCopyWithImpl(
          this as BeneficiaryInfoSearchModel, $identity, $identity);
  @override
  String toString() {
    return BeneficiaryInfoSearchModelMapper.ensureInitialized()
        .stringifyValue(this as BeneficiaryInfoSearchModel);
  }

  @override
  bool operator ==(Object other) {
    return BeneficiaryInfoSearchModelMapper.ensureInitialized()
        .equalsValue(this as BeneficiaryInfoSearchModel, other);
  }

  @override
  int get hashCode {
    return BeneficiaryInfoSearchModelMapper.ensureInitialized()
        .hashValue(this as BeneficiaryInfoSearchModel);
  }
}

extension BeneficiaryInfoSearchModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BeneficiaryInfoSearchModel, $Out> {
  BeneficiaryInfoSearchModelCopyWith<$R, BeneficiaryInfoSearchModel, $Out>
      get $asBeneficiaryInfoSearchModel => $base
          .as((v, t, t2) => _BeneficiaryInfoSearchModelCopyWithImpl(v, t, t2));
}

abstract class BeneficiaryInfoSearchModelCopyWith<
    $R,
    $In extends BeneficiaryInfoSearchModel,
    $Out> implements EntitySearchModelCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get id;
  @override
  $R call(
      {List<String>? id,
      String? householdClientReferenceId,
      String? givenName,
      String? clientReferenceId,
      String? tenantId,
      double? latitude,
      double? longitude,
      String? boundaryCode});
  BeneficiaryInfoSearchModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _BeneficiaryInfoSearchModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BeneficiaryInfoSearchModel, $Out>
    implements
        BeneficiaryInfoSearchModelCopyWith<$R, BeneficiaryInfoSearchModel,
            $Out> {
  _BeneficiaryInfoSearchModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BeneficiaryInfoSearchModel> $mapper =
      BeneficiaryInfoSearchModelMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>? get id =>
      $value.id != null
          ? ListCopyWith($value.id!, (v, t) => ObjectCopyWith(v, $identity, t),
              (v) => call(id: v))
          : null;
  @override
  $R call(
          {Object? id = $none,
          Object? householdClientReferenceId = $none,
          Object? givenName = $none,
          Object? clientReferenceId = $none,
          Object? tenantId = $none,
          Object? latitude = $none,
          Object? longitude = $none,
          Object? boundaryCode = $none}) =>
      $apply(FieldCopyWithData({
        if (id != $none) #id: id,
        if (householdClientReferenceId != $none)
          #householdClientReferenceId: householdClientReferenceId,
        if (givenName != $none) #givenName: givenName,
        if (clientReferenceId != $none) #clientReferenceId: clientReferenceId,
        if (tenantId != $none) #tenantId: tenantId,
        if (latitude != $none) #latitude: latitude,
        if (longitude != $none) #longitude: longitude,
        if (boundaryCode != $none) #boundaryCode: boundaryCode
      }));
  @override
  BeneficiaryInfoSearchModel $make(CopyWithData data) =>
      BeneficiaryInfoSearchModel.ignoreDeleted(
          id: data.get(#id, or: $value.id),
          householdClientReferenceId: data.get(#householdClientReferenceId,
              or: $value.householdClientReferenceId),
          givenName: data.get(#givenName, or: $value.givenName),
          clientReferenceId:
              data.get(#clientReferenceId, or: $value.clientReferenceId),
          tenantId: data.get(#tenantId, or: $value.tenantId),
          latitude: data.get(#latitude, or: $value.latitude),
          longitude: data.get(#longitude, or: $value.longitude),
          boundaryCode: data.get(#boundaryCode, or: $value.boundaryCode));

  @override
  BeneficiaryInfoSearchModelCopyWith<$R2, BeneficiaryInfoSearchModel, $Out2>
      $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
          _BeneficiaryInfoSearchModelCopyWithImpl($value, $cast, t);
}

class BeneficiaryInfoModelMapper
    extends SubClassMapperBase<BeneficiaryInfoModel> {
  BeneficiaryInfoModelMapper._();

  static BeneficiaryInfoModelMapper? _instance;
  static BeneficiaryInfoModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = BeneficiaryInfoModelMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BeneficiaryInfoModel';

  static BeneficiaryInfoAdditionalFields? _$additionalFields(
          BeneficiaryInfoModel v) =>
      v.additionalFields;
  static const Field<BeneficiaryInfoModel, BeneficiaryInfoAdditionalFields>
      _f$additionalFields =
      Field('additionalFields', _$additionalFields, opt: true);
  static String? _$id(BeneficiaryInfoModel v) => v.id;
  static const Field<BeneficiaryInfoModel, String> _f$id =
      Field('id', _$id, opt: true);
  static String _$householdClientReferenceId(BeneficiaryInfoModel v) =>
      v.householdClientReferenceId;
  static const Field<BeneficiaryInfoModel, String>
      _f$householdClientReferenceId =
      Field('householdClientReferenceId', _$householdClientReferenceId);
  static String? _$givenName(BeneficiaryInfoModel v) => v.givenName;
  static const Field<BeneficiaryInfoModel, String> _f$givenName =
      Field('givenName', _$givenName, opt: true);
  static String? _$identifierType(BeneficiaryInfoModel v) => v.identifierType;
  static const Field<BeneficiaryInfoModel, String> _f$identifierType =
      Field('identifierType', _$identifierType, opt: true);
  static String? _$identifierId(BeneficiaryInfoModel v) => v.identifierId;
  static const Field<BeneficiaryInfoModel, String> _f$identifierId =
      Field('identifierId', _$identifierId, opt: true);
  static bool? _$isHead(BeneficiaryInfoModel v) => v.isHead;
  static const Field<BeneficiaryInfoModel, bool> _f$isHead =
      Field('isHead', _$isHead, opt: true);
  static String? _$status(BeneficiaryInfoModel v) => v.status;
  static const Field<BeneficiaryInfoModel, String> _f$status =
      Field('status', _$status, opt: true);
  static String? _$mobileNumber(BeneficiaryInfoModel v) => v.mobileNumber;
  static const Field<BeneficiaryInfoModel, String> _f$mobileNumber =
      Field('mobileNumber', _$mobileNumber, opt: true);
  static double? _$latitude(BeneficiaryInfoModel v) => v.latitude;
  static const Field<BeneficiaryInfoModel, double> _f$latitude =
      Field('latitude', _$latitude, opt: true);
  static double? _$longitude(BeneficiaryInfoModel v) => v.longitude;
  static const Field<BeneficiaryInfoModel, double> _f$longitude =
      Field('longitude', _$longitude, opt: true);
  static bool? _$nonRecoverableError(BeneficiaryInfoModel v) =>
      v.nonRecoverableError;
  static const Field<BeneficiaryInfoModel, bool> _f$nonRecoverableError = Field(
      'nonRecoverableError', _$nonRecoverableError,
      opt: true, def: false);
  static String _$clientReferenceId(BeneficiaryInfoModel v) =>
      v.clientReferenceId;
  static const Field<BeneficiaryInfoModel, String> _f$clientReferenceId =
      Field('clientReferenceId', _$clientReferenceId);
  static String? _$tenantId(BeneficiaryInfoModel v) => v.tenantId;
  static const Field<BeneficiaryInfoModel, String> _f$tenantId =
      Field('tenantId', _$tenantId, opt: true);
  static int? _$rowVersion(BeneficiaryInfoModel v) => v.rowVersion;
  static const Field<BeneficiaryInfoModel, int> _f$rowVersion =
      Field('rowVersion', _$rowVersion, opt: true);
  static AuditDetails? _$auditDetails(BeneficiaryInfoModel v) => v.auditDetails;
  static const Field<BeneficiaryInfoModel, AuditDetails> _f$auditDetails =
      Field('auditDetails', _$auditDetails, opt: true);
  static ClientAuditDetails? _$clientAuditDetails(BeneficiaryInfoModel v) =>
      v.clientAuditDetails;
  static const Field<BeneficiaryInfoModel, ClientAuditDetails>
      _f$clientAuditDetails =
      Field('clientAuditDetails', _$clientAuditDetails, opt: true);
  static bool? _$isDeleted(BeneficiaryInfoModel v) => v.isDeleted;
  static const Field<BeneficiaryInfoModel, bool> _f$isDeleted =
      Field('isDeleted', _$isDeleted, opt: true, def: false);

  @override
  final MappableFields<BeneficiaryInfoModel> fields = const {
    #additionalFields: _f$additionalFields,
    #id: _f$id,
    #householdClientReferenceId: _f$householdClientReferenceId,
    #givenName: _f$givenName,
    #identifierType: _f$identifierType,
    #identifierId: _f$identifierId,
    #isHead: _f$isHead,
    #status: _f$status,
    #mobileNumber: _f$mobileNumber,
    #latitude: _f$latitude,
    #longitude: _f$longitude,
    #nonRecoverableError: _f$nonRecoverableError,
    #clientReferenceId: _f$clientReferenceId,
    #tenantId: _f$tenantId,
    #rowVersion: _f$rowVersion,
    #auditDetails: _f$auditDetails,
    #clientAuditDetails: _f$clientAuditDetails,
    #isDeleted: _f$isDeleted,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = MappableClass.useAsDefault;
  @override
  late final ClassMapperBase superMapper =
      EntityModelMapper.ensureInitialized();

  static BeneficiaryInfoModel _instantiate(DecodingData data) {
    return BeneficiaryInfoModel(
        additionalFields: data.dec(_f$additionalFields),
        id: data.dec(_f$id),
        householdClientReferenceId: data.dec(_f$householdClientReferenceId),
        givenName: data.dec(_f$givenName),
        identifierType: data.dec(_f$identifierType),
        identifierId: data.dec(_f$identifierId),
        isHead: data.dec(_f$isHead),
        status: data.dec(_f$status),
        mobileNumber: data.dec(_f$mobileNumber),
        latitude: data.dec(_f$latitude),
        longitude: data.dec(_f$longitude),
        nonRecoverableError: data.dec(_f$nonRecoverableError),
        clientReferenceId: data.dec(_f$clientReferenceId),
        tenantId: data.dec(_f$tenantId),
        rowVersion: data.dec(_f$rowVersion),
        auditDetails: data.dec(_f$auditDetails),
        clientAuditDetails: data.dec(_f$clientAuditDetails),
        isDeleted: data.dec(_f$isDeleted));
  }

  @override
  final Function instantiate = _instantiate;

  static BeneficiaryInfoModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BeneficiaryInfoModel>(map);
  }

  static BeneficiaryInfoModel fromJson(String json) {
    return ensureInitialized().decodeJson<BeneficiaryInfoModel>(json);
  }
}

mixin BeneficiaryInfoModelMappable {
  String toJson() {
    return BeneficiaryInfoModelMapper.ensureInitialized()
        .encodeJson<BeneficiaryInfoModel>(this as BeneficiaryInfoModel);
  }

  Map<String, dynamic> toMap() {
    return BeneficiaryInfoModelMapper.ensureInitialized()
        .encodeMap<BeneficiaryInfoModel>(this as BeneficiaryInfoModel);
  }

  BeneficiaryInfoModelCopyWith<BeneficiaryInfoModel, BeneficiaryInfoModel,
          BeneficiaryInfoModel>
      get copyWith => _BeneficiaryInfoModelCopyWithImpl(
          this as BeneficiaryInfoModel, $identity, $identity);
  @override
  String toString() {
    return BeneficiaryInfoModelMapper.ensureInitialized()
        .stringifyValue(this as BeneficiaryInfoModel);
  }

  @override
  bool operator ==(Object other) {
    return BeneficiaryInfoModelMapper.ensureInitialized()
        .equalsValue(this as BeneficiaryInfoModel, other);
  }

  @override
  int get hashCode {
    return BeneficiaryInfoModelMapper.ensureInitialized()
        .hashValue(this as BeneficiaryInfoModel);
  }
}

extension BeneficiaryInfoModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BeneficiaryInfoModel, $Out> {
  BeneficiaryInfoModelCopyWith<$R, BeneficiaryInfoModel, $Out>
      get $asBeneficiaryInfoModel =>
          $base.as((v, t, t2) => _BeneficiaryInfoModelCopyWithImpl(v, t, t2));
}

abstract class BeneficiaryInfoModelCopyWith<
    $R,
    $In extends BeneficiaryInfoModel,
    $Out> implements EntityModelCopyWith<$R, $In, $Out> {
  BeneficiaryInfoAdditionalFieldsCopyWith<$R, BeneficiaryInfoAdditionalFields,
      BeneficiaryInfoAdditionalFields>? get additionalFields;
  @override
  AuditDetailsCopyWith<$R, AuditDetails, AuditDetails>? get auditDetails;
  @override
  ClientAuditDetailsCopyWith<$R, ClientAuditDetails, ClientAuditDetails>?
      get clientAuditDetails;
  @override
  $R call(
      {BeneficiaryInfoAdditionalFields? additionalFields,
      String? id,
      String? householdClientReferenceId,
      String? givenName,
      String? identifierType,
      String? identifierId,
      bool? isHead,
      String? status,
      String? mobileNumber,
      double? latitude,
      double? longitude,
      bool? nonRecoverableError,
      String? clientReferenceId,
      String? tenantId,
      int? rowVersion,
      AuditDetails? auditDetails,
      ClientAuditDetails? clientAuditDetails,
      bool? isDeleted});
  BeneficiaryInfoModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _BeneficiaryInfoModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BeneficiaryInfoModel, $Out>
    implements BeneficiaryInfoModelCopyWith<$R, BeneficiaryInfoModel, $Out> {
  _BeneficiaryInfoModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BeneficiaryInfoModel> $mapper =
      BeneficiaryInfoModelMapper.ensureInitialized();
  @override
  BeneficiaryInfoAdditionalFieldsCopyWith<$R, BeneficiaryInfoAdditionalFields,
          BeneficiaryInfoAdditionalFields>?
      get additionalFields => $value.additionalFields?.copyWith
          .$chain((v) => call(additionalFields: v));
  @override
  AuditDetailsCopyWith<$R, AuditDetails, AuditDetails>? get auditDetails =>
      $value.auditDetails?.copyWith.$chain((v) => call(auditDetails: v));
  @override
  ClientAuditDetailsCopyWith<$R, ClientAuditDetails, ClientAuditDetails>?
      get clientAuditDetails => $value.clientAuditDetails?.copyWith
          .$chain((v) => call(clientAuditDetails: v));
  @override
  $R call(
          {Object? additionalFields = $none,
          Object? id = $none,
          String? householdClientReferenceId,
          Object? givenName = $none,
          Object? identifierType = $none,
          Object? identifierId = $none,
          Object? isHead = $none,
          Object? status = $none,
          Object? mobileNumber = $none,
          Object? latitude = $none,
          Object? longitude = $none,
          Object? nonRecoverableError = $none,
          String? clientReferenceId,
          Object? tenantId = $none,
          Object? rowVersion = $none,
          Object? auditDetails = $none,
          Object? clientAuditDetails = $none,
          Object? isDeleted = $none}) =>
      $apply(FieldCopyWithData({
        if (additionalFields != $none) #additionalFields: additionalFields,
        if (id != $none) #id: id,
        if (householdClientReferenceId != null)
          #householdClientReferenceId: householdClientReferenceId,
        if (givenName != $none) #givenName: givenName,
        if (identifierType != $none) #identifierType: identifierType,
        if (identifierId != $none) #identifierId: identifierId,
        if (isHead != $none) #isHead: isHead,
        if (status != $none) #status: status,
        if (mobileNumber != $none) #mobileNumber: mobileNumber,
        if (latitude != $none) #latitude: latitude,
        if (longitude != $none) #longitude: longitude,
        if (nonRecoverableError != $none)
          #nonRecoverableError: nonRecoverableError,
        if (clientReferenceId != null) #clientReferenceId: clientReferenceId,
        if (tenantId != $none) #tenantId: tenantId,
        if (rowVersion != $none) #rowVersion: rowVersion,
        if (auditDetails != $none) #auditDetails: auditDetails,
        if (clientAuditDetails != $none)
          #clientAuditDetails: clientAuditDetails,
        if (isDeleted != $none) #isDeleted: isDeleted
      }));
  @override
  BeneficiaryInfoModel $make(CopyWithData data) => BeneficiaryInfoModel(
      additionalFields:
          data.get(#additionalFields, or: $value.additionalFields),
      id: data.get(#id, or: $value.id),
      householdClientReferenceId: data.get(#householdClientReferenceId,
          or: $value.householdClientReferenceId),
      givenName: data.get(#givenName, or: $value.givenName),
      identifierType: data.get(#identifierType, or: $value.identifierType),
      identifierId: data.get(#identifierId, or: $value.identifierId),
      isHead: data.get(#isHead, or: $value.isHead),
      status: data.get(#status, or: $value.status),
      mobileNumber: data.get(#mobileNumber, or: $value.mobileNumber),
      latitude: data.get(#latitude, or: $value.latitude),
      longitude: data.get(#longitude, or: $value.longitude),
      nonRecoverableError:
          data.get(#nonRecoverableError, or: $value.nonRecoverableError),
      clientReferenceId:
          data.get(#clientReferenceId, or: $value.clientReferenceId),
      tenantId: data.get(#tenantId, or: $value.tenantId),
      rowVersion: data.get(#rowVersion, or: $value.rowVersion),
      auditDetails: data.get(#auditDetails, or: $value.auditDetails),
      clientAuditDetails:
          data.get(#clientAuditDetails, or: $value.clientAuditDetails),
      isDeleted: data.get(#isDeleted, or: $value.isDeleted));

  @override
  BeneficiaryInfoModelCopyWith<$R2, BeneficiaryInfoModel, $Out2>
      $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
          _BeneficiaryInfoModelCopyWithImpl($value, $cast, t);
}

class BeneficiaryInfoAdditionalFieldsMapper
    extends SubClassMapperBase<BeneficiaryInfoAdditionalFields> {
  BeneficiaryInfoAdditionalFieldsMapper._();

  static BeneficiaryInfoAdditionalFieldsMapper? _instance;
  static BeneficiaryInfoAdditionalFieldsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals
          .use(_instance = BeneficiaryInfoAdditionalFieldsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'BeneficiaryInfoAdditionalFields';

  static String _$schema(BeneficiaryInfoAdditionalFields v) => v.schema;
  static const Field<BeneficiaryInfoAdditionalFields, String> _f$schema =
      Field('schema', _$schema, opt: true, def: 'BeneficiaryInfo');
  static int _$version(BeneficiaryInfoAdditionalFields v) => v.version;
  static const Field<BeneficiaryInfoAdditionalFields, int> _f$version =
      Field('version', _$version);
  static List<AdditionalField> _$fields(BeneficiaryInfoAdditionalFields v) =>
      v.fields;
  static const Field<BeneficiaryInfoAdditionalFields, List<AdditionalField>>
      _f$fields = Field('fields', _$fields, opt: true, def: const []);

  @override
  final MappableFields<BeneficiaryInfoAdditionalFields> fields = const {
    #schema: _f$schema,
    #version: _f$version,
    #fields: _f$fields,
  };
  @override
  final bool ignoreNull = true;

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = MappableClass.useAsDefault;
  @override
  late final ClassMapperBase superMapper =
      AdditionalFieldsMapper.ensureInitialized();

  static BeneficiaryInfoAdditionalFields _instantiate(DecodingData data) {
    return BeneficiaryInfoAdditionalFields(
        schema: data.dec(_f$schema),
        version: data.dec(_f$version),
        fields: data.dec(_f$fields));
  }

  @override
  final Function instantiate = _instantiate;

  static BeneficiaryInfoAdditionalFields fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<BeneficiaryInfoAdditionalFields>(map);
  }

  static BeneficiaryInfoAdditionalFields fromJson(String json) {
    return ensureInitialized()
        .decodeJson<BeneficiaryInfoAdditionalFields>(json);
  }
}

mixin BeneficiaryInfoAdditionalFieldsMappable {
  String toJson() {
    return BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized()
        .encodeJson<BeneficiaryInfoAdditionalFields>(
            this as BeneficiaryInfoAdditionalFields);
  }

  Map<String, dynamic> toMap() {
    return BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized()
        .encodeMap<BeneficiaryInfoAdditionalFields>(
            this as BeneficiaryInfoAdditionalFields);
  }

  BeneficiaryInfoAdditionalFieldsCopyWith<BeneficiaryInfoAdditionalFields,
          BeneficiaryInfoAdditionalFields, BeneficiaryInfoAdditionalFields>
      get copyWith => _BeneficiaryInfoAdditionalFieldsCopyWithImpl(
          this as BeneficiaryInfoAdditionalFields, $identity, $identity);
  @override
  String toString() {
    return BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized()
        .stringifyValue(this as BeneficiaryInfoAdditionalFields);
  }

  @override
  bool operator ==(Object other) {
    return BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized()
        .equalsValue(this as BeneficiaryInfoAdditionalFields, other);
  }

  @override
  int get hashCode {
    return BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized()
        .hashValue(this as BeneficiaryInfoAdditionalFields);
  }
}

extension BeneficiaryInfoAdditionalFieldsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, BeneficiaryInfoAdditionalFields, $Out> {
  BeneficiaryInfoAdditionalFieldsCopyWith<$R, BeneficiaryInfoAdditionalFields,
          $Out>
      get $asBeneficiaryInfoAdditionalFields => $base.as(
          (v, t, t2) => _BeneficiaryInfoAdditionalFieldsCopyWithImpl(v, t, t2));
}

abstract class BeneficiaryInfoAdditionalFieldsCopyWith<
    $R,
    $In extends BeneficiaryInfoAdditionalFields,
    $Out> implements AdditionalFieldsCopyWith<$R, $In, $Out> {
  @override
  ListCopyWith<$R, AdditionalField,
      AdditionalFieldCopyWith<$R, AdditionalField, AdditionalField>> get fields;
  @override
  $R call({String? schema, int? version, List<AdditionalField>? fields});
  BeneficiaryInfoAdditionalFieldsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
      Then<$Out2, $R2> t);
}

class _BeneficiaryInfoAdditionalFieldsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, BeneficiaryInfoAdditionalFields, $Out>
    implements
        BeneficiaryInfoAdditionalFieldsCopyWith<$R,
            BeneficiaryInfoAdditionalFields, $Out> {
  _BeneficiaryInfoAdditionalFieldsCopyWithImpl(
      super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<BeneficiaryInfoAdditionalFields> $mapper =
      BeneficiaryInfoAdditionalFieldsMapper.ensureInitialized();
  @override
  ListCopyWith<$R, AdditionalField,
          AdditionalFieldCopyWith<$R, AdditionalField, AdditionalField>>
      get fields => ListCopyWith($value.fields, (v, t) => v.copyWith.$chain(t),
          (v) => call(fields: v));
  @override
  $R call({String? schema, int? version, List<AdditionalField>? fields}) =>
      $apply(FieldCopyWithData({
        if (schema != null) #schema: schema,
        if (version != null) #version: version,
        if (fields != null) #fields: fields
      }));
  @override
  BeneficiaryInfoAdditionalFields $make(CopyWithData data) =>
      BeneficiaryInfoAdditionalFields(
          schema: data.get(#schema, or: $value.schema),
          version: data.get(#version, or: $value.version),
          fields: data.get(#fields, or: $value.fields));

  @override
  BeneficiaryInfoAdditionalFieldsCopyWith<$R2, BeneficiaryInfoAdditionalFields,
      $Out2> $chain<$R2, $Out2>(
          Then<$Out2, $R2> t) =>
      _BeneficiaryInfoAdditionalFieldsCopyWithImpl($value, $cast, t);
}
