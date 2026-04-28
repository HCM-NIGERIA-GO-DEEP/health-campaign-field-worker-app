import 'package:dart_mappable/dart_mappable.dart';
import 'package:drift/drift.dart';
import 'package:digit_data_model/data_model.dart';

part 'beneficiary_info.mapper.dart';

@MappableClass(ignoreNull: true, discriminatorValue: MappableClass.useAsDefault)
class BeneficiaryInfoSearchModel extends EntitySearchModel with BeneficiaryInfoSearchModelMappable {
  final List<String>? id;
  final String? householdClientReferenceId;
  final String? givenName;
  final String? clientReferenceId;
  final String? tenantId;
  final double? latitude;
  final double? longitude;
  
  BeneficiaryInfoSearchModel({
    this.id,
    this.householdClientReferenceId,
    this.givenName,
    this.clientReferenceId,
    this.tenantId,
    this.latitude,
    this.longitude,
    super.boundaryCode,
    super.isDeleted,
  }):  super();

  @MappableConstructor()
  BeneficiaryInfoSearchModel.ignoreDeleted({
    this.id,
    this.householdClientReferenceId,
    this.givenName,
    this.clientReferenceId,
    this.tenantId,
    this.latitude,
    this.longitude,
    super.boundaryCode,
  }):  super(isDeleted: false);
}

@MappableClass(ignoreNull: true, discriminatorValue: MappableClass.useAsDefault)
class BeneficiaryInfoModel extends EntityModel with BeneficiaryInfoModelMappable {

  static const schemaName = 'BeneficiaryInfo';

  final String? id;
  final String householdClientReferenceId;
  final String? givenName;
  final String? identifierType;
  final String? identifierId;
  final bool? isHead;
  final String? status;
  final String? mobileNumber;
  final double? latitude;
  final double? longitude;
  final bool? nonRecoverableError;
  final String clientReferenceId;
  final String? tenantId;
  final int? rowVersion;
  final BeneficiaryInfoAdditionalFields? additionalFields;

  BeneficiaryInfoModel({
    this.additionalFields,
    this.id,
    required this.householdClientReferenceId,
    this.givenName,
    this.identifierType,
    this.identifierId,
    this.isHead,
    this.status,
    this.mobileNumber,
    this.latitude,
    this.longitude,
    this.nonRecoverableError = false,
    required this.clientReferenceId,
    this.tenantId,
    this.rowVersion,
    super.auditDetails,
    super.clientAuditDetails,
    super.isDeleted = false,
  }): super();

  BeneficiaryInfoCompanion get companion {
    return BeneficiaryInfoCompanion(
      auditCreatedBy: Value(auditDetails?.createdBy),
      auditCreatedTime: Value(auditDetails?.createdTime),
      auditModifiedBy: Value(auditDetails?.lastModifiedBy),
      clientCreatedTime: Value(clientAuditDetails?.createdTime),
      clientModifiedTime: Value(clientAuditDetails?.lastModifiedTime),
      clientCreatedBy: Value(clientAuditDetails?.createdBy),
      clientModifiedBy: Value(clientAuditDetails?.lastModifiedBy),
      auditModifiedTime: Value(auditDetails?.lastModifiedTime),
      additionalFields: Value(additionalFields?.toJson()),
      isDeleted: Value(isDeleted),
      id: Value(id),
      householdClientReferenceId: Value(householdClientReferenceId),
      givenName: Value(givenName),
      identifierType: Value(identifierType),
      identifierId: Value(identifierId),
      isHead: Value(isHead),
      status: Value(status),
      mobileNumber: Value(mobileNumber),
      latitude: Value(latitude),
      longitude: Value(longitude),
      nonRecoverableError: Value(nonRecoverableError),
      clientReferenceId: Value(clientReferenceId),
      tenantId: Value(tenantId),
      rowVersion: Value(rowVersion),
      );
  }
}

@MappableClass(ignoreNull: true, discriminatorValue: MappableClass.useAsDefault)
class BeneficiaryInfoAdditionalFields extends AdditionalFields with BeneficiaryInfoAdditionalFieldsMappable {
  BeneficiaryInfoAdditionalFields({
    super.schema = 'BeneficiaryInfo',
    required super.version,
    super.fields,
  });
}
