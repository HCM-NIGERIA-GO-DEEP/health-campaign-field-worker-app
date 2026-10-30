// Shared fixtures for the unique-ID pool characterization tests.
//
// These tests document how the pool ID moves through the REGISTRATION flow on
// today's code (branch smc-mc-base). They are evidence for the
// "Beneficiary ID Pool Report", not a fix. Every assertion names the
// production change that would flip it, so a later fix can turn the file
// into a regression guard by inverting the expectation.
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/data_model.init.dart' as dm_init;
import 'package:digit_flow_builder/blocs/flow_crud_bloc.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_app.dart';

/// Screen key of the REGISTRATION search screen (`searchBeneficiary` in
/// REGISTRATION.json). Header and footer widgets read state through this bare
/// key; the body reads through the composite key below.
const kScreen = 'searchBeneficiary';

/// One concrete instance of that screen: `<screenKey>::<instanceId>`.
const kKey = 'searchBeneficiary::S1';

class MockUniqueIdPoolRepo extends Mock
    implements LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel> {}

/// A pool row as the download writes it (`remote/unique_id_pool.dart:84-93`):
/// the status is a plain string and the row carries the downloader's uuid.
UniqueIdPoolModel poolRow(
  String id, {
  String status = 'UN_ASSIGNED',
  int createdTime = 0,
  String userUuid = 'U1',
}) =>
    UniqueIdPoolModel(
      id: id,
      status: status,
      deviceUuid: 'D1',
      userUuid: userUuid,
      auditDetails: AuditDetails(createdBy: userUuid, createdTime: createdTime),
    );

/// An individual whose only identifier has the given type and id.
IndividualModel individualWith(String type, String id, {String crid = 'IND-1'}) =>
    IndividualModel(
      clientReferenceId: crid,
      identifiers: [
        IdentifierModel(
          individualClientReferenceId: crid,
          clientReferenceId: 'IDF-$id',
          identifierType: type,
          identifierId: id,
        ),
      ],
    );

/// The search screen's state after the loader wrote the pool values and the
/// user typed a name: results, form data and the three widget-data keys.
FlowCrudState seededSearchState() => const FlowCrudState(
      stateWrapper: [
        {'row': 1}
      ],
      formData: {'f': 1},
      widgetData: {
        'latestBeneficiaryId': 'ID-1',
        'uniqueIdPoolCount': 40,
        'searchBar': 'ab',
      },
    );

/// Mirrors `WidgetStateContext._buildEvalContext`
/// (`flow_widget_state.dart:94-106`) for a widget outside any list.
Map<String, dynamic> evalContextWith(Map<String, dynamic> wd) => {
      'itemData': null,
      'parentData': null,
      'contextData': null,
      'formData': <String, dynamic>{},
      'widgetData': wd,
      'item': null,
    };

/// `FlowBuilderSingleton` has no reset; `setInitialData` is its only writer
/// for `loggedInUser` and `beneficiaryIdMinCount` (`utils.dart:50-74`).
/// Pass `userUuid: ''` together with `user: null` for "nobody logged in".
void setSingleton({int? minCount, UserModel? user, String? userUuid}) =>
    FlowBuilderSingleton().setInitialData(
      loggedInUserUuid: userUuid ?? user?.uuid ?? 'U1',
      maxRadius: 0,
      projectId: 'P1',
      selectedBeneficiaryType: BeneficiaryType.individual,
      projectType: null,
      selectedProject: ProjectModel(id: 'P1', name: 'P'),
      loggedInUser: user,
      beneficiaryIdMinCount: minCount,
    );

void resetSingleton() {
  setSingleton();
  FlowBuilderSingleton().clearUniqueIdPoolSnapshot();
}

/// Call once per test file in `setUpAll`.
void initTestEnv() {
  dm_init.initializeMappers();
  initializeFunctionRegistry();
  registerFallbackValue(UniqueIdPoolSearchModel());
  registerFallbackValue(poolRow('fallback'));
}

/// `disposeAll` is the only registry method that also clears `_instanceIds`
/// (`flow_crud_bloc.dart:702-711`). Call in `setUp` and `tearDown`.
void resetRegistry() => FlowCrudStateRegistry().disposeAll();

/// Pumps a MaterialApp page and returns a BuildContext inside it. The route
/// has no arguments, so executors resolve their key from
/// `contextData['_compositeKey']` (`interpolation.dart:121-123`).
Future<BuildContext> pumpContext(
  WidgetTester tester, {
  LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>? repo,
}) async {
  late BuildContext ctx;
  Widget child = Builder(builder: (c) {
    ctx = c;
    return const SizedBox();
  });
  if (repo != null) {
    child = RepositoryProvider<
        LocalRepository<UniqueIdPoolModel, UniqueIdPoolSearchModel>>.value(
      value: repo,
      child: child,
    );
  }
  await tester.pumpWidget(WidgetApp(child: child));
  return ctx;
}
