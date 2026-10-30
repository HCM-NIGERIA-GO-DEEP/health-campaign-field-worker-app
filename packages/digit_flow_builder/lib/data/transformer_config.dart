final jsonConfig = {
  "beneficiaryRegistration": {
    "fallbackModel": "HouseholdModel",
    // fallback model to map form values which are not mapped to any field
    "models": {
      "HouseholdModel": {
        "mappings": {
          "id": "householdDetails.id",
          "memberCount": "householdDetails.memberCount",
          "latitude": "beneficiaryLocation.latLng[0]",
          "longitude": "beneficiaryLocation.latLng[1]",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId":
                "__ref:HouseholdModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "beneficiaryLocation.latLng[0]",
            "longitude": "beneficiaryLocation.latLng[1]",
            "locationAccuracy": "beneficiaryLocation.latLng[2]",
            "addressLine1": "beneficiaryLocation.addressLine1",
            "addressLine2": "addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "type": "__value:PERMANENT",
            "boundaryType": "address.boundaryType",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
            },
            "boundary": "address.boundary",
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "householdType": "__context:householdType",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "additionalFields": {
            "childrenCount": "householdDetails.childrenCount",
            "pregnantWomenCount": "householdDetails.pregnantWomenCount",
            "memberCount": "householdDetails.memberCount",
            "caregiverConsent": "caregiverConsent.consentToParticipate",
            "ACTION1": "registrationHealthTalkChecklist.ACTION1",
            "ACTION2": "registrationHealthTalkChecklist.ACTION2",
            "ACTION3": "registrationHealthTalkChecklist.ACTION3",
            "ACTION4": "registrationHealthTalkChecklist.ACTION4",
            "ACTION5": "registrationHealthTalkChecklist.ACTION5",
            "ACTION6": "registrationHealthTalkChecklist.ACTION6",
            "ACTION7": "registrationHealthTalkChecklist.ACTION7",
            "ACTION8": "registrationHealthTalkChecklist.ACTION8",
            "ACTION9": "registrationHealthTalkChecklist.ACTION9",
            "ACTION10": "registrationHealthTalkChecklist.ACTION10",
            "ACTION11": "registrationHealthTalkChecklist.ACTION11"
          }
        }
      },
      "IndividualModel": {
        "mappings": {
          "id": "householdDetails.id",
          "individualId": "householdDetails.individualId",
          "userId": "householdDetails.userId",
          "dateOfBirth": "beneficiaryDetails.dobPicker",
          "mobileNumber": "householdDetails.phone",
          "altContactNumber": "contactInfo.altContact",
          "email": "contactInfo.email",
          "fatherName": "family.fatherName",
          "husbandName": "family.husbandName",
          "photo": "personalDetails.photo",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "name": {
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            "givenName": "householdDetails.nameOfIndividual",
            "familyName": "householdDetails.familyname",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
            "additionalFields": {"lastName": "householdDetails.lastName"}
          },
          "additionalFields": {
            "weight": "beneficiaryDetails.weight",
            "height": "beneficiaryDetails.height",
            "isPregnant": "beneficiaryDetails.isPregnant",
            "lastName": "householdDetails.lastName"
          },
          "bloodGroup": "health.bloodGroup",
          "gender": "householdDetails.gender",
          "address": "list:AddressModel",
          "identifiers": "list:IdentifierModel",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "boundaryCode": "__context:boundary.code",
        },
        "listMappings": {
          "IdentifierModel": {
            // listSource points at extraContext['identifierEntries'], built in
            // transformer_executor.dart from (1) the existing hidden
            // "identifiers" idPopulator field (unchanged Beneficiary ID
            // capture) and (2) the new identificationType/identificationNumber
            // fields, when both are filled in. Each entry is a
            // {identifierType, identifierId} map, so the mappings below read
            // plain keys off that per-item map rather than the old
            // "householdDetails.identifiers[0]/[1]" comma-split of a single
            // combined string.
            "listSource": "__context:identifierEntries",
            "mappings": {
              "id": "id",
              "identifierType": "identifierType",
              "identifierId": "identifierId",
              "boundaryCode": "__context:selectedBoundaryCode",
              "nonRecoverableError": "error.nonRecoverable",
              "individualClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "clientReferenceId": "__generate:uuid",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          },
          "AddressModel": {
            "mappings": {
              "id": "address.id",
              "boundaryCode": "__context:selectedBoundaryCode",
              "relatedClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "doorNo": "address.doorNo",
              "latitude": "beneficiaryLocation.latLng[0]",
              "longitude": "beneficiaryLocation.latLng[1]",
              "locationAccuracy": "beneficiaryLocation.latLng[2]",
              "addressLine1": "beneficiaryLocation.addressLine1",
              "addressLine2": "addressLine2",
              "landmark": "address.landmark",
              "city": "address.city",
              "type": "__value:PERMANENT",
              "pincode": "address.pincode",
              "buildingName": "address.buildingName",
              "street": "address.street",
              "boundaryType": "address.boundaryType",
              "locality": {
                "code": "__context:selectedBoundaryCode",
                "name": "__context:boundary.name",
                "nonRecoverableError": "address.nonRecoverable",
                "tenantId": "__context:tenantId",
                "rowVersion": "meta.rowVersion",
              },
              "boundary": "address.boundary",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      },
      "ProjectBeneficiaryModel": {
        "mappings": {
          "id": "beneficiaryDetails.id",
          "projectId": "__context:projectId",
          "tenantId": "__context:tenantId",
          "beneficiaryId": "beneficiaryDetails.beneficiaryId",
          "tag": "beneficiaryDetails.scanner",
          "beneficiaryClientReferenceId":
              "__switch:__context:beneficiaryType:{INDIVIDUAL:__ref:IndividualModel.clientReferenceId,HOUSEHOLD:__ref:HouseholdModel.clientReferenceId}",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "rowVersion": "meta.rowVersion",
          "dateOfRegistration": "householdDetails.dateOfRegistration",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "HouseholdMemberModel": {
        "mappings": {
          "id": "members.id",
          "householdId": "members.householdId",
          "householdClientReferenceId":
              "__ref:HouseholdModel.clientReferenceId",
          "individualId": "members.individualId",
          "individualClientReferenceId":
              "__ref:IndividualModel.clientReferenceId",
          "isHeadOfHousehold": "householdDetails.isHeadOfFamily",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "name":
                "__concatName:beneficiaryDetails.nameOfIndividual,beneficiaryDetails.familyname",
            "dateOfBirth": "beneficiaryDetails.dobPicker",
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            "beneficiaryId": "beneficiaryDetails.beneficiaryId"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
    }
  },
  // Bulk-creates one ProjectBeneficiaryModel per individual passed in
  // __context:individuals. Used by the search-page OPEN button when the row
  // has zero projectBeneficiaries: the household + individuals already exist
  // in the local store (downsynced), so we only need to mint the PB join rows
  // to enroll every member in the current project — no form, no second
  // registration. Implicit list-item context resolves the bare
  // "clientReferenceId" mapping against individuals[index].clientReferenceId
  // (see transformer_service.dart:882–916).
  "bulkProjectBeneficiaryFromMembers": {
    "models": {
      "ProjectBeneficiaryModel": {
        "listSource": "__context:individuals",
        "mappings": {
          "projectId": "__context:projectId",
          "tenantId": "__context:tenantId",
          "beneficiaryClientReferenceId": "clientReferenceId",
          "clientReferenceId": "__generate:uuid",
          "dateOfRegistration": "__value:DATETIME.NOW",
          "rowVersion": "meta.rowVersion",
          "auditDetails": "__generate:audit",
          "clientAuditDetails": "__generate:clientAudit",
        }
      }
    }
  },
  "householdConsentRegistration": {
    "fallbackModel": "HouseholdModel",
    "models": {
      "HouseholdModel": {
        "mappings": {
          "id": "housing.id",
          "memberCount": "householdDetails.memberCount",
          "latitude": "beneficiaryLocation.latLng[0]",
          "longitude": "beneficiaryLocation.latLng[1]",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId":
                "__ref:HouseholdModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "beneficiaryLocation.latLng[0]",
            "longitude": "beneficiaryLocation.latLng[1]",
            "locationAccuracy": "beneficiaryLocation.latLng[2]",
            "addressLine1": "beneficiaryLocation.addressLine1",
            "addressLine2": "addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "type": "__value:PERMANENT",
            "boundaryType": "address.boundaryType",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
            },
            "boundary": "address.boundary",
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "householdType": "__context:householdType",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "additionalFields": {
            "childrenCount": "householdDetails.childrenCount",
            "pregnantWomenCount": "householdDetails.pregnantWomenCount",
            "memberCount": "householdDetails.memberCount",
            "caregiverConsent": "caregiverConsent.consentToParticipate",
            "ACTION1": "registrationHealthTalkChecklist.ACTION1",
            "ACTION2": "registrationHealthTalkChecklist.ACTION2",
            "ACTION3": "registrationHealthTalkChecklist.ACTION3",
            "ACTION4": "registrationHealthTalkChecklist.ACTION4",
            "ACTION5": "registrationHealthTalkChecklist.ACTION5",
            "ACTION6": "registrationHealthTalkChecklist.ACTION6",
            "ACTION7": "registrationHealthTalkChecklist.ACTION7",
            "ACTION8": "registrationHealthTalkChecklist.ACTION8",
            "ACTION9": "registrationHealthTalkChecklist.ACTION9",
            "ACTION10": "registrationHealthTalkChecklist.ACTION10",
            "ACTION11": "registrationHealthTalkChecklist.ACTION11"
          }
        }
      }
    }
  },
  "individualRegistration": {
    "fallbackModel": "IndividualModel",
    // fallback model to map form values which are not mapped to any field
    "models": {
      "IndividualModel": {
        "mappings": {
          "id": "personalDetails.id",
          "individualId": "personalDetails.individualId",
          "userId": "personalDetails.userId",
          "userUuid": "personalDetails.uuid",
          "dateOfBirth": "beneficiaryDetails.dobPicker",
          "mobileNumber": "beneficiaryDetails.phone",
          "altContactNumber": "contactInfo.altContact",
          "email": "contactInfo.email",
          "fatherName": "family.fatherName",
          "husbandName": "family.husbandName",
          "photo": "personalDetails.photo",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "name": {
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            // This config drives the ADD_MEMBER flow, whose only page is
            // `beneficiaryDetails` - and form paths are `<pageName>.<field>`.
            // Pointing givenName at `householdDetails` (a page that flow does
            // not have) resolved to null in both directions: members synced
            // with no given name, their overview card rendered "--" for the
            // first name, and editing one left the name field blank because
            // the reverse mapper wrote the value back under the same
            // non-existent page key. Every sibling field here is already
            // `beneficiaryDetails.*`.
            "givenName": "beneficiaryDetails.nameOfIndividual",
            "familyName": "beneficiaryDetails.familyname",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "additionalFields": {
            "weight": "beneficiaryDetails.weight",
            "height": "beneficiaryDetails.height",
            "isPregnant": "beneficiaryDetails.isPregnant"
          },
          "bloodGroup": "health.bloodGroup",
          "gender": "beneficiaryDetails.gender",
          "address": "list:AddressModel",
          "identifiers": "list:IdentifierModel",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "boundaryCode": "__context:boundary.code",
        },
        "listMappings": {
          "IdentifierModel": {
            // See the matching comment in the beneficiaryRegistration config
            // above: listSource reads extraContext['identifierEntries'],
            // which preserves the existing hidden "identifiers" field's
            // behavior as entry 1 and adds the new
            // identificationType/identificationNumber pair as entry 2.
            "listSource": "__context:identifierEntries",
            "mappings": {
              "id": "id",
              "identifierType": "identifierType",
              "identifierId": "identifierId",
              "boundaryCode": "__context:selectedBoundaryCode",
              "nonRecoverableError": "error.nonRecoverable",
              "individualClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "clientReferenceId": "__generate:uuid",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          },
          "AddressModel": {
            "mappings": {
              "id": "address.id",
              "boundaryCode": "__context:selectedBoundaryCode",
              "relatedClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "doorNo": "address.doorNo",
              "latitude": "beneficiaryLocation.latLng[0]",
              "longitude": "beneficiaryLocation.latLng[1]",
              "locationAccuracy": "beneficiaryLocation.latLng[2]",
              "addressLine1": "beneficiaryLocation.addressLine1",
              "addressLine2": "addressLine2",
              "landmark": "address.landmark",
              "city": "address.city",
              "type": "__value:PERMANENT",
              "pincode": "address.pincode",
              "buildingName": "address.buildingName",
              "street": "address.street",
              "boundaryType": "address.boundaryType",
              "locality": {
                "code": "__context:selectedBoundaryCode",
                "name": "__context:boundary.name",
                "nonRecoverableError": "address.nonRecoverable",
                "tenantId": "__context:tenantId",
                "rowVersion": "meta.rowVersion",
              },
              "boundary": "address.boundary",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      },
      "ProjectBeneficiaryModel": {
        "mappings": {
          "id": "beneficiaryDetails.id",
          "projectId": "__context:projectId",
          "tenantId": "__context:tenantId",
          "beneficiaryId": "beneficiaryDetails.beneficiaryId",
          "tag": "beneficiaryDetails.scanner",
          "beneficiaryClientReferenceId":
              "__switch:__context:beneficiaryType:{INDIVIDUAL:__ref:IndividualModel.clientReferenceId,HOUSEHOLD:__context:HouseholdClientReferenceId}",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "rowVersion": "meta.rowVersion",
          "dateOfRegistration": "__value:DATETIME.NOW",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "HouseholdMemberModel": {
        "mappings": {
          "id": "members.id",
          "householdId": "members.householdId",
          "householdClientReferenceId": "__context:HouseholdClientReferenceId",
          "individualId": "members.individualId",
          "individualClientReferenceId":
              "__ref:IndividualModel.clientReferenceId",
          "isHeadOfHousehold": "__value:false",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "name":
                "__concatName:beneficiaryDetails.nameOfIndividual,beneficiaryDetails.familyname",
            "gender": "beneficiaryDetails.gender",
            "dateOfBirth": "beneficiaryDetails.dobPicker",
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            "beneficiaryId": "beneficiaryDetails.beneficiaryId"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
    }
  },
  "indirectBulkDelivery": {
    "models": {
      "TaskModel": {
        "listSource": "__context:futureDoses",
        "skipFirst": 0,
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__context:ProjectBeneficiaryClientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:DELIVERED",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "resources": "list:TaskResourceModel",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "DeliveryDetails.latLng[0]",
            "longitude": "DeliveryDetails.latLng[1]",
            "locationAccuracy": "DeliveryDetails.latLng[2]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": {
            "doseIndex": "__listItem:id",
            "cycleIndex": "__context:cycleIndex",
            "deliveryStrategy": "__listItem:deliveryStrategy",
            "householdClientReferenceId":
                "__context:HouseholdClientReferenceId",
            "memberCount": "__context:memberCount",
            "individualClientReferenceId":
                "__context:individualClientReferenceId",
            "beneficiaryId": "__context:beneficiaryId",
            "childName": "__context:childName",
            "ageInMonths": "__context:ageInMonths",
            "gender": "__context:gender",
            "headName": "__context:headName",
            "headMobileNumber": "__context:headMobileNumber"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        },
        "listMappings": {
          "TaskResourceModel": {
            // Mirror the direct delivery's resourceCard so future indirect doses
            // carry the same productVariantId as what was just administered
            // (e.g., SPAQ1 vs SPAQ2 by age) instead of a hardcoded doseCriteria[0].
            "listSource": "DeliveryDetails.resourceCard",
            "mappings": {
              "clientReferenceId": "__generate:uuid",
              "taskId": "taskId",
              "productVariantId":
                  "DeliveryDetails.resourceCard.resourceDelivered.productId",
              "quantity": "__value:1",
              "isDelivered": "__value:true",
              "deliveryComment": "DeliveryDetails.deliveryComment",
              "nonRecoverableError": "error.nonRecoverable",
              "taskclientReferenceId": "__ref:TaskModel.clientReferenceId",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit"
            }
          }
        }
      }
    }
  },
  "delivery": {
    "fallbackModel": "TaskModel",
    "models": {
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__context:ProjectBeneficiaryClientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:ADMINISTRATION_SUCCESS",
          // todo: need to update later for multiround campaign
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "resources": "list:TaskResourceModel",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "DeliveryDetails.latLng[0]",
            "longitude": "DeliveryDetails.latLng[1]",
            "locationAccuracy": "DeliveryDetails.latLng[2]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": {
            "doseIndex": "__context:doseIndex",
            "cycleIndex": "__context:cycleIndex",
            "deliveryStrategy": "__context:deliveryStrategy",
            "householdClientReferenceId":
                "__context:HouseholdClientReferenceId",
            "memberCount": "__context:memberCount",
            "individualClientReferenceId":
                "__context:individualClientReferenceId",
            "beneficiaryId": "__context:beneficiaryId",
            "childName": "__context:childName",
            "ageInMonths": "__context:ageInMonths",
            "gender": "__context:gender",
            "headName": "__context:headName",
            "headMobileNumber": "__context:headMobileNumber",

            /// Household/individual context carried onto the delivery task so
            /// a task row is self-describing in reports without re-joining to
            /// the household. Sourced from nav params set on the DELIVERY
            /// navigation, exactly the way memberCount/headName already are.
            "childrenCount": "__context:childrenCount",
            "pregnantWomenCount": "__context:pregnantWomenCount",
            "identificationType": "__context:identificationType",
            "identificationNumber": "__context:identificationNumber",

            /// Whether this household had already been delivered to when the
            /// task was raised. Computed by fn:isDelivered on the DELIVERY
            /// navigation - a task-status check, rather than inferring it from
            /// closed-household state, which conflates "not delivered yet"
            /// with "closed".
            "isDelivered": "__context:isDelivered",

            /// What was handed over. TaskResourceModel carries these per
            /// resource row; mirroring them on the task keeps the aggregate
            /// visible without expanding the resource list.
            "quantity": "DeliveryDetails.resourceCard.quantityDistributed",
            "productVariant":
                "DeliveryDetails.resourceCard.resourceDelivered.productId",

            /// When the delivery happened, and the boundary it happened in.
            "dateOfAdministration": "__value:DATETIME.NOW",
            "administrativeArea": "__context:boundary.name",

            /// One GS1 barcode per ITN handed over, captured by the scanner
            /// field on the DeliveryDetails page. TaskResourceModel carries
            /// only an aggregate quantity and has no per-unit column, so the
            /// serials live here instead - the same approach the stock flow
            /// already uses for its own "scanResource". additionalFields is
            /// serialised along with the rest of the task by the oplog, so
            /// this syncs without any change to sync_service.
            "scanResource": "DeliveryDetails.scanner",
            "ACTION1": "DeliveryChecklist.ACTION1",
            "ACTION2": "DeliveryChecklist.ACTION2",
            "ACTION3": "DeliveryChecklist.ACTION3",
            "ACTION4": "DeliveryChecklist.ACTION4",
            "ACTION5": "DeliveryChecklist.ACTION5",
            "ACTION6": "DeliveryChecklist.ACTION6",
            "ACTION7": "DeliveryChecklist.ACTION7",
            "ACTION8": "DeliveryChecklist.ACTION8",
            "ACTION9": "DeliveryChecklist.ACTION9",
            "ACTION10": "DeliveryChecklist.ACTION10",
            "ACTION11": "DeliveryChecklist.ACTION11"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        },
        "listMappings": {
          "TaskResourceModel": {
            "listSource": "DeliveryDetails.resourceCard",
            "mappings": {
              "id": "id",
              "clientReferenceId": "__generate:uuid",
              "taskId": "taskId",
              "productVariantId":
                  "DeliveryDetails.resourceCard.resourceDelivered.productId",
              "quantity": "DeliveryDetails.resourceCard.quantityDistributed",
              "isDelivered": "__value:true",
              "deliveryComment": "DeliveryDetails.deliveryComment",
              "nonRecoverableError": "error.nonRecoverable",
              "taskclientReferenceId": "__ref:TaskModel.clientReferenceId",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      }
    }
  },
  "ineligibleConfig": {
    "fallbackModel": "TaskModel",
    "models": {
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__context:ProjectBeneficiaryClientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:INELIGIBLE",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "address.latLng[0]",
            "longitude": "address.latLng[1]",
            "locationAccuracy": "address.latLng[1]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": {
            "doseIndex": "__context:doseIndex",
            "cycleIndex": "__context:cycleIndex",
            "householdClientReferenceId":
                "__context:HouseholdClientReferenceId",
            "memberCount": "__context:memberCount",
            "individualClientReferenceId":
                "__context:individualClientReferenceId",
            "beneficiaryId": "__context:beneficiaryId",
            "childName": "__context:childName",
            "ageInMonths": "__context:ageInMonths",
            "gender": "__context:gender",
            "headName": "__context:headName",
            "headMobileNumber": "__context:headMobileNumber"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  "unableToDeliverConfig": {
    "fallbackModel": "TaskModel",
    "models": {
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__context:ProjectBeneficiaryClientReferenceId",
          "createdBy": "__context:userId",
          "status": "unableToDeliver.reason",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "unableToDeliver.latLng[0]",
            "longitude": "unableToDeliver.latLng[1]",
            "locationAccuracy": "unableToDeliver.latLng[2]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": {
            "doseIndex": "__context:doseIndex",
            "cycleIndex": "__context:cycleIndex",
            "comment": "unableToDeliver.comment",
            "householdClientReferenceId":
                "__context:HouseholdClientReferenceId",
            "memberCount": "__context:memberCount",
            "individualClientReferenceId":
                "__context:individualClientReferenceId",
            "beneficiaryId": "__context:beneficiaryId",
            "childName": "__context:childName",
            "ageInMonths": "__context:ageInMonths",
            "gender": "__context:gender",
            "headName": "__context:headName",
            "headMobileNumber": "__context:headMobileNumber"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  "redose": {
    "fallbackModel": "TaskModel",
    "models": {
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__context:ProjectBeneficiaryClientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:VISITED",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "resources": "list:TaskResourceModel",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "__context:latitude",
            "longitude": "__context:longitude",
            "locationAccuracy": "__context:locationAccuracy",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": {
            "doseIndex": "__context:doseIndex",
            "cycleIndex": "__context:cycleIndex",
            "reasonForRedose": "RedoseDetails.reasonForRedose",
            "redoseComments": "RedoseDetails.redoseComments",
            "taskType": "__value:REDOSE",
            "householdClientReferenceId":
                "__context:HouseholdClientReferenceId",
            "memberCount": "__context:memberCount",
            "individualClientReferenceId":
                "__context:individualClientReferenceId",
            "beneficiaryId": "__context:beneficiaryId",
            "childName": "__context:childName",
            "ageInMonths": "__context:ageInMonths",
            "gender": "__context:gender",
            "headName": "__context:headName",
            "headMobileNumber": "__context:headMobileNumber"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        },
        "listMappings": {
          "TaskResourceModel": {
            "listSource": "RedoseDetails.resourceCard",
            "mappings": {
              "id": "id",
              "clientReferenceId": "__generate:uuid",
              "taskId": "taskId",
              "productVariantId":
                  "RedoseDetails.resourceCard.resourceDelivered.productId",
              "quantity": "RedoseDetails.resourceCard.quantityDistributed",
              "isDelivered": "__value:true",
              "deliveryComment": "__value:REDOSE",
              "nonRecoverableError": "error.nonRecoverable",
              "taskclientReferenceId": "__ref:TaskModel.clientReferenceId",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      }
    }
  },
  "stock": {
    "fallbackModel": "StockModel",
    "multiEntityField": "stockDetails.productdetail",
    "models": {
      "StockModel": {
        "mappings": {
          "id": "stockDetails.id",
          "clientReferenceId": "__generate:uuid",
          "facilityId": "warehouseDetails.facilityToWhich",
          "productVariantId": "stockDetails.productdetail.id",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "quantity":
              "__switch:__context:stockEntryType:{RECEIPT:stockProductDetails.quantityReceived,RETURNED:stockProductDetails.quantityReturned,ISSUED:stockProductDetails.quantitySent,DAMAGED:stockProductDetails.quantityDamaged,LOSS:stockProductDetails.quantityLost}",
          "wayBillNumber": "stockProductDetails.wayBillNumber",
          "transactionType": "__context:transactionType",
          "transactionReason":
              "__switch:__context:stockEntryType:{RECEIPT:__value:RECEIVED,RETURNED:__value:RETURNED,ISSUED:__value:ISSUED,DAMAGED:stockDetails.transactionReason,LOSS:stockDetails.transactionReason}",
          "transactingPartyId": "stockDetails.transactingPartyId",
          "senderId":
              "__switch:__context:senderPartyType:{STAFF:__context:loggedInUserUuid,default:stockDetails.facilityFromWhich}",
          "senderType":
              "__switch:__context:senderPartyType:{STAFF:__value:STAFF,default:__value:WAREHOUSE}",
          "receiverId":
              "__switch:__context:receiverPartyType:{STAFF:__context:teamCode,default:warehouseDetails.facilityToWhich}",
          "receiverType":
              "__switch:__context:receiverPartyType:{STAFF:__value:STAFF,default:__value:WAREHOUSE}",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "campaignNumber": "__context:selectedProject.referenceID",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "partial_flow": "__value:false",
            "sku": "stockDetails.productdetail.sku",
            "batchNumber": "stockProductDetails.batchNumber",
            "expiryDate": "stockProductDetails.expiryDate",
            "comments": "__context.comment",
            "transportType": "stockDetails.transportType",
            "vehicle_number": "stockDetails.vehicleNumber",
            "deliveryTeam": "stockDetails.deliveryTeam",
            "deliveryTeamName": "__context:deliveryTeamName",
            "wayBillNumber": "stockProductDetails.wayBillNumber",
            "mrnNumber": "__context:mrnNumber",
            "stockEntryType": "__context:stockEntryType",
            "primaryRole": "__context:primaryRole",
            "secondaryRole": "__context:secondaryRole",
            // A __switch with no matching case and no `default` throws, and
            // mapFormToEntities aborts the whole model on a throw - so a
            // RECEIPT (the only stockEntryType absent here) produced no
            // StockModel at all. The executor's multi-entity branch swallows
            // that exception, so receiving stock looked like it succeeded:
            // the MRN was issued and the success screen shown, with nothing
            // written. What RECEIPT must not resolve to is IN_TRANSIT - that
            // is what the incomingTransactions query filters on, and received
            // stock has by definition already arrived.
            "status":
                "__switch:__context:stockEntryType:{ISSUED:__value:IN_TRANSIT,RETURNED:__value:IN_TRANSIT,LOSS:__value:LOST,DAMAGED:__value:DAMAGED,default:__value:RECEIVED}",
            "scanResource": "stockProductDetails.scanResource",
            "quantityWastage": "stockProductDetails.quantityWastage",
            "quantityPartialUsed": "stockProductDetails.quantityPartialUsed"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "dateOfEntry": "warehouseDetails.dateOfEntry"
        }
      },
    }
  },
  "stockReceipt": {
    "fallbackModel": "StockModel",
    "models": {
      "StockModel": {
        "mappings": {
          "id": "stockReceiptDetails.id",
          "clientReferenceId": "__generate:uuid",
          "facilityId": "__context:userFacilityId",
          "productVariantId": "__context:productVariantId",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "quantity": "__context:quantity",
          "wayBillNumber": "stockReceiptDetails.wayBillNumber",
          "transactionType": "__context:transactionType",
          "transactionReason": "__value:RECEIVED",
          "campaignNumber": "__context:selectedProject.referenceID",
          "senderId": "__context:senderFacilityId",
          "senderType": "__switch:__context:senderPartyType:{STAFF:__value:STAFF,default:__value:WAREHOUSE}",
          "receiverId": "__context:userFacilityId",
          "receiverType": "__switch:__context:receiverPartyType:{STAFF:__value:STAFF,default:__value:WAREHOUSE}",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "partial_flow": "__context:partial_flow",
            "sku": "__context:sku",
            "deliveryTeamName": "__context:receivedFromName",
            "batchNumber": "stockReceiptDetails.batchNumber",
            "expiryDate": "stockReceiptDetails.expiryDate",
            "comments": "__context.comment",
            "transportType": "__context:transportType",
            "vehicle_number": "__context:vehicleNumber",
            "mrnNumber": "__context:mrnNumber",
            "wayBillNumber": "stockReceiptDetails.wayBillNumber",
            "stockEntryType": "__context:stockEntryType",
            "primaryRole": "__context:primaryRole",
            "secondaryRole": "__context:secondaryRole"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "dateOfEntry": "__value:DATETIME.NOW"
        }
      },
    }
  },
  "stockReject": {
    "fallbackModel": "StockModel",
    "models": {
      "StockModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid",
          "facilityId": "__context:userFacilityId",
          "productVariantId": "__context:productVariantId",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "quantity": "__context:quantity",
          "campaignNumber": "__context:selectedProject.referenceID",
          "wayBillNumber": "stockReceiptDetails.wayBillNumber",
          "transactionType": "__value:DISPATCHED",
          "transactionReason": "__value:null",
          "senderId": "__context:senderFacilityId",
          "senderType": "__value:WAREHOUSE",
          "receiverId": "__context:receiverFacilityId",
          "receiverType": "__value:WAREHOUSE",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "partial_flow": "__value:false",
            "sku": "__context:sku",
            "batchNumber": "stockReceiptDetails.batchNumber",
            "expiryDate": "stockReceiptDetails.expiryDate",
            "comments": "__context:comment",
            "mrnNumber": "__context:mrnNumber",
            "stockEntryType": "__context:stockEntryType",
            "primaryRole": "__context:primaryRole",
            "secondaryRole": "__context:secondaryRole"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "dateOfEntry": "__value:DATETIME.NOW"
        }
      },
    }
  },
  // Shortfall Return / Reissue (Accept/Partial Accept PRD, Phase 2). Serves
  // TWO call sites that share the same shape - sender/receiver swapped,
  // context-driven, needs the dispatch to surface in the other side's
  // incomingTransactions:
  //   1. Partial Accept on stockReceiptDetails creates the Shortfall Return
  //      itself (stockEntryType: RETURNED) sending the shortfall back to the
  //      original sender.
  //   2. Accepting that return as "stock in transit / miscount" creates a
  //      brand-new dispatch (stockEntryType: ISSUED) re-sending the same
  //      quantity on to the original receiver - a genuine new dispatch, not
  //      a return, so stockEntryType is passed per call site rather than
  //      hardcoded.
  // Cloned from stockReject (which was unused - a leftover from before
  // "Reject" was retired) with two additions: "status":IN_TRANSIT, which is
  // what incomingTransactions filters on - without it neither call site's
  // transaction would ever surface for the other side to resolve - and
  // originalIssueClientReferenceId, a durable link back to the original
  // dispatch, used by reconciliation to roll a dispatch -> return -> reissue
  // chain up to one line instead of double-counting it as a fresh
  // allocation. stockEntryType is passed as RETURNED or ISSUED (not a new
  // enum value) so stock_balance_executor.dart's existing branches for both
  // apply unchanged - introducing a new stockEntryType would need
  // balance-calculation changes too. Waybill, batch, transport, and vehicle
  // details are copied from the original dispatch so the shortfall/reissue
  // remains traceable to the shipment that produced it.
  "shortfallTransaction": {
    // Only the explicit movement fields belong to a new row. Unmapped popup
    // values (for example the parent's actualQuantityReceived) must not leak.
    "models": {
      "StockModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid",
          "facilityId": "__context:userFacilityId",
          "productVariantId": "__context:productVariantId",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "quantity": "__context:quantity",
          "campaignNumber": "__context:selectedProject.referenceID",
          "wayBillNumber": "__context:wayBillNumber",
          "transactionType": "__value:DISPATCHED",
          // This config builds BOTH halves of the shortfall lifecycle: the
          // RETURNED record a lower level sends back after a partial accept,
          // and the ISSUED re-issue an upper level sends down to replace it.
          //
          // The Stock Returned report filters on transactionReason RETURNED
          // (see getReportTransactionReasonFilter), so leaving this null for
          // every shortfall meant a returned shortfall never appeared there -
          // it was only ever visible through View Transactions, which filters
          // on the MRN alone. The re-issue half must stay null: it is a fresh
          // dispatch, and the Stock Issued report does not filter on reason.
          "transactionReason":
              "__switch:__context:stockEntryType:{RETURNED:__value:RETURNED,default:__value:null}",
          "senderId": "__context:senderFacilityId",
          "senderType": "__context:senderPartyType",
          "receiverId": "__context:receiverFacilityId",
          "receiverType": "__context:receiverPartyType",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "partial_flow": "__value:true",
            "sku": "__context:sku",
            "batchNumber": "__context:batchNumber",
            "transportType": "__context:transportType",
            "vehicle_number": "__context:vehicleNumber",
            "expiryDate": "stockReceiptDetails.expiryDate",
            "comments": "__context:comment",
            "mrnNumber": "__context:mrnNumber",
            "stockEntryType": "__context:stockEntryType",
            "status": "__value:IN_TRANSIT",
            "originalIssueClientReferenceId":
                "__context:originalIssueClientReferenceId",
            "discrepancyReason": "__context:discrepancyReason",
            "wayBillNumber": "__context:wayBillNumber",
            "primaryRole": "__context:primaryRole",
            "secondaryRole": "__context:secondaryRole"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "dateOfEntry": "__value:DATETIME.NOW"
        }
      },
    }
  },
  "stockLessExcess": {
    "fallbackModel": "StockModel",
    "models": {
      "StockModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid",
          "facilityId": "warehouseDetails.facilityToWhich",
          "productVariantId": "lessExcessDetails.productVariant.id",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "quantity": "lessExcessDetails.quantity",
          // Without this the Waybill Number column on the Loss/Excess View
          // Reports detail table had no source at all - neither
          // StockModel.wayBillNumber nor additionalFields.wayBillNumber was
          // ever written, so getWayBillNumber fell through both arguments
          // and returned '' for every row.
          "wayBillNumber": "lessExcessDetails.wayBillNumber",
          "campaignNumber": "__context:selectedProject.referenceID",
          "transactionType":
              "__switch:__context:stockEntryType:{LESS:__value:DISPATCHED,default:__value:RECEIVED}",
          // The user-entered explanation is stored in adjustmentReason below.
          // transactionReason is reserved for system transaction codes.
          "transactionReason":
              "__switch:__context:stockEntryType:{LESS:__value:null,default:__value:RECEIVED}",
          "senderId": "__context:senderId",
          "senderType": "__context:senderType",
          "receiverId": "__context:receiverId",
          "receiverType": "__context:receiverType",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "partial_flow": "__value:false",
            "sku": "lessExcessDetails.productVariant.sku",
            "mrnNumber": "__context:mrnNumber",
            "stockEntryType": "__context:stockEntryType",
            // Give standalone adjustments the same lifecycle status field as
            // other stock writes: loss is terminal, excess is received.
            "status":
                "__switch:__context:stockEntryType:{LESS:__value:LOST,default:__value:RECEIVED}",
            "adjustmentReason": "lessExcessDetails.reasonForLessExcess",
            // Mirrored into additionalFields as well as onto the top-level
            // StockModel columns. The server does not always echo
            // wayBillNumber (and quantity) back on a sync-down, so a record
            // that round-trips can come back with the top-level column null
            // while additionalFields survives intact - which is why
            // getWayBillNumber takes the top-level value AND the
            // additionalFields copy as its two arguments. Writing both gives
            // every report row a source that survives the round trip.
            "wayBillNumber": "lessExcessDetails.wayBillNumber",
            "quantity": "lessExcessDetails.quantity"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "dateOfEntry": "warehouseDetails.dateOfEntry"
        }
      }
    }
  },
  "stockReconciliation": {
    "fallbackModel": "StockReconciliationModel",
    "models": {
      "StockReconciliationModel": {
        "mappings": {
          "id": "stockRecon.id",
          "clientReferenceId": "__generate:uuid",
          "facilityId": "stockRecon.stockReconciliationCard.facilityId",
          "productVariantId":
              "stockRecon.stockReconciliationCard.productVariantId",
          "referenceId": "__context:projectId",
          "referenceIdType": "__value:PROJECT",
          "physicalCount": "stockRecon.manualCount",
          "calculatedCount":
              "stockRecon.stockReconciliationCard.stockMetrics.stockInHand",
          "commentsOnReconciliation": "stockRecon.comments",
          "dateOfReconciliation": "__value:DATETIME.NOW",
          "nonRecoverableError": "errors.nonRecoverable",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": {
            "stockReceived":
                "stockRecon.stockReconciliationCard.stockMetrics.stockReceived",
            "stockIssued":
                "stockRecon.stockReconciliationCard.stockMetrics.stockIssued",
            "stockReturned":
                "stockRecon.stockReconciliationCard.stockMetrics.stockReturned",
            "stockLost":
                "stockRecon.stockReconciliationCard.stockMetrics.stockLost",
            "stockDamaged":
                "stockRecon.stockReconciliationCard.stockMetrics.stockDamaged",
            "stockExcess":
                "stockRecon.stockReconciliationCard.stockMetrics.stockExcess",
            "stockLess":
                "stockRecon.stockReconciliationCard.stockMetrics.stockLess",
            // Persisted so the reconciliation REPORT can repeat the
            // breakdown the card shows. Without these the report lists Stock
            // Lost / Stock Damaged in full and cannot be reconciled against
            // stockInHand by hand.
            "reportedLostShortfall":
                "stockRecon.stockReconciliationCard.stockMetrics.reportedLostShortfall",
            "reportedDamagedShortfall":
                "stockRecon.stockReconciliationCard.stockMetrics.reportedDamagedShortfall",
            "lowerFacilityLostShortfall":
                "stockRecon.stockReconciliationCard.stockMetrics.lowerFacilityLostShortfall",
            "lowerFacilityDamagedShortfall":
                "stockRecon.stockReconciliationCard.stockMetrics.lowerFacilityDamagedShortfall",
            "stockInHand":
                "stockRecon.stockReconciliationCard.stockMetrics.stockInHand"
          },
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      }
    }
  },
  "complaintRegistration": {
    "fallbackModel": "PgrServiceModel",
    "models": {
      "PgrServiceModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid", // referenceId in code
          "tenantId": "__context:tenantId",
          "serviceCode": "complaintType.complaintType",
          "description": "complaintDetails.complaintDescription",
          "source": "__value:mobile",
          "applicationStatus": "__value:CREATED",
          "user": {
            "tenantId": "__context:tenantId",
            "clientReferenceId": "__generate:uuid",
            "complaintClientReferenceId":
                "__ref:PgrServiceModel.clientReferenceId",
            "name": "complaintDetails.name",
            "mobileNumber": "complaintDetails.contactNumber",
            "auditDetails": "__generate:audit",
            "clientAuditDetails": "__generate:clientAudit",
            "uuid": "__context:userId",
            "userName": "__context:userId",
            "type": "__value:EMPLOYEE"
          },
          "address": {
            "relatedClientReferenceId":
                "__ref:PgrServiceModel.clientReferenceId",
            "addressLine1": "locationDetails.addressLine1",
            "addressLine2": "locationDetails.addressLine2",
            "landmark": "locationDetails.landmark",
            "pincode": "locationDetails.pincode",
            "type": "locationDetails.typeOfAddress",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:selectedBoundaryName",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "auditDetails": "__generate:audit",
          "additionalDetail": {
            "supervisorName": "complaintDetails.supervisorName",
            "supervisorContactNumber":
                "complaintDetails.supervisorContactNumber",
            "otherComplaintDescription": "complaintType.otherReason"
          },
          "clientAuditDetails": "__generate:clientAudit"
        }
      }
    }
  },
  "closeHouseholdRegistration": {
    "fallbackModel": "HouseholdModel",
    // fallback model to map form values which are not mapped to any field
    "models": {
      "HouseholdModel": {
        "mappings": {
          "id": "housing.id",
          "memberCount": "__value: 1",
          "latitude": "closeHouseholdDetails.latLng[0]",
          "longitude": "closeHouseholdDetails.latLng[1]",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId":
                "__ref:HouseholdModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "closeHouseholdDetails.latLng[0]",
            "longitude": "closeHouseholdDetails.latLng[1]",
            "locationAccuracy": "closeHouseholdDetails.latLng[2]",
            "addressLine1": "beneficiaryLocation.addressLine1",
            "addressLine2": "addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "type": "__value:PERMANENT",
            "boundaryType": "address.boundaryType",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
            },
            "boundary": "address.boundary",
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "householdType": "__context:householdType",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "additionalFields": {"date": "closeHouseholdDetails.date"}
        }
      },
      "IndividualModel": {
        "mappings": {
          "id": "personalDetails.id",
          "individualId": "personalDetails.individualId",
          "userId": "personalDetails.userId",
          "userUuid": "personalDetails.uuid",
          "altContactNumber": "contactInfo.altContact",
          "email": "contactInfo.email",
          "fatherName": "family.fatherName",
          "husbandName": "family.husbandName",
          "photo": "personalDetails.photo",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "name": {
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            "givenName": "closeHouseholdDetails.headName",
            "familyName": "closeHouseholdDetails.familyname",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
            "additionalFields": {"lastName": "closeHouseholdDetails.lastName"},
          },
          "bloodGroup": "health.bloodGroup",
          "gender": "beneficiaryDetails.gender",
          "address": "list:AddressModel",
          "identifiers": "list:IdentifierModel",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "boundaryCode": "__context:boundary.code",
        },
        "listMappings": {
          "IdentifierModel": {
            "mappings": {
              "id": "id",
              // Still a hard-coded DEFAULT + uuid, so a closed household shows
              // a 36-char uuid on the search card where a normally-registered
              // one shows its short Beneficiary ID.
              //
              // Switching this to the registration configs'
              // "listSource": "__context:identifierEntries" is necessary but
              // NOT sufficient: the hidden `identifiers` idPopulator it would
              // read is built from `availableIDs` during the first form build,
              // while LOAD_UNIQUE_ID_POOL only runs in a post-frame callback
              // afterwards - so the form has already settled on DEFAULT by the
              // time the pool id exists, and the mapping faithfully carries
              // that DEFAULT through. The id has to be resolved after the pool
              // load (e.g. at submit time off __context:latestBeneficiaryId)
              // before this mapping is worth changing.
              "identifierType": "__value:DEFAULT",
              "identifierId": "__generate:uuid",

              // "identifierType": "closeHouseholdDetails.identifiers[0]",
              // "identifierId": "closeHouseholdDetails.identifiers[1]",

              // "identifierType": "__value:UNIQUE_BENEFICIARY_ID",
              // "identifierId": "__context:latestBeneficiaryId[1]",

              "boundaryCode": "__context:selectedBoundaryCode",
              "nonRecoverableError": "error.nonRecoverable",
              "individualClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "clientReferenceId": "__generate:uuid",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          },
          "AddressModel": {
            "mappings": {
              "id": "address.id",
              "boundaryCode": "__context:selectedBoundaryCode",
              "relatedClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "doorNo": "address.doorNo",
              "latitude": "closeHouseholdDetails.latLng[0]",
              "longitude": "closeHouseholdDetails.latLng[1]",
              "locationAccuracy": "closeHouseholdDetails.latLng[2]",
              "addressLine1": "beneficiaryLocation.addressLine1",
              "addressLine2": "addressLine2",
              "landmark": "address.landmark",
              "city": "address.city",
              "type": "__value:PERMANENT",
              "pincode": "address.pincode",
              "buildingName": "address.buildingName",
              "street": "address.street",
              "boundaryType": "address.boundaryType",
              "locality": {
                "code": "__context:selectedBoundaryCode",
                "name": "__context:boundary.name",
                "nonRecoverableError": "address.nonRecoverable",
                "tenantId": "__context:tenantId",
                "rowVersion": "meta.rowVersion",
              },
              "boundary": "address.boundary",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      },
      "ProjectBeneficiaryModel": {
        "mappings": {
          "id": "beneficiaryDetails.id",
          "projectId": "__context:projectId",
          "tenantId": "__context:tenantId",
          "beneficiaryId": "beneficiaryDetails.beneficiaryId",
          "tag": "closeHouseholdDetails.scanner",
          "beneficiaryClientReferenceId":
              "__switch:__context:beneficiaryType:{INDIVIDUAL:__ref:IndividualModel.clientReferenceId,HOUSEHOLD:__ref:HouseholdModel.clientReferenceId}",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "rowVersion": "meta.rowVersion",
          "dateOfRegistration": "__value:DATETIME.NOW",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "HouseholdMemberModel": {
        "mappings": {
          "id": "members.id",
          "householdId": "members.householdId",
          "householdClientReferenceId":
              "__ref:HouseholdModel.clientReferenceId",
          "individualId": "members.individualId",
          "individualClientReferenceId":
              "__ref:IndividualModel.clientReferenceId",
          "isHeadOfHousehold": "__value: true",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",

          /// Note: Generate uuid
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__ref:ProjectBeneficiaryModel.clientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:CLOSED_HOUSEHOLD",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "closeHouseholdDetails.latLng[0]",
            "longitude": "closeHouseholdDetails.latLng[1]",
            "locationAccuracy": "closeHouseholdDetails.latLng[2]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  // Entity shape copied from "closeHouseholdRegistration" above (same complete
  // set: Household/Individual placeholder/Identifier placeholder/Address/
  // HouseholdMember/ProjectBeneficiary/Task with status CLOSED_HOUSEHOLD), so
  // a declined-consent household is never left without the entities the
  // isEdit reopen path already expects to find and update. Sourced from our
  // own "beneficiaryLocation"/"caregiverConsent" pages instead of
  // CLOSEHOUSEHOLD.json's "closeHouseholdDetails" page. givenName/familyName
  // come from caregiverConsent's own (optional) nameOfIndividual/familyname
  // fields - same opportunistic capture Closed Household already does via
  // headName/familyname, so a name isn't lost just because consent was
  // declined before the full registration interview happened.
  "householdConsentDeclinedRegistration": {
    "fallbackModel": "HouseholdModel",
    "models": {
      "HouseholdModel": {
        "mappings": {
          "id": "housing.id",
          "memberCount": "__value: 1",
          "latitude": "beneficiaryLocation.latLng[0]",
          "longitude": "beneficiaryLocation.latLng[1]",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId":
                "__ref:HouseholdModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "beneficiaryLocation.latLng[0]",
            "longitude": "beneficiaryLocation.latLng[1]",
            "locationAccuracy": "beneficiaryLocation.latLng[2]",
            "addressLine1": "beneficiaryLocation.addressLine1",
            "addressLine2": "addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "type": "__value:PERMANENT",
            "boundaryType": "address.boundaryType",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
            },
            "boundary": "address.boundary",
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "householdType": "__context:householdType",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "additionalFields": {
            "caregiverConsent": "caregiverConsent.consentToParticipate"
          }
        }
      },
      "IndividualModel": {
        "mappings": {
          "id": "personalDetails.id",
          "individualId": "personalDetails.individualId",
          "userId": "personalDetails.userId",
          "userUuid": "personalDetails.uuid",
          "altContactNumber": "contactInfo.altContact",
          "email": "contactInfo.email",
          "fatherName": "family.fatherName",
          "husbandName": "family.husbandName",
          "photo": "personalDetails.photo",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "name": {
            "individualClientReferenceId":
                "__ref:IndividualModel.clientReferenceId",
            // Optional on this page (no full registration interview happens
            // before consent) - caregiverConsent.nameOfIndividual/familyname
            // are the same optional fields Closed Household's
            // headName/familyname already model this scenario with. Resolve
            // to null when left blank, same as before this field existed;
            // the full Registration flow's mandatory name fields are the
            // durable source once consent becomes Yes.
            "givenName": "caregiverConsent.nameOfIndividual",
            "familyName": "caregiverConsent.familyname",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit",
          },
          "bloodGroup": "health.bloodGroup",
          "gender": "beneficiaryDetails.gender",
          "address": "list:AddressModel",
          "identifiers": "list:IdentifierModel",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "boundaryCode": "__context:boundary.code",
        },
        "listMappings": {
          "IdentifierModel": {
            "mappings": {
              "id": "id",
              "identifierType": "__value:DEFAULT",
              "identifierId": "__generate:uuid",
              "boundaryCode": "__context:selectedBoundaryCode",
              "nonRecoverableError": "error.nonRecoverable",
              "individualClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "clientReferenceId": "__generate:uuid",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          },
          "AddressModel": {
            "mappings": {
              "id": "address.id",
              "boundaryCode": "__context:selectedBoundaryCode",
              "relatedClientReferenceId":
                  "__ref:IndividualModel.clientReferenceId",
              "doorNo": "address.doorNo",
              "latitude": "beneficiaryLocation.latLng[0]",
              "longitude": "beneficiaryLocation.latLng[1]",
              "locationAccuracy": "beneficiaryLocation.latLng[2]",
              "addressLine1": "beneficiaryLocation.addressLine1",
              "addressLine2": "addressLine2",
              "landmark": "address.landmark",
              "city": "address.city",
              "type": "__value:PERMANENT",
              "pincode": "address.pincode",
              "buildingName": "address.buildingName",
              "street": "address.street",
              "boundaryType": "address.boundaryType",
              "locality": {
                "code": "__context:selectedBoundaryCode",
                "name": "__context:boundary.name",
                "nonRecoverableError": "address.nonRecoverable",
                "tenantId": "__context:tenantId",
                "rowVersion": "meta.rowVersion",
              },
              "boundary": "address.boundary",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion",
              "clientAuditDetails": "__generate:clientAudit",
              "auditDetails": "__generate:audit",
            }
          }
        }
      },
      "ProjectBeneficiaryModel": {
        "mappings": {
          "id": "beneficiaryDetails.id",
          "projectId": "__context:projectId",
          "tenantId": "__context:tenantId",
          "beneficiaryId": "beneficiaryDetails.beneficiaryId",
          "beneficiaryClientReferenceId":
              "__switch:__context:beneficiaryType:{INDIVIDUAL:__ref:IndividualModel.clientReferenceId,HOUSEHOLD:__ref:HouseholdModel.clientReferenceId}",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "rowVersion": "meta.rowVersion",
          "dateOfRegistration": "__value:DATETIME.NOW",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "HouseholdMemberModel": {
        "mappings": {
          "id": "members.id",
          "householdId": "members.householdId",
          "householdClientReferenceId":
              "__ref:HouseholdModel.clientReferenceId",
          "individualId": "members.individualId",
          "individualClientReferenceId":
              "__ref:IndividualModel.clientReferenceId",
          "isHeadOfHousehold": "__value: true",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
        }
      },
      "TaskModel": {
        "mappings": {
          "id": "taskDetails.id",
          "projectId": "__context:projectId",
          "projectBeneficiaryId": "taskDetails.projectBeneficiaryId",
          "projectBeneficiaryClientReferenceId":
              "__ref:ProjectBeneficiaryModel.clientReferenceId",
          "createdBy": "__context:userId",
          "status": "__value:CLOSED_HOUSEHOLD",
          "nonRecoverableError": "errors.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "rowVersion": "meta.rowVersion",
          "plannedStartDate": "taskDetails.plannedStartDate",
          "plannedEndDate": "taskDetails.plannedEndDate",
          "actualStartDate": "taskDetails.actualStartDate",
          "actualEndDate": "taskDetails.actualEndDate",
          "createdDate": "__generate:timestamp",
          "address": {
            "id": "address.id",
            "relatedClientReferenceId": "__ref:TaskModel.clientReferenceId",
            "doorNo": "address.doorNo",
            "latitude": "beneficiaryLocation.latLng[0]",
            "longitude": "beneficiaryLocation.latLng[1]",
            "locationAccuracy": "beneficiaryLocation.latLng[2]",
            "addressLine1": "address.addressLine1",
            "addressLine2": "address.addressLine2",
            "landmark": "address.landmark",
            "city": "address.city",
            "type": "__value:PERMANENT",
            "pincode": "address.pincode",
            "buildingName": "address.buildingName",
            "street": "address.street",
            "boundaryType": "address.boundaryType",
            "boundary": "address.boundary",
            "locality": {
              "code": "__context:selectedBoundaryCode",
              "name": "__context:boundary.name",
              "nonRecoverableError": "address.nonRecoverable",
              "tenantId": "__context:tenantId",
              "rowVersion": "meta.rowVersion"
            },
            "nonRecoverableError": "address.nonRecoverable",
            "tenantId": "__context:tenantId",
            "rowVersion": "meta.rowVersion",
            "clientAuditDetails": "__generate:clientAudit",
            "auditDetails": "__generate:audit"
          },
          "additionalFields": "additionalInfo.fields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  "referralCreation": {
    "fallbackModel": "HFReferralModel",
    "models": {
      "HFReferralModel": {
        "mappings": {
          "localityCode": "__context:selectedBoundaryCode",
          "id": "referralDetails.id",
          "tenantId": "__context:tenantId",
          "name": "referralDetails.nameOfChild",
          "projectId": "__context:projectId",
          "projectFacilityId": "facilityDetails.evaluationFacility",
          "symptomSurveyId": "referralDetails.symptomSurveyId",
          "beneficiaryId": "referralDetails.beneficiaryId",
          "referralCode": "referralDetails.referralCode",
          "nationalLevelId": "referralDetails.nationalLevelId",
          "symptom":
              "__switch:navigation.isEdit:{true:navigation.referralSymptom,default:referralDetails.referralReason}",
          "nonRecoverableError": "referralDetails.nonRecoverable",
          "clientReferenceId":
              "__switch:navigation.isEdit:{true:navigation.clientReferenceId,default:__generate:uuid}",
          "rowVersion":
              "__switch:navigation.isEdit:{true:navigation.rowVersion,default:meta.rowVersion}",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "additionalFields": {
            // Static field mappings
            "boundaryCode": "facilityDetails.administrativeUnit",
            "referralCycle": "referralDetails.referralCycle",
            "gender": "referralDetails.gender",
            "ageInMonths": "referralDetails.ageInMonths",
            "nameOfReferral": "referralDetails.nameOfChild",
            "dateOfEvaluation": "facilityDetails.dateOfEvaluation",
            "referredBy": "facilityDetails.referredByKey",
            "hfCoordinator": "facilityDetails.hfCoordinator",
            // Checklist fields from side effect pages (sideEffectSick, sideEffectFever,
            // sideEffectFromCurrentCycle, sideEffectFromPreviousCycle) are automatically
            // captured as unmapped fields and merged into additionalFields via fallbackModel.
          }
        }
      }
    },
  },
  "referralBeneficaryCreate": {
    "fallbackModel": "HFReferralModel",
    "models": {
      "HFReferralModel": {
        "mappings": {
          "tenantId": "__context:tenantId",
          "projectId": "__context:projectId",
          "projectFacilityId":
              //"__switch:referBeneficiary.evaluationFacility:{Community Health Worker:__context:userUUID,default:referBeneficiary.evaluationFacility}"
              "__switch:referBeneficiary.healthFacility:{Community Health Worker:__context:userUUID,default:referBeneficiary.healthFacility}",
          "beneficiaryId": "__context:selectedIndividualIdentifierId",
          "referralCode": "__context:selectedIndividualClientReferenceId",
          "name": "__context:selectedIndividualName",
          "symptom":
              "__switch:__context:sourceFlow:{CHECKLIST:__context:referralReasons,default:referBeneficiary.referralReason}",
          "nonRecoverableError": "referral.nonRecoverable",
          "clientReferenceId": "__generate:uuid",
          "rowVersion": "meta.rowVersion",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit",
          "localityCode": "__context:selectedBoundaryCode",
          "additionalFields": {
            // Explicit field mappings matching ReferralReconEnums/ReferralReconAdditionalFields
            "boundaryCode": "facilityDetails.administrativeArea",
            "referredBy": "__context:userUUID",
            "referralComments": "referBeneficiary.referralComments",
            "nameOfReferral": "__context:selectedIndividualName",
            "referralCycle": "__context:cycleIndex",
            "gender": "__context:selectedIndividualGender",
            "ageInMonths": "__context:selectedIndividualAgeInMonths",
            "dateOfEvaluation": "__value:DATETIME.NOW",
            "ec1Value": "__context:ec1",
            "ec2Value": "__context:ec2",
            "ec3Value": "__context:ec3",
            "ec4Value": "__context:ec4",
            "ec5Value": "__context:ec5",
            // Referral reasons mapped from checklist: SICK for ec1=YES, FEVER for ec2=YES
            "referralReasons": "__context:referralReasons"
          }
        }
      }
    }
  },
  "markAttendancePresent": {
    "fallbackModel": "AttendanceLogModel",
    "models": {
      "AttendanceLogModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid",
          "tenantId": "__context:tenantId",
          "registerId": "__context:registerId",
          "individualId": "__context:individualId",
          "time": "__context:entryTime",
          "status": "__value:ACTIVE",
          "type": "__value:ENTRY",
          "uploadToServer": "__value:false",
          "rowVersion": "__value:1",
          "additionalDetails": "__context:additionalFields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  "attendanceLogSave": {
    "fallbackModel": "AttendanceLogModel",
    "multiEntityField": "attendanceLogs",
    "models": {
      "AttendanceLogModel": {
        "mappings": {
          "clientReferenceId": "__generate:uuid",
          "tenantId": "attendanceLogs.tenantId",
          "registerId": "attendanceLogs.registerId",
          "individualId": "attendanceLogs.individualId",
          "time": "attendanceLogs.entryTime",
          "status": "attendanceLogs.status",
          "type": "attendanceLogs.type",
          "uploadToServer": "attendanceLogs.uploadToServer",
          "rowVersion": "__value:1",
          "additionalDetails": "attendanceLogs.additionalFields",
          "clientAuditDetails": "__generate:clientAudit",
          "auditDetails": "__generate:audit"
        }
      }
    }
  },
  "attendanceLogSubmit": {
    "fallbackModel": "AttendanceLogModel",
    "multiEntityField": "attendanceLogs",
    "models": {
      "AttendanceLogModel": {
        "mappings": {
          "clientReferenceId": "attendanceLogs.uuid",
          "tenantId": "attendanceLogs.tenantId",
          "registerId": "attendanceLogs.registerId",
          "individualId": "attendanceLogs.individualId",
          "time": "attendanceLogs.entryTime",
          "status": "attendanceLogs.status",
          "type": "attendanceLogs.type",
          "uploadToServer": "__value:true",
          "rowVersion": "attendanceLogs.rowVersion",
          "additionalDetails": "attendanceLogs.additionalFields",
          "clientAuditDetails": "attendanceLogs.clientAudit",
          "auditDetails": "attendanceLogs.audit"
        }
      }
    }
  },
  "attendanceAttendeeStatusReset": {
    "fallbackModel": "AttendeeModel",
    "multiEntityField": "attendees",
    "models": {
      "AttendeeModel": {
        "mappings": {
          "id": "attendees.id",
          "tenantId": "attendees.tenantId",
          "registerId": "attendees.registerId",
          "individualId": "attendees.individualId",
          "enrollmentDate": "attendees.enrollmentDate",
          "denrollmentDate": "attendees.denrollmentDate",
          "name": "attendees.name",
          "rowVersion": "attendees.rowVersion",
          "status": "attendees.status",
          "tag": "attendees.tag",
          "nonRecoverableError": "attendees.nonRecoverableError",
          "additionalFields": "attendees.additionalFields",
          "auditDetails": "attendees.auditDetails",
          "clientAuditDetails": "attendees.clientAuditDetails"
        }
      }
    }
  }
};
