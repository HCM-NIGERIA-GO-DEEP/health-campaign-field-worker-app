/// The household record carries a copy of its head's details.
///
/// Liberia CR (2026-11-27): reports read the head's name, phone and gender
/// from the Household itself. They live on the head's Individual, so
/// CREATE_EVENT and UPDATE_EVENT copy them onto the Household that is saved
/// in the same batch ([withHouseholdHeadDetails]). Reading them from the
/// record being saved keeps the copy right on every create and edit path,
/// whichever form or config built the records.
///
/// The keys are the ones the delivery task already uses for the same values.
library;

import 'package:digit_data_model/data_model.dart';
import 'package:flutter/foundation.dart';

const headNameKey = 'headName';
const headMobileNumberKey = 'headMobileNumber';
const headGenderKey = 'headGender';
const headIndividualClientReferenceIdKey = 'headIndividualClientReferenceId';

/// [batch] (the records one CREATE_EVENT or UPDATE_EVENT is about to save)
/// with the head's details copied onto its Household.
///
/// Copies only when the batch holds exactly one Household and exactly one
/// Individual, and no HouseholdMember in the batch says that individual is
/// not the head of that household. Every form that saves a Household
/// together with an Individual is a form about the head; a member's form
/// saves no Household, or saves it with the member's HouseholdMember record.
///
/// A detail the head does not have (no phone, no gender) is removed from the
/// Household, never saved empty. A value that changes keeps its place in the
/// list, so an unchanged household still compares equal to the stored one.
///
/// Returns [batch] itself when there is nothing to change, and never throws:
/// saving the records matters more than the copy.
List<EntityModel> withHouseholdHeadDetails(List<EntityModel> batch) {
  try {
    final households = batch.whereType<HouseholdModel>().toList();
    final individuals = batch.whereType<IndividualModel>().toList();
    if (households.length != 1 || individuals.length != 1) return batch;

    final household = households.single;
    final head = individuals.single;

    for (final member in batch.whereType<HouseholdMemberModel>()) {
      if (member.individualClientReferenceId != head.clientReferenceId) {
        continue;
      }
      if (!member.isHeadOfHousehold) return batch;
      final memberHousehold = member.householdClientReferenceId;
      if (memberHousehold != null &&
          memberHousehold != household.clientReferenceId) {
        return batch;
      }
    }

    final details = <String, String?>{
      headNameKey: [head.name?.givenName, head.name?.familyName]
          .map((part) => part?.trim() ?? '')
          .where((part) => part.isNotEmpty)
          .join(' '),
      headMobileNumberKey: head.mobileNumber?.trim(),
      headGenderKey: head.gender?.toValue().toString(),
      headIndividualClientReferenceIdKey: head.clientReferenceId,
    };

    final fields = <AdditionalField>[];
    final written = <String>{};
    var changed = false;
    for (final field in household.additionalFields?.fields ??
        const <AdditionalField>[]) {
      if (!details.containsKey(field.key)) {
        fields.add(field);
        continue;
      }
      final value = details[field.key];
      if (value == null || value.isEmpty || !written.add(field.key)) {
        changed = true;
        continue;
      }
      if (field.value != value) changed = true;
      fields.add(field.value == value ? field : AdditionalField(field.key, value));
    }
    details.forEach((key, value) {
      if (value == null || value.isEmpty || written.contains(key)) return;
      fields.add(AdditionalField(key, value));
      changed = true;
    });
    if (!changed) return batch;

    final stamped = household.copyWith(
      additionalFields: HouseholdAdditionalFields(
        version: household.additionalFields?.version ?? 1,
        fields: fields,
      ),
    );
    return [
      for (final entity in batch) identical(entity, household) ? stamped : entity,
    ];
  } catch (e) {
    debugPrint('Could not copy the head\'s details to the household: $e');
    return batch;
  }
}
