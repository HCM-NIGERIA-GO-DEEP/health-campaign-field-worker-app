import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

class UpdateIdentifierStatusExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) => actionType == 'UPDATE_IDENTIFIER_STATUS';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    debugPrint('UPDATE_IDENTIFIER_STATUS: ========== STARTING ==========');

    final identifierType = action.properties['identifierType'] as String? ??
        'UNIQUE_BENEFICIARY_ID';

    debugPrint(
        'UPDATE_IDENTIFIER_STATUS: Looking for identifier type: $identifierType');

    final entities = contextData['entities'] as List<dynamic>?;
    if (entities == null || entities.isEmpty) {
      debugPrint(
          'UPDATE_IDENTIFIER_STATUS: No entities found in contextData[entities]');
      return contextData;
    }

    final individualEntities = entities.whereType<IndividualModel>().toList();

    if (individualEntities.isEmpty) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: No IndividualModel entities found');
      return contextData;
    }

    debugPrint(
        'UPDATE_IDENTIFIER_STATUS: Found ${individualEntities.length} IndividualModel entities');

    final latestBeneficiaryId = contextData['latestBeneficiaryId'] as String?;
    final householdMembers =
        entities.whereType<HouseholdMemberModel>().toList();

    // Fetch available IDs from pool
    final poolRepository = context
        .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();
    final searchResult = await poolRepository.search(UniqueIdPoolSearchModel(
      status: IdStatus.unAssigned.toValue(),
    ));

    List<UniqueIdPoolModel> availablePoolIds;
    if (searchResult is Future) {
      availablePoolIds = await (searchResult as Future<List<UniqueIdPoolModel>>);
    } else {
      availablePoolIds = List<UniqueIdPoolModel>.from(searchResult as List);
    }

    availablePoolIds.sort((a, b) {
      final aTime = a.auditDetails?.createdTime ?? 0;
      final bTime = b.auditDetails?.createdTime ?? 0;
      return aTime.compareTo(bTime);
    });

    final List<String> allAvailableIds =
        availablePoolIds.map((e) => e.id!).toList();
    // Ensure latestBeneficiaryId is at the front if it exists in the list to maintain consistency
    if (latestBeneficiaryId != null &&
        allAvailableIds.contains(latestBeneficiaryId)) {
      allAvailableIds.remove(latestBeneficiaryId);
      allAvailableIds.insert(0, latestBeneficiaryId);
    }

    int idIndex = 0;
    String? getNextId() =>
        idIndex < allAvailableIds.length ? allAvailableIds[idIndex++] : null;

    final updatedEntities = entities.map((entity) {
      if (entity is! IndividualModel) return entity;

      final individual = entity;
      final member = householdMembers.firstWhereOrNull(
        (m) => m.individualClientReferenceId == individual.clientReferenceId,
      );
      final isHead = member?.isHeadOfHousehold ?? false;

      var identifiers =
          List<IdentifierModel>.from(individual.identifiers ?? []);
      bool modified = false;

      // Add UNIQUE_BENEFICIARY_ID if missing
      if (identifierType == 'UNIQUE_BENEFICIARY_ID' ||
          identifierType == 'E_TOKEN') {
        bool hasUniqueId = identifiers
            .any((id) => id.identifierType == 'UNIQUE_BENEFICIARY_ID');
        if (!hasUniqueId) {
          final id = getNextId();
          if (id != null) {
            identifiers.add(IdentifierModel(
              identifierType: 'UNIQUE_BENEFICIARY_ID',
              identifierId: id,
              clientReferenceId: IdGen.i.identifier,
              tenantId: individual.tenantId,
              individualClientReferenceId: individual.clientReferenceId,
              clientAuditDetails: individual.clientAuditDetails,
              auditDetails: individual.auditDetails,
            ));
            modified = true;
          }
        }

        // Add E_TOKEN if head and missing
        if (isHead) {
          bool hasEToken =
              identifiers.any((id) => id.identifierType == 'E_TOKEN');
          if (!hasEToken) {
            final id = getNextId();
            if (id != null) {
              identifiers.add(IdentifierModel(
                identifierType: 'E_TOKEN',
                identifierId: id,
                clientReferenceId: IdGen.i.identifier,
                tenantId: individual.tenantId,
                individualClientReferenceId: individual.clientReferenceId,
                clientAuditDetails: individual.clientAuditDetails,
                auditDetails: individual.auditDetails,
              ));
              modified = true;
            }
          }
        }
      }

      return modified
          ? individual.copyWith(identifiers: identifiers)
          : individual;
    }).toList();

    contextData['entities'] = updatedEntities;
    final updatedIndividualEntities =
        updatedEntities.whereType<IndividualModel>().toList();

    final uniqueIdPoolToUpdate = <UniqueIdPoolModel>[];
    bool foundMatch = false;

    for (final individual in updatedIndividualEntities) {
      final identifiers = individual.identifiers;
      if (identifiers == null || identifiers.isEmpty) {
        debugPrint(
            'UPDATE_IDENTIFIER_STATUS: Individual ${individual.clientReferenceId} has no identifiers');
        continue;
      }

      for (final id in identifiers) {
        if (id.identifierType == 'UNIQUE_BENEFICIARY_ID' ||
            id.identifierType == 'E_TOKEN') {
          foundMatch = true;
          final identifierId = id.identifierId;
          debugPrint(
              'UPDATE_IDENTIFIER_STATUS: Found matching identifier: $identifierId with type ${id.identifierType}');

          if (identifierId == null || identifierId.isEmpty) {
            debugPrint(
                'UPDATE_IDENTIFIER_STATUS: Identifier ID is null or empty, skipping');
            continue;
          }

          try {
            final repository = context.read<
                LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();

            final searchResult = repository.search(UniqueIdPoolSearchModel(
              id: identifierId,
            ));

            List<UniqueIdPoolModel> searchResults;
            if (searchResult is Future) {
              searchResults =
                  await (searchResult as Future<List<UniqueIdPoolModel>>);
            } else {
              searchResults =
                  List<UniqueIdPoolModel>.from(searchResult as List);
            }

            if (searchResults.isEmpty) {
              debugPrint(
                  'UPDATE_IDENTIFIER_STATUS: No UniqueIdPoolModel found for id: $identifierId');
              continue;
            }

            final uniqueIdPoolModel = searchResults.first;

            final now = DateTime.now().millisecondsSinceEpoch;
            final currentUserUuid =
                FlowBuilderSingleton().loggedInUserUuid ?? '';

            final updatedClientAudit =
                uniqueIdPoolModel.clientAuditDetails != null
                    ? uniqueIdPoolModel.clientAuditDetails!.copyWith(
                        lastModifiedBy: currentUserUuid,
                        lastModifiedTime: now,
                      )
                    : ClientAuditDetails(
                        createdBy: uniqueIdPoolModel.auditDetails?.createdBy ??
                            currentUserUuid,
                        createdTime:
                            uniqueIdPoolModel.auditDetails?.createdTime ?? now,
                        lastModifiedBy: currentUserUuid,
                        lastModifiedTime: now,
                      );

            final updatedUniqueId = uniqueIdPoolModel.copyWith(
              status: IdStatus.assigned.toValue(),
              clientAuditDetails: updatedClientAudit,
            );

            uniqueIdPoolToUpdate.add(updatedUniqueId);
            debugPrint(
                'UPDATE_IDENTIFIER_STATUS: Prepared UniqueIdPoolModel update: $identifierId -> ASSIGNED');
          } catch (e) {
            debugPrint(
                'UPDATE_IDENTIFIER_STATUS: Error searching/updating UniqueIdPoolModel: $e');
          }
        }
      }
    }

    if (!foundMatch) {
      debugPrint(
          'UPDATE_IDENTIFIER_STATUS: No identifiers found with type $identifierType - skipping');
      return contextData;
    }

    if (uniqueIdPoolToUpdate.isEmpty) {
      debugPrint(
          'UPDATE_IDENTIFIER_STATUS: No UniqueIdPoolModels to update - skipping');
      return contextData;
    }

    debugPrint(
        'UPDATE_IDENTIFIER_STATUS: Updating ${uniqueIdPoolToUpdate.length} UniqueIdPoolModels to ASSIGNED via local repository');

    try {
      final repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();

      for (final uniqueIdModel in uniqueIdPoolToUpdate) {
        await repository.update(uniqueIdModel);
      }

      debugPrint(
          'UPDATE_IDENTIFIER_STATUS: Successfully updated UniqueIdPoolModels');
    } catch (e) {
      debugPrint(
          'UPDATE_IDENTIFIER_STATUS: Error updating UniqueIdPoolModels: $e');
    }

    return contextData;
  }
}
