import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/address_type.dart';

import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../utils/utils.dart';

/// Persists bednet class-row entities: [IndividualModel] (with [AddressModel]),
/// [ProjectBeneficiaryModel], [HouseholdMemberModel].
///
/// [TaskModel] is created or updated when **teacher** details are submitted (see
/// [createOrUpdateBednetTaskForClassDetails]), after class distribution metrics
/// are already stored on the class row, with [TaskResourceModel] rows when a
/// project product variant can be resolved.
///
/// Mirrors the registration flow in the reference
/// `CustomBeneficiaryRegistrationBloc` (BLoC orchestrates; repository performs saves).
class BednetDistributionRepository {
  BednetDistributionRepository({
    required this.individualLocalRepository,
    required this.householdMemberLocalRepository,
    required this.projectBeneficiaryLocalRepository,
    required this.taskLocalRepository,
    required this.projectResourceLocalRepository,
  });

  final LocalRepository<IndividualModel, IndividualSearchModel>
      individualLocalRepository;
  final LocalRepository<HouseholdMemberModel, HouseholdMemberSearchModel>
      householdMemberLocalRepository;
  final LocalRepository<ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>
      projectBeneficiaryLocalRepository;
  final LocalRepository<TaskModel, TaskSearchModel> taskLocalRepository;
  final LocalRepository<ProjectResourceModel, ProjectResourceSearchModel>
      projectResourceLocalRepository;

  /// Status when class distribution task is recorded successfully.
  static const String kBednetTaskAdministrationSuccessStatus =
      'ADMINISTRATION_SUCCESS';

  /// Creates one class distribution row: individual + project beneficiary +
  /// household member (task is created on teacher submit).
  Future<IndividualModel> createClassDistributionEntities({
    required HouseholdModel school,
    required int classIndex,
    required String userUuid,
    required String boundaryCode,
    String? boundaryName,
  }) async {
    final tenantId = RegistrationDeliverySingleton().tenantId;
    final projectId = RegistrationDeliverySingleton().projectId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('tenantId is not set on RegistrationDeliverySingleton');
    }
    if (projectId == null || projectId.isEmpty) {
      throw StateError('projectId is not set on RegistrationDeliverySingleton');
    }

    final coords = school.bednetLatLngFromAdditionalFields;
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final auditDetails = AuditDetails(
      createdBy: userUuid,
      createdTime: createdAt,
    );
    final clientAuditDetails = ClientAuditDetails(
      createdBy: userUuid,
      createdTime: createdAt,
    );

    final locality = boundaryCode.isEmpty
        ? null
        : LocalityModel(
            code: boundaryCode,
            name: boundaryName ?? boundaryCode,
          );

    final individualClientReferenceId = IdGen.i.identifier;
    final projectBeneficiaryClientReferenceId = IdGen.i.identifier;
    final householdMemberClientReferenceId = IdGen.i.identifier;

