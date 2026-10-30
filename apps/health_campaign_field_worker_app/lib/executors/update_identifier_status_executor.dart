import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/id_status.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/action_handler/executors/toast_executor.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/beneficiary_id/pool_id_assignment.dart';
import '../utils/i18_key_constants.dart' as i18;

/// Gives each new individual a pool ID at save time, from the database.
///
/// Runs before CREATE_EVENT in the HOUSEHOLD and ADD_MEMBER create branches.
/// The pool ID that the screen passed in can be missing (DEFAULT/UUID), stale,
/// already used, or another user's (RC-01 to RC-04 in the pool-ID report).
/// This step reads the logged-in user's free rows, keeps a valid ID, replaces
/// any other one with the oldest free row, marks the row ASSIGNED, and returns
/// the corrected entities for CREATE_EVENT. With no free row the UUID stays,
/// and the user sees a warning. It never throws.
class UpdateIdentifierStatusExecutor extends ActionExecutor {
  @override
  bool canHandle(String actionType) => actionType == 'UPDATE_IDENTIFIER_STATUS';

  @override
  Future<Map<String, dynamic>> execute(
    ActionConfig action,
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    final identifierType =
        action.properties['identifierType'] as String? ?? uniqueBeneficiaryIdType;

    final entities = contextData['entities'];
    if (entities is! List || entities.isEmpty) return contextData;

    final individuals = entities.whereType<IndividualModel>().toList();
    if (individuals.isEmpty) return contextData;

    // Only new individuals get pool IDs. An existing individual's ID is
    // ASSIGNED, so the rules below would replace it. The config runs this step
    // only in create branches; this guard keeps that true for any config.
    final navigation = contextData['navigation'];
    final isEdit = navigation is Map &&
        (navigation['isEdit'] == true || navigation['isEdit'] == 'true');
    final existingModels = contextData['existingModels'];
    if (isEdit || (existingModels is List && existingModels.isNotEmpty)) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: edit flow, pool IDs not changed');
      return contextData;
    }

    final userUuid = FlowBuilderSingleton().currentUserUuid;
    if (userUuid == null) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: no logged-in user, pool not used');
      return contextData;
    }

    final LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> repository;
    final List<UniqueIdPoolModel> freeRows;
    try {
      repository = context
          .read<LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>();
      freeRows = await repository.search(UniqueIdPoolSearchModel(
        status: IdStatus.unAssigned.toValue(),
        userUuid: userUuid,
      ));
    } catch (e) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: cannot read the pool: $e');
      return contextData;
    }

    final result = assignPoolIds(
      individuals: individuals,
      unassignedRows: freeRows,
      userUuid: userUuid,
      newClientReferenceId: () => IdGen.instance.identifier,
      identifierType: identifierType,
    );

    final saved = <String, IndividualModel>{};
    var formData = contextData['formData'];
    var anyMarkFailed = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    void patchForm(String fromType, String fromId, String toType, String toId) {
      final form = formData;
      if (form is! Map<String, dynamic>) return;
      formData = replaceIdentifierInFormData(form,
          fromType: fromType, fromId: fromId, toType: toType, toId: toId);
    }

    for (final a in result.assignments) {
      final row = a.row;
      debugPrint('UPDATE_IDENTIFIER_STATUS: ${a.original.clientReferenceId} '
          '-> ${a.outcome.name} (${a.reason}) row=${row?.id}');
      if (row == null) continue;

      try {
        await repository.update(
            markPoolRowAssigned(row, userUuid: userUuid, nowMillis: now));
      } catch (e) {
        debugPrint('UPDATE_IDENTIFIER_STATUS: cannot mark ${row.id}: $e');
        anyMarkFailed = true;
        // No row is marked for this individual, so it must not carry a pool
        // ID: a free row would be given again later, and a stale ID belongs to
        // someone else. Fall back to DEFAULT/UUID, as with an empty pool.
        final uuid = IdGen.instance.identifier;
        final stripped = withoutPoolId(a.original,
            identifierType: identifierType, uuid: uuid);
        if (stripped != null) {
          final oldId = a.original.identifiers!
              .firstWhere((i) =>
                  i.identifierType == identifierType &&
                  (i.identifierId?.isNotEmpty ?? false))
              .identifierId!;
          saved[a.original.clientReferenceId] = stripped;
          patchForm(identifierType, oldId, defaultIdentifierType, uuid);
        }
        continue;
      }
      FlowBuilderSingleton().consumeUniqueIdPoolId();

      if (a.outcome == PoolIdOutcome.reassigned) {
        saved[a.original.clientReferenceId] = a.individual;
        final replaced = a.replaced;
        if (replaced != null &&
            replaced.identifierType != null &&
            replaced.identifierId != null) {
          patchForm(replaced.identifierType!, replaced.identifierId!,
              identifierType, row.id);
        }
      }
    }

    if (result.anyExhausted || anyMarkFailed) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: no free pool ID; the UUID is kept');
      if (context.mounted) await _warnNoFreeIds(context, contextData);
    }

    if (saved.isEmpty) return contextData;

    return {
      ...contextData,
      'entities': [
        for (final e in entities)
          if (e is IndividualModel && saved.containsKey(e.clientReferenceId))
            saved[e.clientReferenceId]
          else
            e,
      ],
      if (formData != null) 'formData': formData,
    };
  }

  Future<void> _warnNoFreeIds(
    BuildContext context,
    Map<String, dynamic> contextData,
  ) async {
    try {
      await ToastExecutor().execute(
        ActionConfig(
          action: '',
          actionType: 'SHOW_TOAST',
          properties: {
            'message': i18.beneficiaryId.noBeneficiaryIdsText,
            'type': 'warning',
          },
        ),
        context,
        contextData,
      );
    } catch (e) {
      debugPrint('UPDATE_IDENTIFIER_STATUS: cannot show the warning: $e');
    }
  }
}
