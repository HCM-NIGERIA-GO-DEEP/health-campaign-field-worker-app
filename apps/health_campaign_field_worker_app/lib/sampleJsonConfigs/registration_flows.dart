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
          "properties": {
            "type": "success"
          },
          "description": "DELIVERY_SUCCESSFUL_PANEL_CARD_DESC",
          "additionalWidgets": [
            {
              "type": "template",
              "format": "labelPairList",
              "fieldName": "successCardLabelPairList",
              "data": [
                {
                  "key": "E_TOKEN",
                  "value": "{{contextData.0.headIndividual.IndividualModel.identifiers.0.identifierId}}"
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
                      "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
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
                  "name": "previewScreen",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "searchBeneficiary"
                }
              }
            ],
            "fieldName": "viewHouseholdButton",
            "mandatory": true,
            "properties": {
              "type": "primary"
            }
          },
          "secondaryAction": {
            "type": "template",
            "label": "GO_BACK",
            "format": "button",
            "hidden": false,
            "onAction": [
              {
                "actionType": "REFRESH_SEARCH",
                "properties": {
                  "screenName": "searchBeneficiary"
                }
              },
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "name": "searchBeneficiary",
                  "type": "TEMPLATE",
                  "navigationMode": "popUntilAndReplace",
                  "popUntilPageName": "searchBeneficiary"
                }
              }
            ],
            "fieldName": "goBack",
            "mandatory": true,
            "properties": {
              "type": "secondary"
            }
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
          "actionType": "REFRESH_SEARCH",
          "properties": {
            "screenName": "searchBeneficiary"
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "name": "searchBeneficiary",
            "type": "TEMPLATE",
            "navigationMode": "popUntilAndReplace",
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
              "actionType": "REFRESH_SEARCH",
              "properties": {
                "screenName": "searchBeneficiary"
              }
            },
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
              {
                "field": "isHeadOfHousehold",
                "equals": true
              }
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {
                "left": "{{startDate}}",
                "right": "{{now}}",
                "operator": "lt"
              },
              {
                "left": "{{endDate}}",
                "right": "{{now}}",
                "operator": "gt"
              }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {
                  "value": "{{dose}}",
                  "operation": "increment"
                }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {
                  "value": "{{cycle}}",
                  "operation": "increment"
                },
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "skip": {
              "from": "{{effectiveDose}}"
            },
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
              "context": [
                "{{individuals.0}}",
                "{{household.0}}"
              ],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {
                  "type": "ageInMonths",
                  "source": "dateOfBirth"
                }
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
          "format": "card",
          "children": [
            {
              "data": [
                {
                  "key": "HOUSEHOLD_FIRST_NAME",
                  "value": "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "HOUSEHOLD_LAST_NAME",
                  "value": "{{contextData.0.headIndividual.IndividualModel.name.familyName}}",
                  "isActive": true
                },
                {
                  "key": "MEMBER_COUNT",
                  "value": "{{contextData.0.household.HouseholdModel.memberCount}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {
            "type": "primary",
            "cardType": "primary"
          },
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
                  "value": "{{contextData.0.headIndividual.IndividualModel.mobileNumber}}",
                  "isActive": true
                },
                {
                  "key": "E_TOKEN",
                  "value": "{{contextData.0.headIndividual.IndividualModel.identifiers.0.identifierId}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {
            "type": "primary",
            "cardType": "primary"
          },
          "schemaCode": null
        },
        {
          "type": "template",
          "format": "card",
          "children": [
            {
              "type": "template",
              "child": {
                "type": "template",
                "format": "card",
                "children": [
                  {
                    "type": "template",
                    "format": "row",
                    "children": [
                      {
                        "type": "template",
                        "format": "column",
                        "children": [
                          {
                            "type": "template",
                            "visible": "{{fn:hasBeneficiaryId(item.individual.0.identifiers.0)}}==true",
                            "label": "{{ item.individual.0.identifiers.0.identifierId }}",
                            "format": "tag",
                            "fieldName": "isHead"
                          },
                          {
                            "type": "template",
                            "visible": "{{fn:hasBeneficiaryId(item.individual.0.identifiers.0)}}==false",
                            "label": "NO_BENEFICIARY_ID",
                            "format": "tag",
                            "fieldName": "isHead"
                          }
                        ]
                      },
                      {
                        "type": "template",
                        "label": "REGISTRATION_EDIT_INDIVIDUAL_BUTTON_LABEL",
                        "format": "button",
                        "visible": "{{fn:hasRole('REGISTRAR')}} == true",
                        "disabled": "{{fn:disableEdit(item.task, item.hFReferral)}}==true",
                        "onAction": [
                          {
                            "actions": [
                              {
                                "actionType": "REVERSE_TRANSFORM",
                                "properties": {
                                  "data": [
                                    {
                                      "key": "entities",
                                      "value": "{{item.individual}}"
                                    },
                                    {
                                      "key": "entities",
                                      "value": "{{item.projectBeneficiary}}"
                                    }
                                  ],
                                  "configName": "individualRegistration",
                                  "entityTypes": [
                                    "IndividualModel",
                                    "ProjectBeneficiaryModel"
                                  ]
                                }
                              },
                              {
                                "actionType": "NAVIGATION",
                                "properties": {
                                  "data": [
                                    {
                                      "key": "HouseholdClientReferenceId",
                                      "value": "{{item.member.0.householdClientReferenceId}}"
                                    },
                                    {
                                      "key": "isEdit",
                                      "value": "true"
                                    },
                                    {
                                      "key": "isHead",
                                      "value": "{{fn:isHead(item.member)}}"
                                    },
                                    {
                                      "key": "UNIQUE_BENEFICIARY_ID",
                                      "value": "{{latestBeneficiaryId}}"
                                    }
                                  ],
                                  "name": "ADD_MEMBER",
                                  "type": "FORM"
                                }
                              }
                            ],
                            "condition": {
                              "type": "custom",
                              "expression": "{{fn:hasBeneficiaryId(item.individual.0.identifiers.0)}}==false"
                            }
                          },
                          {
                            "actions": [
                              {
                                "actionType": "REVERSE_TRANSFORM",
                                "properties": {
                                  "data": [
                                    {
                                      "key": "entities",
                                      "value": "{{item.individual}}"
                                    },
                                    {
                                      "key": "entities",
                                      "value": "{{item.projectBeneficiary}}"
                                    }
                                  ],
                                  "configName": "individualRegistration",
                                  "entityTypes": [
                                    "IndividualModel",
                                    "ProjectBeneficiaryModel"
                                  ]
                                }
                              },
                              {
                                "actionType": "NAVIGATION",
                                "properties": {
                                  "data": [
                                    {
                                      "key": "HouseholdClientReferenceId",
                                      "value": "{{item.member.0.householdClientReferenceId}}"
                                    },
                                    {
                                      "key": "isEdit",
                                      "value": "true"
                                    },
                                    {
                                      "key": "isHead",
                                      "value": "{{fn:isHead(item.member)}}"
                                    }
                                  ],
                                  "name": "ADD_MEMBER",
                                  "type": "FORM"
                                }
                              }
                            ],
                            "condition": {
                              "type": "custom",
                              "expression": "{{fn:hasBeneficiaryId(item.individual.0.identifiers.0)}}==true"
                            }
                          }
                        ],
                        "fieldName": "editIndividualButton",
                        "properties": {
                          "icon": "Edit",
                          "size": "large",
                          "type": "tertiary",
                          "mainAxisSize": "min",
                          "mainAxisAlignment": "center"
                        }
                      }
                    ],
                    "fieldName": "individualRow",
                    "properties": {
                      "bottomGap": 16,
                      "mainAxisSize": "max",
                      "mainAxisAlignment": "spaceBetween"
                    }
                  },
                  {
                    "type": "template",
                    "value": "{{ item.individual.0.name.givenName }} {{ item.individual.0.name.familyName }}",
                    "format": "textTemplate",
                    "fieldName": "individualName",
                    "properties": {
                      "bottomGap": 16
                    }
                  },
                  {
                    "type": "template",
                    "value": "{{item.individual.0.gender }} | {{fn:formatDate(item.individual.0.dateOfBirth, 'age')}}",
                    "format": "textTemplate",
                    "fieldName": "genderAge",
                    "properties": {
                      "bottomGap": 16
                    }
                  },
                  {
                    "type": "template",
                    "label": "IS_HEAD",
                    "format": "tag",
                    "visible": "{{fn:isHead(item.member)}}",
                    "fieldName": "isHead",
                    "properties": {
                      "tagType": "error",
                      "bottomGap": 16
                    }
                  }
                ],
                "fieldName": "memberCard",
                "properties": {
                  "type": "secondary",
                  "spacing": 0,
                  "cardType": "secondary"
                }
              },
              "format": "listView",
              "hidden": false,
              "fieldName": "listViewMembers",
              "dataSource": "members",
              "properties": {
                "spacing": "spacer4"
              }
            },
            {
              "type": "template",
              "label": "ADD_MEMBER",
              "format": "button",
              "visible": "{{fn:hasRole('REGISTRAR')}} == true && {{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==true",
              "onAction": [
                {
                  "condition": {
                    "expression": "{{fn:length(contextData.0.members)}} > {{contextData.0.household.HouseholdModel.additionalFields.fields.childrenCount}}"
                  },
                  "actions": [
                    {
                      "actionType": "SHOW_TOAST",
                      "properties": {
                        "message": "REGISTRATION_SEARCH_BENEFICIARY_CHILDREN_COUNT_EXCEEDED",
                        "type": "error"
                      }
                    }
                  ]
                },
                {
                  "condition": {
                    "expression": "DEFAULT"
                  },
                  "actions": [
                    {
                      "actionType": "NAVIGATION",
                      "properties": {
                        "data": [
                          {
                            "key": "HouseholdClientReferenceId",
                            "value": "{{contextData.0.household.HouseholdModel.clientReferenceId}}"
                          },
                          {
                            "key": "UNIQUE_BENEFICIARY_ID",
                            "value": "{{latestBeneficiaryId}}"
                          },
                          {
                            "key": "isHead",
                            "value": "false"
                          }
                        ],
                        "name": "ADD_MEMBER",
                        "type": "FORM"
                      }
                    }
                  ]
                }
              ],
              "fieldName": "addMember",
              "properties": {
                "icon": "AddIcon",
                "size": "medium",
                "type": "tertiary",
                "mainAxisSize": "max",
                "mainAxisAlignment": "center"
              },
              "schemaCode": null
            },
            {
              "type": "template",
              "visible": "{{fn:hasRole('REGISTRAR')}} == true && {{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==false",
              "label": "ADD_MEMBER",
              "format": "actionPopup",
              "fieldName": "beneficiaryIdMinCheck",
              "properties": {
                "size": "medium",
                "type": "tertiary",
                "popupConfig": {
                  "body": [],
                  "type": "alert",
                  "title": "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_TITLE",
                  "description": "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_DESCRIPTION",
                  "footerActions": [
                    {
                      "type": "template",
                      "label": "REGISTRATION_SEARCH_BENEFICIARY_SKIP_CONTINUE_LABEL",
                      "format": "button",
                      "onAction": [
                        {
                          "actionType": "CLOSE_POPUP",
                          "properties": {
                            "parentScreenKey": "householdOverview"
                          }
                        },
                        {
                          "condition": {
                            "expression": "{{fn:length(contextData.0.members)}} > {{contextData.0.household.HouseholdModel.additionalFields.fields.childrenCount}}"
                          },
                          "actions": [
                            {
                              "actionType": "SHOW_TOAST",
                              "properties": {
                                "message": "REGISTRATION_SEARCH_BENEFICIARY_CHILDREN_COUNT_EXCEEDED",
                                "type": "error"
                              }
                            }
                          ]
                        },
                        {
                          "condition": {
                            "expression": "DEFAULT"
                          },
                          "actions": [
                            {
                              "actionType": "NAVIGATION",
                              "properties": {
                                "data": [
                                  {
                                    "key": "HouseholdClientReferenceId",
                                    "value": "{{contextData.0.household.HouseholdModel.clientReferenceId}}"
                                  },
                                  {
                                    "key": "UNIQUE_BENEFICIARY_ID",
                                    "value": "{{latestBeneficiaryId}}"
                                  }
                                ],
                                "name": "ADD_MEMBER",
                                "type": "FORM"
                              }
                            }
                          ]
                        }
                      ],
                      "fieldName": "clearFilter",
                      "visible": "{{fn:hasMinimumBeneficiaryId(1, uniqueIdPoolCount)}} == true",
                      "properties": {
                        "size": "large",
                        "type": "secondary",
                        "mainAxisSize": "max"
                      }
                    },
                    {
                      "type": "template",
                      "label": "REGISTRATION_SEARCH_BENEFICIARY_DOWNLOAD_ID",
                      "format": "button",
                      "onAction": [
                        {
                          "actionType": "CLOSE_POPUP",
                          "properties": {
                            "parentScreenKey": "householdOverview"
                          }
                        },
                        {
                          "actionType": "NAVIGATE_TO_BENEFICIARY_ID_DOWN_SYNC",
                          "properties": {}
                        }
                      ],
                      "fieldName": "saveFilter",
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
            }
          ],
          "properties": {
            "type": "primary",
            "cardType": "primary"
          },
          "schemaCode": null
        }
      ],
      "name": "householdOverview",
      "order": 3,
      "footer": [
        {
          "type": "template",
          "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_ACTION_BUTTON_LABEL_1",
          "format": "button",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
          "disabled": "{{fn:hasRole('REGISTRAR')}} == true && {{fn:isUnder5CountMismatch(contextData.0.members, contextData.0.household)}} == true",
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
                          "value": "{{fn:getRegistrationInsufficientStockMessage()}}",
                          "format": "textTemplate",
                          "fieldName": "insufficientStockOverviewText",
                          "maxLines": 8,
                          "properties": {
                            "textAlign": "center"
                          }
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
                              "properties": {
                                "name": "HOME",
                                "type": "HOME"
                              }
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
                "expression": "{{fn:hasStockForDelivery(contextData.0.eligibleProductVariants)}} == false"
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
                        "value": "{{contextData.0.projectBeneficiary.ProjectBeneficiaryModel.clientReferenceId}}"
                      },
                      {
                        "key": "HouseholdClientReferenceId",
                        "value": "{{navigation.HouseholdClientReferenceId}}"
                      },
                      {
                        "key": "memberCount",
                        "value": "{{contextData.0.household.HouseholdModel.memberCount}}"
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
                        "value": "{{contextData.0.currentDelivery.0.deliveryStrategy}}"
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
                        "value": "{{contextData.0.targetCycle.0.deliveries.0.doseCriteria.0.ProductVariants.0.quantity}}"
                      },
                      {
                        "key": "nameOfIndividual",
                        "value": "{{contextData.0.headIndividual.IndividualModel.name.givenName}}"
                      },
                      {
                        "key": "lastName",
                        "value": "{{contextData.0.headIndividual.IndividualModel.name.familyName}}"
                      },
                      {
                        "key": "beneficiaryId",
                        "value": "{{contextData.0.headIndividual.IndividualModel.identifiers.0.identifierId}}"
                      }
                    ],
                    "name": "DELIVERY",
                    "type": "FORM"
                  }
                }
              ],
              "condition": {
                "expression": "DEFAULT"
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
        {
          "type": "template",
          "label": "ACKNOWLEDGEMENT_SUCCESS_LABEL_TEXT",
          "format": "button",
          "visible": "{{fn:hasRole('REGISTRAR')}} == true",
          "disabled": "{{fn:isUnder5CountMismatch(contextData.0.members, contextData.0.household)}} == true",
          "onAction": [
            {
              "actionType": "CLEAR_STATE",
              "properties": {
                "clearAll": true
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "name": "searchBeneficiary",
                "type": "TEMPLATE",
                "navigationMode": "popUntilAndReplace",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "fieldName": "backToSearchRegistrar",
          "properties": {
            "size": "large",
            "type": "secondary",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          }
        }
      ],
      "header": [],
      "heading": "REGISTRATION_HOUSEHOLD_OVERVIEW_HEADING",
      "category": "REGISTRATION",
      "navigateTo": null,
      "screenType": "TEMPLATE",
      "description": "REGISTRATION_HOUSEHOLD_OVERVIEW_DESC",
      "initActions": [
        {
          "actionType": "LOAD_UNIQUE_ID_POOL"
        },
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
            "name": "projectBeneficiary",
            "match": {
              "field": "beneficiaryClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "ProjectBeneficiaryModel"
          },
          {
            "name": "headOfHousehold",
            "match": {
              "field": "householdClientReferenceId",
              "equalsFrom": "clientReferenceId"
            },
            "entity": "HouseholdMemberModel",
            "filters": [
              {
                "field": "isHeadOfHousehold",
                "equals": true
              }
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {
                "left": "{{startDate}}",
                "right": "{{now}}",
                "operator": "lt"
              },
              {
                "left": "{{endDate}}",
                "right": "{{now}}",
                "operator": "gt"
              }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {
                  "value": "{{dose}}",
                  "operation": "increment"
                }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {
                  "value": "{{cycle}}",
                  "operation": "increment"
                },
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "skip": {
              "from": "{{effectiveDose}}"
            },
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
              "context": [
                "{{individuals.0}}",
                "{{household.0}}"
              ],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {
                  "type": "ageInMonths",
                  "source": "dateOfBirth"
                }
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
                  "value": "{{contextData.0.headIndividual.IndividualModel.name.givenName}}",
                  "isActive": true
                },
                {
                  "key": "HOUSEHOLD_LAST_NAME",
                  "value": "{{contextData.0.headIndividual.IndividualModel.name.familyName}}",
                  "isActive": true
                },
                {
                  "key": "MEMBER_COUNT",
                  "value": "{{contextData.0.household.HouseholdModel.memberCount}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {
            "type": "primary",
            "cardType": "primary"
          },
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
                  "value": "{{contextData.0.headIndividual.IndividualModel.mobileNumber}}",
                  "isActive": true
                },
                {
                  "key": "E_TOKEN",
                  "value": "{{contextData.0.headIndividual.IndividualModel.identifiers.0.identifierId}}",
                  "isActive": true
                }
              ],
              "type": "template",
              "format": "labelPairList",
              "fieldName": "householdDetails"
            }
          ],
          "properties": {
            "type": "primary",
            "cardType": "primary"
          },
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
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [],
                "name": "searchBeneficiary",
                "type": "TEMPLATE"
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
        }
      ],
      "header": [
        {
          "label": "HOUSEHOLD_BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "name": "searchBeneficiary",
                "type": "TEMPLATE"
              }
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
          "actionType": "LOAD_UNIQUE_ID_POOL"
        },
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
              {
                "field": "isHeadOfHousehold",
                "equals": true
              }
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
            "order": 1,
            "where": [
              {
                "left": "{{startDate}}",
                "right": "{{now}}",
                "operator": "lt"
              },
              {
                "left": "{{endDate}}",
                "right": "{{now}}",
                "operator": "gt"
              }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": 1,
                "then": {
                  "value": "{{dose}}",
                  "operation": "increment"
                }
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
                  "left": {
                    "value": "{{dose}}",
                    "operation": "increment"
                  },
                  "right": "{{deliveryLength}}",
                  "operator": "lte"
                },
                "else": {
                  "value": "{{cycle}}",
                  "operation": "increment"
                },
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "skip": {
              "from": "{{effectiveDose}}"
            },
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
              "context": [
                "{{individuals.0}}",
                "{{household.0}}"
              ],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {
                  "type": "ageInMonths",
                  "source": "dateOfBirth"
                }
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
          "label": "SEARCH_LABEL_BY_BENEFICIARY_NAME_OR_ID",
          "format": "searchBar",
          "disabled": false,
          "onAction": [
            {
              "actions": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "data": [
                      {
                        "key": "givenName",
                        "value": "field.value",
                        "operation": "contains"
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
              "condition": {
                "expression": "{{nameSearch}}==true"
              }
            },
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
              "condition": {
                "expression": "DEFAULT"
              }
            }
          ],
          "fieldName": "searchBar",
          "mandatory": true,
          "validations": [
            {
              "type": "minSearchChars",
              "value": 2
            },
            {
              "type": "minSearchChars",
              "value": 12,
              "condition": {
                "expression": "{{idSearch}}==true"
              }
            }
          ]
        },
        {
          "type": "template",
          "label": "SEARCH_BY_PROXIMITY",
          "format": "proximitySearch",
          "onAction": [
            {
              "actionType": "field.value==true ? SEARCH_EVENT : CLEAR_STATE",
              "properties": {
                "data": [
                  {
                    "key": "",
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
              "actionType": "field.value==true ? SEARCH_EVENT : CLEAR_STATE",
              "properties": {
                "widgetKeys": [
                  "searchBar"
                ],
                "filterKeys": [
                  "givenName",
                  "identifierId"
                ],
                "triggerSearch": true,
                "type": "field.value==true ? SEARCH_EVENT : CLEAR_STATE"
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
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
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
          "data": "members",
          "type": "template",
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
                      "visible": "{{fn:hasBeneficiaryId(item.headIndividual.0.identifiers.0)}}==true",
                      "value": "{{ item.headIndividual.0.identifiers.0.identifierId }}",
                      "format": "textTemplate",
                      "fieldName": "beneficiaryId",
                      "maxLines": 2,
                      "properties": {
                        "style": "headingS"
                      }
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
                            "actionType": "OPEN_POPUP",
                            "properties": {
                              "size": "medium",
                              "type": "secondary",
                              "popupConfig": {
                                "body": [
                                  {
                                    "type": "template",
                                    "value": "{{fn:getRegistrationInsufficientStockMessage()}}",
                                    "format": "textTemplate",
                                    "fieldName": "insufficientStockRegistrationText",
                                    "maxLines": 8,
                                    "properties": {
                                      "textAlign": "center"
                                    }
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
                                    "fieldName": "closeInsufficientStockRegistrationPopUp",
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
                          "expression": "{{fn:hasStockForRegistration()}}==false && {{fn:isClosedHousehold(item.tasks)}} == false && {{fn:hasRole('DISTRIBUTOR')}} == false"
                        }
                      },
                      {
                        "actions": [
                          {
                            "actionType": "REVERSE_TRANSFORM",
                            "properties": {
                              "data": [
                                {
                                  "key": "entities",
                                  "value": "{{item}}"
                                }
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
                                  "value": "{{ item.HouseholdModel.clientReferenceId }}"
                                },
                                {
                                  "key": "projectBeneficiaryClientReferenceId",
                                  "value": "{{ item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId }}"
                                },
                                {
                                  "key": "isEdit",
                                  "value": "true"
                                },
                                {
                                  "key": "isClosedHousehold",
                                  "value": "true"
                                }
                              ],
                              "name": "previewScreen",
                              "type": "TEMPLATE"
                            }
                          }
                        ],
                        "condition": {
                          "expression": "{{fn:isClosedHousehold(item.tasks)}} == true"
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
                                  "value": "{{ item.HouseholdModel.clientReferenceId }}"
                                },
                                {
                                  "key": "ProjectBeneficiaryClientReferenceId",
                                  "value": "{{ item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId }}"
                                }
                              ],
                              "name": "householdOverview",
                              "type": "TEMPLATE"
                            }
                          }
                        ],
                        "condition": {
                          "expression": "{{fn:hasRole('DISTRIBUTOR')}} == true && {{fn:isClosedHousehold(item.tasks)}} == false"
                        }
                      },
                      {
                        "actions": [
                          {
                            "actionType": "REVERSE_TRANSFORM",
                            "properties": {
                              "data": [
                                {
                                  "key": "entities",
                                  "value": "{{item}}"
                                }
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
                                  "value": "{{ item.HouseholdModel.clientReferenceId }}"
                                },
                                {
                                  "key": "projectBeneficiaryClientReferenceId",
                                  "value": "{{ item.projectBeneficiaries.ProjectBeneficiaryModel.clientReferenceId }}"
                                },
                                {
                                  "key": "isEdit",
                                  "value": "true"
                                },
                                {
                                  "key": "isClosedHousehold",
                                  "value": "true"
                                },
                                {
                                  "key": "UNIQUE_BENEFICIARY_ID",
                                  "value": "{{latestBeneficiaryId}}"
                                },
                                {
                                  "key": "uniqueBeneficiaryIdModel",
                                  "value": "{{latestBeneficiaryIdModel}}"
                                },
                                {
                                  "key": "identifier",
                                  "value": "{{item.headIndividual}}"
                                }
                              ],
                              "name": "householdOverview",
                              "type": "FORM"
                            }
                          }
                        ],
                        "condition": {
                          "expression": "{{fn:hasStockForRegistration()}}==true && {{fn:isClosedHousehold(item.tasks)}} == false && {{fn:hasRole('DISTRIBUTOR')}} == false"
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
                                  "value": "{{ item.HouseholdModel.clientReferenceId }}"
                                },
                                {
                                  "key": "nameOfIndividual",
                                  "value": "{{ item.headIndividual.0.name.givenName }}"
                                },
                                {
                                  "key": "UNIQUE_BENEFICIARY_ID",
                                  "value": "{{item.headIndividual.0.identifiers.0.identifierId}}"
                                }
                              ],
                              "name": "HOUSEHOLD",
                              "type": "TEMPLATE"
                            }
                          }
                        ],
                        "condition": {
                          "expression": "DEFAULT"
                        }
                      }
                    ],
                    "fieldName": "openMemberCard",
                    "properties": {
                      "size": "medium",
                      "type": "secondary"
                    }
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
                "value": "{{ item.headIndividual.0.name.givenName }} {{ item.headIndividual.0.name.familyName }}",
                "format": "textTemplate",
                "fieldName": "householdName",
                "properties": {
                  "style": "headingS"
                }
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
                "value": "SEARCH_HOUSEHOLD_STATUS_NOT_VISITED",
                "format": "textTemplate",
                "visible": "{{fn:isClosedHousehold(item.tasks)}} == false",
                "fieldName": "statusNotVisited",
                "properties": {}
              }
            ],
            "fieldName": "memberCard"
          },
          "format": "listView",
          "hidden": false,
          "fieldName": "listView",
          "properties": {
            "spacing": "spacer4"
          },
          "schemaCode": null
        }
      ],
      "initActions": [
        {
          "actionType": "LOAD_UNIQUE_ID_POOL"
        }
      ],
      "name": "searchBeneficiary",
      "order": 1,
      "footer": [
        {
          "icon": "FilterAlt",
          "type": "template",
          "label": "DOWNLOAD_BENEFICIARY_IDS",
          "format": "actionPopup",
          "visible": "{{fn:hasRole('REGISTRAR')}} == true && {{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==false",
          "disabled": "false",
          "fieldName": "beneficiaryIdMinCheck",
          "properties": {
            "icon": "FilterAlt",
            "size": "large",
            "type": "primary",
            "popupConfig": {
              "body": [],
              "type": "alert",
              "title": "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_TITLE",
              "description": "REGISTRATION_SEARCH_BENEFICIARY_MIN_BENEFICIARY_ID_LEFT_DESCRIPTION",
              "footerActions": [
                {
                  "type": "template",
                  "label": "REGISTRATION_SEARCH_BENEFICIARY_SKIP_CONTINUE_LABEL",
                  "format": "button",
                  "onAction": [
                    {
                      "actionType": "CLOSE_POPUP",
                      "properties": {
                        "parentScreenKey": "searchBeneficiary"
                      }
                    },
                    {
                      "actionType": "NAVIGATION",
                      "properties": {
                        "data": [
                          {
                            "key": "nameOfIndividual",
                            "value": "{{searchBar}}"
                          },
                          {
                            "key": "UNIQUE_BENEFICIARY_ID",
                            "value": "{{latestBeneficiaryId}}"
                          },
                          {
                            "key": "uniqueBeneficiaryIdModel",
                            "value": "{{latestBeneficiaryIdModel}}"
                          }
                        ],
                        "name": "HOUSEHOLD",
                        "type": "FORM"
                      }
                    }
                  ],
                  "fieldName": "skip",
                  "visible": "{{fn:hasMinimumBeneficiaryId(1, uniqueIdPoolCount)}} == true",
                  "properties": {
                    "size": "large",
                    "type": "secondary",
                    "mainAxisSize": "max"
                  }
                },
                {
                  "type": "template",
                  "label": "REGISTRATION_SEARCH_BENEFICIARY_DOWNLOAD_ID",
                  "format": "button",
                  "onAction": [
                    {
                      "actionType": "CLOSE_POPUP",
                      "properties": {
                        "parentScreenKey": "searchBeneficiary"
                      }
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
          "visible": "{{fn:hasRole('REGISTRAR')}} == true && {{fn:hasMinimumBeneficiaryId(singleton.beneficiaryIdMinCount, uniqueIdPoolCount)}}==true",
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
                          "value": "{{fn:getRegistrationInsufficientStockMessage()}}",
                          "format": "textTemplate",
                          "fieldName": "insufficientStockRegistrationText",
                          "maxLines": 8,
                          "properties": {
                            "textAlign": "center"
                          }
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
                          "fieldName": "closeInsufficientStockRegistrationPopUp",
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
                      {
                        "key": "nameOfIndividual",
                        "value": "{{searchBar}}"
                      },
                      {
                        "key": "UNIQUE_BENEFICIARY_ID",
                        "value": "{{latestBeneficiaryId}}"
                      },
                      {
                        "key": "uniqueBeneficiaryIdModel",
                        "value": "{{latestBeneficiaryIdModel}}"
                      }
                    ],
                    "name": "HOUSEHOLD",
                    "type": "FORM"
                  }
                }
              ],
              "condition": {
                "condition": {
                  "expression": "DEFAULT"
                }
              }
            }
          ],
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
          "label": "BACK",
          "format": "backLink",
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {
                "name": "HOME",
                "type": "HOME"
              }
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
              {
                "field": "isHeadOfHousehold",
                "equals": true
              }
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
          "pagination": {
            "limit": 5,
            "maxItems": 15
          }
        }
      },
      "scrollListener": {
        "debounceMs": 0,
        "onScrollUp": [
          {
            "actionType": "REFRESH_SEARCH",
            "properties": {
              "pagination": {
                "limit": 5,
                "maxItems": 15
              }
            }
          }
        ],
        "triggerMode": "bidirectional",
        "onScrollDown": [
          {
            "actionType": "REFRESH_SEARCH",
            "properties": {
              "pagination": {
                "limit": 5,
                "maxItems": 15
              }
            }
          }
        ],
        "showLoadingIndicator": true
      },
      "submitCondition": null,
      "preventScreenCapture": false
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
              "label": "APPONE_REGISTRATION_DELIVERYDETAILS_ACTION_BUTTON_LABEL_1",
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
                          "properties": {
                            "textAlign": "center"
                          }
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
                              "properties": {
                                "parentScreenKey": "DELIVERY"
                              }
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
                "expression": "{{fn:hasStockForDelivery(contextData.0.eligibleProductVariants)}} == false"
              }
            }
          ],
          "navigateTo": {
            "name": "DeliveryChecklist",
            "type": "template"
          },
          "properties": [
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_DELIVERYDETAILS_label_dateOfDelivery",
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
                {
                  "code": "SP1",
                  "name": "SP1"
                },
                {
                  "code": "SP2",
                  "name": "SP2"
                },
                {
                  "code": "AQ1",
                  "name": "AQ1"
                },
                {
                  "code": "AQ2",
                  "name": "AQ2"
                }
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
                {
                  "code": "SP1",
                  "name": "SP1"
                },
                {
                  "code": "SP2",
                  "name": "SP2"
                },
                {
                  "code": "AQ1",
                  "name": "AQ1"
                },
                {
                  "code": "AQ2",
                  "name": "AQ2"
                }
              ],
              "includeInSummary": true,
              "required.message": "REGISTRATION_RESOURCE_CARD_SELECTION_REQUIRED"
            },
            {
              "type": "string",
              "enums": [
                {
                  "code": "SUCCESSFUL_DELIVERY",
                  "name": "SUCCESSFUL_DELIVERY"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_deliveryComments",
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
                {
                  "type": "isGS1Code",
                  "value": true
                },
                {
                  "type": "scanLimit",
                  "value": 4
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
          "actionLabel": "APPONE_REGISTRATION_DELIVERYDETAILS_ACTION_BUTTON_LABEL_2",
          "description": "APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_DESCRIPTION",
          "showTabView": false,
          "showAlertPopUp": {
            "title": "APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE",
            "conditions": [],
            "description": "APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_DESCRIPTION",
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
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
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
          "heading": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_HEADING",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "data": [
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  },
                  {
                    "key": "cycleIndex",
                    "value": "{{navigation.cycleIndex}}"
                  },
                  {
                    "key": "doseIndex",
                    "value": "{{navigation.doseIndex}}"
                  },
                  {
                    "key": "deliveryStrategy",
                    "value": "{{navigation.deliveryStrategy}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to fetch config."
                    }
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
                    "properties": {
                      "message": "Failed to create household."
                    }
                  }
                ]
              }
            },
            {
              "actions": [
                {
                  "actionType": "FETCH_TRANSFORMER_CONFIG",
                  "properties": {
                    "data": [
                      {
                        "key": "ProjectBeneficiaryClientReferenceId",
                        "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                      },
                      {
                        "key": "cycleIndex",
                        "value": "{{navigation.cycleIndex}}"
                      },
                      {
                        "key": "deliveryStrategy",
                        "value": "{{navigation.deliveryStrategy}}"
                      },
                      {
                        "key": "futureDoses",
                        "value": "{{navigation.futureDoses}}"
                      }
                    ],
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to fetch config for bulk delivery."
                        }
                      }
                    ],
                    "configName": "indirectBulkDelivery"
                  }
                },
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to create bulk tasks."
                        }
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
                        "properties": {
                          "message": "Failed to update stock balance."
                        }
                      }
                    ]
                  }
                }
              ],
              "condition": {
                "expression": "doseIndex == 1"
              }
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
                  }
                ],
                "name": "deliverySuccess",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Navigation failed."
                    }
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_TRUCK_IN_THE_NET",
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_NET_IS_DIRTY",
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_MEND_YOUR_NETS",
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_THE_NET_PROTECTS",
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            },
            {
              "type": "boolean",
              "label": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_PROTECT_FROM_MALERIA",
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
                  "message": "APPONE_DELIVERYFLOW_DELIVERYDETAIL_ACTIONS_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": ""
            }
          ],
          "actionLabel": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SUBMIT_LABEL",
          "description": "APPONE_DELIVERYFLOW_DELIVERYDETAILS_ACTIONS_SCREEN_DESCRIPTION",
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
                "properties": {
                  "message": "Failed to fetch config."
                }
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
                "properties": {
                  "message": "Failed to create household."
                }
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
                "properties": {
                  "message": "Failed to update stock balance."
                }
              }
            ]
          }
        },
        {
          "actions": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "data": [
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value": "{{navigation.ProjectBeneficiaryClientReferenceId}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to fetch config for bulk delivery."
                    }
                  }
                ],
                "configName": "indirectBulkDelivery"
              }
            },
            {
              "actionType": "CREATE_EVENT",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to create bulk tasks."
                    }
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
                    "properties": {
                      "message": "Failed to update stock balance."
                    }
                  }
                ]
              }
            }
          ],
          "condition": {
            "expression": "doseIndex == 1"
          }
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
              {
                "key": "beneficiaryId",
                "value": "{{navigation.beneficiaryId}}"
              }
            ],
            "name": "deliverySuccess",
            "type": "TEMPLATE",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "Navigation failed."
                }
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
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_ACTION_BUTTON_LABEL_1",
              "format": "button",
              "fieldName": "householdDetailsSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "name": "beneficiaryDetails",
                    "type": "form"
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel, IndividualModel, TaskModel",
                    "modify": [
                      {
                        "key": "TaskModel.status",
                        "value": "NOT_ADMINISTERED"
                      }
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel, IndividualModel",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to update household."
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {
                "type": "custom",
                "expression": "isEdit==true"
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to create household."
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {
                "expression": "DEFAULT"
              }
            }
          ],
          "navigateTo": {
            "name": "beneficiaryDetails",
            "type": "form"
          },
          "properties": [
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration",
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
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_dateOfRegistration_mandatory_message"
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
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText",
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
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
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
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_helpText",
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
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone",
              "order": 3,
              "value": "",
              "format": "mobileNumber",
              "hidden": false,
              "isMdms": false,
              "pattern": r"^0\d{9}$",
              "tooltip": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_tooltip",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_helpText",
              "infoText": "",
              "readOnly": false,
              "required": false,
              "fieldName": "phone",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "maxLength": 10,
                "minLength": 10,
                "errorMessage": "MOBILE_LENGTH_10_DIGIT_ERROR"
              },
              "validations": [
                {
                  "type": "pattern",
                  "value": r"^0\d{9}$",
                  "message": "MOBILE_NUMBER_START_WITH_ZERO_ERROR"
                },
                {
                  "type": "minLength",
                  "value": 10,
                  "message": "MOBILE_LENGTH_10_DIGIT_ERROR"
                },
                {
                  "type": "maxLength",
                  "value": 10,
                  "message": "MOBILE_LENGTH_10_DIGIT_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "MOBILE_LENGTH_10_DIGIT_ERROR",
              "pattern.message": "MOBILE_NUMBER_START_WITH_ZERO_ERROR"
            },
            {
              "type": "string",
              "enums": [
                {
                  "code": "MALE",
                  "name": "MALE"
                },
                {
                  "code": "FEMALE",
                  "name": "FEMALE"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_gender_addmember",
              "order": 5,
              "value": "",
              "format": "select",
              "hidden": false,
              "isMdms": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "gender",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "common-masters.GenderType",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "GENDER_MANDATORY_MESSAGE_ADDMEMBER"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "dropDownOptions": [
                {
                  "code": "MALE",
                  "name": "MALE"
                },
                {
                  "code": "FEMALE",
                  "name": "FEMALE"
                }
              ],
              "required.message": "GENDER_MANDATORY_MESSAGE_ADDMEMBER"
            },
            {
              "type": "integer",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount",
              "order": 4,
              "range": {
                "max": "10",
                "min": "1",
                "errorMessage": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message"
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
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_mandatory_message"
                },
                {
                  "type": "min",
                  "value": "1",
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_min_message"
                },
                {
                  "type": "max",
                  "value": "10",
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_mandatory_message"
            },
            {
              "type": "integer",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount",
              "order": 5,
              "range": {
                "max": "9",
                "min": "0",
                "errorMessage": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message"
              },
              "value": "0",
              "format": "numeric",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_helpText",
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
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_mandatory_message"
                },
                {
                  "type": "min",
                  "value": "0",
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_min_message"
                },
                {
                  "type": "max",
                  "value": "9",
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message"
                },
                {
                  "type": "maxField",
                  "value": "memberCount",
                  "message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_maxField_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required": true,
              "required.message": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_mandatory_message"
            },
            {
              "type": "integer",
              "label": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount",
              "order": 6,
              "value": "0",
              "format": "numeric",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "pregnantWomenCount",
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
              "type": "boolean",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily",
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
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_isHeadOfFamily_mandatory_message"
            },
            {
              "type": "string",
              "enums": [
                {
                  "code": "DEFAULT",
                  "name": "DEFAULT"
                },
                {
                  "code": "UNIQUE_BENEFICIARY_ID",
                  "name": "UNIQUE_BENEFICIARY_ID"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identifiers",
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
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message"
            }
          ],
          "actionLabel": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_ACTION_BUTTON_LABEL_1",
          "description": "APPONE_REGISTRATION_HOUSEHOLDDETAILS_SCREEN_DESCRIPTION",
          "showTabView": false,
          "submitCondition": {
            "expression": [
              {
                "condition": "isEdit == true"
              }
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
              "label": "APPONE_REGISTRATION_BENEFICIARY_LOCATION_ACTION_BUTTON_LABEL_1",
              "format": "button",
              "fieldName": "beneficiaryLocationSubmitButton",
              "onAction": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "name": "householdDetails",
                    "type": "form"
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel, IndividualModel, TaskModel, TaskResourceModel",
                    "modify": [
                      {
                        "key": "TaskModel.status",
                        "value": "NOT_ADMINISTERED"
                      }
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "HouseholdModel",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to update household."
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {
                "type": "custom",
                "expression": "isEdit==true"
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
                        "properties": {
                          "message": "Failed to fetch config."
                        }
                      }
                    ],
                    "configName": "beneficiaryRegistration"
                  }
                },
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Failed to create household."
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
                        "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                      }
                    ],
                    "name": "householdOverview",
                    "type": "TEMPLATE",
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
                  }
                }
              ],
              "condition": {
                "expression": "DEFAULT"
              }
            }
          ],
          "navigateTo": {
            "name": "householdDetails",
            "type": "form"
          },
          "properties": [
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_settlement",
              "order": 1,
              "value": "",
              "format": "locality",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_helpText",
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
                  "message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_mandatory_message"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_gps_coordinate_accuracy",
              "order": 2,
              "value": "",
              "format": "latLng",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_helpText",
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
                  "message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_mandatory_message"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1",
              "order": 3,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_helpText",
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
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine1_min_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_helpText",
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
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_addressLine2_min_message"
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
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_helpText",
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
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_min_message"
              },
              "validations": [
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_landmark_min_message"
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
              "helpText": "APPONE_REGISTRATION_BENEFICIARYLOCATION_label_pincode_helpText",
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
                {
                  "code": "PERMANENT",
                  "name": "BENEFICIARYLOCATION_PERMANENT"
                },
                {
                  "code": "CORRESPONDENCE",
                  "name": "BENEFICIARYLOCATION_CORRESPONDENCE"
                },
                {
                  "code": "OTHER",
                  "name": "BENEFICIARYLOCATION_OTHER"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARY_LOCATION_label_typeOfAddress",
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
                {
                  "code": "PERMANENT",
                  "name": "BENEFICIARYLOCATION_PERMANENT"
                },
                {
                  "code": "CORRESPONDENCE",
                  "name": "BENEFICIARYLOCATION_CORRESPONDENCE"
                },
                {
                  "code": "OTHER",
                  "name": "BENEFICIARYLOCATION_OTHER"
                }
              ],
              "includeInSummary": false
            }
          ],
          "actionLabel": "APPONE_REGISTRATION_BENEFICIARY_LOCATION_ACTION_BUTTON_LABEL_BEDNET_NEXT",
          "description": "",
          "showTabView": false,
          "submitCondition": null,
          "preventScreenCapture": false
        }
      ],
      "summary": false,
      "version": 3,
      "category": "REGISTRATION",
      "disabled": false,
      "onAction": [
        {
          "actions": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to fetch config."
                    }
                  }
                ],
                "createEntities": [
                  "ProjectBeneficiaryModel"
                ],
                "configName": "beneficiaryRegistration"
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
                "entity": "HouseholdModel, IndividualModel, ProjectBeneficiaryModel",
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
                    "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                  }
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Navigation failed."
                    }
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
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to fetch config."
                    }
                  }
                ],
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
              "actionType": "UPDATE_EVENT",
              "properties": {
                "entity": "HouseholdModel, IndividualModel, TaskModel",
                "modify": [
                  {
                    "key": "TaskModel.status",
                    "value": "NOT_ADMINISTERED"
                  }
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
                    "value": "{{navigation.projectBeneficiaryClientReferenceId}}"
                  }
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Navigation failed."
                    }
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
                    "properties": {
                      "message": "Failed to fetch config."
                    }
                  }
                ],
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
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to create household."
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
                    "value": "{{contextData.entities.HouseholdModel.clientReferenceId}}"
                  },
                  {
                    "key": "ProjectBeneficiaryClientReferenceId",
                    "value": "{{contextData.entities.ProjectBeneficiaryModel.clientReferenceId}}"
                  }
                ],
                "name": "householdOverview",
                "type": "TEMPLATE",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Navigation failed."
                    }
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "condition": {
            "expression": "DEFAULT"
          }
        }
      ],
      "isSelected": true,
      "screenType": "FORM",
      "initActions": [],
      "wrapperConfig": {
        "filters": [
          {
            "field": "isHeadOfHousehold",
            "equals": true
          }
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "from": "{{singleton.selectedProject.additionalDetails.projectType.cycles}}",
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
            "skip": {
              "from": "{{effectiveDose}}"
            },
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
              "context": [
                "{{individuals.0}}",
                "{{household.0}}"
              ],
              "condition": "{{item.condition}}",
              "transformations": {
                "age": {
                  "type": "ageInMonths",
                  "source": "dateOfBirth"
                }
              }
            }
          }
        }
      },
      "scrollListener": {}
    },
    {
      "name": "ADD_MEMBER",
      "order": 4,
      "pages": [
        {
          "body": null,
          "flow": "ADD_MEMBER",
          "page": "beneficiaryDetails",
          "type": "object",
          "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_HEADING_addmember",
          "order": 4,
          "footer": [
            {
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_ACTION_BUTTON_LABEL_addmember",
              "format": "button",
              "fieldName": "addMemberSubmitButton",
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
                    "onError": [
                      {
                        "actionType": "SHOW_TOAST",
                        "properties": {
                          "message": "Navigation failed."
                        }
                      }
                    ],
                    "navigationMode": "popUntilAndPush",
                    "popUntilPageName": "searchBeneficiary"
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
          "heading": "APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_HEADING_addmember",
          "summary": false,
          "version": 1,
          "onAction": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "data": [
                  {
                    "key": "HouseholdClientReferenceId",
                    "value": "{{navigation.HouseholdClientReferenceId}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Failed to fetch config."
                    }
                  }
                ],
                "configName": "individualRegistration"
              }
            },
            {
              "actions": [
                {
                  "actionType": "UPDATE_EVENT",
                  "properties": {
                    "entity": "IndividualModel, ProjectBeneficiaryModel"
                  }
                }
              ],
              "condition": {
                "type": "custom",
                "expression": "isEdit == true"
              }
            },
            {
              "actions": [
                {
                  "actionType": "CREATE_EVENT",
                  "properties": {}
                }
              ],
              "condition": {
                "expression": "DEFAULT"
              }
            },
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
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "Navigation failed."
                    }
                  }
                ],
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "searchBeneficiary"
              }
            }
          ],
          "navigateTo": {
            "name": "householdOverview",
            "type": "TEMPLATE"
          },
          "properties": [
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_addmember",
              "order": 1,
              "value": "",
              "format": "text",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText_addmember",
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
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message_addmember"
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message_addmember"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message_addmember"
                },
                {
                  "type": "maxLength",
                  "value": "200",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_max_message_addmember"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_mandatory_message_addmember"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_addmember",
              "order": 2,
              "value": "",
              "format": "text",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "familyname",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "minLength": "2",
                "errorMessage": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_min_message_addmember"
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_mandatory_message_addmember"
                },
                {
                  "type": "minLength",
                  "value": "2",
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_min_message_addmember"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_mandatory_message_addmember"
            },
            {
              "type": "string",
              "enums": [
                {
                  "code": "DEFAULT",
                  "name": "DEFAULT"
                },
                {
                  "code": "UNIQUE_BENEFICIARY_ID",
                  "name": "UNIQUE_BENEFICIARY_ID"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identifiers_addmember",
              "order": 3,
              "value": "",
              "format": "idPopulator",
              "hidden": true,
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
              "includeInForm": true,
              "schemaCode": "HCM.ID_TYPE_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message_addmember"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "dropDownOptions": [
                {
                  "code": "DEFAULT",
                  "name": "DEFAULT"
                },
                {
                  "code": "UNIQUE_BENEFICIARY_ID",
                  "name": "UNIQUE_BENEFICIARY_ID"
                },
                {
                  "code": "OTHER",
                  "name": "OTHER"
                }
              ],
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_idpopulator_mandatory_message_addmember"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_addmember",
              "order": 4,
              "value": "",
              "format": "dob",
              "hidden": false,
              "isMdms": false,
              "tooltip": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_tooltip_addmember",
              "ageRange": {
                "maxAge": 59,
              "minAge": 0,
                "errorMessage": "AGE_VALIDATION_ADDMEMBER"
              },
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_helpText_addmember",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "dobPicker",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_mandatory_message_addmember"
                },
                {
                  "type": "minAge",
                  "value": 0,
                  "message": "AGE_VALIDATION_ADDMEMBER"
                },
                {
                  "type": "maxAge",
                  "value": 59,
                  "message": "AGE_VALIDATION_ADDMEMBER"
                },
                {
                  "type": "minAgeHead",
                  "value": 216,
                  "message": "AGE_VALIDATION"
                },
                {
                  "type": "maxAgeHead",
                  "value": 1800,
                  "message": "AGE_VALIDATION"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "required.message": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_mandatory_message_addmember"
            },
            {
              "type": "string",
              "enums": [
                {
                  "code": "MALE",
                  "name": "MALE"
                },
                {
                  "code": "FEMALE",
                  "name": "FEMALE"
                }
              ],
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_gender_addmember",
              "order": 5,
              "value": "",
              "format": "select",
              "hidden": false,
              "isMdms": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "required": true,
              "fieldName": "gender",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "common-masters.GenderType",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "GENDER_MANDATORY_MESSAGE_ADDMEMBER"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "dropDownOptions": [
                {
                  "code": "MALE",
                  "name": "MALE"
                },
                {
                  "code": "FEMALE",
                  "name": "FEMALE"
                }
              ],
              "required.message": "GENDER_MANDATORY_MESSAGE_ADDMEMBER"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_addmember",
              "order": 6,
              "value": "",
              "format": "mobileNumber",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.isHead==true"
                  }
                ]
              },
              "isMdms": false,
              "pattern": r"^0\d{9}$",
              "tooltip": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_tooltip_addmember",
              "helpText": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_phone_helpText_addmember",
              "infoText": "",
              "readOnly": false,
              "fieldName": "phone",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "lengthRange": {
                "maxLength": 10,
                "minLength": 10,
                "errorMessage": "MOBILE_LENGTH_10_DIGIT_ERROR"
              },
              "validations": [
                {
                  "type": "pattern",
                  "value": r"^0\d{9}$",
                  "message": "MOBILE_NUMBER_START_WITH_ZERO_ERROR"
                },
                {
                  "type": "minLength",
                  "value": 10,
                  "message": "MOBILE_LENGTH_10_DIGIT_ERROR"
                },
                {
                  "type": "maxLength",
                  "value": 10,
                  "message": "MOBILE_LENGTH_10_DIGIT_ERROR"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "pattern.message": "MOBILE_NUMBER_START_WITH_ZERO_ERROR"
            },
            {
              "type": "string",
              "label": "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_scanner_addmember",
              "order": 7,
              "value": "",
              "format": "scanner",
              "hidden": true,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "scanner",
              "mandatory": false,
              "showLabel": false,
              "comparisonConfig": {
                "model": "projectBeneficiary",
                "extractKey": "tag",
                "extractFrom": "column",
                "filters": [],
                "errorMessage": "BENEFICIARY_TAG_ALREADY_ASSIGNED"
              },
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
              "systemDate": false,
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "includeInSummary": true
            }
          ],
          "actionLabel": "APPONE_REGISTRATION_BENEFICIARYDETAILS_ACTION_BUTTON_LABEL_addmember",
          "description": "APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_DESCRIPTION_addmember",
          "showTabView": false,
          "submitCondition": null,
          "showAlertPopUp": {
            "title": "APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE",
            "conditions": [],
            "description": "APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_DESCRIPTION_addmember",
            "primaryActionLabel": "ACTION_SUBMIT",
            "secondaryActionLabel": "ACTION_CANCEL"
          },
          "preventScreenCapture": false,
          "conditionalNavigateTo": null
        }
      ],
      "summary": false,
      "version": 3,
      "category": "REGISTRATION",
      "disabled": false,
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "data": [
              {
                "key": "HouseholdClientReferenceId",
                "value": "{{navigation.HouseholdClientReferenceId}}"
              }
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "Failed to fetch config."
                }
              }
            ],
            "configName": "individualRegistration"
          }
        },
        {
          "actions": [
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "entity": "IndividualModel, ProjectBeneficiaryModel"
              }
            }
          ],
          "condition": {
            "type": "custom",
            "expression": "isEdit == true"
          }
        },
        {
          "actions": [
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
              "properties": {}
            }
          ],
          "condition": {
            "expression": "DEFAULT"
          }
        },
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
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "Navigation failed."
                }
              }
            ],
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "searchBeneficiary"
          }
        }
      ],
      "isSelected": true,
      "screenType": "FORM",
      "initActions": [],
      "wrapperConfig": {
        "filters": [
          {
            "field": "isHeadOfHousehold",
            "equals": true
          }
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