    final addressForIndividual = AddressModel(
      relatedClientReferenceId: individualClientReferenceId,
      latitude: coords.latitude,
      longitude: coords.longitude,
      boundary: boundaryCode.isEmpty ? null : boundaryCode,
      type: AddressType.permanent,
      tenantId: tenantId,
      locality: locality,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    final classNameLabel = 'Class $classIndex';

    final individual = IndividualModel(
      clientReferenceId: individualClientReferenceId,
      tenantId: tenantId,
      rowVersion: 1,
      name: NameModel(
        givenName: classNameLabel,
        familyName: school.bednetDisplayName,
        individualClientReferenceId: individualClientReferenceId,
        auditDetails: auditDetails,
        clientAuditDetails: clientAuditDetails,
      ),
      gender: Gender.other,
      address: [addressForIndividual],
      additionalFields: IndividualAdditionalFields(
        version: 1,
        fields: [
          AdditionalField('schoolId', school.bednetSchoolId),
          AdditionalField(
              'householdClientReferenceId', school.clientReferenceId),
          AdditionalField(kBednetClassIndexKey, classIndex),
          AdditionalField('className', classNameLabel),
          AdditionalField(kBednetFlowKey, true),
          AdditionalField(
            'projectBeneficiaryClientReferenceId',
            projectBeneficiaryClientReferenceId,
          ),
        ],
      ),
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    await individualLocalRepository.create(individual);

    final projectBeneficiary = ProjectBeneficiaryModel(
      clientReferenceId: projectBeneficiaryClientReferenceId,
      projectId: projectId,
      beneficiaryClientReferenceId: school.clientReferenceId,
      dateOfRegistration: createdAt,
      tenantId: tenantId,
      rowVersion: 1,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    await projectBeneficiaryLocalRepository.create(projectBeneficiary);

    final householdMember = HouseholdMemberModel(
      clientReferenceId: householdMemberClientReferenceId,
      householdClientReferenceId: school.clientReferenceId,
      individualClientReferenceId: individualClientReferenceId,
      isHeadOfHousehold: false,
      tenantId: tenantId,
      rowVersion: 1,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    await householdMemberLocalRepository.create(householdMember);
    return individual;
  }

  Future<String?> _resolveProductVariantIdForProject(String projectId) async {
    final list = await projectResourceLocalRepository.search(
      ProjectResourceSearchModel(projectId: [projectId]),
    );
    if (list.isEmpty) return null;
    ProjectResourceModel? preferred;
    for (final pr in list) {
      final n = pr.resource.name?.toLowerCase() ?? '';
      if (n.contains('bednet') ||
          n.contains('llin') ||
          (n.contains('net') && n.contains('bed'))) {
        preferred = pr;
        break;
      }
    }
    preferred ??= list.first;
    return preferred.resource.productVariantId;
  }

  /// Bed nets delivered = boys + girls present (matches distribution summary).
  List<TaskResourceModel> _bednetTaskResources({
    required String taskClientReferenceId,
    required ClassDetailsModel details,
    required String? productVariantId,
    required String tenantId,
    required AuditDetails auditDetails,
    required ClientAuditDetails clientAuditDetails,
  }) {
    if (productVariantId == null || productVariantId.isEmpty) {
      return [];
    }
    final quantity = details.boysPresent + details.girlsPresent;
    return [
      TaskResourceModel(
        clientReferenceId: IdGen.i.identifier,
        taskclientReferenceId: taskClientReferenceId,
        productVariantId: productVariantId,
        quantity: quantity.toString(),
        isDelivered: quantity > 0,
        deliveryComment:
            BednetDistributionRepository.kBednetTaskAdministrationSuccessStatus,
        tenantId: tenantId,
        additionalFields: TaskResourceAdditionalFields(
          version: 1,
          fields: [
            AdditionalField('administeredQuantity', quantity),
            AdditionalField(
              'status',
              BednetDistributionRepository
                  .kBednetTaskAdministrationSuccessStatus,
            ),
          ],
        ),
        auditDetails: auditDetails,
        clientAuditDetails: clientAuditDetails,
      ),
    ];
  }

  TaskAdditionalFields _taskAdditionalFieldsFromClassDetails({
    required ClassDetailsModel details,
    required HouseholdModel school,
    required IndividualModel classIndividual,
  }) {
    int? classIndex;
    for (final field in classIndividual.additionalFields?.fields ??
        const <AdditionalField>[]) {
      if (field.key.toLowerCase() == kBednetClassIndexKey.toLowerCase()) {
        classIndex = int.tryParse(field.value.toString());
        break;
      }
    }

    final classDisplayName =
        classIndividual.name?.givenName?.trim().isNotEmpty == true
            ? classIndividual.name!.givenName!.trim()
            : (classIndex != null ? 'Class $classIndex' : '');

    return TaskAdditionalFields(
      version: 1,
      fields: [
        AdditionalField(
            kBednetTaskAdministrationStatusKey,
            BednetDistributionRepository
                .kBednetTaskAdministrationSuccessStatus),
        AdditionalField(kBednetTaskSchoolNameKey, school.bednetDisplayName),
        AdditionalField(
            kBednetTaskSchoolClientRefKey, school.clientReferenceId),
        if (classDisplayName.isNotEmpty)
          AdditionalField(kBednetTaskClassNameKey, classDisplayName),
        AdditionalField(kBednetTaskTotalPupilKey, details.pupilCount),
        AdditionalField(kBednetTaskTotalBoysKey, details.numberOfBoys),
        AdditionalField(kBednetTaskTotalGirlsKey, details.numberOfGirls),
        AdditionalField(kBednetTaskPupilsPresentKey, details.pupilsPresent),
        AdditionalField(kBednetTaskBoysPresentKey, details.boysPresent),
        AdditionalField(kBednetTaskGirlsPresentKey, details.girlsPresent),
        AdditionalField(kBednetTaskPupilsAbsentKey, details.pupilsAbsent),
        AdditionalField(kBednetTaskTotalAbsentKey, details.pupilsAbsent),
        AdditionalField(
          kBednetTaskDistributionDateKey,
          details.distributionDate.millisecondsSinceEpoch,
        ),
        if (classIndex != null)
          AdditionalField(kBednetClassIndexKey, classIndex),
      ],
    );
  }

  /// Creates or updates the bednet [TaskModel] after class details and teacher
  /// info are persisted (invoked from teacher submit with [ClassDetailsModel]).
  /// Metrics are on [TaskModel.additionalFields]; [TaskResourceModel] lines are
  /// added when a project resource / product variant is available.
  Future<void> createOrUpdateBednetTaskForClassDetails({
    required HouseholdModel school,
    required IndividualModel classIndividual,
    required ClassDetailsModel details,
    required String userUuid,
    required String boundaryCode,
    String? boundaryName,
  }) async {
    final tenantId = RegistrationDeliverySingleton().tenantId;
    final projectId = RegistrationDeliverySingleton().projectId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('tenantId is not set on RegistrationDeliverySingleton');
    }
    if (projectId == null || projectId.isEmpty) {
      throw StateError('projectId is not set on RegistrationDeliverySingleton');
    }

    final productVariantId =
        await _resolveProductVariantIdForProject(projectId);

    final individualFieldMap = <String, Object?>{
      for (final field in classIndividual.additionalFields?.fields ??
          const <AdditionalField>[])
        field.key.toLowerCase(): field.value as Object?,
    };
    final projectBeneficiaryClientRefFromIndividual =
        individualFieldMap['projectbeneficiaryclientreferenceid']?.toString();
    final projectBeneficiaryIdFromIndividual =
        individualFieldMap['projectbeneficiaryid']?.toString();

    ProjectBeneficiaryModel? projectBeneficiary;

    // Primary path: resolve PB from beneficiary linkage details already tied to
    // the class row (more reliable than only using individual client ref).
    if (projectBeneficiaryClientRefFromIndividual != null &&
        projectBeneficiaryClientRefFromIndividual.isNotEmpty) {
      final byClientRef = await projectBeneficiaryLocalRepository.search(
        ProjectBeneficiarySearchModel(
          projectId: [projectId],
          clientReferenceId: [projectBeneficiaryClientRefFromIndividual],
        ),
      );
      projectBeneficiary = byClientRef.firstOrNull;
    }

    if (projectBeneficiary == null &&
        projectBeneficiaryIdFromIndividual != null &&
        projectBeneficiaryIdFromIndividual.isNotEmpty) {
      final byId = await projectBeneficiaryLocalRepository.search(
        ProjectBeneficiarySearchModel(
          projectId: [projectId],
          id: [projectBeneficiaryIdFromIndividual],
        ),
      );
      projectBeneficiary = byId.firstOrNull;
    }

    // Fallback for rows where PB refs were not yet persisted.
    final householdClientRefFromIndividual =
        individualFieldMap['householdclientreferenceid']?.toString();
    final beneficiaryRefCandidates = <String>[
      if (householdClientRefFromIndividual != null &&
          householdClientRefFromIndividual.isNotEmpty)
        householdClientRefFromIndividual,
      school.clientReferenceId,
      classIndividual.clientReferenceId,
    ];

    for (final beneficiaryRef in beneficiaryRefCandidates) {
      if (projectBeneficiary != null) break;
      final byBeneficiaryRef = await projectBeneficiaryLocalRepository.search(
        ProjectBeneficiarySearchModel(
          projectId: [projectId],
          beneficiaryClientReferenceId: [beneficiaryRef],
        ),
      );
      projectBeneficiary = byBeneficiaryRef.firstOrNull;
    }

    if (projectBeneficiary == null) {
      // Older/synced class rows might not have a BEDNET project beneficiary yet.
      // Create one on-demand so task save can proceed.
      final nowForBeneficiary = DateTime.now().millisecondsSinceEpoch;
      final auditForBeneficiary = AuditDetails(
        createdBy: userUuid,
        createdTime: nowForBeneficiary,
      );
      final clientAuditForBeneficiary = ClientAuditDetails(
        createdBy: userUuid,
        createdTime: nowForBeneficiary,
      );

      projectBeneficiary = ProjectBeneficiaryModel(
        clientReferenceId: IdGen.i.identifier,
        projectId: projectId,
        beneficiaryClientReferenceId: school.clientReferenceId,
        dateOfRegistration: nowForBeneficiary,
        tenantId: tenantId,
        rowVersion: 1,
        auditDetails: auditForBeneficiary,
        clientAuditDetails: clientAuditForBeneficiary,
      );

      await projectBeneficiaryLocalRepository.create(projectBeneficiary);
    }

    final coords = school.bednetLatLngFromAdditionalFields;
    final now = DateTime.now().millisecondsSinceEpoch;

    final locality = boundaryCode.isEmpty
        ? null
        : LocalityModel(
            code: boundaryCode,
            name: boundaryName ?? boundaryCode,
          );

    final additionalFields = _taskAdditionalFieldsFromClassDetails(
      details: details,
      school: school,
      classIndividual: classIndividual,
    );

    final existingTasks = await taskLocalRepository.search(
      TaskSearchModel(
        projectId: projectId,
        projectBeneficiaryClientReferenceId: [
          projectBeneficiary.clientReferenceId
        ],
      ),
    );
    final existing = existingTasks.firstOrNull;

    if (existing != null) {
      final prevAudit = existing.auditDetails;
      final prevClient = existing.clientAuditDetails;
      final newAudit = prevAudit != null
          ? AuditDetails(
              createdBy: prevAudit.createdBy,
              createdTime: prevAudit.createdTime,
              lastModifiedBy: userUuid,
              lastModifiedTime: now,
            )
          : AuditDetails(createdBy: userUuid, createdTime: now);
      final newClientAudit = prevClient != null
          ? ClientAuditDetails(
              createdBy: prevClient.createdBy,
              createdTime: prevClient.createdTime,
              lastModifiedBy: userUuid,
              lastModifiedTime: now,
            )
          : ClientAuditDetails(createdBy: userUuid, createdTime: now);

      final taskAddress = AddressModel(
        relatedClientReferenceId: existing.clientReferenceId,
        latitude: coords.latitude,
        longitude: coords.longitude,
        boundary: boundaryCode.isEmpty ? null : boundaryCode,
        type: AddressType.permanent,
        tenantId: tenantId,
        locality: locality,
        auditDetails: newAudit,
        clientAuditDetails: newClientAudit,
      );

      final resources = _bednetTaskResources(
        taskClientReferenceId: existing.clientReferenceId,
        details: details,
        productVariantId: productVariantId,
        tenantId: tenantId,
        auditDetails: newAudit,
        clientAuditDetails: newClientAudit,
      );

      final mergedResources =
          resources.isNotEmpty ? resources : existing.resources;

      await taskLocalRepository.update(
        existing.copyWith(
          additionalFields: additionalFields,
          address: taskAddress,
          resources: mergedResources,
          status: kBednetTaskAdministrationSuccessStatus,
          auditDetails: newAudit,
          clientAuditDetails: newClientAudit,
        ),
      );
      return;
    }

    final taskClientReferenceId = IdGen.i.identifier;
    final auditDetails = AuditDetails(
      createdBy: userUuid,
      createdTime: now,
    );
    final clientAuditDetails = ClientAuditDetails(
      createdBy: userUuid,
      createdTime: now,
    );

    final taskAddress = AddressModel(
      relatedClientReferenceId: taskClientReferenceId,
      latitude: coords.latitude,
      longitude: coords.longitude,
      boundary: boundaryCode.isEmpty ? null : boundaryCode,
      type: AddressType.permanent,
      tenantId: tenantId,
      locality: locality,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    final resources = _bednetTaskResources(
      taskClientReferenceId: taskClientReferenceId,
      details: details,
      productVariantId: productVariantId,
      tenantId: tenantId,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    final task = TaskModel(
      clientReferenceId: taskClientReferenceId,
      projectId: projectId,
      projectBeneficiaryClientReferenceId: projectBeneficiary.clientReferenceId,
      createdBy: userUuid,
      status: kBednetTaskAdministrationSuccessStatus,
      tenantId: tenantId,
      rowVersion: 1,
      createdDate: now,
      address: taskAddress,
      additionalFields: additionalFields,
      resources: resources.isEmpty ? null : resources,
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    await taskLocalRepository.create(task);
  }
}
