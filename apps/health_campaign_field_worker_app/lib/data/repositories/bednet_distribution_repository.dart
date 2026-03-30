import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/address_type.dart';
import 'package:uuid/uuid.dart';

import '../../models/bednet_distribution/bednet_distribution_models.dart';
import '../../utils/utils.dart';

/// Persists bednet class-row entities: [IndividualModel] (with [AddressModel]),
/// [ProjectBeneficiaryModel], [HouseholdMemberModel].
///
/// [TaskModel] is created only when class distribution **details** are submitted
/// (see [createOrUpdateBednetTaskForClassDetails]), with [TaskResourceModel] rows
/// when a project product variant can be resolved.
///
/// Mirrors the registration flow in the reference
/// `CustomBeneficiaryRegistrationBloc` (BLoC orchestrates; repository performs saves).
class BednetDistributionRepository {
  static const _uuid = Uuid();

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
  /// household member (no [TaskModel] — task is created when class details are saved).
  Future<void> createClassDistributionEntities({
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

    final individualClientReferenceId = _uuid.v1();
    final projectBeneficiaryClientReferenceId = _uuid.v1();
    final householdMemberClientReferenceId = _uuid.v1();

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
        ],
      ),
      auditDetails: auditDetails,
      clientAuditDetails: clientAuditDetails,
    );

    await individualLocalRepository.create(individual);

    final projectBeneficiary = ProjectBeneficiaryModel(
      clientReferenceId: projectBeneficiaryClientReferenceId,
      projectId: projectId,
      beneficiaryClientReferenceId: individualClientReferenceId,
      dateOfRegistration: createdAt,
      tenantId: tenantId,
      rowVersion: 1,
      tag: 'BEDNET',
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
        clientReferenceId: _uuid.v1(),
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
              BednetDistributionRepository.kBednetTaskAdministrationSuccessStatus,
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
        AdditionalField(kBednetTaskAdministrationStatusKey,
            BednetDistributionRepository.kBednetTaskAdministrationSuccessStatus),
        AdditionalField(kBednetTaskSchoolNameKey, school.bednetDisplayName),
        AdditionalField(kBednetTaskSchoolClientRefKey, school.clientReferenceId),
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

  /// Creates or updates the bednet [TaskModel] after class details are filled in.
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

    final productVariantId = await _resolveProductVariantIdForProject(projectId);

    final beneficiaries = await projectBeneficiaryLocalRepository.search(
      ProjectBeneficiarySearchModel(
        projectId: [projectId],
        beneficiaryClientReferenceId: [classIndividual.clientReferenceId],
        tag: ['BEDNET'],
      ),
    );
    final projectBeneficiary = beneficiaries.firstOrNull;
    if (projectBeneficiary == null) {
      throw StateError(
        'No BEDNET project beneficiary for individual '
        '${classIndividual.clientReferenceId}',
      );
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

    final taskClientReferenceId = _uuid.v1();
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
