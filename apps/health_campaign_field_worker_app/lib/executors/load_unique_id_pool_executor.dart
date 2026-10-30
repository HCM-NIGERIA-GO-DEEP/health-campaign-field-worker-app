import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/action_handler/action_config.dart';
import 'package:digit_flow_builder/action_handler/executors/action_executor.dart';
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:digit_flow_builder/widget_registry.dart';
import 'package:flutter/material.dart';

import '../blocs/localization/app_localization.dart';
import '../services/beneficiary_id_service.dart';
import '../utils/utils.dart';

class LoadUniqueIdPoolExecutor extends ActionExecutor {
  final bool defaultAllocate;
  LoadUniqueIdPoolExecutor({this.defaultAllocate = false});

  @override
  bool canHandle(String actionType) => actionType == 'LOAD_UNIQUE_ID_POOL';

  @override
  Future<Map<String, dynamic>> execute(ActionConfig action,
      BuildContext context, Map<String, dynamic> contextData) async {
    final key = CrudItemContext.of(context)?.compositeKey ??
        getEffectiveCompositeKey(context, contextData);
    final allocate = action.properties['allocate'] == true || defaultAllocate;
    final navigation =
        Map<String, dynamic>.from(contextData['navigation'] as Map? ?? {});
    final formData =
        Map<String, dynamic>.from(contextData['formData'] as Map? ?? {});
    final household =
        Map<String, dynamic>.from(formData['householdDetails'] as Map? ?? {});
    final oldIdentifier = household['identifiers']?.toString() ?? '';
    bool yes(dynamic value) => value == true || value == 'true';
    final ordinaryEdit = yes(navigation['isEdit']) &&
        !yes(navigation['isClosedHousehold']) &&
        !yes(navigation['isNotBeneficiary']);
    if (allocate &&
        ordinaryEdit &&
        oldIdentifier.startsWith('UNIQUE_BENEFICIARY_ID,')) {
      return {
        ...contextData,
        'latestBeneficiaryId':
            oldIdentifier.substring(oldIdentifier.indexOf(',') + 1).trim()
      };
    }

    void publish(Map<String, dynamic> values) {
      if (key == null) return;
      final current = FlowCrudStateRegistry().get(key) ?? const FlowCrudState();
      FlowCrudStateRegistry().update(key,
          current.copyWith(widgetData: {...?current.widgetData, ...values}));
    }

    try {
      if (!context.isRegistrarRole) {
        throw StateError('BENEFICIARY_IDS_REGISTRAR_ONLY');
      }
      final service = BeneficiaryIdService.forContext(context);
      final session =
          navigation['beneficiaryIdAllocationKey']?.toString() ?? key;
      final rows = await service.available(session: allocate ? session : null);
      UniqueIdPoolModel? first = rows.isEmpty ? null : rows.first;
      String? identifier;
      String? rawId;
      if (allocate) {
        final boundary = FlowBuilderSingleton().boundary;
        if (boundary == null || session == null) {
          throw StateError('BENEFICIARY_DISTRIBUTION_POINT_UNAVAILABLE');
        }
        final result = await service.allocate(boundary, session);
        identifier = result.identifier;
        rawId = result.rawId;
        first = (await service.pool.search(UniqueIdPoolSearchModel(id: rawId)))
            .first;
        household['identifiers'] = 'UNIQUE_BENEFICIARY_ID,$identifier';
        formData['householdDetails'] = household;
      } else if (first != null) {
        final boundary = FlowBuilderSingleton().boundary;
        if (boundary != null) {
          identifier = await service.compose(boundary, first.id);
        }
        rawId = first.id;
      }
      final values = <String, dynamic>{
        'uniqueIdPoolCount': rows.length,
        'latestBeneficiaryId': identifier,
        'latestBeneficiaryIdModel': first,
        'rawBeneficiaryId': rawId,
        if (allocate) 'beneficiaryIdAllocationKey': session,
      };
      publish(values);
      if (action.properties['requireAvailable'] == true && rows.isEmpty) {
        throw StateError('BENEFICIARY_IDS_DOWNLOAD_REQUIRED');
      }
      return {...contextData, ...values, if (allocate) 'formData': formData};
    } catch (error) {
      final values = <String, dynamic>{
        'uniqueIdPoolCount': 0,
        'latestBeneficiaryId': null,
        'latestBeneficiaryIdModel': null,
        'rawBeneficiaryId': null,
      };
      publish(values);
      final blocked = allocate || action.properties['requireAvailable'] == true;
      final message = error is StateError
          ? error.message.toString()
          : 'BENEFICIARY_IDS_DOWNLOAD_REQUIRED';
      if (blocked && context.mounted && action.properties['silent'] != true) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).translate(message))));
      }
      return {
        ...contextData,
        ...values,
        if (blocked) 'haltActionChain': true,
        if (blocked) 'beneficiaryIdError': message,
      };
    }
  }
}
