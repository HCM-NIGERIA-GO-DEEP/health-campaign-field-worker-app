final dynamic sampleFlows = {
  "id": "9d3a901b-d831-427b-8aeb-4bbda9ec2018",
  "tenantId": "mz",
  "schemaCode": "HCM-ADMIN-CONSOLE.FormConfigTemplate",
  "uniqueIdentifier": "REGISTRATION.MR-DN",
  "name": "REGISTRATION",
  "flows": [
    {
      "body": [
        {
          "type": "template",
          "label": "DELIVERY_SUCCESSFUL_PANEL_CARD_HEADING",
          "format": "panelCard",
          "heading": "DELIVERY_SUCCESSFUL_PANEL_CARD_HEADING",
          "fieldName": "successCard",
          "mandatory": true,
          "properties": {"type": "success"},
          "description": "DELIVERY_SUCCESSFUL_PANEL_CARD_DESC",
          "additionalWidgets": [
            {
              "type": "template",
              "format": "labelPairList",
              "fieldName": "successCardLabelPairList",
              "data": [
                {
                  "key": "E_TOKEN",
                  "value":
                      "{{fn:getUniqueBeneficiaryId(contextData.0.headIndividual.IndividualModel.identifiers)}}"
                }
              ]
            }
          ],
          "primaryAction": {
            "type": "template",
            "label": "VIEW_HOUSEHOLD_DETAILS",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "data": [
                    {
                      "key": "HouseholdClientReferenceId",
                      "value": "{{navigation.HouseholdClientReferenceId}}"
                    },
                    {
                      "key": "ProjectBeneficiaryClientReferenceId",
                      "value":
                          "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                    },
                    {
                      "key": "memberCount",
                      "value": "{{navigation.memberCount}}"
                    },
                    {
                      "key": "beneficiaryId",
                      "value": "{{navigation.beneficiaryId}}"
                    }
                  ],
                  "name": "householdOverview",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "searchBeneficiary"
                }
              }
            ],
            "fieldName": "viewHouseholdButton",
            "mandatory": true,
            "properties": {"type": "primary"}
          },
          "secondaryAction": {
            "type": "template",
            "label": "GO_BACK",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "name": "searchBeneficiary",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndReplace",
                  "popUntilPageName": "searchBeneficiary"
                }
              },
              {
                "actionType": "REFRESH_SEARCH",
                "properties": {"screenName": "searchBeneficiary"}
              }
            ],
            "fieldName": "goBack",
            "mandatory": true,
            "properties": {"type": "secondary"}
          },
          "primaryActionLabel": "VIEW_HOUSEHOLD_DETAILS",
          "secondaryActionLabel": "GO_BACK"
        }
      ],
      "name": "deliverySuccess",
      "order": 11,
      "footer": [],
      "onSystemBack": [
        {
          "actionType": "NAVIGATION",
          "properties": {
            "name": "searchBeneficiary",
            "type": "TEMPLATE",
            "navigationMode": "popUntilAndReplace",
            "popUntilPageName": "searchBeneficiary"
          }
        },
        {
          "actionType": "REFRESH_SEARCH",
          "properties": {"screenName": "searchBeneficiary"}
        }
      ],
      "header": [
        {
          "type": "template",
          "label": "DELIVERY_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  }
                ],
                "name": "searchBeneficiary",
                "type": "TEMPLATE",
                "navigationMode": "popUntilAndReplace",
                "popUntilPageName": "searchBeneficiary"
              }
            },
            {
              "actionType": "REFRESH_SEARCH",
              "properties": {"screenName": "searchBeneficiary"}
            }
          ],
          "fieldName": "deliveryBack",
          "mandatory": true
        }
      ],
      "category": "DELIVERY",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "submitCondition": null,
      "preventScreenCapture": false,
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT"
          }
        }
      ],
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {"field": "isHeadOfHousehold", "equals": true}
            ]
          },
          {
            "name": "headIndividual",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "headOfHousehold.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "members",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "relations": [
              {
                "name": "member",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "clientReferenceId"
                },
                "entity": "HouseholdMemberModel"
              },
              {
                "name": "individual",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "individualClientReferenceId"
                },
                "entity": "IndividualModel"
              },
              {
                "name": "projectBeneficiary",
                "match": {
                  "field": "beneficiaryClientReferenceId",
                  "equalsFrom": "individual.clientReferenceId"
                },
                "entity": "ProjectBeneficiaryModel"
              },
              {
                "name": "task",
                "match": {
                  "field": "projectBeneficiaryClientReferenceId",
                  "equalsFrom": "projectBeneficiary.clientReferenceId"
                },
                "entity": "TaskModel"
              },
              {
                "name": "hFReferral",
                "match": {
                  "field": "beneficiaryId",
                  "equalsFrom": "individual.identifiers.0.identifierId"
                },
                "entity": "HFReferralModel"
              }
            ]
          }
        ],
        "computed": {
          "currentRunningCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {"left": "{{startDate}}", "right": "{{now}}", "operator": "lt"},
              {"left": "{{endDate}}", "right": "{{now}}", "operator": "gt"}
            ],
            "select": "{{id}}",
            "default": -1,
            "takeFirst": true
          },
          "nextDoseId": {
            "order": 4,
            "fallback": 1,
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": 1,
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {"value": "{{dose}}", "operation": "increment"}
              }
            }
          },
          "nextCycleId": {
            "order": 5,
            "fallback": "{{currentRunningCycle}}",
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": "{{currentRunningCycle}}",
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {"value": "{{cycle}}", "operation": "increment"},
                "then": "{{cycle}}"
              }
            }
          },
          "effectiveDose": {
            "order": 6,
            "fallback": 0,
            "condition": {
              "if": {
                "left": "{{nextCycleId}}",
                "right": "{{cycle}}",
                "operator": "equals"
              },
              "else": 0,
              "then": "{{dose}}"
            }
          },
          "deliveryLength": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 3,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "select": "{{deliveries.length}}",
            "default": 0,
            "takeFirst": true
          },
          "hasCycleArrived": {
            "order": 2,
            "fallback": false,
            "condition": {
              "left": "{{cycle}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            }
          }
        },
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": [
            "household",
            "individual",
            "householdMember",
            "projectBeneficiary",
            "task",
            "hFReferral"
          ],
          "primary": "household"
        },
        "computedList": {
          "pastCycles": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 6,
            "where": {
              "left": "{{item.id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "lt"
            }
          },
          "futureTasks": {
            "from": "{{tasks}}",
            "order": 2,
            "where": {
              "left": "{{item.additionalFields.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "targetCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "currentDelivery": {
            "from": "{{targetCycle.0.deliveries}}",
            "order": 4,
            "where": {
              "left": "{{id}}",
              "right": "{{nextDoseId}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "futureDeliveries": {
            "from": "{{targetCycle.0.deliveries}}",
            "skip": {"from": "{{effectiveDose}}"},
            "order": 3,
            "where": {
              "left": "{{item.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "eligibleProductVariants": {
            "from": "{{currentDelivery.0.doseCriteria}}",
            "order": 5,
            "fallback": [],
            "takeLast": false,
            "evaluateCondition": {
              "context": ["{{individuals.0}}", "{{household.0}}"],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {"type": "ageInMonths", "source": "dateOfBirth"}
              }
            }
          }
        }
      }
    },
    {
      "body": [
        {
          "type": "template",
          "label": "CAREGIVER_CONSENT_DECLINED_PANEL_HEADING",
          "format": "panelCard",
          "heading": "CAREGIVER_CONSENT_DECLINED_PANEL_HEADING",
          "fieldName": "consentDeclinedCard",
          "mandatory": true,
          "properties": {"type": "success"},
          "description": "CAREGIVER_CONSENT_DECLINED_PANEL_DESC",
          "primaryAction": {
            "type": "template",
            "label": "VIEW_HOUSEHOLD_DETAILS",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "data": [
                    {
                      "key": "HouseholdClientReferenceId",
                      "value": "{{navigation.HouseholdClientReferenceId}}"
                    }
                  ],
                  "name": "householdOverview",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "searchBeneficiary"
                }
              }
            ],
            "fieldName": "viewHouseholdDetails",
            "mandatory": true,
            "properties": {"type": "primary"}
          },
          "primaryActionLabel": "VIEW_HOUSEHOLD_DETAILS",
          "secondaryAction": {
            "type": "template",
            "label": "Back to Search",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "name": "searchBeneficiary",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "searchBeneficiary"
                }
              },
              {
                "actionType": "REFRESH_SEARCH",
                "properties": {"screenName": "searchBeneficiary"}
              }
            ],
            "fieldName": "backToSearch",
            "mandatory": true,
            "properties": {"type": "secondary"}
          },
          "secondaryActionLabel": "Back to Search"
        }
      ],
      "name": "caregiverAcknowledgement",
      "order": 13,
      "footer": [],
      "onSystemBack": [
        {
          "actionType": "NAVIGATION",
          "properties": {
            "name": "searchBeneficiary",
            "type": "TEMPLATE",
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "searchBeneficiary"
          }
        }
      ],
      "header": [
        {
          "type": "template",
          "label": "DELIVERY_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  }
                ],
                "name": "searchBeneficiary",
                "type": "TEMPLATE",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ]
        }
      ],
      "summary": false,
      "version": 1,
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "submitCondition": null,
      "preventScreenCapture": false
    },
    {
      "body": [
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_FIRST_NAME",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "HOUSEHOLD_LAST_NAME",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.familyName}}",
                  "isActive": true
                },
                {
                  "key": "MEMBER_COUNT",
                  "value":
                      "{{contextData.0.household.HouseholdModel.memberCount}}",
                  "isActive": true
                },
                {
                  "key":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount",
                  "value":
                      "{{fn:getAdditionalFieldValue(contextData.0.household.HouseholdModel.additionalFields.fields, 'childrenCount')}}",
                  "isActive": true
                },
                {
                  "key":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount",
                  "value":
                      "{{fn:getAdditionalFieldValue(contextData.0.household.HouseholdModel.additionalFields.fields, 'pregnantWomenCount')}}",
                  "isActive": true
                },
                {
                  "key": "NUMBER_OF_ITN_FOR_DELIVERY",
                  "value":
                      "{{fn:itnsForMemberCount(contextData.0.household.HouseholdModel.memberCount)}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        },
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_MOBILE_NUMBER",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.mobileNumber}}",
                  "isActive": true
                },
                {
                  "key": "E_TOKEN",
                  "value":
                      "{{fn:getUniqueBeneficiaryId(contextData.0.headIndividual.IndividualModel.identifiers)}}",
                  "isActive": true
                },
                {
                  "key":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationType",
                  "value":
                      "{{fn:getCapturedIdentifierValue(contextData.0.headIndividual.IndividualModel.identifiers, 'identifierType')}}",
                  "isActive": true,
                  "hideIfNull": true
                },
                {
                  "key":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber",
                  "value":
                      "{{fn:getCapturedIdentifierValue(contextData.0.headIndividual.IndividualModel.identifiers, 'identifierId')}}",
                  "isActive": true,
                  "hideIfNull": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        }
      ],
      "name": "householdOverview",
      "order": 3,
      "footer": [
        {
          "type": "template",
          "label": "APPONE_REGISTRATION_HOUSEHOLDOVERVIEW_ACTION_BUTTON_NEXT",
          "format": "button",
          "visible": "{{fn:hasRole('REGISTRAR')}} == false",
          "disabled": "{{fn:isClosedHousehold(contextData.0.tasks)}} == true",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "OPEN_POPUP",
                  "properties": {
                    "size": "large",
                    "type": "primary",
                    "popupConfig": {
                      "body": [
                        {
                          "type": "template",
                          "value":
                              "{{fn:getRegistrationInsufficientStockMessage()}}",
                          "format": "textTemplate",
                          "fieldName": "insufficientStockOverviewText",
                          "maxLines": 8,
                          "properties": {"textAlign": "center"}
                        }
                      ],
                      "type": "alert",
                      "title": "INSUFFICIENT_STOCK_TITLE",
                      "titleIcon": "Warning",
                      "footerActions": [
                        {
                          "type": "template",
                          "label": "BACK_TO_HOME_LABEL",
                          "format": "button",
                          "onAction": [
                            {
                              "actionType": "CLOSE_POPUP",
                              "properties": {
                                "parentScreenKey": "householdOverview"
                              }
                            },
                            {
                              "actionType": "NAVIGATION",
                              "properties": {"name": "HOME", "type": "HOME"}
                            }
                          ],
                          "fieldName": "closeInsufficientStockOverviewPopUp",
                          "properties": {
                            "size": "large",
                            "type": "primary",
                            "mainAxisSize": "max"
                          }
                        }
                      ],
                      "showCloseButton": true,
                      "barrierDismissible": true
                    }
                  }
                }
              ],
              "condition": {
                "expression":
                    "{{fn:hasStockForDelivery(contextData.0.eligibleProductVariants)}} == false"
              }
            },
            {
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                      },
                      {
                        "key": "HouseholdClientReferenceId",
                        "value": "{{navigation.HouseholdClientReferenceId}}"
                      },
                      {
                        "key": "memberCount",
                        "value":
                            "{{contextData.0.household.HouseholdModel.memberCount}}"
                      },
                      {
                        "key": "cycleIndex",
                        "value": "{{contextData.0.nextCycleId}}"
                      },
                      {
                        "key": "doseIndex",
                        "value": "{{contextData.0.nextDoseId}}"
                      },
                      {
                        "key": "deliveryStrategy",
                        "value":
                            "{{contextData.0.currentDelivery.0.deliveryStrategy}}"
                      },
                      {
                        "key": "totalDosesInCycle",
                        "value": "{{contextData.0.deliveryLength}}"
                      },
                      {
                        "key": "futureDoses",
                        "value": "{{contextData.0.futureDeliveries}}"
                      },
                      {
                        "key": "qty",
                        "value":
                            "{{fn:itnsForMemberCount(contextData.0.household.HouseholdModel.memberCount)}}"
                      },
                      {
                        "key": "nameOfIndividual",
                        "value":
                            "{{contextData.0.headIndividual.IndividualModel.name.givenName}}"
                      },
                      {
                        "key": "lastName",
                        "value":
                            "{{contextData.0.headIndividual.IndividualModel.name.familyName}}"
                      },
                      {
                        "key": "beneficiaryId",
                        "value":
                            "{{fn:getUniqueBeneficiaryId(contextData.0.headIndividual.IndividualModel.identifiers)}}"
                      },
                      // Household/individual context persisted onto the
                      // delivery TaskModel (see the delivery config's
                      // additionalFields), so a task row is self-describing
                      // in reports without re-joining to the household.
                      {
                        "key": "childrenCount",
                        "value":
                            "{{fn:getAdditionalFieldValue(contextData.0.household.HouseholdModel.additionalFields.fields, 'childrenCount')}}"
                      },
                      {
                        "key": "pregnantWomenCount",
                        "value":
                            "{{fn:getAdditionalFieldValue(contextData.0.household.HouseholdModel.additionalFields.fields, 'pregnantWomenCount')}}"
                      },
                      {
                        "key": "headMobileNumber",
                        "value":
                            "{{contextData.0.headIndividual.IndividualModel.mobileNumber}}"
                      },
                      {
                        // Positional access sent whatever sat at index 0 -
                        // the generated beneficiary id, or the DEFAULT
                        // placeholder. getCapturedIdentifierValue skips both
                        // and returns the real captured identifier
                        // (National ID, Voter ID, Passport, Licence).
                        "key": "identificationType",
                        "value":
                            "{{fn:getCapturedIdentifierValue(contextData.0.headIndividual.IndividualModel.identifiers, 'identifierType')}}"
                      },
                      {
                        "key": "identificationNumber",
                        "value":
                            "{{fn:getCapturedIdentifierValue(contextData.0.headIndividual.IndividualModel.identifiers, 'identifierId')}}"
                      },
                      // Task-status based, so "not delivered yet" is not
                      // confused with "household closed".
                      {
                        "key": "isDelivered",
                        "value": "{{fn:isDelivered(contextData.0.tasks)}}"
                      }
                    ],
                    "name": "DELIVERY",
                    "type": "FORM"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "fieldName": "registerBeneficiary",
          "mandatory": true,
          "properties": {
            "size": "large",
            "type": "primary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          }
        },
        {
          "type": "template",
          "label": "CORE_COMMON_SAVE",
          "format": "button",
          "visible": "{{fn:hasRole('REGISTRAR')}} == true",
          // Also disabled once the health-talk checklist has been submitted:
          // the acknowledgement screen links back here, and with Save still
          // live the same checklist could be filled repeatedly in a loop.
          "disabled":
              "{{fn:isClosedHousehold(contextData.0.tasks)}} == true || {{fn:isChecklistCompleted(contextData.0.household.HouseholdModel.additionalFields.fields)}} == true",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  }
                ],
                "name": "registrationHealthTalk",
                "type": "FORM"
              }
            }
          ],
          "fieldName": "backToSearchRegistrar",
          "mandatory": true,
          "properties": {
            "size": "large",
            "type": "primary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          }
        }
      ],
      "header": [
        {
          "label": "HOUSEHOLD_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"name": "householdDetails"}
            },
            {
              "actionType": "REFRESH_SEARCH",
              "properties": {"screenName": "searchBeneficiary"}
            }
          ]
        }
      ],
      "heading": "REGISTRATION_HOUSEHOLD_OVERVIEW_HEADING",
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "description": "REGISTRATION_HOUSEHOLD_OVERVIEW_DESC",
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT"
          }
        }
      ],
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {"field": "isHeadOfHousehold", "equals": true}
            ]
          },
          {
            "name": "headIndividual",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "headOfHousehold.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "projectBeneficiaries",
            "match": {
              "field": "beneficiaryClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "ProjectBeneficiaryModel"
          },
          {
            "name": "tasks",
            "match": {
              "field": "projectBeneficiaryClientReferenceId",
              "inFrom": "projectBeneficiaries.clientReferenceId"
            },
            "entity": "TaskModel"
          },
          {
            "name": "members",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "relations": [
              {
                "name": "member",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "clientReferenceId"
                },
                "entity": "HouseholdMemberModel"
              },
              {
                "name": "individual",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "individualClientReferenceId"
                },
                "entity": "IndividualModel"
              },
              {
                "name": "projectBeneficiary",
                "match": {
                  "field": "beneficiaryClientReferenceId",
                  "equalsFrom": "individual.clientReferenceId"
                },
                "entity": "ProjectBeneficiaryModel"
              },
              {
                "name": "task",
                "match": {
                  "field": "projectBeneficiaryClientReferenceId",
                  "equalsFrom": "projectBeneficiary.clientReferenceId"
                },
                "entity": "TaskModel"
              },
              {
                "name": "hFReferral",
                "match": {
                  "field": "beneficiaryId",
                  "equalsFrom": "individual.identifiers.0.identifierId"
                },
                "entity": "HFReferralModel"
              }
            ]
          }
        ],
        "computed": {
          "currentRunningCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {"left": "{{startDate}}", "right": "{{now}}", "operator": "lt"},
              {"left": "{{endDate}}", "right": "{{now}}", "operator": "gt"}
            ],
            "select": "{{id}}",
            "default": -1,
            "takeFirst": true
          },
          "nextDoseId": {
            "order": 4,
            "fallback": 1,
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": 1,
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {"value": "{{dose}}", "operation": "increment"}
              }
            }
          },
          "nextCycleId": {
            "order": 5,
            "fallback": "{{currentRunningCycle}}",
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": "{{currentRunningCycle}}",
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {"value": "{{cycle}}", "operation": "increment"},
                "then": "{{cycle}}"
              }
            }
          },
          "effectiveDose": {
            "order": 6,
            "fallback": 0,
            "condition": {
              "if": {
                "left": "{{nextCycleId}}",
                "right": "{{cycle}}",
                "operator": "equals"
              },
              "else": 0,
              "then": "{{dose}}"
            }
          },
          "deliveryLength": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 3,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "select": "{{deliveries.length}}",
            "default": 0,
            "takeFirst": true
          },
          "hasCycleArrived": {
            "order": 2,
            "fallback": false,
            "condition": {
              "left": "{{cycle}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            }
          }
        },
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": [
            "household",
            "individual",
            "householdMember",
            "projectBeneficiary",
            "task",
            "hFReferral"
          ],
          "primary": "household"
        },
        "computedList": {
          "pastCycles": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 6,
            "where": {
              "left": "{{item.id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "lt"
            }
          },
          "futureTasks": {
            "from": "{{tasks}}",
            "order": 2,
            "where": {
              "left": "{{item.additionalFields.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "targetCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "currentDelivery": {
            "from": "{{targetCycle.0.deliveries}}",
            "order": 4,
            "where": {
              "left": "{{id}}",
              "right": "{{nextDoseId}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "futureDeliveries": {
            "from": "{{targetCycle.0.deliveries}}",
            "skip": {"from": "{{effectiveDose}}"},
            "order": 3,
            "where": {
              "left": "{{item.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "eligibleProductVariants": {
            "from": "{{currentDelivery.0.doseCriteria}}",
            "order": 5,
            "fallback": [],
            "takeLast": false,
            "evaluateCondition": {
              "context": ["{{individuals.0}}", "{{household.0}}"],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {"type": "ageInMonths", "source": "dateOfBirth"}
              }
            }
          }
        }
      },
      "submitCondition": null,
      "preventScreenCapture": false
    },
    {
      "body": [
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_FIRST_NAME",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "HOUSEHOLD_LAST_NAME",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.familyName}}",
                  "isActive": true
                },
                {
                  "key": "MEMBER_COUNT",
                  "value":
                      "{{contextData.0.household.HouseholdModel.memberCount}}",
                  "isActive": true
                },
                {
                  "key": "NUMBER_OF_ITN_FOR_DELIVERY",
                  "value":
                      "{{fn:itnsForMemberCount(contextData.0.household.HouseholdModel.memberCount)}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        },
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_MOBILE_NUMBER",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.mobileNumber}}",
                  "isActive": true
                },
                {
                  "key": "E_TOKEN",
                  "value":
                      "{{fn:getUniqueBeneficiaryId(contextData.0.headIndividual.IndividualModel.identifiers)}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        }
      ],
      "name": "previewScreen",
      "order": 12,
      "footer": [
        {
          "type": "template",
          "label": "REGISTER_NEW_BENEFICIARY",
          "format": "button",
          "visible": true,
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"name": "searchBeneficiary"}
            }
          ],
          "fieldName": "registerBeneficiary",
          "mandatory": true,
          "properties": {
            "size": "large",
            "type": "primary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          }
        }
      ],
      "header": [
        {
          "label": "HOUSEHOLD_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"name": "searchBeneficiary"}
            }
          ]
        }
      ],
      "heading": "REGISTRATION_HOUSEHOLD_OVERVIEW_HEADING",
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "description": "REGISTRATION_HOUSEHOLD_OVERVIEW_DESC",
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT"
          }
        }
      ],
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {"field": "isHeadOfHousehold", "equals": true}
            ]
          },
          {
            "name": "headIndividual",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "headOfHousehold.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "members",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "relations": [
              {
                "name": "member",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "clientReferenceId"
                },
                "entity": "HouseholdMemberModel"
              },
              {
                "name": "individual",
                "match": {
                  "field": "clientReferenceId",
                  "equalsFrom": "individualClientReferenceId"
                },
                "entity": "IndividualModel"
              },
              {
                "name": "projectBeneficiary",
                "match": {
                  "field": "beneficiaryClientReferenceId",
                  "equalsFrom": "individual.clientReferenceId"
                },
                "entity": "ProjectBeneficiaryModel"
              },
              {
                "name": "task",
                "match": {
                  "field": "projectBeneficiaryClientReferenceId",
                  "equalsFrom": "projectBeneficiary.clientReferenceId"
                },
                "entity": "TaskModel"
              },
              {
                "name": "hFReferral",
                "match": {
                  "field": "beneficiaryId",
                  "equalsFrom": "individual.identifiers.0.identifierId"
                },
                "entity": "HFReferralModel"
              }
            ]
          }
        ],
        "computed": {
          "currentRunningCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {"left": "{{startDate}}", "right": "{{now}}", "operator": "lt"},
              {"left": "{{endDate}}", "right": "{{now}}", "operator": "gt"}
            ],
            "select": "{{id}}",
            "default": -1,
            "takeFirst": true
          },
          "nextDoseId": {
            "order": 4,
            "fallback": 1,
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": 1,
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {"value": "{{dose}}", "operation": "increment"}
              }
            }
          },
          "nextCycleId": {
            "order": 5,
            "fallback": "{{currentRunningCycle}}",
            "condition": {
              "if": {
                "left": "{{cycle}}",
                "right": "{{currentRunningCycle}}",
                "operator": "equals"
              },
              "else": "{{currentRunningCycle}}",
              "then": {
                "if": {
                  "left": {"value": "{{dose}}", "operation": "increment"},
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {"value": "{{cycle}}", "operation": "increment"},
                "then": "{{cycle}}"
              }
            }
          },
          "effectiveDose": {
            "order": 6,
            "fallback": 0,
            "condition": {
              "if": {
                "left": "{{nextCycleId}}",
                "right": "{{cycle}}",
                "operator": "equals"
              },
              "else": 0,
              "then": "{{dose}}"
            }
          },
          "deliveryLength": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 3,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "select": "{{deliveries.length}}",
            "default": 0,
            "takeFirst": true
          },
          "hasCycleArrived": {
            "order": 2,
            "fallback": false,
            "condition": {
              "left": "{{cycle}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            }
          }
        },
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": [
            "household",
            "individual",
            "householdMember",
            "projectBeneficiary",
            "task",
            "hFReferral"
          ],
          "primary": "household"
        },
        "computedList": {
          "pastCycles": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 6,
            "where": {
              "left": "{{item.id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "lt"
            }
          },
          "futureTasks": {
            "from": "{{tasks}}",
            "order": 2,
            "where": {
              "left": "{{item.additionalFields.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "targetCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "currentDelivery": {
            "from": "{{targetCycle.0.deliveries}}",
            "order": 4,
            "where": {
              "left": "{{id}}",
              "right": "{{nextDoseId}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "futureDeliveries": {
            "from": "{{targetCycle.0.deliveries}}",
            "skip": {"from": "{{effectiveDose}}"},
            "order": 3,
            "where": {
              "left": "{{item.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "eligibleProductVariants": {
            "from": "{{currentDelivery.0.doseCriteria}}",
            "order": 5,
            "fallback": [],
            "takeLast": false,
            "evaluateCondition": {
              "context": ["{{individuals.0}}", "{{household.0}}"],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {"type": "ageInMonths", "source": "dateOfBirth"}
              }
            }
          }
        }
      },
      "submitCondition": null,
      "preventScreenCapture": false
    },
    {
      "body": [
        {
          "type": "template",
          "label": "SEARCH_BY_PROXIMITY",
          "format": "proximitySearch",
          "onAction": [
            {
              "actionType": "field.value==true ? SEARCH_EVENT : CLEAR_STATE",
              "properties": {
                "data": [
                  // Latitude/longitude live on the address table, not on
                  // household - without this root the filter resolves
                  // against the primary table's always-null coordinate
                  // columns and matches nothing.
                  {
                    "key": "",
                    "root": "address",
                    "value": 5,
                    "operation": "within"
                  },
                  {
                    "key": "localityBoundaryCode",
                    "root": "address",
                    "value": "{{singleton.boundary.code}}",
                    "operation": "equals"
                  }
                ],
                "name": "address",
                "type": "field.value==true ? SEARCH_EVENT : CLEAR_STATE"
              }
            }
          ],
          "fieldName": "proximitySearch",
          "mandatory": true,
          "schemaCode": null,
          "validations": [
            {
              "key": "proximityRadius",
              "value": 5,
              "errorMessage": "PROXIMITY_RADIUS_ERROR_MESSAGE"
            }
          ]
        },
        {
          "type": "template",
          "label": "SEARCH_BY_NAME",
          "format": "switch",
          "onAction": [
            {
              "actionType": "CLEAR_STATE",
              "properties": {
                "widgetKeys": [
                  "searchBar",
                  "idSearchBar",
                  "nationalIdSearchBar",
                  "phoneNumberSearchBar",
                  "beneficiaryIdSearch",
                  "nationalIdSearch",
                  "phoneNumberSearch"
                ],
                "filterKeys": [
                  "givenName,familyName",
                  "identifierId",
                  "identifierType",
                  "mobileNumber"
                ],
                "triggerSearch": true
              }
            }
          ],
          "fieldName": "nameSearch",
          "mandatory": true,
          "schemaCode": null,
          "validations": []
        },
        {
          "type": "template",
          "label": "BENEFICIARY_ID_SEARCH_REGISTRATION",
          "format": "switch",
          "onAction": [
            {
              "actionType": "CLEAR_STATE",
              "properties": {
                "widgetKeys": [
                  "searchBar",
                  "idSearchBar",
                  "nationalIdSearchBar",
                  "phoneNumberSearchBar",
                  "nameSearch",
                  "nationalIdSearch",
                  "phoneNumberSearch"
                ],
                "filterKeys": [
                  "givenName,familyName",
                  "identifierId",
                  "identifierType",
                  "mobileNumber"
                ],
                "triggerSearch": true
              }
            }
          ],
          "fieldName": "beneficiaryIdSearch",
          "mandatory": true,
          "schemaCode": null,
          "validations": []
        },
        {
          "type": "template",
          "label": "NATIONAL_ID_SEARCH_REGISTRATION",
          "format": "switch",
          "onAction": [
            {
              "actionType": "CLEAR_STATE",
              "properties": {
                "widgetKeys": [
                  "searchBar",
                  "idSearchBar",
                  "nationalIdSearchBar",
                  "phoneNumberSearchBar",
                  "nameSearch",
                  "beneficiaryIdSearch",
                  "phoneNumberSearch"
                ],
                "filterKeys": [
                  "givenName,familyName",
                  "identifierId",
                  "identifierType",
                  "mobileNumber"
                ],
                "triggerSearch": true
              }
            }
          ],
          "fieldName": "nationalIdSearch",
          "mandatory": true,
          "schemaCode": null,
          "validations": []
        },
        {
          "type": "template",
          "label": "PHONE_NUMBER_SEARCH_REGISTRATION",
          "format": "switch",
          "onAction": [
            {
              "actionType": "CLEAR_STATE",
              "properties": {
                "widgetKeys": [
                  "searchBar",
                  "idSearchBar",
                  "nationalIdSearchBar",
                  "phoneNumberSearchBar",
                  "nameSearch",
                  "beneficiaryIdSearch",
                  "nationalIdSearch"
                ],
                "filterKeys": [
                  "givenName,familyName",
                  "identifierId",
                  "identifierType",
                  "mobileNumber"
                ],
                "triggerSearch": true
              }
            }
          ],
          "fieldName": "phoneNumberSearch",
          "mandatory": true,
          "schemaCode": null,
          "validations": []
        },
        {
          "type": "template",
          "label": "NAME_OF_INDIVIDUAL",
          "format": "searchBar",
          "visible": "{{nameSearch}} == true",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "data": [
                      {
                        "key": "givenName,familyName",
                        "value": "field.value",
                        "operation": "containsAll"
                      },
                      {
                        "key": "localityBoundaryCode",
                        "root": "address",
                        "value": "{{singleton.boundary.code}}",
                        "operation": "equals"
                      }
                    ],
                    "name": "name",
                    "type": "field.value==true ? SEARCH_EVENT : CLEAR_EVENT"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "fieldName": "searchBar",
          "mandatory": true,
          "validations": [
            {"type": "minSearchChars", "value": 2}
          ],
          "minSearchChars": 2
        },
        {
          "type": "template",
          "label": "ID_OF_INDIVIDUAL",
          "format": "searchBar",
          "visible":
              "{{nameSearch}} != true && {{nationalIdSearch}} != true && {{phoneNumberSearch}} != true",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "data": [
                      {
                        "key": "identifierId",
                        "value": "field.value",
                        "operation": "equals"
                      },
                      {
                        "key": "identifierType",
                        "value": "UNIQUE_BENEFICIARY_ID",
                        "operation": "equals"
                      },
                      {
                        "key": "localityBoundaryCode",
                        "root": "address",
                        "value": "{{singleton.boundary.code}}",
                        "operation": "equals"
                      }
                    ],
                    "name": "identifier",
                    "type": "field.value==true ? SEARCH_EVENT : CLEAR_EVENT"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "fieldName": "idSearchBar",
          "mandatory": true,
          // Generated beneficiary IDs contain underscores (e.g.
          // UNIQUE_BENEFICIARY_ID values), which this allow-list excluded,
          // blocking the user from even typing "_" to search by it.
          "allowedCharacters": "a-zA-Z0-9_",
          "validations": [
            {"type": "minSearchChars", "value": 2}
          ],
          "minSearchChars": 2
        },
        {
          "type": "template",
          "label": "NATIONAL_ID_OF_INDIVIDUAL",
          "format": "searchBar",
          "visible": "{{nationalIdSearch}} == true",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "data": [
                      {
                        "key": "identifierId",
                        "value": "field.value",
                        "operation": "equals"
                      },
                      {
                        "key": "identifierType",
                        "value": [
                          "NATIONAL_ID",
                          "VOTER_ID",
                          "PASSPORT",
                          "DRIVERS_LICENSE"
                        ],
                        "operation": "in"
                      },
                      {
                        "key": "localityBoundaryCode",
                        "root": "address",
                        "value": "{{singleton.boundary.code}}",
                        "operation": "equals"
                      }
                    ],
                    "name": "identifier",
                    "type": "field.value==true ? SEARCH_EVENT : CLEAR_EVENT"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "fieldName": "nationalIdSearchBar",
          "mandatory": true,
          "allowedCharacters": "a-zA-Z0-9",
          "validations": [
            {"type": "minSearchChars", "value": 3}
          ],
          "minSearchChars": 3
        },
        {
          "type": "template",
          "label": "PHONE_NUMBER_OF_INDIVIDUAL",
          "format": "searchBar",
          "visible": "{{phoneNumberSearch}} == true",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "data": [
                      {
                        "key": "mobileNumber",
                        "value": "field.value",
                        "operation": "equals",
                        "root": "individual"
                      },
                      {
                        "key": "localityBoundaryCode",
                        "root": "address",
                        "value": "{{singleton.boundary.code}}",
                        "operation": "equals"
                      }
                    ],
                    "name": "phoneNumber",
                    "type": "field.value==true ? SEARCH_EVENT : CLEAR_EVENT"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "fieldName": "phoneNumberSearchBar",
          "mandatory": true,
          "allowedCharacters": "0-9",
          "validations": [
            {"type": "minSearchChars", "value": 8}
          ],
          "minSearchChars": 8
        },
        {
          "data": "members",
          "type": "template",
          // A household marked closed (Mark Closed Household or a declined
          // consent) is a Registrar-owned placeholder - there is nothing for
          // a Distributor to deliver to until a Registrar reopens and
          // completes it, and the OPEN button is dead for them anyway. Drop
          // those rows from the Distributor's result list entirely rather
          // than showing an unusable card. itemFilter is evaluated per item
          // by list_view_widget before the card is built, so a filtered-out
          // household never renders.
          //
          // A user who holds BOTH roles keeps seeing them: reopening a
          // closed household is a registration action and runs from this
          // very card's OPEN button, so filtering on DISTRIBUTOR alone
          // would lock a dual-role user out of their own Registrar work.
          "itemFilter":
              "{{fn:hasRole('DISTRIBUTOR')}} == false || {{fn:hasRole('REGISTRAR')}} == true || {{fn:isHouseholdMarkedClosed(item.tasks)}} == false",
          "child": {
            "type": "template",
            "format": "card",
            "visible": true,
            "children": [
              {
                "type": "template",
                "format": "row",
                "children": [
                  {
                    "type": "template",
                    "format": "expanded",
                    "child": {
                      "type": "template",
                      "value":
                          "{{fn:getUniqueBeneficiaryId(item.headIndividual.0.identifiers)}}",
                      "format": "textTemplate",
                      "fieldName": "beneficiaryId",
                      "maxLines": 2,
                      "properties": {"style": "headingS"}
                    }
                  },
                  {
                    "type": "template",
                    "label": "OPEN",
                    "format": "button",
                    "disabled": "{{fn:isClosedHousehold(item.tasks)}} == true",
                    "onAction": [
                      {
                        "actions": [
                          {
                            "actionType": "REVERSE_TRANSFORM",
                            "properties": {
                              "data": [
                                {"key": "entities", "value": "{{item}}"}
                              ],
                              "configName": "beneficiaryRegistration",
                              "entityTypes": [
                                "HouseholdModel",
                                "IndividualModel",
                                "TaskModel"
                              ]
                            }
                          },
                          {
                            "actionType": "NAVIGATION",
                            "properties": {
                              "data": [
                                {
                                  "key": "HouseholdClientReferenceId",
                                  "value":
                                      "{{ item.HouseholdModel.clientReferenceId }}"
                                },
                                {
                                  "key": "ProjectBeneficiaryClientReferenceId",
                                  "value":
                                      "{{ item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId }}"
                                },
                                {"key": "isEdit", "value": "true"},
                                {"key": "isClosedHousehold", "value": "true"}
                              ],
                              "name": "previewScreen",
                              "type": "TEMPLATE"
                            }
                          }
                        ],
                        "condition": {
                          "expression":
                              "{{fn:isClosedHousehold(item.tasks)}} == true"
                        }
                      },
                      {
                        "actions": [
                          {
                            "actionType": "REVERSE_TRANSFORM",
                            "properties": {
                              "data": [
                                {"key": "entities", "value": "{{item}}"}
                              ],
                              "configName": "beneficiaryRegistration",
                              "entityTypes": [
                                "HouseholdModel",
                                "IndividualModel",
                                "TaskModel"
                              ]
                            }
                          },
                          {
                            "actionType": "NAVIGATION",
                            "properties": {
                              "data": [
                                {
                                  "key": "HouseholdClientReferenceId",
                                  "value":
                                      "{{item.HouseholdModel.clientReferenceId}}"
                                },
                                {
                                  "key": "ProjectBeneficiaryClientReferenceId",
                                  "value":
                                      "{{item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId}}"
                                },
                                {"key": "isEdit", "value": "true"},
                                {
                                  "key": "isClosedHousehold",
                                  "value":
                                      "{{fn:isHouseholdMarkedClosed(item.tasks)}}"
                                },
                                {
                                  "key": "identifier",
                                  "value": "{{item.headIndividual}}"
                                },
                                {
                                  "key": "startPage",
                                  "value": "caregiverConsent"
                                },
                                {"key": "deferFormRoutePop", "value": "true"}
                              ],
                              "name": "HOUSEHOLD",
                              "type": "FORM"
                            }
                          }
                        ],
                        "condition": {
                          "expression":
                              "{{fn:isCaregiverConsentMissing(item.HouseholdModel)}} == true"
                        }
                      },
                      {
                        "actions": [
                          {
                            "actionType": "REVERSE_TRANSFORM",
                            "properties": {
                              "data": [
                                {"key": "entities", "value": "{{item}}"}
                              ],
                              "configName": "beneficiaryRegistration",
                              "entityTypes": [
                                "HouseholdModel",
                                "IndividualModel",
                                "TaskModel"
                              ]
                            }
                          },
                          {
                            "actionType": "NAVIGATION",
                            "properties": {
                              "data": [
                                {
                                  "key": "HouseholdClientReferenceId",
                                  "value":
                                      "{{item.HouseholdModel.clientReferenceId}}"
                                },
                                {
                                  "key": "ProjectBeneficiaryClientReferenceId",
                                  "value":
                                      "{{item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId}}"
                                },
                                {"key": "isEdit", "value": "true"},
                                {"key": "isClosedHousehold", "value": "true"},
                                {
                                  "key": "identifier",
                                  "value": "{{item.headIndividual}}"
                                },
                                {
                                  "key": "startPage",
                                  "value": "caregiverConsent"
                                },
                                {"key": "deferFormRoutePop", "value": "true"}
                              ],
                              "name": "HOUSEHOLD",
                              "type": "FORM"
                            }
                          }
                        ],
                        "condition": {
                          "expression":
                              "{{fn:isClosedHousehold(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks)}} == true"
                        }
                      },
                      {
                        "actions": [
                          {
                            "actionType": "NAVIGATION",
                            "properties": {
                              "data": [
                                {
                                  "key": "HouseholdClientReferenceId",
                                  "value":
                                      "{{item.HouseholdModel.clientReferenceId}}"
                                },
                                {
                                  "key": "ProjectBeneficiaryClientReferenceId",
                                  "value":
                                      "{{item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId}}"
                                }
                              ],
                              "name": "householdOverview",
                              "type": "TEMPLATE"
                            }
                          }
                        ],
                        "condition": {"expression": "DEFAULT"}
                      }
                    ],
                    "fieldName": "openMemberCard",
                    "properties": {"size": "medium", "type": "secondary"}
                  }
                ],
                "fieldName": "detailsRow",
                "properties": {
                  "mainAxisSize": "max",
                  "mainAxisAlignment": "spaceBetween"
                }
              },
              {
                "type": "template",
                "value":
                    "{{ item.headIndividual.0.name.givenName }} {{ item.headIndividual.0.name.familyName }}",
                "format": "textTemplate",
                "fieldName": "householdName",
                "properties": {"style": "headingS"}
              },
              {
                "type": "template",
                "format": "labelPairList",
                "fieldName": "nationalIdDisplay",
                "data": [
                  {
                    // Indexing position 1 assumed the captured identifier
                    // always sat there. A household registered without a
                    // National ID has only the generated ones, so that slot
                    // held the DEFAULT placeholder (or the beneficiary id)
                    // and the card displayed it as though it were a real
                    // identifier. getCapturedIdentifierValue skips
                    // UNIQUE_BENEFICIARY_ID and DEFAULT and returns null when
                    // nothing else was captured, so hideIfNull drops the row
                    // entirely - which is what "no identifier" should look
                    // like.
                    "key":
                        "{{fn:getCapturedIdentifierValue(item.headIndividual.0.identifiers, 'identifierType')}}",
                    "value":
                        "{{fn:getCapturedIdentifierValue(item.headIndividual.0.identifiers, 'identifierId')}}",
                    "isActive": true,
                    "hideIfNull": true
                  }
                ]
              },
              {
                "type": "template",
                "value": "SEARCH_HOUSEHOLD_STATUS_ITN_DELIVERED",
                "format": "textTemplate",
                "visible": "{{fn:isClosedHousehold(item.tasks)}} == true",
                "fieldName": "statusDelivered",
                "properties": {}
              },
              {
                "type": "template",
                "value": "SEARCH_HOUSEHOLD_STATUS_CLOSED_HOUSEHOLD",
                "format": "textTemplate",
                "visible": "{{fn:isHouseholdMarkedClosed(item.tasks)}} == true",
                "fieldName": "statusClosedHousehold",
                "properties": {}
              },
              {
                "type": "template",
                "value": "SEARCH_HOUSEHOLD_STATUS_DELIVERY_PENDING",
                "format": "textTemplate",
                "visible":
                    "{{fn:isClosedHousehold(item.tasks)}} == false && {{fn:isHouseholdMarkedClosed(item.tasks)}} == false",
                "fieldName": "statusNotVisited",
                "properties": {}
              }
            ],
            "fieldName": "memberCard"
          },
          "format": "listView",
          "hidden": false,
          "fieldName": "listView",
          "properties": {"spacing": "spacer4"},
          "schemaCode": null
        }
      ],
      "name": "searchBeneficiary",
      "order": 1,
      "footer": [
        {
          "icon": "FilterAlt",
          "type": "template",
          "label": "DOWNLOAD_BENEFICIARY_IDS",
          "hidden": true,
          "format": "actionPopup",
          "visible":
              "{{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==false && {{fn:hasRole('DISTRIBUTOR')}}==false",
          "disabled": "false",
          "fieldName": "beneficiaryIdMinCheck",
          "properties": {
            "icon": "FilterAlt",
            "size": "large",
            "type": "primary",
            "popupConfig": {
              "body": [],
              "type": "alert",
              "title":
                  "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_TITLE",
              "description":
                  "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_DESCRIPTION",
              "footerActions": [
                {
                  "type": "template",
                  "label":
                      "REGISTRATION_SEARCH_BENEFICIARY_SKIP_CONTINUE_LABEL",
                  "format": "button",
                  "onAction": [
                    {
                      "actionType": "CLOSE_POPUP",
                      "properties": {"parentScreenKey": "searchBeneficiary"}
                    },
                    {
                      "actionType": "NAVIGATION",
                      "properties": {
                        "data": [
                          {"key": "nameOfIndividual", "value": "{{searchBar}}"},
                          {
                            "key": "UNIQUE_BENEFICIARY_ID",
                            "value": "{{latestBeneficiaryId}}"
                          },
                          {
                            "key": "uniqueBeneficiaryIdModel",
                            "value": "{{latestBeneficiaryIdModel}}"
                          },
                          {"key": "deferFormRoutePop", "value": "true"}
                        ],
                        "name": "HOUSEHOLD",
                        "type": "FORM"
                      }
                    }
                  ],
                  "fieldName": "skip",
                  "properties": {
                    "size": "large",
                    "type": "secondary",
                    "mainAxisSize": "max"
                  },
                  "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false"
                },
                {
                  "type": "template",
                  "label": "REGISTRATION_SEARCH_BENEFICIARY_DOWNLOAD_ID",
                  "format": "button",
                  "onAction": [
                    {
                      "actionType": "CLOSE_POPUP",
                      "properties": {"parentScreenKey": "searchBeneficiary"}
                    },
                    {
                      "actionType": "NAVIGATE_TO_BENEFICIARY_ID_DOWN_SYNC",
                      "properties": {}
                    }
                  ],
                  "fieldName": "downloadID",
                  "properties": {
                    "size": "large",
                    "type": "primary",
                    "mainAxisSize": "max"
                  }
                }
              ],
              "showCloseButton": true,
              "barrierDismissible": true
            },
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "schemaCode": null
        },
        {
          "type": "template",
          "label": "REGISTER_NEW_BENEFICIARY",
          "format": "button",
          "fieldName": "registerNewBeneficiary",
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "OPEN_POPUP",
                  "properties": {
                    "popupConfig": {
                      "body": [
                        {
                          "type": "template",
                          "value":
                              "{{fn:getRegistrationInsufficientStockMessage()}}",
                          "format": "textTemplate",
                          "fieldName": "insufficientStockRegistrationText",
                          "maxLines": 8,
                          "properties": {"textAlign": "center"}
                        }
                      ],
                      "title": "INSUFFICIENT_STOCK_TITLE",
                      "titleIcon": "Warning",
                      "type": "alert",
                      "footerActions": [
                        {
                          "type": "template",
                          "label": "RETURN_TO_HOUSEHOLD_SCREEN_LABEL",
                          "format": "button",
                          "onAction": [
                            {
                              "actionType": "CLOSE_POPUP",
                              "properties": {
                                "parentScreenKey": "searchBeneficiary"
                              }
                            }
                          ],
                          "fieldName":
                              "closeInsufficientStockRegistrationPopUp",
                          "properties": {
                            "size": "large",
                            "type": "primary",
                            "mainAxisSize": "max"
                          }
                        }
                      ],
                      "showCloseButton": true,
                      "barrierDismissible": true
                    }
                  }
                }
              ],
              "condition": {
                "expression": "{{fn:hasStockForRegistration()}}==false"
              }
            },
            {
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {"key": "nameOfIndividual", "value": "{{searchBar}}"},
                      {
                        "key": "UNIQUE_BENEFICIARY_ID",
                        "value": "{{latestBeneficiaryId}}"
                      },
                      {
                        "key": "uniqueBeneficiaryIdModel",
                        "value": "{{latestBeneficiaryIdModel}}"
                      },
                      {"key": "deferFormRoutePop", "value": "true"}
                    ],
                    "name": "HOUSEHOLD",
                    "type": "FORM"
                  }
                }
              ],
              "condition": {
                "condition": {"expression": "DEFAULT"}
              }
            }
          ],
          "mandatory": true,
          "properties": {
            "size": "large",
            "type": "primary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false"
        }
      ],
      "header": [
        {
          "label": "BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"name": "HOME", "type": "HOME"}
            }
          ]
        }
      ],
      "heading": "REGISTRATION_SEARCH_HOUSEHOLD_HEADING",
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "description": "",
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "members",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {"field": "isHeadOfHousehold", "equals": true}
            ]
          },
          {
            "name": "headIndividual",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "headOfHousehold.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "individuals",
            "match": {
              "field": "clientReferenceId",
              "inFrom": "members.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "projectBeneficiaries",
            "match": {
              "field": "beneficiaryClientReferenceId",
              "inFrom": "household.clientReferenceId"
            },
            "entity": "ProjectBeneficiaryModel"
          },
          {
            "name": "tasks",
            "match": {
              "field": "projectBeneficiaryClientReferenceId",
              "inFrom": "projectBeneficiaries.clientReferenceId"
            },
            "entity": "TaskModel"
          },
          {
            "name": "sideEffects",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "SideEffectModel"
          },
          {
            "name": "hFReferral",
            "match": {
              "field": "beneficiaryId",
              "equalsFrom": "individual.identifiers.0.identifierId"
            },
            "entity": "HFReferralModel"
          }
        ],
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": [
            "household",
            "individual",
            "householdMember",
            "projectBeneficiary",
            "task"
          ],
          "primary": "household",
          "pagination": {"limit": 20, "maxItems": 200}
        }
      },
      "scrollListener": {
        "debounceMs": 300,
        "onScrollUp": [
          {
            "actionType": "REFRESH_SEARCH",
            "properties": {
              "pagination": {"limit": 20, "maxItems": 200}
            }
          }
        ],
        "triggerMode": "bidirectional",
        "onScrollDown": [
          {
            "actionType": "REFRESH_SEARCH",
            "properties": {
              "pagination": {"limit": 20, "maxItems": 200}
            }
          }
        ],
        "showLoadingIndicator": true
      },
      "submitCondition": null,
      "preventScreenCapture": false
    },
    {
      // Health talk for pure Registrar users: DeliveryChecklist (the same
      // 7-item e-token/net-care checklist) is tied to the Distributor's
      // DELIVERY flow and runs CREATE_EVENT for the actual delivery task -
      // not appropriate here since no physical net handover happens at
      // registration time for a Registrar who doesn't also distribute.
      // This reuses the exact same checklist content/labels but on
      // acknowledgement just returns to search, mirroring what
      // backToSearchRegistrar did directly before this was added.
      "name": "registrationHealthTalk",
      "order": 14,
      "pages": [
        {
          "body": null,
          "flow": "registrationHealthTalk",
          "page": "registrationHealthTalkChecklist",
          "type": "object",
          "label": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_HEADING",
          "order": 1,
          "footer": [
            {
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
              "format": "button",
              "fieldName": "registrationHealthTalkSubmitButton",
              // The checklist persistence itself lives in this flow's own
              // (flow-level) onAction further down, which is what
              // screen_builder's _handleFormSubmission executes. This
              // navigation is kept as it was originally.
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value": "{{navigation.HouseholdClientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                      }
                    ],
                    "name": "registrationHealthTalkSuccess",
                    "type": "TEMPLATE"
                  }
                }
              ],
              "properties": {
                "size": "large",
                "type": "primary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              }
            }
          ],
          "module": "REGISTRATION",
          "heading":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  }
                ],
                "name": "registrationHealthTalkSuccess",
                "type": "TEMPLATE"
              }
            }
          ],
          "navigateTo": null,
          "properties": [
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_RECEIVE_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION1",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_TRUCK_IN_THE_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION2",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_ROLL_UP_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION3",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_NET_IS_DIRTY",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION4",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_MEND_YOUR_NETS",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION5",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_THE_NET_PROTECTS",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION6",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_PROTECT_FROM_MALERIA",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION7",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            }
          ],
          "actionLabel":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
          "description":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_DESCRIPTION",
          "showTabView": false,
          "submitCondition": null,
          "preventScreenCapture": false,
          "conditionalNavigateTo": null,
          "showAlertPopUp": {
            "title": "APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE",
            "description": "HOUSEHOLD_CHECKLIST_SUBMIT_DESCRIPTION",
            "primaryActionLabel": "ACTION_SUBMIT",
            "secondaryActionLabel": "ACTION_CANCEL"
          }
        }
      ],
      "category": "REGISTRATION",
      "disabled": false,
      "isSelected": true,
      "onAction": [
        // Persist the checklist answers onto the household BEFORE
        // navigating away.
        //
        // This has to live at flow level, not on the footer button: for a
        // screenType "FORM" flow the forms engine renders and owns the
        // submit button, and submission routes through
        // FormSubmissionRegistry into screen_builder's
        // _handleFormSubmission, which executes widget.config['onAction'] -
        // this list. Actions placed on the page's footer button are never
        // executed at all, which is why earlier attempts to save ACTION1..7
        // there silently did nothing.
        //
        // The household is re-searched here rather than relying on the
        // flow's initActions. initActions run via
        // ActionHandler.execute(parsed, context, {'wrappers': const []}) -
        // with no compositeKey in that contextData, so search_executor may
        // not write its results back into FlowCrudStateRegistry, leaving
        // _handleFormSubmission's registryState.base null and
        // contextData['entities'] empty. UpdateExecutor then logs
        // "No entities found in contextData[entities]" and returns without
        // writing anything - a silent no-op. awaitResults makes this search
        // populate contextData['entities'] synchronously before
        // UPDATE_EVENT runs.
        //
        // The "HouseholdModel.additionalFields.fields.<key>" modify path
        // merges into the existing additionalFields (crud_executor), so
        // childrenCount / pregnantWomenCount / caregiverConsent already on
        // the household are preserved.
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT",
            "awaitResults": true,
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to load the household."}
              }
            ]
          }
        },
        {
          "actionType": "UPDATE_EVENT",
          "properties": {
            "entity": "HouseholdModel",
            "modify": [
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION1",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION1}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION2",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION2}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION3",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION3}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION4",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION4}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION5",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION5}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION6",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION6}}"
              },
              {
                "key": "HouseholdModel.additionalFields.fields.ACTION7",
                "value": "{{formData.registrationHealthTalkChecklist.ACTION7}}"
              }
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to save the checklist."}
              }
            ]
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "data": [
              {
                "key": "HouseholdClientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}"
              },
              {
                "key": "ProjectBeneficiaryClientReferenceId",
                "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
              }
            ],
            "name": "registrationHealthTalkSuccess",
            "type": "TEMPLATE",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Navigation failed."}
              }
            ],
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "householdOverview"
          }
        }
      ],
      "scrollListener": {},
      "summary": false,
      "version": 1,
      "screenType": "FORM",
      // The checklist answers are persisted onto the household on submit,
      // so the flow has to actually load that household first - with no
      // relations there are no existingModels and the UPDATE_EVENT would
      // silently no-op. Mirrors householdOverview's loading, trimmed to the
      // single entity this flow writes to.
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          }
        ],
        // Without this block search_executor bails out with
        // "No searchConfig in config, skipping search. primaryModel=null,
        // select=[]" - it never runs the query, so contextData['entities']
        // stays empty and the UPDATE_EVENT below finds nothing to write the
        // checklist answers onto. `relations` alone is not enough; the
        // search needs a primary entity and a select list, exactly as
        // householdOverview and previewScreen declare.
        "searchConfig": {
          "select": ["household"],
          "primary": "household"
        }
      },
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT"
          }
        }
      ]
    },
    {
      "body": [
        {
          "type": "template",
          "label": "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_HEADING",
          "format": "panelCard",
          "heading": "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_HEADING",
          "fieldName": "registrationHealthTalkSuccessCard",
          "mandatory": true,
          "properties": {"type": "success"},
          "description": "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_DESC",
          "additionalWidgets": [
            {
              "type": "template",
              "format": "labelPairList",
              "fieldName": "registrationHealthTalkSuccessLabelPairList",
              "data": [
                {
                  "key": "E_TOKEN",
                  "value":
                      "{{fn:getUniqueBeneficiaryId(contextData.0.headIndividual.IndividualModel.identifiers)}}",
                  "hideIfNull": true
                }
              ]
            }
          ],
          "primaryAction": {
            "type": "template",
            "label": "VIEW_HOUSEHOLD_DETAILS",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "data": [
                    {
                      "key": "HouseholdClientReferenceId",
                      "value": "{{navigation.HouseholdClientReferenceId}}"
                    },
                    {
                      "key": "ProjectBeneficiaryClientReferenceId",
                      "value":
                          "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                    }
                  ],
                  "name": "householdOverview",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "searchBeneficiary"
                }
              }
            ],
            "fieldName": "viewHouseholdButton",
            "mandatory": true,
            "properties": {"type": "primary"}
          },
          "secondaryAction": {
            "type": "template",
            "label": "GO_BACK",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "name": "searchBeneficiary",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndReplace",
                  "popUntilPageName": "searchBeneficiary"
                }
              },
              {
                "actionType": "REFRESH_SEARCH",
                "properties": {"screenName": "searchBeneficiary"}
              }
            ],
            "fieldName": "goBack",
            "mandatory": true,
            "properties": {"type": "secondary"}
          },
          "primaryActionLabel": "VIEW_HOUSEHOLD_DETAILS",
          "secondaryActionLabel": "GO_BACK"
        }
      ],
      "name": "registrationHealthTalkSuccess",
      "order": 15,
      "footer": [],
      "onSystemBack": [
        {
          "actionType": "NAVIGATION",
          "properties": {
            "name": "searchBeneficiary",
            "type": "TEMPLATE",
            "navigationMode": "popUntilAndReplace",
            "popUntilPageName": "searchBeneficiary"
          }
        },
        {
          "actionType": "REFRESH_SEARCH",
          "properties": {"screenName": "searchBeneficiary"}
        }
      ],
      "header": [
        {
          "type": "template",
          "label": "DELIVERY_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "name": "searchBeneficiary",
                "type": "TEMPLATE",
                "navigationMode": "popUntilAndReplace",
                "popUntilPageName": "searchBeneficiary"
              }
            },
            {
              "actionType": "REFRESH_SEARCH",
              "properties": {"screenName": "searchBeneficiary"}
            }
          ],
          "fieldName": "registrationHealthTalkSuccessBack",
          "mandatory": true
        }
      ],
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "submitCondition": null,
      "preventScreenCapture": false,
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}",
                "operation": "equals"
              }
            ],
            "name": "household",
            "type": "SEARCH_EVENT"
          }
        }
      ],
      "wrapperConfig": {
        "filters": [],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {"field": "isHeadOfHousehold", "equals": true}
            ]
          },
          {
            "name": "headIndividual",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "headOfHousehold.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          }
        ],
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": ["household", "individual", "householdMember"],
          "primary": "household"
        }
      }
    },
    {
      "name": "DELIVERY",
      "order": 10,
      "pages": [
        {
          "body": null,
          "flow": "DELIVERY",
          "page": "DeliveryDetails",
          "type": "object",
          "label": "APPONE_REGISTRATION_DELIVERYINTERVENTION_SCREEN_HEADING",
          "order": 1,
          "footer": [
            {
              "label":
                  "APPONE_REGISTRATION_DELIVERYDETAILS_ACTION_BUTTON_LABEL_1",
              "format": "button",
              "fieldName": "deliveryDetailsSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "name": "DeliveryChecklist",
                    "type": "template"
                  }
                }
              ],
              "properties": {
                "size": "large",
                "type": "primary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              }
            }
          ],
          "module": "REGISTRATION",
          "heading": "APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "OPEN_POPUP",
                  "properties": {
                    "popupConfig": {
                      "body": [
                        {
                          "type": "template",
                          "value": "{{fn:getInsufficientStockMessage()}}",
                          "format": "textTemplate",
                          "fieldName": "insufficientStockMessageText",
                          "maxLines": 8,
                          "properties": {"textAlign": "center"}
                        }
                      ],
                      "title": "INSUFFICIENT_STOCK_TITLE",
                      "titleIcon": "Warning",
                      "type": "alert",
                      "footerActions": [
                        {
                          "type": "template",
                          "label": "GO_BACK",
                          "format": "button",
                          "onAction": [
                            {
                              "actionType": "CLOSE_POPUP",
                              "properties": {"parentScreenKey": "DELIVERY"}
                            }
                          ],
                          "fieldName": "closeInsufficientStockPopUp",
                          "properties": {
                            "size": "large",
                            "type": "primary",
                            "mainAxisSize": "max"
                          }
                        }
                      ],
                      "showCloseButton": true,
                      "barrierDismissible": true
                    }
                  }
                }
              ],
              "condition": {
                "expression":
                    "{{fn:hasStockForDelivery(contextData.0.eligibleProductVariants)}} == false"
              }
            }
          ],
          "navigateTo": {"name": "DeliveryChecklist", "type": "template"},
          "properties": [
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_DELIVERYDETAILS_label_dateOfDelivery",
              "order": 1,
              "value": "",
              "format": "date",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "fieldName": "dateOfRegistration",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            },
            {
              "type": "integer",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount",
              "order": 1,
              "value": "{{navigation.memberCount}}",
              "format": "numeric",
              "hidden": false,
              "isMdms": false,
              "disabled": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "fieldName": "memberCount",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            },
            {
              "type": "dynamic",
              "enums": [
                {"code": "SP1", "name": "SP1"},
                {"code": "SP2", "name": "SP2"},
                {"code": "AQ1", "name": "AQ1"},
                {"code": "AQ2", "name": "AQ2"}
              ],
              "label": "APPONE_REGISTRATION_DELIVERYDETAILS_label_resource",
              "order": 2,
              "value": "",
              "format": "custom",
              "hidden": false,
              "isMdms": false,
              "disabled": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "required": true,
              "fieldName": "resourceCard",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message": "REGISTRATION_RESOURCE_CARD_SELECTION_REQUIRED"
                }
              ],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "dropDownOptions": [
                {"code": "SP1", "name": "SP1"},
                {"code": "SP2", "name": "SP2"},
                {"code": "AQ1", "name": "AQ1"},
                {"code": "AQ2", "name": "AQ2"}
              ],
              "includeInSummary": true,
              "required.message":
                  "REGISTRATION_RESOURCE_CARD_SELECTION_REQUIRED"
            },
            {
              "type": "string",
              "enums": [
                {"code": "SUCCESSFUL_DELIVERY", "name": "SUCCESSFUL_DELIVERY"}
              ],
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_deliveryComments",
              "order": 3,
              "value": "",
              "format": "dropdown",
              "hidden": true,
              "isMdms": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "deliveryComment",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "HCM.DELIVERY_COMMENT_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_DELIVERYDETAILS_label_scanner",
              "order": 5,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "scanner",
              "mandatory": false,
              "showLabel": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {"type": "isGS1Code", "value": true},
                {"type": "scanLimit", "value": 3},
                {"type": "allowManualEntry", "value": true},
                {
                  // Was "^[!-~]{1,20}$" - any 1-20 printable characters, so
                  // a manually typed "sjfk" passed. Same guard-rail as the
                  // Liberia branch (4f3cbadc3): uppercase alphanumeric with
                  // hyphens allowed, minimum 8 characters. Rejects short /
                  // lowercase junk while still accepting GTIN-style digits
                  // and XXXX-XXXX-XXXX codes.
                  // TIGHTEN once the real code format is confirmed - and
                  // note a non-matching manual code is rejected with a toast
                  // here, so an over-strict pattern blocks valid codes.
                  "type": "manualSerialPattern",
                  "value": "^[A-Z0-9][A-Z0-9-]{7,}\$",
                  "message": "APPONE_REGISTRATION_DELIVERYDETAILS_label_scanner_serial_pattern_message"
                }
              ],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            },
            {
              "type": "string",
              "label": "APPONE_DELIVERYDETAILS_LATLNG_LABEL",
              "order": 4,
              "value": "",
              "format": "latLng",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "latLng",
              "mandatory": false,
              "showLabel": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            }
          ],
          "actionLabel":
              "APPONE_REGISTRATION_DELIVERYDETAILS_ACTION_BUTTON_LABEL_2",
          "description":
              "APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_DESCRIPTION",
          "showTabView": false,
          "showAlertPopUp": {
            "title": "APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE",
            "conditions": [],
            "description":
                "APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_DESCRIPTION",
            "primaryActionLabel": "ACTION_SUBMIT",
            "secondaryActionLabel": "ACTION_CANCEL"
          },
          "submitCondition": null,
          "preventScreenCapture": false
        },
        {
          "body": null,
          "flow": "DELIVERY",
          "page": "DeliveryChecklist",
          "type": "object",
          "label": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_HEADING",
          "order": 2,
          "footer": [
            {
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
              "format": "button",
              "fieldName": "deliveryChecklistSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "name": "household-acknowledgement",
                    "type": "template"
                  }
                }
              ],
              "properties": {
                "size": "large",
                "type": "primary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              }
            }
          ],
          "module": "REGISTRATION",
          "heading":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "data": [
                  // The delivery transformer reads each of these as
                  // "__context:<key>". A key absent here resolves to null
                  // and is dropped SILENTLY, which is why the saved
                  // TaskModel carried only quantity/productVariant/
                  // dateOfAdministration/scanResource. Names follow what
                  // the transformer expects, not what navigation calls
                  // them - hence headName/headMobileNumber.
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  },
                  {"key": "memberCount", "value": "{{navigation.memberCount}}"},
                  {
                    "key": "beneficiaryId",
                    "value": "{{navigation.beneficiaryId}}"
                  },
                  {
                    "key": "headName",
                    "value":
                        "{{fn:fullName(navigation.nameOfIndividual, navigation.lastName)}}"
                  },
                  {
                    "key": "headMobileNumber",
                    "value": "{{navigation.headMobileNumber}}"
                  },
                  {
                    "key": "childrenCount",
                    "value": "{{navigation.childrenCount}}"
                  },
                  {
                    "key": "pregnantWomenCount",
                    "value": "{{navigation.pregnantWomenCount}}"
                  },
                  {
                    "key": "identificationType",
                    "value": "{{navigation.identificationType}}"
                  },
                  {
                    "key": "identificationNumber",
                    "value": "{{navigation.identificationNumber}}"
                  },
                  // The task being written IS the delivery, so this is
                  // true by construction. Reading navigation.isDelivered
                  // here recorded the state BEFORE this delivery - computed
                  // back on householdOverview - so a first delivery always
                  // stored false.
                  {"key": "isDelivered", "value": "true"},
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  },
                  {"key": "cycleIndex", "value": "{{navigation.cycleIndex}}"},
                  {"key": "doseIndex", "value": "{{navigation.doseIndex}}"},
                  {
                    "key": "deliveryStrategy",
                    "value": "{{navigation.deliveryStrategy}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to fetch config."}
                  }
                ],
                "configName": "delivery"
              }
            },
            {
              "actionType": "CREATE_EVENT",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to create household."}
                  }
                ]
              }
            },
            {
              "actionType": "REFRESH_SEARCH",
              "properties": {"screenName": "searchBeneficiary"}
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  },
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  }
                ],
                "name": "deliverySuccess",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Navigation failed."}
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "householdOverview"
              }
            }
          ],
          "navigateTo": {
            "name": "household-acknowledgement",
            "type": "template"
          },
          "properties": [
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_RECEIVE_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION1",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_TRUCK_IN_THE_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION2",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_ROLL_UP_NET",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION3",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_NET_IS_DIRTY",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION4",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_MEND_YOUR_NETS",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION5",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_THE_NET_PROTECTS",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION6",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_PROTECT_FROM_MALERIA",
              "order": 1,
              "value": "",
              "format": "checkbox",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "ACTION7",
              "required": true,
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            }
          ],
          "actionLabel":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
          "description":
              "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_DESCRIPTION",
          "showTabView": false,
          "submitCondition": null,
          "preventScreenCapture": false,
          "conditionalNavigateTo": null,
          "showAlertPopUp": {
            "title": "APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE",
            "description": "HOUSEHOLD_CHECKLIST_SUBMIT_DESCRIPTION",
            "primaryActionLabel": "ACTION_SUBMIT",
            "secondaryActionLabel": "ACTION_CANCEL"
          }
        }
      ],
      "summary": false,
      "version": 3,
      "category": "DELIVERY",
      "disabled": false,
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "data": [
                  // The delivery transformer reads each of these as
                  // "__context:<key>". A key absent here resolves to null
                  // and is dropped SILENTLY, which is why the saved
                  // TaskModel carried only quantity/productVariant/
                  // dateOfAdministration/scanResource. Names follow what
                  // the transformer expects, not what navigation calls
                  // them - hence headName/headMobileNumber.
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  },
                  {"key": "memberCount", "value": "{{navigation.memberCount}}"},
                  {
                    "key": "beneficiaryId",
                    "value": "{{navigation.beneficiaryId}}"
                  },
                  {
                    "key": "headName",
                    "value":
                        "{{fn:fullName(navigation.nameOfIndividual, navigation.lastName)}}"
                  },
                  {
                    "key": "headMobileNumber",
                    "value": "{{navigation.headMobileNumber}}"
                  },
                  {
                    "key": "childrenCount",
                    "value": "{{navigation.childrenCount}}"
                  },
                  {
                    "key": "pregnantWomenCount",
                    "value": "{{navigation.pregnantWomenCount}}"
                  },
                  {
                    "key": "identificationType",
                    "value": "{{navigation.identificationType}}"
                  },
                  {
                    "key": "identificationNumber",
                    "value": "{{navigation.identificationNumber}}"
                  },
                  // The task being written IS the delivery, so this is
                  // true by construction. Reading navigation.isDelivered
                  // here recorded the state BEFORE this delivery - computed
                  // back on householdOverview - so a first delivery always
                  // stored false.
                  {"key": "isDelivered", "value": "true"},
              {
                "key": "ProjectBeneficiaryClientReferenceId",
                "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
              },
              {
                "key": "deliveryComment",
                "value": "{{navigation.deliveryComment}}"
              }
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to fetch config."}
              }
            ],
            "configName": "delivery"
          }
        },
        {
          "actionType": "CREATE_EVENT",
          "properties": {
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to create household."}
              }
            ]
          }
        },
        {
          "actionType": "UPDATE_STOCK_BALANCE",
          "properties": {
            "entity": "TaskModel",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to update stock balance."}
              }
            ]
          }
        },
        {
          "actionType": "REFRESH_SEARCH",
          "properties": {"screenName": "searchBeneficiary"}
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "data": [
              {
                "key": "ProjectBeneficiaryClientReferenceId",
                "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
              },
              {
                "key": "HouseholdClientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}"
              },
              {"key": "beneficiaryId", "value": "{{navigation.beneficiaryId}}"}
            ],
            "name": "deliverySuccess",
            "type": "TEMPLATE",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Navigation failed."}
              }
            ],
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "householdOverview"
          }
        }
      ],
      "isSelected": true,
      "screenType": "FORM",
      "initActions": [],
      "wrapperConfig": {},
      "scrollListener": {}
    },
    {
      "name": "HOUSEHOLD",
      "order": 2,
      "pages": [
        {
          "body": null,
          "flow": "HOUSEHOLD",
          "page": "householdDetails",
          "type": "object",
          "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_SCREEN_HEADING",
          "order": 4,
          "footer": [
            {
              "label":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_ACTION_BUTTON_LABEL_1",
              "format": "button",
              "fieldName": "householdDetailsSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {"name": "beneficiaryDetails", "type": "form"}
                }
              ],
              "properties": {
                "size": "large",
                "type": "primary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              }
            }
          ],
          "module": "REGISTRATION",
          "heading": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel, IndividualModel, TaskModel",
                    "modify": [
                      {"key": "TaskModel.status", "value": "NOT_ADMINISTERED"}
                    ],
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to update closed household."
                        }
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      },
                      {"key": "isEdit", "value": "true"},
                      {"key": "isClosedHousehold", "value": "true"},
                      {"key": "registrationPendingHealthTalk", "value": "true"}
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                  }
                }
              ],
              "condition": {
                "type": "custom",
                "expression": "isEdit==true && isClosedHousehold==true"
              }
            },
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel, IndividualModel",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to update household."}
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {"type": "custom", "expression": "isEdit==true"}
            },
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to create household."}
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      },
                      {"key": "registrationPendingHealthTalk", "value": "true"}
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "navigateTo": {"name": "beneficiaryDetails", "type": "form"},
          "properties": [
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration",
              "order": 1,
              "value": "",
              "format": "date",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "required": true,
              "fieldName": "dateOfRegistration",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration_mandatory_message"
            },
            {
              "type": "string",
              "label": "HOUSEHOLD_FIRST_NAME",
              "order": 2,
              "value": "",
              "format": "text",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "nameOfIndividual",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "maxLength": "200",
                "minLength": "2",
                "errorMessage":
                    "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName",
              "order": 2,
              "value": "",
              "format": "text",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_helpText",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "familyname",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_mandatory_message"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_min_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_mandatory_message"
            },
            {
              "type": "string",
              "label": "",
              "order": 2.5,
              "value": "MALE",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "required": false,
              "fieldName": "gender",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone",
              "order": 3,
              "value": "",
              "format": "mobileNumber",
              "hidden": false,
              "isMdms": false,
              "pattern": "^\\d+",
              "tooltip":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_tooltip",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_helpText",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "phone",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "maxLength": 9,
                "minLength": 9,
                "errorMessage": "MOBILE_LENGTH_9_DIGIT_ERROR"
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "MOBILE_LENGTH_9_DIGIT_ERROR"
                },
                {
                  "type": "pattern",
                  "value": "^\\d+",
                  "message": "MB_ONLY_NUMBER"
                },
                {
                  "type": "minLength",
                  "value": 9,
                  "message": "MOBILE_LENGTH_9_DIGIT_ERROR"
                },
                {
                  "type": "maxLength",
                  "value": 9,
                  "message": "MOBILE_LENGTH_9_DIGIT_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "MOBILE_LENGTH_9_DIGIT_ERROR",
              "pattern.message": "MB_ONLY_NUMBER"
            },
            {
              "type": "integer",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount",
              "order": 4,
              "range": {
                "max": "30",
                "min": "1",
                "errorMessage":
                    "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message"
              },
              "value": "1",
              "format": "numeric",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "memberCount",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_mandatory_message"
                },
                {
                  "type": "min",
                  "value": "1",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_min_message"
                },
                {
                  "type": "max",
                  "value": "30",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_mandatory_message"
            },
            {
              "type": "integer",
              "label":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount",
              "order": 5,
              "range": {
                "max": "30",
                "min": "0",
                "errorMessage":
                    "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message"
              },
              "value": "0",
              "format": "numeric",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "childrenCount",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_mandatory_message"
                },
                {
                  "type": "min",
                  "value": "0",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_min_message"
                },
                {
                  "type": "max",
                  "value": "100",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message"
                },
                {
                  // memberCount - 1: a household always has at least one
                  // non-child member (the head), so children can never equal
                  // the total.
                  "type": "maxField",
                  "value": {"field": "memberCount", "offset": -1},
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_maxField_message"
                },
                {
                  "type": "maxFieldSum",
                  "value": {
                    "with": "pregnantWomenCount",
                    "maxField": "memberCount"
                  },
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenAndPregnantWomen_maxFieldSum_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "integer",
              "label":
                  "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount",
              "order": 6,
              "value": "0",
              "format": "numeric",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "pregnantWomenCount",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount_mandatory_message"
                },
                {
                  "type": "min",
                  "value": "0",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount_min_message"
                },
                {
                  "type": "max",
                  "value": "30",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount_max_message"
                },
                {
                  "type": "maxField",
                  "value": "memberCount",
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount_maxField_message"
                },
                {
                  "type": "maxFieldSum",
                  "value": {"with": "childrenCount", "maxField": "memberCount"},
                  "message":
                      "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenAndPregnantWomen_maxFieldSum_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "boolean",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily",
              "order": 7,
              "value": "true",
              "format": "checkbox",
              "hidden": true,
              "includeInForm": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "isHeadOfFamily",
              "mandatory": false,
              "showLabel": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily_mandatory_message"
            },
            {
              "type": "string",
              "enums": [
                {"code": "NATIONAL_ID", "name": "NATIONAL_ID"},
                {"code": "DRIVERS_LICENSE", "name": "DRIVERS_LICENSE"},
                {"code": "PASSPORT", "name": "PASSPORT"},
                {"code": "VOTER_ID", "name": "VOTER_ID"}
              ],
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationType",
              "order": 8,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "isMdms": true,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationType_helpText",
              "infoText": "",
              "readOnly": false,
              "required": false,
              "fieldName": "identificationType",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "HCM.IDENTIFICATION_TYPE_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "includeInSummary": true
            },
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber",
              "order": 9,
              "value": "",
              "format": "text",
              "hidden": false,
              "visible": "{{identificationType}} != ''",
              "isMdms": false,
              "pattern": "^[a-zA-Z0-9]+\$",
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_helpText",
              "infoText": "",
              "readOnly": false,
              "required": false,
              "fieldName": "identificationNumber",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "requiredIf",
                  "value": "identificationType",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_mandatory_message"
                },
                {
                  "type": "pattern",
                  "value": "^[a-zA-Z0-9]+\$",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_pattern_message"
                },
                {
                  "type": "conditionalPattern",
                  "value": {
                    "switchOn": "identificationType",
                    "cases": {
                      "NATIONAL_ID": {
                        "pattern": "^[A-Za-z0-9]{8}\$",
                        "message":
                            "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_nationalId_pattern_message"
                      },
                      "PASSPORT": {
                        "pattern": "^SLR[0-9]{6}\$",
                        "message":
                            "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_passport_pattern_message"
                      },
                      "VOTER_ID": {
                        "pattern": "^[0-9]{7}\$",
                        "message":
                            "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_voterId_pattern_message"
                      },
                      "DRIVERS_LICENSE": {
                        "pattern": "^[A-Za-z]{2}[0-9]{9}\$",
                        "message":
                            "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_driversLicense_pattern_message"
                      }
                    }
                  }
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "enums": [
                {"code": "DEFAULT", "name": "DEFAULT"},
                {
                  "code": "UNIQUE_BENEFICIARY_ID",
                  "name": "UNIQUE_BENEFICIARY_ID"
                }
              ],
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identifiers",
              "order": 10,
              "value": "",
              "format": "idPopulator",
              "hidden": true,
              "includeInForm": true,
              "isMdms": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "identifiers",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "HCM.ID_TYPE_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message"
            }
          ],
          "actionLabel":
              "APPONE_REGISTRATION_HOUSEHOLDDETAILS_ACTION_BUTTON_LABEL_1",
          "description":
              "APPONE_REGISTRATION_HOUSEHOLDDETAILS_SCREEN_DESCRIPTION",
          "showTabView": false,
          // Existing households submit their updated details here. New
          // registrations continue through beneficiaryDetails and location.
          "submitCondition": {
            "expression": [
              {"condition": "isEdit == true"}
            ]
          },
          "preventScreenCapture": false
        },
        {
          "body": null,
          "flow": "HOUSEHOLD",
          "page": "beneficiaryLocation",
          "type": "object",
          "label": "APPONE_REGISTRATION_BENEFICIARY_LOCATION_SCREEN_HEADING",
          "order": 1,
          "footer": [
            {
              "label":
                  "APPONE_REGISTRATION_BENEFICIARY_LOCATION_ACTION_BUTTON_LABEL_1",
              "format": "button",
              "fieldName": "beneficiaryLocationSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {"name": "caregiverConsent", "type": "form"}
                }
              ],
              "properties": {
                "size": "large",
                "type": "primary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              }
            }
          ],
          "module": "REGISTRATION",
          "heading": "APPONE_REGISTRATION_BENEFICIARY_LOCATION_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity":
                        "HouseholdModel, IndividualModel, TaskModel, TaskResourceModel",
                    "modify": [
                      {"key": "TaskModel.status", "value": "NOT_ADMINISTERED"}
                    ],
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to update closed household."
                        }
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {
                "type": "custom",
                "expression": "isEdit==true && isClosedHousehold==true"
              }
            },
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to update household."}
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {"type": "custom", "expression": "isEdit==true"}
            },
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to fetch config."}
                      }
                    ],
                    "configName": "beneficiaryRegistration",
                    "createEntities": ["ProjectBeneficiaryModel"]
                  }
                },
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Failed to create household."}
                      }
                    ]
                  }
                },
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "data": [
                      {
                        "key": "HouseholdClientReferenceId",
                        "value":
                            "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      },
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value":
                            "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {"message": "Navigation failed."}
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {"expression": "DEFAULT"}
            }
          ],
          "navigateTo": {"name": "caregiverConsent", "type": "form"},
          "properties": [
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_settlement",
              "order": 1,
              "value": "",
              "format": "locality",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_helpText",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "administrativeArea",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_mandatory_message"
            },
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_gps_coordinate_accuracy",
              "order": 2,
              "value": "",
              "format": "latLng",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_helpText",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "latLng",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_mandatory_message"
            },
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1",
              "order": 3,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "addressLine1",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "minLength": "2",
                "errorMessage":
                    "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_min_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "addressLine2",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "minLength": "2",
                "errorMessage":
                    "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_min_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark",
              "order": 5,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "landmark",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "minLength": "2",
                "errorMessage":
                    "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_min_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_pincode",
              "order": 6,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "pattern": "^\\d+",
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_pincode_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "pincode",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "pattern",
                  "value": "^\\d+",
                  "message": "PINCODE_ONLY_NUMBERS"
                }
              ],
              "errorMessage": "",
              "pattern.message": "PINCODE_ONLY_NUMBERS"
            },
            {
              "type": "string",
              "enums": [
                {"code": "PERMANENT", "name": "BENEFICIARYLOCATION_PERMANENT"},
                {
                  "code": "CORRESPONDENCE",
                  "name": "BENEFICIARYLOCATION_CORRESPONDENCE"
                },
                {"code": "OTHER", "name": "BENEFICIARYLOCATION_OTHER"}
              ],
              "label":
                  "APPONE_REGISTRATION_BENEFICIARY_LOCATION_label_typeOfAddress",
              "order": 7,
              "value": "PERMANENT",
              "format": "dropdown",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "typeOfAddress",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "includeInForm": true,
              "isMultiSelect": false,
              "dropDownOptions": [
                {"code": "PERMANENT", "name": "BENEFICIARYLOCATION_PERMANENT"},
                {
                  "code": "CORRESPONDENCE",
                  "name": "BENEFICIARYLOCATION_CORRESPONDENCE"
                },
                {"code": "OTHER", "name": "BENEFICIARYLOCATION_OTHER"}
              ],
              "includeInSummary": false
            }
          ],
          "actionLabel":
              "APPONE_REGISTRATION_BENEFICIARY_LOCATION_ACTION_BUTTON_LABEL_BEDNET_NEXT",
          "description": "",
          "showTabView": false,
          "submitCondition": null,
          "preventScreenCapture": false
        },
        {
          "body": null,
          "flow": "HOUSEHOLD",
          "page": "caregiverConsent",
          "type": "object",
          "label": "APPONE_REGISTRATION_CAREGIVER_CONSENT_SCREEN_HEADING",
          "order": 2,
          "module": "REGISTRATION",
          "heading": "APPONE_REGISTRATION_CAREGIVER_CONSENT_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [],
          "properties": [
            {
              "type": "string",
              "enums": [
                {"code": "TRUE", "name": "APPONE_CAREGIVER_CONSENT_YES"},
                {"code": "FALSE", "name": "APPONE_CAREGIVER_CONSENT_NO"}
              ],
              "label":
                  "APPONE_REGISTRATION_CAREGIVER_CONSENT_label_consentToParticipate",
              "order": 1,
              "value": "",
              "format": "radio",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "consentToParticipate",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_REGISTRATION_CAREGIVER_CONSENT_label_consentToParticipate_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message":
                  "APPONE_REGISTRATION_CAREGIVER_CONSENT_label_consentToParticipate_mandatory_message"
            },
            {
              "type": "string",
              "label": "HOUSEHOLD_FIRST_NAME",
              "order": 2,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "nameOfIndividual",
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              // Optional, same as Closed Household's headName/familyname -
              // declining consent means no full registration interview
              // happened, so there's no reliable source for a name yet. Only
              // shown/collected when consent is declined; the full
              // Registration flow's own (mandatory) name fields are what
              // capture it once consent later becomes Yes.
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "caregiverConsent.consentToParticipate==FALSE",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName",
              "order": 3,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText":
                  "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_helpText",
              "infoText": "",
              "readOnly": false,
              "fieldName": "familyname",
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "caregiverConsent.consentToParticipate==FALSE",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_min_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message":
                      "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            }
          ],
          "actionLabel":
              "APPONE_REGISTRATION_CAREGIVER_CONSENT_ACTION_BUTTON_LABEL_1",
          "showTabView": false,
          "submitCondition": null,
          "preventScreenCapture": false,
          "conditionalNavigateTo": [
            {
              "condition": "caregiverConsent.consentToParticipate==TRUE",
              "navigateTo": {"name": "householdDetails", "type": "form"}
            },
            {
              "condition":
                  "caregiverConsent.consentToParticipate==FALSE && navigation.isEdit==true && navigation.isClosedHousehold==true",
              "navigateTo": {
                "name": "caregiverAcknowledgement",
                "type": "TEMPLATE"
              }
            },
            {
              "condition": "caregiverConsent.consentToParticipate==FALSE",
              "navigateTo": {
                "name": "caregiverAcknowledgement",
                "type": "submit"
              }
            }
          ]
        }
      ],
      "summary": false,
      "version": 3,
      "category": "REGISTRATION",
      "disabled": false,
      "onAction": [
        {
          "actions": [
            {"actionType": "GENERATE_LOCAL_BENEFICIARY_ID"},
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to fetch config."}
                  }
                ],
                "createEntities": ["ProjectBeneficiaryModel"],
                "configName": "beneficiaryRegistration"
              }
            },
            {
              "actionType": "UPDATE_IDENTIFIER_STATUS",
              "properties": {
                "identifierType": "UNIQUE_BENEFICIARY_ID",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update beneficiary id status."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "CREATE_EVENT",
              "properties": {
                "entity": "ProjectBeneficiaryModel, IndividualModel",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update closed household."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "entity":
                    "HouseholdModel, IndividualModel, ProjectBeneficiaryModel",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update closed household."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value":
                        "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                  }
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Navigation failed."}
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "condition": {
            "type": "custom",
            "expression": "isEdit==true && isNotBeneficiary==true"
          }
        },
        {
          "actions": [
            {"actionType": "GENERATE_LOCAL_BENEFICIARY_ID"},
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to fetch config."}
                  }
                ],
                "configName": "beneficiaryRegistration",
                "createEntities": ["ProjectBeneficiaryModel"]
              }
            },
            {
              "actionType": "UPDATE_IDENTIFIER_STATUS",
              "properties": {
                "identifierType": "UNIQUE_BENEFICIARY_ID",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update beneficiary id status."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "entity": "HouseholdModel, IndividualModel, TaskModel",
                "modify": [
                  {"key": "TaskModel.status", "value": "NOT_ADMINISTERED"}
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update closed household."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{navigation.projectBeneficiaryClientReferenceId}}"
                  },
                  {"key": "registrationPendingHealthTalk", "value": "true"}
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Navigation failed."}
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "condition": {
            "type": "custom",
            "expression": "isEdit==true && isClosedHousehold==true"
          }
        },
        {
          "actions": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to fetch config."}
                  }
                ],
                "configName": "householdConsentDeclinedRegistration"
              }
            },
            {
              "actionType": "CREATE_EVENT",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to save household."}
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value":
                        "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                  }
                ],
                "name": "caregiverAcknowledgement",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Navigation failed."}
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "condition": {
            "type": "custom",
            "expression": "caregiverConsent.consentToParticipate==FALSE"
          }
        },
        {
          "actions": [
            {"actionType": "GENERATE_LOCAL_BENEFICIARY_ID"},
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to fetch config."}
                  }
                ],
                "configName": "beneficiaryRegistration",
                "createEntities": ["ProjectBeneficiaryModel"]
              }
            },
            {
              "actionType": "UPDATE_IDENTIFIER_STATUS",
              "properties": {
                "identifierType": "UNIQUE_BENEFICIARY_ID",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to update beneficiary id status."
                    }
                  }
                ]
              }
            },
            {
              "actionType": "CREATE_EVENT",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Failed to create household."}
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value":
                        "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value":
                        "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                  },
                  {"key": "registrationPendingHealthTalk", "value": "true"}
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {"message": "Navigation failed."}
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "condition": {"expression": "DEFAULT"}
        }
      ],
      "isSelected": true,
      "screenType": "FORM",
      "initActions": [],
      "wrapperConfig": {
        "filters": [
          {"field": "isHeadOfHousehold", "equals": true}
        ],
        "relations": [
          {
            "name": "household",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "householdClientReferenceId"
            },
            "entity": "HouseholdModel"
          },
          {
            "name": "members",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "household.clientReferenceId"
            },
            "entity": "HouseholdMemberModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "HouseholdMemberModel.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "individuals",
            "match": {
              "field": "clientReferenceId",
              "inFrom": "members.individualClientReferenceId"
            },
            "entity": "IndividualModel"
          },
          {
            "name": "projectBeneficiaries",
            "match": {
              "field": "beneficiaryClientReferenceId",
              "equalsFrom": "household.clientReferenceId"
            },
            "entity": "ProjectBeneficiaryModel"
          },
          {
            "name": "tasks",
            "match": {
              "field": "projectBeneficiaryClientReferenceId",
              "inFrom": "projectBeneficiaries.clientReferenceId"
            },
            "entity": "TaskModel"
          },
          {
            "name": "sideEffects",
            "match": {
              "field": "clientReferenceId",
              "equalsFrom": "household.clientReferenceId"
            },
            "entity": "SideEffectModel"
          },
          {
            "name": "hFReferral",
            "match": {
              "field": "beneficiaryId",
              "equalsFrom": "individual.identifiers.0.identifierId"
            },
            "entity": "HFReferralModel"
          }
        ],
        "rootEntity": "HouseholdMemberModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": [
            "individual",
            "household",
            "householdMember",
            "projectBeneficiary",
            "task"
          ],
          "primary": "household"
        },
        "computedList": {
          "pastCycles": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 6,
            "where": {
              "left": "{{item.id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "lt"
            }
          },
          "futureTasks": {
            "from": "{{tasks}}",
            "order": 2,
            "where": {
              "left": "{{item.additionalFields.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "targetCycle": {
            "from":
                "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": {
              "left": "{{id}}",
              "right": "{{currentRunningCycle}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "currentDelivery": {
            "from": "{{targetCycle.0.deliveries}}",
            "order": 4,
            "where": {
              "left": "{{id}}",
              "right": "{{nextDoseId}}",
              "operator": "equals"
            },
            "fallback": null,
            "takeLast": true
          },
          "futureDeliveries": {
            "from": "{{targetCycle.0.deliveries}}",
            "skip": {"from": "{{effectiveDose}}"},
            "order": 3,
            "where": {
              "left": "{{item.deliveryStrategy}}",
              "right": "INDIRECT",
              "operator": "equals"
            }
          },
          "eligibleProductVariants": {
            "from": "{{currentDelivery.0.doseCriteria}}",
            "order": 5,
            "fallback": [],
            "takeLast": false,
            "evaluateCondition": {
              "context": ["{{individuals.0}}", "{{household.0}}"],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {"type": "ageInMonths", "source": "dateOfBirth"}
              }
            }
          }
        }
      },
      "scrollListener": {}
    }
  ],
  "order": 1,
  "active": true,
  "project": "MR-DN",
  "version": 1,
  "disabled": false,
  "isSelected": true,
  "initialPage": "searchBeneficiary",
  "isActive": true,
  "auditDetails": {
    "createdBy": "b43b260c-f620-45d3-a43f-f53148f87f15",
    "lastModifiedBy": "f4e90853-80b7-47cc-91e7-f8cd5ec00e20",
    "createdTime": 1766988969631,
    "lastModifiedTime": 1773055228737
  }
};
