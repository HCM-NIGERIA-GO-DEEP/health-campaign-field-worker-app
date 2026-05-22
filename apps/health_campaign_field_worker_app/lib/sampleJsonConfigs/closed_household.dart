final dynamic sampleCloseHouseholdFlows = {
  "name": "CLOSEDHOUSEHOLD",
  "initialPage": "CLOSEHOUSEHOLD",
  "order": 7,
  "project": "LLIN-mz",
  "version": 1,
  "disabled": false,
  "isSelected": true,
  "flows": [

    {
      "screenType": "FORM",
      "name": "CLOSEHOUSEHOLD",
      "project": "LLIN-mz",
      "version": 1,
      "disabled": false,
      "isSelected": true,
      "pages": [
        {
          "page": "closeHouseholdDetails",
          "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_HEADING",
          "order": 1,
          "type": "object",
          "description": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_DESCRIPTION",
          "actionLabel": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_ACTION_LABEL",
          "properties": [
            {
              "type": "date",
              "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_date_LABEL",
              "order": 1,
              "value": "",
              "format": "date",
              "hidden": false,
              "tooltip": "",
              "helpText": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_date_HELP_TEXT",
              "infoText": "",
              "readOnly": true,
              "fieldName": "date",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": true,
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message":
                      "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_date_REQUIRED_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_settlement_LABEL",
              "order": 1,
              "value": "",
              "format": "locality",
              "hidden": false,
              "tooltip": "",
              "helpText":
                  "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_settlement_HELP_TEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "settlement",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_settlement_REQUIRED_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_latLng_LABEL",
              "order": 2,
              "value": "",
              "format": "latLng",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "latLng",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_latLng_REQUIRED_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_LABEL",
              "order": 3,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "headName",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInForm": true,
              "validations": [
                {
                  "type": "minLength",
                  "value": "3",
                  "message":
                      "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_MIN_LENGTH_ERROR"
                },
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": []
            },
            {
              "type": "string",
              "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_scanner_LABEL",
              "order": 4,
              "value": "",
              "format": "scanner",
              "hidden": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "scanner",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false
            }
          ],
          "value": null,
          "required": null,
          "hidden": null,
          "helpText": null,
          "innerLabel": null,
          "validations": null,
          "tooltip": null,
          "startDate": null,
          "endDate": null,
          "readOnly": null,
          "charCount": null,
          "systemDate": null,
          "isMultiSelect": null,
          "includeInForm": null,
          "includeInSummary": null,
          "autoEnable": null
        },
      ],
      "overView": "CLOSEHOUSEHOLD_SUMMARY_HEADING",
      "summary": false,
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "configName": "closeHouseholdRegistration",
            "data": [],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to fetch config."}
              }
            ]
          }
        },
        {
          "actionType": "CREATE_EVENT",
          "properties": {
            "entity":
                "HouseholdModel, IndividualModel, ProjectBeneficiaryModel, HouseholdMemberModel, TaskModel",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Failed to create stock."}
              }
            ]
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "closedHouseholdSummary",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "Navigation failed."}
              }
            ],
            "data": [
              {
                "key": "HouseholdClientReferenceId",
                "value":
                    "{{entities.HouseholdModel.clientReferenceId}}"
              }
            ]
          }
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "order": 4,
      "name": "closedHouseholdSummary",
      "heading": "CLOSEHOUSEHOLD_SUMMARY_HEADING",
      "description": "CLOSEHOUSEHOLD_SUMMARY_DESCRIPTION",
      "header": [
        {
          "label": "CLOSEHOUSEHOLD_SUMMARY_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {"type": "BACK"}
            }
          ]
        }
      ],
      "footer": [
        {
          "type": "template",
          "label": "CLOSEHOUSEHOLD_SUMMARY_NEXT_ACTION_LABEL",
          "format": "button",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "closeHouseholdSuccess",
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value":
                        "{{contextData.0.household.HouseholdModel.clientReferenceId}}"
                  }
                ]
              }
            }
          ],
          "fieldName": "nextButton",
          "properties": {
            "size": "large",
            "type": "primary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          }
        }
      ],
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
      "body": [
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_HEAD_NAME",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "ADMINISTRATIVE_AREA",
                  "value":
                      "{{contextData.0.household.HouseholdModel.address.locality.code}}",
                  "isActive": true
                },
                {
                  "key": "MEMBER_COUNT",
                  "value":
                      "{{contextData.0.household.HouseholdModel.memberCount}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "closedHouseholdSummaryDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        }
      ],
      "wrapperConfig": {
        "rootEntity": "HouseholdModel",
        "wrapperName": "HouseholdWrapper",
        "searchConfig": {
          "select": ["household", "individual", "householdMember"],
          "primary": "household"
        },
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
        ]
      }
    },
    {
      "screenType": "TEMPLATE",
      "order": 3,
      "name": "closeHouseholdSuccess",
      "heading": "",
      "description": "",
      "header": [],
      "footer": [],
      "initActions": [],
      "body": [
        {
          "type": "template",
          "format": "panelCard",
          "label": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_HEADING",
          "description": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_DESCRIPTION",
          "properties": {"type": "success"},
          "primaryAction": {
            "label":
                "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_PRIMARY_ACTION_LABEL",
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {"type": "HOME"}
              }
            ]
          },
          "secondaryAction": {
            "label":
                "CLOSEHOUSEHOLD_CLOSEHOUSEHOLD_SUCCESS_SECONDARY_ACTION_LABEL",
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "type": "TEMPLATE",
                  "name": "closedHouseholdSummary",
                  "data": [
                    {
                      "key": "HouseholdClientReferenceId",
                      "value": "{{navigation.HouseholdClientReferenceId}}"
                    }
                  ]
                }
              }
            ]
          }
        }
      ]
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
                  "key": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_DATE_LABEL",
                  "value":
                      "",
                  "isActive": true
                },
                {
                  "key": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_SETTLEMENT_LABEL",
                  "value":
                      "",
                  "isActive": true
                },
                {
                  "key": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_HOUSEHOLD_HEAD_NAME_LABEL",
                  "value":
                      "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_GPS_ACCURACY_LABEL",
                  "value":
                      "",
                  "isActive": true
                },
                // {
                //   "key": "HOUSEHOLD_HEAD_NAME",
                //   "value":
                //       "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                //   "isActive": true
                // },
                // {
                //   "key": "CLOSEHOUSEHOLD_SUMMARY_SETTLEMENT",
                //   "value":
                //       "{{contextData.0.household.HouseholdModel.memberCount}}",
                //   "isActive": true
                // },
                // {
                //   "key": "NUMBER_OF_ITN_FOR_DELIVERY",
                //   "value": "",
                //   "isActive": true
                // }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {"type": "primary", "cardType": "primary"},
          "schemaCode": null
        },
       
      ],
      "name": "closedHouseholdSummary",
      "order": 2,
      "footer": [
        {
          "type": "template",
          "label": "REGISTER_BENEFICIARY",
          "format": "button",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value": "{{navigation.test0012}}"
                  },
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  }
                ],
                "name": "DELIVERY",
                "type": "FORM"
              }
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
      ],
      "header": [
        {
          "label": "HOUSEHOLD_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {"name": "CLOSEHOUSEHOLD", "type": "FORM"}
            }
          ]
        }
      ],
      "heading": "",
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "description": "",
      "initActions": [
        {"actionType": "LOAD_UNIQUE_ID_POOL"},
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
        }
      },
      "submitCondition": null,
      "preventScreenCapture": false
    },
  ]
};