import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class HFReferralLocalRepository
    extends LocalRepository<HFReferralModel, HFReferralSearchModel> {
  HFReferralLocalRepository(super.sql, super.opLogManager);

  void listenToChanges({
    required HFReferralSearchModel query,
    required void Function(List<HFReferralModel> data) listener,
  }) async {
    return retryLocalCallOperation(() async {
      final select = sql.select(sql.hFReferral)
        ..where(
          (tbl) => buildAnd([
            if (query.projectId != null) tbl.projectId.isIn(query.projectId!),
          ]),
        );

      select.watch().listen((event) {
        final data = event
            .map((referral) {
              final additionalData = referral.additionalFields != null
                  ? jsonDecode(referral.additionalFields!)
                  : null;
              List<Map<String, dynamic>> fields = additionalData != null &&
                      additionalData['fields'] != null
                  ? List<Map<String, dynamic>>.from(additionalData['fields'])
                  : <Map<String, dynamic>>[];

              final HFReferralAdditionalFields additionalFields =
                  HFReferralAdditionalFields(
                version: additionalData?['version'] ?? 1,
                fields: fields
                    .where((field) =>
                        field['key'] != null && field['value'] != null)
                    .map((field) => AdditionalField(
                          field['key'] as String,
                          field['value'],
                        ))
                    .toList(),
              );

              return HFReferralModel(
                id: referral.id,
                clientReferenceId: referral.clientReferenceId,
                rowVersion: referral.rowVersion,
                tenantId: referral.tenantId,
                name: referral.name,
                projectId: referral.projectId,
                projectFacilityId: referral.projectFacilityId,
                symptom: referral.symptom,
                symptomSurveyId: referral.symptomSurveyId,
                beneficiaryId: referral.beneficiaryId,
                referralCode: referral.referralCode,
                nationalLevelId: referral.nationalLevelId,
                localityCode: referral.localityCode,
                isDeleted: referral.isDeleted,
                additionalFields: additionalFields,
                auditDetails: referral.auditCreatedBy != null
                    ? AuditDetails(
                        createdBy: referral.auditCreatedBy!,
                        createdTime: referral.auditCreatedTime!,
                        lastModifiedBy: referral.auditModifiedBy,
                        lastModifiedTime: referral.auditModifiedTime,
                      )
                    : null,
                clientAuditDetails: referral.clientCreatedTime == null ||
                        referral.clientCreatedBy == null
                    ? null
                    : ClientAuditDetails(
                        createdTime: referral.clientCreatedTime!,
                        createdBy: referral.clientCreatedBy!,
                        lastModifiedBy: referral.clientModifiedBy,
                        lastModifiedTime: referral.clientModifiedTime,
                      ),
              );
            })
            .where((element) => element.isDeleted != true)
            .toList();

        listener(data);
      });
    });
  }

  @override
  FutureOr<List<HFReferralModel>> search(
    HFReferralSearchModel query, [
    String? userId,
  ]) async {
    return retryLocalCallOperation(() async {
      final selectQuery = sql.select(sql.hFReferral).join([]);

      final results = await (selectQuery
            ..where(buildAnd([
              if (query.clientReferenceId != null)
                sql.hFReferral.clientReferenceId.isIn(
                  query.clientReferenceId!,
                ),
              if (query.name != null)
                sql.hFReferral.name.contains(
                  query.name!,
                ),
              if (query.beneficiaryId != null)
                sql.hFReferral.beneficiaryId.isIn(
                  query.beneficiaryId!,
                ),
              if (query.projectId != null)
                sql.hFReferral.projectId.isIn(
                  query.projectId!,
                ),
              if (query.localityCode != null)
                sql.hFReferral.localityCode.isIn(
                  query.localityCode!,
                ),
              if (userId != null)
                sql.hFReferral.auditCreatedBy.equals(
                  userId,
                ),
            ])))
          .get();

      return results
          .map((e) {
            final referral = e.readTableOrNull(sql.hFReferral);
            if (referral == null) return null;

            // Parse additional fields generically from JSON
            final additionalData = referral.additionalFields != null
                ? jsonDecode(referral.additionalFields!)
                : null;
            List<Map<String, dynamic>> data =
                additionalData != null && additionalData['fields'] != null
                    ? List<Map<String, dynamic>>.from(additionalData['fields'])
                    : <Map<String, dynamic>>[];

            final HFReferralAdditionalFields additionalFields =
                HFReferralAdditionalFields(
              version: additionalData?['version'] ?? 1,
              fields: data
                  .where(
                      (field) => field['key'] != null && field['value'] != null)
                  .map((field) => AdditionalField(
                        field['key'] as String,
                        field['value'],
                      ))
                  .toList(),
            );

            return HFReferralModel(
              id: referral.id,
              clientReferenceId: referral.clientReferenceId,
              rowVersion: referral.rowVersion,
              tenantId: referral.tenantId,
              name: referral.name,
              projectId: referral.projectId,
              projectFacilityId: referral.projectFacilityId,
              symptom: referral.symptom,
              symptomSurveyId: referral.symptomSurveyId,
              beneficiaryId: referral.beneficiaryId,
              referralCode: referral.referralCode,
              nationalLevelId: referral.nationalLevelId,
              localityCode: referral.localityCode,
              isDeleted: referral.isDeleted,
              additionalFields: additionalFields,
              auditDetails: AuditDetails(
                createdBy: referral.auditCreatedBy!,
                createdTime: referral.auditCreatedTime!,
                lastModifiedBy: referral.auditModifiedBy,
                lastModifiedTime: referral.auditModifiedTime,
              ),
              clientAuditDetails: referral.clientCreatedTime == null ||
                      referral.clientCreatedBy == null
                  ? null
                  : ClientAuditDetails(
                      createdTime: referral.clientCreatedTime!,
                      createdBy: referral.clientCreatedBy!,
                      lastModifiedBy: referral.clientModifiedBy,
                      lastModifiedTime: referral.clientModifiedTime,
                    ),
            );
          })
          .whereNotNull()
          .where((element) => element.isDeleted != true)
          .toList();
    });
  }

  @override
  FutureOr<void> create(
    HFReferralModel entity, {
    bool createOpLog = true,
    DataOperation dataOperation = DataOperation.create,
  }) async {
    return retryLocalCallOperation(() async {
      final referralCompanion = entity.companion;
      await sql.batch((batch) async {
        batch.insert(sql.hFReferral, referralCompanion);
        await super.create(entity, createOpLog: createOpLog);
      });
    });
  }

  @override
  FutureOr<void> bulkCreate(
    List<HFReferralModel> entities,
  ) async {
    return retryLocalCallOperation(() async {
      final referralCompanions = entities
          .map(
            (e) => e.companion.copyWith(
              name: Value(e.name),
            ),
          )
          .toList();

      await sql.batch((batch) async {
        batch.insertAll(
          sql.hFReferral,
          referralCompanions,
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }

  @override
  FutureOr<void> update(
    HFReferralModel entity, {
    bool createOpLog = true,
    DataOperation dataOperation = DataOperation.update,
  }) async {
    return retryLocalCallOperation(() async {
      final referralCompanion = entity.companion.copyWith(
        name: Value(entity.name),
      );

      await sql.batch((batch) {
        batch.update(
          sql.hFReferral,
          referralCompanion,
          where: (table) => table.clientReferenceId.equals(
            entity.clientReferenceId,
          ),
        );
      });

      await super.update(entity,
          createOpLog: createOpLog, dataOperation: dataOperation);
    });
  }

  @override
  DataModelType get type => DataModelType.hFReferral;
}
