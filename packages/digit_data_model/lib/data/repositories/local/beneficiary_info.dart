import 'dart:async';

import 'package:digit_data_model/data_model.dart';
import 'package:drift/drift.dart';

class BeneficiaryInfoLocalRepository
    extends LocalRepository<BeneficiaryInfoModel, BeneficiaryInfoSearchModel> {
  const BeneficiaryInfoLocalRepository(super.sql, super.opLogManager);

  @override
  DataModelType get type => DataModelType.beneficiaryInfo;

  @override
  FutureOr<List<BeneficiaryInfoModel>> search(
    BeneficiaryInfoSearchModel query, [
    String? userId,
  ]) async {
    return retryLocalCallOperation<List<BeneficiaryInfoModel>>(() async {
      final selectQuery = sql.select(sql.beneficiaryInfo);

      final results = await (selectQuery
            ..where(
              (tbl) => buildAnd([
                if (query.clientReferenceId != null)
                  tbl.clientReferenceId.equals(
                    query.clientReferenceId!,
                  ),
                if (query.householdClientReferenceId != null)
                  tbl.householdClientReferenceId.equals(
                    query.householdClientReferenceId!,
                  ),
                if (query.id != null)
                  tbl.id.isIn(
                    query.id!,
                  ),
                if (query.tenantId != null)
                  tbl.tenantId.equals(
                    query.tenantId!,
                  ),
                if (query.latitude != null)
                  tbl.latitude.equals(
                    query.latitude!,
                  ),
                if (query.longitude != null)
                  tbl.longitude.equals(
                    query.longitude!,
                  ),
              ]),
            ))
          .get();

      return results
          .map((e) => BeneficiaryInfoModel(
                clientReferenceId: e.clientReferenceId,
                householdClientReferenceId: e.householdClientReferenceId,
                id: e.id,
                givenName: e.givenName,
                identifierType: e.identifierType,
                identifierId: e.identifierId,
                isHead: e.isHead,
                status: e.status,
                mobileNumber: e.mobileNumber,
                latitude: e.latitude,
                longitude: e.longitude,
                tenantId: e.tenantId,
                rowVersion: e.rowVersion,
                nonRecoverableError: e.nonRecoverableError,
                auditDetails: (e.auditCreatedBy != null &&
                        e.auditCreatedTime != null)
                    ? AuditDetails(
                        createdBy: e.auditCreatedBy!,
                        createdTime: e.auditCreatedTime!,
                        lastModifiedBy: e.auditModifiedBy,
                        lastModifiedTime: e.auditModifiedTime,
                      )
                    : null,
                clientAuditDetails: (e.clientCreatedBy != null &&
                        e.clientCreatedTime != null)
                    ? ClientAuditDetails(
                        createdBy: e.clientCreatedBy!,
                        createdTime: e.clientCreatedTime!,
                        lastModifiedBy: e.clientModifiedBy,
                        lastModifiedTime: e.clientModifiedTime,
                      )
                    : null,
                isDeleted: e.isDeleted ?? false,
              ))
          .toList();
    });
  }

  @override
  FutureOr<void> create(
    BeneficiaryInfoModel entity, {
    bool createOpLog = false,
    DataOperation dataOperation = DataOperation.create,
  }) async {
    return retryLocalCallOperation(() async {
      await sql.batch((batch) async {
        batch.insert(
          sql.beneficiaryInfo,
          entity.companion,
          mode: InsertMode.insertOrReplace,
        );
      });

      await super.create(entity, createOpLog: createOpLog);
    });
  }

  @override
  FutureOr<void> bulkCreate(
    List<BeneficiaryInfoModel> entities,
  ) async {
    return retryLocalCallOperation(() async {
      final companions = entities.map((e) => e.companion).toList();

      await sql.batch((batch) async {
        batch.insertAll(
          sql.beneficiaryInfo,
          companions,
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  @override
  FutureOr<void> update(
    BeneficiaryInfoModel entity, {
    bool createOpLog = false,
    DataOperation dataOperation = DataOperation.update,
  }) async {
    return retryLocalCallOperation(() async {
      await sql.batch((batch) async {
        batch.update(
          sql.beneficiaryInfo,
          entity.companion,
          where: (table) => table.clientReferenceId.equals(
            entity.clientReferenceId,
          ),
        );
      });

      await super.update(entity, createOpLog: createOpLog);
    });
  }

  @override
  FutureOr<void> delete(
    BeneficiaryInfoModel entity, {
    bool createOpLog = false,
  }) async {
    return retryLocalCallOperation(() async {
      final updated = entity.copyWith(
        isDeleted: true,
        clientAuditDetails: ClientAuditDetails(
          createdBy: entity.clientAuditDetails!.createdBy,
          createdTime: entity.clientAuditDetails!.createdTime,
          lastModifiedBy: entity.clientAuditDetails!.lastModifiedBy,
          lastModifiedTime: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await sql.batch((batch) {
        batch.update(
          sql.beneficiaryInfo,
          updated.companion,
          where: (table) => table.clientReferenceId.equals(
            entity.clientReferenceId,
          ),
        );
      });

      return super.delete(updated, createOpLog: createOpLog);
    });
  }
}
