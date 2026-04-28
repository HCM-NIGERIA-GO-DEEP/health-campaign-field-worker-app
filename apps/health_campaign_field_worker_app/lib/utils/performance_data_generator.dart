import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:digit_data_model/data_model.dart';

Future<void> populateLargeDataset(LocalSqlDataStore db) async {
  const uuid = Uuid();
  const tenantId = 'ba'; 
  const auditUser = 'performance_test';
  const projectId = '6f85e110-1b65-4a2a-a22e-7dde6221cbf0';
  const boundaryCode = 'NIGERIAUAT_NI_02_01_10_01_22_WARUM_NOMADI';
  
  const baseLat = 12.928;
  const baseLng = 77.6279;
  
  final now = DateTime.now().millisecondsSinceEpoch;

  const totalHouseholds = 100000;
  const individualsPerHousehold = 3;
  const beneficiariesPerHousehold = 2; 
  const batchSize = 250; // Smaller batch size to prevent UI jank

  print('Generating 100k HH, 300k Individuals, and 200k Beneficiaries...');

  // REMOVED: PRAGMA statements that were causing "database is locked" errors.
  // We will use the default database settings for stability.

  for (int i = 0; i < totalHouseholds; i += batchSize) {
    try {
      await db.batch((batch) {
        for (int j = i; j < i + batchSize && j < totalHouseholds; j++) {
          final householdRefId = uuid.v4();
          final hhLat = baseLat + (j * 0.00001);
          final hhLng = baseLng + (j * 0.00001);
          
          // 1. Create Household
          batch.insert(
            db.household,
            HouseholdCompanion.insert(
              clientReferenceId: householdRefId,
              tenantId: Value(tenantId),
              memberCount: const Value(individualsPerHousehold),
              clientCreatedTime: Value(now),
              clientCreatedBy: Value(auditUser),
              auditCreatedBy: Value(auditUser),
              auditCreatedTime: Value(now),
              rowVersion: const Value(1),
              isDeleted: const Value(false),
            ),
          );

          // 2. Household Address
          batch.insert(
            db.address,
            AddressCompanion.insert(
              relatedClientReferenceId: Value(householdRefId),
              localityBoundaryCode: Value(boundaryCode),
              latitude: Value(hhLat),
              longitude: Value(hhLng),
              tenantId: Value(tenantId),
              auditCreatedBy: Value(auditUser),
              auditCreatedTime: Value(now),
              clientCreatedTime: Value(now),
              clientCreatedBy: Value(auditUser),
              rowVersion: const Value(1),
              isDeleted: const Value(false),
            ),
          );

          // 3. Create Individuals per Household
          for (int k = 0; k < individualsPerHousehold; k++) {
            final individualRefId = uuid.v4();
            final identifierUuid = uuid.v4();
            final givenName = 'User_${j}_$k';
            final familyName = 'Family_$j';
            final isHead = (k == 0);

            // Individual record
            batch.insert(
              db.individual,
              IndividualCompanion.insert(
                clientReferenceId: individualRefId,
                tenantId: Value(tenantId),
                clientCreatedTime: Value(now),
                clientCreatedBy: Value(auditUser),
                auditCreatedBy: Value(auditUser),
                auditCreatedTime: Value(now),
                rowVersion: const Value(1),
                isDeleted: const Value(false),
              ),
            );

            // Name record
            batch.insert(
              db.name,
              NameCompanion.insert(
                individualClientReferenceId: Value(individualRefId),
                givenName: Value(givenName),
                familyName: Value(familyName),
                tenantId: Value(tenantId),
                auditCreatedBy: Value(auditUser),
                auditCreatedTime: Value(now),
                clientCreatedTime: Value(now),
                clientCreatedBy: Value(auditUser),
                rowVersion: const Value(1),
                isDeleted: const Value(false),
              ),
            );

            // Identifier record
            batch.insert(
              db.identifier,
              IdentifierCompanion.insert(
                clientReferenceId: uuid.v4(),
                individualClientReferenceId: individualRefId,
                identifierType: const Value('DEFAULT'),
                identifierId: Value(identifierUuid),
                tenantId: Value(tenantId),
                auditCreatedBy: Value(auditUser),
                auditCreatedTime: Value(now),
                clientCreatedTime: Value(now),
                clientCreatedBy: Value(auditUser),
                rowVersion: const Value(1),
                isDeleted: const Value(false),
              ),
            );

            // Member link
            batch.insert(
              db.householdMember,
              HouseholdMemberCompanion.insert(
                clientReferenceId: uuid.v4(),
                householdClientReferenceId: Value(householdRefId),
                individualClientReferenceId: Value(individualRefId),
                isHeadOfHousehold: isHead,
                tenantId: Value(tenantId),
                auditCreatedBy: Value(auditUser),
                auditCreatedTime: Value(now),
                clientCreatedTime: Value(now),
                clientCreatedBy: Value(auditUser),
                rowVersion: const Value(1),
                isDeleted: const Value(false),
              ),
            );

            // BeneficiaryInfo (Denormalized Search Index)
            batch.insert(
              db.beneficiaryInfo,
              BeneficiaryInfoCompanion.insert(
                clientReferenceId: individualRefId,
                householdClientReferenceId: householdRefId,
                givenName: Value(givenName),
                identifierType: const Value('DEFAULT'),
                identifierId: Value(identifierUuid),
                isHead: Value(isHead),
                latitude: Value(hhLat),
                longitude: Value(hhLng),
                tenantId: Value(tenantId),
                auditCreatedBy: Value(auditUser),
                auditCreatedTime: Value(now),
                clientCreatedTime: Value(now),
                clientCreatedBy: Value(auditUser),
                rowVersion: const Value(1),
                isDeleted: const Value(false),
              ),
            );

            // 4. Project Beneficiary
            if (k < beneficiariesPerHousehold) {
              batch.insert(
                db.projectBeneficiary,
                ProjectBeneficiaryCompanion.insert(
                  clientReferenceId: uuid.v4(),
                  projectId: Value(projectId),
                  beneficiaryClientReferenceId: Value(individualRefId),
                  dateOfRegistration: now,
                  tenantId: Value(tenantId),
                  auditCreatedBy: Value(auditUser),
                  auditCreatedTime: Value(now),
                  clientCreatedTime: Value(now),
                  clientCreatedBy: Value(auditUser),
                  rowVersion: const Value(1),
                  isDeleted: const Value(false),
                ),
              );
            }
          }
        }
      });
      if (i % 2500 == 0) print('Inserted $i households...');
    } catch (e) {
      print('Error in batch $i: $e');
      // Continue to next batch instead of crashing the whole process
    }
  }
  print('Success! Population complete.');
}
