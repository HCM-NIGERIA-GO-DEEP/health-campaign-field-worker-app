import 'package:drift/drift.dart';

@TableIndex(name: 'beneficiary_info_lat_long', columns: {#latitude, #longitude})
class BeneficiaryInfo extends Table {
  TextColumn get id => text().nullable()();
  TextColumn get householdClientReferenceId => text()();
  TextColumn get givenName => text().nullable()();
  TextColumn get identifierType => text().nullable()();
  TextColumn get identifierId => text().nullable()();
  BoolColumn get isHead => boolean().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get mobileNumber => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get auditCreatedBy => text().nullable()();
  BoolColumn get nonRecoverableError => boolean().nullable().withDefault(const Constant(false))();
  IntColumn get auditCreatedTime => integer().nullable()();
  IntColumn get clientCreatedTime => integer().nullable()();
  TextColumn get clientModifiedBy => text().nullable()();
  TextColumn get clientCreatedBy => text().nullable()();
  IntColumn get clientModifiedTime => integer().nullable()();
  TextColumn get auditModifiedBy => text().nullable()();
  IntColumn get auditModifiedTime => integer().nullable()();
  TextColumn get clientReferenceId => text()();
  TextColumn get tenantId => text().nullable()();
  BoolColumn get isDeleted => boolean().nullable().withDefault(const Constant(false))();
  IntColumn get rowVersion => integer().nullable()();
  TextColumn get additionalFields => text().nullable()();

  @override
  Set<Column> get primaryKey => { auditCreatedBy, clientReferenceId,  };
}
