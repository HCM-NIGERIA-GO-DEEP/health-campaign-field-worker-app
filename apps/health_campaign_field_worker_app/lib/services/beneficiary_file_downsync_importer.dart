import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/address_type.dart';
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:digit_data_model/models/entities/household_type.dart';
import 'package:dio/dio.dart';
import 'package:survey_form/models/entities/service.dart';

class BeneficiaryDownloadLink {
  final String fileType;
  final String url;
  final int recordCount;
  final int? expiresAt;

  const BeneficiaryDownloadLink({
    required this.fileType,
    required this.url,
    required this.recordCount,
    this.expiresAt,
  });

  factory BeneficiaryDownloadLink.fromMap(Map<String, dynamic> map) {
    return BeneficiaryDownloadLink(
      fileType: map['fileType']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      recordCount: _readInt(map['recordCount']) ?? 0,
      expiresAt: _readInt(map['expiresAt']),
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class BeneficiaryFileDownsyncResult {
  final int importedCount;
  final Map<String, int> importedByType;

  const BeneficiaryFileDownsyncResult({
    required this.importedCount,
    required this.importedByType,
  });
}

typedef BeneficiaryFileProgress = FutureOr<void> Function(
  int importedCount,
  Map<String, int> importedByType,
);

class BeneficiaryFileDownsyncImporter {
  static const int _batchSize = 100;

  final Dio dio;
  final String? minioPublicUrl;

  final LocalRepository<IndividualModel, IndividualSearchModel>
      individualLocalRepository;
  final LocalRepository<HouseholdModel, HouseholdSearchModel>
      householdLocalRepository;
  final LocalRepository<HouseholdMemberModel, HouseholdMemberSearchModel>
      householdMemberLocalRepository;
  final LocalRepository<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>
      projectBeneficiaryLocalRepository;
  final LocalRepository<TaskModel, TaskSearchModel> taskLocalRepository;
  final LocalRepository<SideEffectModel, SideEffectSearchModel>
      sideEffectLocalRepository;
  final LocalRepository<ReferralModel, ReferralSearchModel>
      referralLocalRepository;
  final LocalRepository<HFReferralModel, HFReferralSearchModel>
      hfReferralLocalRepository;
  final LocalRepository<ServiceModel, ServiceSearchModel>
      serviceLocalRepository;

  BeneficiaryFileDownsyncImporter({
    required this.dio,
    this.minioPublicUrl,
    required this.individualLocalRepository,
    required this.householdLocalRepository,
    required this.householdMemberLocalRepository,
    required this.projectBeneficiaryLocalRepository,
    required this.taskLocalRepository,
    required this.sideEffectLocalRepository,
    required this.referralLocalRepository,
    required this.hfReferralLocalRepository,
    required this.serviceLocalRepository,
  });

  Future<BeneficiaryFileDownsyncResult> importLinks(
    List<BeneficiaryDownloadLink> links, {
    BeneficiaryFileProgress? onProgress,
  }) async {
    final counters = <String, int>{};
    var totalImported = 0;

    for (final link in links) {
      if (link.url.isEmpty) continue;

      await for (final rawLine in _readNdjsonLines(link)) {
        final line = rawLine.trim();
        if (line.isEmpty) continue;

        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;

        await _addDecodedLine(decoded);

        totalImported += 1;
        final type = decoded['_t']?.toString() ?? link.fileType;
        counters[type] = (counters[type] ?? 0) + 1;

        if (totalImported % _batchSize == 0) {
          await _flush();
          await onProgress?.call(totalImported, Map.of(counters));
        }
      }
      await _flush();
      await onProgress?.call(totalImported, Map.of(counters));
    }

    return BeneficiaryFileDownsyncResult(
      importedCount: totalImported,
      importedByType: counters,
    );
  }

  final List<HouseholdModel> _households = [];
  final List<IndividualModel> _individuals = [];
  final List<HouseholdMemberModel> _householdMembers = [];
  final List<ProjectBeneficiaryModel> _projectBeneficiaries = [];
  final List<TaskModel> _tasks = [];
  final List<SideEffectModel> _sideEffects = [];
  final List<ReferralModel> _referrals = [];
  final List<HFReferralModel> _hfReferrals = [];
  final List<ServiceModel> _services = [];

  String _resolveUrl(String url) {
    final publicBase = minioPublicUrl?.trim();
    if (publicBase == null || publicBase.isEmpty) return url;
    return url.replaceFirst(
      RegExp(r'https?://localhost:\d+'),
      publicBase.endsWith('/')
          ? publicBase.substring(0, publicBase.length - 1)
          : publicBase,
    );
  }

  Stream<String> _readNdjsonLines(BeneficiaryDownloadLink link) async* {
    final response = await dio.get<ResponseBody>(
      _resolveUrl(link.url),
      options: Options(responseType: ResponseType.stream),
    );

    final body = response.data;
    if (body == null) return;

    final source = body.stream.map<List<int>>((chunk) => chunk);
    final iterator = StreamIterator<List<int>>(source);

    try {
      if (!await iterator.moveNext()) return;

      final first = iterator.current;
      final isGzip = first.length >= 2 && first[0] == 0x1f && first[1] == 0x8b;

      final bytes = _pullBytes(iterator, first);
      final decodedStream = isGzip
          ? bytes.transform(gzip.decoder).transform(utf8.decoder)
          : bytes.transform(utf8.decoder);

      yield* decodedStream.transform(const LineSplitter());
    } finally {
      await iterator.cancel();
    }
  }

  Stream<List<int>> _pullBytes(
    StreamIterator<List<int>> iterator,
    List<int> first,
  ) async* {
    yield first;
    while (await iterator.moveNext()) {
      yield iterator.current;
    }
  }

  Future<void> _addDecodedLine(Map<String, dynamic> raw) async {
    final entityType = raw['_t']?.toString();
    final normalized = _normalizeEntityMap(raw);

    switch (entityType) {
      case 'HOUSEHOLD':
        _households.add(_mapHousehold(normalized));
      case 'HOUSEHOLD_MEMBER':
        _householdMembers.add(_mapHouseholdMember(normalized));
      case 'INDIVIDUAL':
        _individuals.add(_mapIndividual(normalized));
      case 'PROJECT_BENEFICIARY':
        _projectBeneficiaries
            .add(ProjectBeneficiaryModelMapper.fromMap(normalized));
      case 'TASK':
        _tasks.add(TaskModelMapper.fromMap(normalized));
      case 'SIDE_EFFECT':
        _sideEffects.add(SideEffectModelMapper.fromMap(normalized));
      case 'REFERRAL':
        _referrals.add(ReferralModelMapper.fromMap(normalized));
      case 'HF_REFERRAL':
        _hfReferrals.add(HFReferralModelMapper.fromMap(normalized));
      case 'SERVICE':
        _services.add(ServiceModelMapper.fromMap(normalized));
      default:
        throw FormatException('Unsupported downsync entity type: $entityType');
    }

    if (_bufferedCount >= _batchSize) {
      await _flush();
    }
  }

  int get _bufferedCount =>
      _households.length +
      _individuals.length +
      _householdMembers.length +
      _projectBeneficiaries.length +
      _tasks.length +
      _sideEffects.length +
      _referrals.length +
      _hfReferrals.length +
      _services.length;

  Future<void> _flush() async {
    if (_households.isNotEmpty) {
      await householdLocalRepository.bulkCreate(List.of(_households));
      _households.clear();
    }
    if (_individuals.isNotEmpty) {
      await individualLocalRepository.bulkCreate(List.of(_individuals));
      _individuals.clear();
    }
    if (_householdMembers.isNotEmpty) {
      await householdMemberLocalRepository
          .bulkCreate(List.of(_householdMembers));
      _householdMembers.clear();
    }
    if (_projectBeneficiaries.isNotEmpty) {
      await projectBeneficiaryLocalRepository
          .bulkCreate(List.of(_projectBeneficiaries));
      _projectBeneficiaries.clear();
    }
    if (_tasks.isNotEmpty) {
      await taskLocalRepository.bulkCreate(List.of(_tasks));
      _tasks.clear();
    }
    if (_sideEffects.isNotEmpty) {
      await sideEffectLocalRepository.bulkCreate(List.of(_sideEffects));
      _sideEffects.clear();
    }
    if (_referrals.isNotEmpty) {
      await referralLocalRepository.bulkCreate(List.of(_referrals));
      _referrals.clear();
    }
    if (_hfReferrals.isNotEmpty) {
      await hfReferralLocalRepository.bulkCreate(List.of(_hfReferrals));
      _hfReferrals.clear();
    }
    if (_services.isNotEmpty) {
      await serviceLocalRepository.bulkCreate(List.of(_services));
      _services.clear();
    }
  }

  HouseholdModel _mapHousehold(Map<String, dynamic> map) {
    return HouseholdModel(
      id: map['id']?.toString(),
      tenantId: map['tenantId']?.toString(),
      clientReferenceId: map['clientReferenceId'].toString(),
      memberCount: _asInt(map['memberCount']),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      rowVersion: _asInt(map['rowVersion']),
      isDeleted: map['isDeleted'] == true,
      auditDetails: _auditDetails(map),
      clientAuditDetails: _clientAuditDetails(map),
      additionalFields: _householdAdditionalFields(map['additionalFields']),
      householdType: _householdType(map['householdType']),
      address: _address(map),
    );
  }

  HouseholdMemberModel _mapHouseholdMember(Map<String, dynamic> map) {
    return HouseholdMemberModel(
      id: map['id']?.toString(),
      tenantId: map['tenantId']?.toString(),
      clientReferenceId: map['clientReferenceId'].toString(),
      householdId: map['householdId']?.toString(),
      householdClientReferenceId: map['householdClientReferenceId']?.toString(),
      individualId: map['individualId']?.toString(),
      individualClientReferenceId:
          map['individualClientReferenceId']?.toString(),
      isHeadOfHousehold: map['isHeadOfHousehold'] == true,
      rowVersion: _asInt(map['rowVersion']),
      isDeleted: map['isDeleted'] == true,
      auditDetails: _auditDetails(map),
      clientAuditDetails: _clientAuditDetails(map),
      additionalFields:
          _householdMemberAdditionalFields(map['additionalFields']),
    );
  }

  IndividualModel _mapIndividual(Map<String, dynamic> map) {
    final clientReferenceId = map['clientReferenceId'].toString();
    return IndividualModel(
      id: map['id']?.toString(),
      individualId: map['individualId']?.toString(),
      userId: map['userId']?.toString(),
      userUuid: map['userUuid']?.toString(),
      tenantId: map['tenantId']?.toString(),
      clientReferenceId: clientReferenceId,
      dateOfBirth: map['dateOfBirth']?.toString(),
      mobileNumber: map['mobileNumber']?.toString(),
      altContactNumber: map['altContactNumber']?.toString(),
      email: map['email']?.toString(),
      fatherName: map['fatherName']?.toString(),
      husbandName: map['husbandName']?.toString(),
      photo: map['photo']?.toString(),
      rowVersion: _asInt(map['rowVersion']),
      isDeleted: map['isDeleted'] == true,
      auditDetails: _auditDetails(map),
      clientAuditDetails: _clientAuditDetails(map),
      name: _name(map, clientReferenceId),
      gender: _gender(map['gender']),
      address: _hasAddress(map)
          ? [_address(map, clientReferenceId: clientReferenceId)!]
          : null,
      identifiers: _identifiers(map, clientReferenceId),
      additionalFields: _individualAdditionalFields(map['additionalFields']),
    );
  }

  AddressModel? _address(
    Map<String, dynamic> map, {
    String? clientReferenceId,
  }) {
    if (!_hasAddress(map)) return null;

    return AddressModel(
      id: map['addressId']?.toString(),
      tenantId:
          map['addressTenantId']?.toString() ?? map['tenantId']?.toString(),
      relatedClientReferenceId:
          map['addressClientReferenceId']?.toString() ?? clientReferenceId,
      doorNo: map['doorNo']?.toString(),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      locationAccuracy: _asDouble(map['locationAccuracy']),
      type: _addressType(map['addressType'] ?? map['type']),
      addressLine1: map['addressLine1']?.toString(),
      addressLine2: map['addressLine2']?.toString(),
      landmark: map['landmark']?.toString(),
      city: map['city']?.toString(),
      pincode: map['pincode']?.toString(),
      buildingName: map['buildingName']?.toString(),
      street: map['street']?.toString(),
      locality: map['localityCode'] == null
          ? null
          : LocalityModel(
              code: map['localityCode'].toString(),
              name: map['localityName']?.toString(),
            ),
      auditDetails: _auditDetails(map),
      clientAuditDetails: _clientAuditDetails(map),
    );
  }

  bool _hasAddress(Map<String, dynamic> map) {
    return map['addressId'] != null ||
        map['latitude'] != null ||
        map['longitude'] != null ||
        map['localityCode'] != null;
  }

  NameModel? _name(Map<String, dynamic> map, String clientReferenceId) {
    if (map['name'] is Map<String, dynamic>) {
      final name = map['name'] as Map<String, dynamic>;
      return NameModelMapper.fromMap({
        ...name,
        'individualClientReferenceId': clientReferenceId,
      });
    }

    if (map['givenName'] == null &&
        map['familyName'] == null &&
        map['otherNames'] == null) {
      return null;
    }

    return NameModel(
      id: map['nameId']?.toString(),
      individualClientReferenceId: clientReferenceId,
      givenName: map['givenName']?.toString(),
      familyName: map['familyName']?.toString(),
      otherNames: map['otherNames']?.toString(),
      tenantId: map['tenantId']?.toString(),
      rowVersion: _asInt(map['rowVersion']),
      auditDetails: _auditDetails(map),
      clientAuditDetails: _clientAuditDetails(map),
    );
  }

  List<IdentifierModel>? _identifiers(
    Map<String, dynamic> map,
    String clientReferenceId,
  ) {
    final identifiers = map['identifiers'];
    if (identifiers is! List) return null;

    return identifiers
        .whereType<Map<String, dynamic>>()
        .map(_normalizeEntityMap)
        .map((identifier) => IdentifierModelMapper.fromMap({
              ...identifier,
              'individualClientReferenceId': clientReferenceId,
            }))
        .toList();
  }

  Map<String, dynamic> _normalizeEntityMap(Map<String, dynamic> raw) {
    final normalized = <String, dynamic>{};

    raw.forEach((key, value) {
      final normalizedKey = _keyAliases[key.toLowerCase()] ?? key;
      normalized[normalizedKey] = _normalizeValue(value);
    });

    normalized['auditDetails'] ??= _auditDetailsMap(normalized);
    normalized['clientAuditDetails'] ??= _clientAuditDetailsMap(normalized);

    return normalized;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value is Map<String, dynamic>) return _normalizeEntityMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }

  AuditDetails? _auditDetails(Map<String, dynamic> map) {
    final audit = _auditDetailsMap(map);
    if (audit == null) return null;
    return AuditDetailsMapper.fromMap(audit);
  }

  ClientAuditDetails? _clientAuditDetails(Map<String, dynamic> map) {
    final audit = _clientAuditDetailsMap(map);
    if (audit == null) return null;
    return ClientAuditDetailsMapper.fromMap(audit);
  }

  Map<String, dynamic>? _auditDetailsMap(Map<String, dynamic> map) {
    if (map['createdBy'] == null || map['createdTime'] == null) return null;
    return {
      'createdBy': map['createdBy'],
      'createdTime': map['createdTime'],
      'lastModifiedBy': map['lastModifiedBy'] ?? map['createdBy'],
      'lastModifiedTime': map['lastModifiedTime'] ?? map['createdTime'],
    };
  }

  Map<String, dynamic>? _clientAuditDetailsMap(Map<String, dynamic> map) {
    if (map['clientCreatedBy'] == null || map['clientCreatedTime'] == null) {
      return null;
    }
    return {
      'createdBy': map['clientCreatedBy'],
      'createdTime': map['clientCreatedTime'],
      'lastModifiedBy': map['clientLastModifiedBy'] ?? map['clientCreatedBy'],
      'lastModifiedTime':
          map['clientLastModifiedTime'] ?? map['clientCreatedTime'],
    };
  }

  HouseholdAdditionalFields? _householdAdditionalFields(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    return HouseholdAdditionalFieldsMapper.fromMap(value);
  }

  HouseholdMemberAdditionalFields? _householdMemberAdditionalFields(
    dynamic value,
  ) {
    if (value is! Map<String, dynamic>) return null;
    return HouseholdMemberAdditionalFieldsMapper.fromMap(value);
  }

  IndividualAdditionalFields? _individualAdditionalFields(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    return IndividualAdditionalFieldsMapper.fromMap(value);
  }

  HouseholdType? _householdType(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'FAMILY':
        return HouseholdType.family;
      case 'COMMUNITY':
        return HouseholdType.community;
      case 'OTHER':
        return HouseholdType.other;
      default:
        return null;
    }
  }

  AddressType? _addressType(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'PERMANENT':
        return AddressType.permanent;
      case 'CORRESPONDENCE':
        return AddressType.correspondence;
      case 'OTHER':
        return AddressType.other;
      case 'STRING':
        return AddressType.string;
      default:
        return null;
    }
  }

