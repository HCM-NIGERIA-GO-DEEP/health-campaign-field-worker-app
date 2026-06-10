import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../router/app_router.dart';
import '../utils/environment_config.dart';
import '../utils/i18_key_constants.dart' as i18;
import '../utils/utils.dart';
import '../widgets/header/back_navigation_help_header.dart';
import '../widgets/localized.dart';

class _TeamMember {
  final String name;
  final String username;
  final String userUuid;

  const _TeamMember({
    required this.name,
    required this.username,
    required this.userUuid,
  });
}

@RoutePage()
class SelectTeamMembersPage extends LocalizedStatefulWidget {
  const SelectTeamMembersPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<SelectTeamMembersPage> createState() => _SelectTeamMembersPageState();
}

class _SelectTeamMembersPageState
    extends LocalizedState<SelectTeamMembersPage> {
  List<_TeamMember> _recorderMembers = [];
  List<_TeamMember> _dispenserMembers = [];
  bool _isLoading = true;
  _TeamMember? _selectedMember1;
  _TeamMember? _selectedMember2;
  bool _isSubmitting = false;

  static final _mappingKeyPattern = RegExp(r'^team_mapping_(\d+)$');

  // additionalFields key used to cache role codes on individual records
  static const _rolesFieldKey = 'user_roles';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // ─── Orchestration ───────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    final results = await Future.wait([
      _loadTeamMembers(),
      _loadExistingMapping(),
    ]);

    final split = results[0] as ({
      List<_TeamMember> recorders,
      List<_TeamMember> dispensers
    });
    final mapping = results[1] as ({String? uuid1, String? uuid2});

    if (!mounted) return;
    setState(() {
      _recorderMembers = split.recorders;
      _dispenserMembers = split.dispensers;
      _selectedMember1 =
          split.recorders.firstWhereOrNull((m) => m.userUuid == mapping.uuid1);
      _selectedMember2 =
          split.dispensers.firstWhereOrNull((m) => m.userUuid == mapping.uuid2);
      _isLoading = false;
    });
  }

  // ─── Team member loading ──────────────────────────────────────────────────

  Future<({List<_TeamMember> recorders, List<_TeamMember> dispensers})>
      _loadTeamMembers() async {
    const empty = (recorders: <_TeamMember>[], dispensers: <_TeamMember>[]);
    try {
      final loggedInUuid = context.loggedInUserUuid;

      // Read all values from context before any await
      final projectId = context.projectId;
      final localStaffRepo = context
          .read<LocalRepository<ProjectStaffModel, ProjectStaffSearchModel>>();
      final remoteStaffRepo = context
          .read<RemoteRepository<ProjectStaffModel, ProjectStaffSearchModel>>();
      final localIndividualRepo = context
          .read<LocalRepository<IndividualModel, IndividualSearchModel>>();
      final remoteIndividualRepo = context
          .read<RemoteRepository<IndividualModel, IndividualSearchModel>>();

      // 1. Project staff: local first, remote fallback
      var staffList = await localStaffRepo.search(
        ProjectStaffSearchModel(projectId: [projectId]),
      );
      if (staffList
          .where((s) => s.userId != null && s.userId != loggedInUuid)
          .isEmpty) {
        final remoteStaff = await remoteStaffRepo.search(
          ProjectStaffSearchModel(projectId: [projectId]),
        );
        if (remoteStaff.isNotEmpty) {
          for (final staff in remoteStaff) {
            await localStaffRepo.create(staff, createOpLog: false);
          }
          staffList = remoteStaff;
        }
      }
      if (staffList.isEmpty) return empty;

      final allUserUuids = staffList
          .where((s) => s.userId != null && s.userId != loggedInUuid)
          .map((s) => s.userId!)
          .toSet()
          .toList();

      if (allUserUuids.isEmpty) return empty;

      // 2. Look up individuals in local DB
      final localIndividuals = await localIndividualRepo.search(
        IndividualSearchModel(userUuid: allUserUuids),
      );

      final localByUuid = {
        for (final ind in localIndividuals)
          if (ind.userUuid != null) ind.userUuid!: ind,
      };

      // 3. For any UUIDs missing from local, fetch via remote raw API
      final missingUuids =
          allUserUuids.where((u) => !localByUuid.containsKey(u)).toList();

      if (missingUuids.isNotEmpty) {
        final fetched = await _fetchAndCacheIndividuals(
          missingUuids,
          localIndividualRepo,
          remoteIndividualRepo,
        );
        localByUuid.addAll(fetched);
      }

      // 4. Partition into RECORDER / DISPENSER using cached role info
      final recorders = <_TeamMember>[];
      final dispensers = <_TeamMember>[];

      for (final ind in localByUuid.values) {
        final roleField = ind.additionalFields?.fields
            .firstWhereOrNull((f) => f.key == _rolesFieldKey);
        final roleCodes =
            roleField?.value?.toString().split(',').toSet() ?? <String>{};

        if (roleCodes.isEmpty) continue;

        final member = _TeamMember(
          name: ind.name?.givenName?.isNotEmpty == true
              ? ind.name!.givenName!
              : (ind.userId ?? ''),
          username: ind.userId ?? '',
          userUuid: ind.userUuid ?? '',
        );

        if (member.username.isEmpty || member.userUuid.isEmpty) continue;

        if (roleCodes.contains('RC')) recorders.add(member);
        if (roleCodes.contains('DS')) dispensers.add(member);
      }

      return (recorders: recorders, dispensers: dispensers);
    } catch (_) {
      return empty;
    }
  }

  /// Fetches individuals for [userUuids] via raw API, saves them to local DB
  /// (with roles cached in additionalFields), and returns a uuid→IndividualModel map.
  Future<Map<String, IndividualModel>> _fetchAndCacheIndividuals(
    List<String> userUuids,
    LocalRepository<IndividualModel, IndividualSearchModel> localRepo,
    RemoteRepository<IndividualModel, IndividualSearchModel> remoteRepo,
  ) async {
    final result = <String, IndividualModel>{};
    try {
      final response = await remoteRepo.dio.post(
        remoteRepo.searchPath,
        queryParameters: {
          'offset': 0,
          'limit': userUuids.length,
          'tenantId': envConfig.variables.tenantId,
        },
        data: {
          'Individual': {'userUuid': userUuids},
        },
      );

      final responseMap = response.data;
      if (responseMap is! Map<String, dynamic> ||
          !responseMap.containsKey('Individual')) return result;

      final individualList = responseMap['Individual'];
      if (individualList is! List) return result;

      final toCreate = <IndividualModel>[];

      for (final raw in individualList.whereType<Map<String, dynamic>>()) {
        final userDetails = raw['userDetails'];
        if (userDetails is! Map<String, dynamic>) continue;
        final roles = userDetails['roles'];
        if (roles is! List) continue;

        final roleCodes = roles
            .whereType<Map<String, dynamic>>()
            .map((r) => r['code'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toSet();

        final nameMap = raw['name'];
        final givenName = nameMap is Map<String, dynamic>
            ? nameMap['givenName'] as String? ?? ''
            : '';
        final username = userDetails['username'] as String? ?? '';
        final userUuid = raw['userUuid'] as String? ?? '';
        final clientReferenceId =
            raw['clientReferenceId'] as String? ?? userUuid;

        if (username.isEmpty || userUuid.isEmpty) continue;

        final individual = IndividualModel(
          clientReferenceId: clientReferenceId,
          id: raw['id'] as String?,
          userUuid: userUuid,
          userId: username,
          tenantId: raw['tenantId'] as String?,
          name: givenName.isNotEmpty
              ? NameModel(
                  individualClientReferenceId: clientReferenceId,
                  givenName: givenName,
                )
              : null,
          additionalFields: IndividualAdditionalFields(
            version: 1,
            fields: [
              AdditionalField(_rolesFieldKey, roleCodes.join(',')),
            ],
          ),
        );

        toCreate.add(individual);
        result[userUuid] = individual;
      }

      for (final ind in toCreate) {
        // Save without OpLog — this is a read-only cache, not a local mutation
        await localRepo.create(ind, createOpLog: false);
      }
    } catch (_) {
      // silently ignore; result may be partial
    }
    return result;
  }

  // ─── Existing mapping loading ─────────────────────────────────────────────

  Future<({String? uuid1, String? uuid2})> _loadExistingMapping() async {
    try {
      final localRepo = context
          .read<LocalRepository<IndividualModel, IndividualSearchModel>>();

      final userUuid = context.loggedInUserUuid;
      var individuals =
          await localRepo.search(IndividualSearchModel(userUuid: [userUuid]));

      // Fall back to remote if not cached locally
      if (individuals.isEmpty) {
        individuals = await _fetchAndSaveCurrentUser(localRepo);
      }

      if (individuals.isEmpty) return (uuid1: null, uuid2: null);

      final fields =
          individuals.first.additionalFields?.fields ?? <AdditionalField>[];
      final latestMapping = _findLatestMapping(fields);

      if (latestMapping == null) return (uuid1: null, uuid2: null);

      final parts = latestMapping.value.toString().split(',');
      if (parts.length < 2) return (uuid1: null, uuid2: null);

      return (uuid1: parts[0], uuid2: parts[1]);
    } catch (_) {
      return (uuid1: null, uuid2: null);
    }
  }

  /// Fetches the logged-in user's individual from remote, creates it in local,
  /// and returns it.
  Future<List<IndividualModel>> _fetchAndSaveCurrentUser(
    LocalRepository<IndividualModel, IndividualSearchModel> localRepo,
  ) async {
    try {
      final remoteRepo = context
          .read<RemoteRepository<IndividualModel, IndividualSearchModel>>();
      final userUuid = context.loggedInUserUuid;
      final individuals =
          await remoteRepo.search(IndividualSearchModel(userUuid: [userUuid]));

      if (individuals.isNotEmpty) {
        // Cache without OpLog — just a read-side cache
        await localRepo.bulkCreate(individuals);
      }
      return individuals;
    } catch (_) {
      return [];
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitSelection() async {
    if (_selectedMember1 == null || _selectedMember2 == null) {
      Toast.showToast(
        context,
        message: localizations.translate(i18.common.corecommonRequired),
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Read context values before any await
      final localRepo = context
          .read<LocalRepository<IndividualModel, IndividualSearchModel>>();
      final loggedInUuid = context.loggedInUserUuid;

      var individuals = await localRepo
          .search(IndividualSearchModel(userUuid: [loggedInUuid]));

      // If not in local, fetch from remote and create locally first
      if (individuals.isEmpty) {
        individuals = await _fetchAndSaveCurrentUser(localRepo);
      }

      if (individuals.isNotEmpty) {
        final individual = individuals.first;
        final existingFields =
            individual.additionalFields?.fields ?? <AdditionalField>[];

        final nextIndex = _nextMappingIndex(existingFields);
        final newValue =
            '${_selectedMember1!.userUuid},${_selectedMember2!.userUuid},${DateTime.now().millisecondsSinceEpoch}';

        final updatedFields = [
          ...existingFields,
          AdditionalField('team_mapping_$nextIndex', newValue),
        ];

        final now = DateTime.now().millisecondsSinceEpoch;

        // auditDetails must be non-null for createOplogEntry to run,
        // and clientAuditDetails.lastModifiedBy must equal the logged-in
        // user UUID so the SyncBloc's createdBy filter finds the entry.
        final updatedIndividual = individual.copyWith(
          additionalFields: IndividualAdditionalFields(
            version: individual.additionalFields?.version ?? 1,
            fields: updatedFields,
          ),
          auditDetails: individual.auditDetails?.copyWith(
                lastModifiedBy: loggedInUuid,
                lastModifiedTime: now,
              ) ??
              AuditDetails(
                createdBy: loggedInUuid,
                createdTime: now,
                lastModifiedBy: loggedInUuid,
                lastModifiedTime: now,
              ),
          clientAuditDetails: individual.clientAuditDetails?.copyWith(
                lastModifiedBy: loggedInUuid,
                lastModifiedTime: now,
              ) ??
              ClientAuditDetails(
                createdBy: loggedInUuid,
                createdTime: now,
                lastModifiedBy: loggedInUuid,
                lastModifiedTime: now,
              ),
        );

        // Update in local DB — creates an OpLog entry so it syncs later
        await localRepo.update(updatedIndividual);
      }
    } catch (_) {
      // silently proceed to home even if update fails
    }

    if (mounted) {
      context.router.replaceAll([HomeRoute()]);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  AdditionalField? _findLatestMapping(List<AdditionalField> fields) {
    AdditionalField? latest;
    int maxIndex = 0;
    for (final f in fields) {
      final match = _mappingKeyPattern.firstMatch(f.key);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n > maxIndex) {
        maxIndex = n;
        latest = f;
      }
    }
    return latest;
  }

  int _nextMappingIndex(List<AdditionalField> fields) {
    int maxIndex = 0;
    for (final f in fields) {
      final match = _mappingKeyPattern.firstMatch(f.key);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!) ?? 0;
      if (n > maxIndex) maxIndex = n;
    }
    return maxIndex + 1;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    final recorderItems = _recorderMembers
        .map((m) => DropdownItem(name: m.name, code: m.username))
        .toList();
    final dispenserItems = _dispenserMembers
        .map((m) => DropdownItem(name: m.name, code: m.username))
        .toList();

    return Scaffold(
      body: ScrollableContent(
        header: const BackNavigationHelpHeaderWidget(showHelp: false),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            SafeArea(
              child: DigitButton(
                mainAxisSize: MainAxisSize.max,
                isDisabled: _isSubmitting ||
                    _selectedMember1 == null ||
                    _selectedMember2 == null,
                label: localizations.translate(i18.common.coreCommonSubmit),
                type: DigitButtonType.primary,
                size: DigitButtonSize.large,
                onPressed: _submitSelection,
              ),
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: DigitCard(
              margin: const EdgeInsets.all(spacer2),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: spacer4),
                  child: Text(
                    localizations
                        .translate(i18.selectTeam.selectTeamMembersTitle),
                    style: textTheme.headingL,
                  ),
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: spacer2),
                    child: LabeledField(
                      label: localizations
                          .translate(i18.selectTeam.teamMember1Label),
                      isRequired: true,
                      capitalizedFirstLetter: false,
                      child: DigitDropdown<String>(
                        onTap: () {},
                        sentenceCaseEnabled: false,
                        items: recorderItems,
                        emptyItemText:
                            localizations.translate(i18.common.noMatchFound),
                        selectedOption: _selectedMember1 != null
                            ? DropdownItem(
                                name: _selectedMember1!.name,
                                code: _selectedMember1!.username,
                              )
                            : null,
                        onSelect: (value) {
                          setState(() {
                            _selectedMember1 = _recorderMembers.firstWhere(
                              (m) => m.username == value.code,
                            );
                          });
                        },
                        onChange: (value) {
                          if (value.isEmpty) {
                            setState(() => _selectedMember1 = null);
                          }
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: spacer2),
                    child: LabeledField(
                      label: localizations
                          .translate(i18.selectTeam.teamMember2Label),
                      isRequired: true,
                      capitalizedFirstLetter: false,
                      child: DigitDropdown<String>(
                        onTap: () {},
                        sentenceCaseEnabled: false,
                        items: dispenserItems,
                        emptyItemText:
                            localizations.translate(i18.common.noMatchFound),
                        selectedOption: _selectedMember2 != null
                            ? DropdownItem(
                                name: _selectedMember2!.name,
                                code: _selectedMember2!.username,
                              )
                            : null,
                        onSelect: (value) {
                          setState(() {
                            _selectedMember2 = _dispenserMembers.firstWhere(
                              (m) => m.username == value.code,
                            );
                          });
                        },
                        onChange: (value) {
                          if (value.isEmpty) {
                            setState(() => _selectedMember2 = null);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