  Gender? _gender(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'MALE':
        return Gender.male;
      case 'FEMALE':
        return Gender.female;
      case 'OTHER':
        return Gender.other;
      default:
        return null;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static const Map<String, String> _keyAliases = {
    'tenantid': 'tenantId',
    'clientreferenceid': 'clientReferenceId',
    'numberofmembers': 'memberCount',
    'addressid': 'addressId',
    'additionaldetails': 'additionalFields',
    'createdby': 'createdBy',
    'lastmodifiedby': 'lastModifiedBy',
    'createdtime': 'createdTime',
    'lastmodifiedtime': 'lastModifiedTime',
    'rowversion': 'rowVersion',
    'isdeleted': 'isDeleted',
    'clientcreatedtime': 'clientCreatedTime',
    'clientlastmodifiedtime': 'clientLastModifiedTime',
    'clientcreatedby': 'clientCreatedBy',
    'clientlastmodifiedby': 'clientLastModifiedBy',
    'householdtype': 'householdType',
    'aid': 'addressId',
    'atenantid': 'addressTenantId',
    'aclientreferenceid': 'addressClientReferenceId',
    'doorno': 'doorNo',
    'locationaccuracy': 'locationAccuracy',
    'addressline1': 'addressLine1',
    'addressline2': 'addressLine2',
    'buildingname': 'buildingName',
    'localitycode': 'localityCode',
    'localityname': 'localityName',
    'householdid': 'householdId',
    'householdclientreferenceid': 'householdClientReferenceId',
    'individualid': 'individualId',
    'individualclientreferenceid': 'individualClientReferenceId',
    'isheadofhousehold': 'isHeadOfHousehold',
    'userid': 'userId',
    'useruuid': 'userUuid',
    'dateofbirth': 'dateOfBirth',
    'mobilenumber': 'mobileNumber',
    'altcontactnumber': 'altContactNumber',
    'fathername': 'fatherName',
    'husbandname': 'husbandName',
    'givenname': 'givenName',
    'familyname': 'familyName',
    'othernames': 'otherNames',
    'nameid': 'nameId',
  };
}
