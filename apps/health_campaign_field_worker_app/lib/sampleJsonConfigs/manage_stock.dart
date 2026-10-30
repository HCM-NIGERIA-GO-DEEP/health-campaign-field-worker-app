final dynamic sampleInventoryFlows = {
  "name": "INVENTORY",
  "initialPage": "manageStock",
  "project": "CMP-2026-03-17-000196",
  "version": 1,
  "disabled": false,
  "isSelected": true,
  "flows": [
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "manageStock",
      "heading": "APP_CONFIG_INVENTORY_manageStock_HEADING",
      "header": [
        {
          "format": "backLink",
          "label": "APP_CONFIG_INVENTORY_manageStock_BACK_BUTTON_LABEL",
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"name": "HOME", "type": "HOME"}
            }
          ]
        }
      ],
      "footer": [
        {
          "format": "button",
          "type": "template",
          "fieldName": "manageStockViewTransactionsButton",
          "label":
              "APP_CONFIG_INVENTORY_manageStock_VIEW_TRANSACTIONS_FOOTER_BUTTON_LABEL",
          "properties": {
            "type": "primary",
            "size": "large",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "viewTransaction",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "viewTransaction",
                "data": []
              }
            }
          ]
        }
      ],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "projectFacility",
            "awaitResults": true,
            "skipAccumulatedFilters": true,
            "data": [
              {
                "key": "projectId",
                "value": "{{singleton.selectedProject.id}}",
                "operation": "equals"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "InventoryWrapper",
        "groupByType": true,
        "rootEntity": "ProjectFacilityModel",
        "filters": [],
        "relations": [
          {
            "name": "facility",
            "entity": "FacilityModel",
            "match": {"field": "id", "equalsFrom": "facilityId"}
          },
          {
            "name": "productVariant",
            "entity": "ProductVariantModel",
            "match": {"field": "id", "equalsFrom": "resource"}
          }
        ],
        "searchConfig": {
          "primary": "projectFacility",
          "select": ["projectFacility", "productVariant", "stock"]
        }
      },
      "body": [
        {
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordStockReceiptCard",
          "heading":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_RECEIPT_HEADING",
          "description":
              "APP_CONFIG_INVENTORY_manageStock_CREATE_RECORDS_FOR_STOCK_RECEIVED_AT_THE_WAREHOUSE_DESCRIPTION",
          "icon": "FileUpload",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "incomingTransactions",
                "data": []
              }
            }
          ]
        },
        {
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordStockIssuedCard",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "heading":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_ISSUED_HEADING",
          "description":
              "APP_CONFIG_INVENTORY_manageStock_CREATE_RECORDS_FOR_STOCK_SENT_OUT_FROM_THE_WAREHOUSE_DESCRIPTION",
          "icon": "FileDownload",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "returnOrIssueSelection",
                "data": []
              }
            }
          ]
        },
        {
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordStockReturnedCard",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
          "heading":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_RETURNED_HEADING",
          "description":
              "APP_CONFIG_INVENTORY_manageStock_CREATE_RECORDS_FOR_STOCK_SENT_OUT_FROM_THE_WAREHOUSE_DESCRIPTION",
          "icon": "FileDownload",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "returnOrIssueSelection",
                "data": []
              }
            }
          ]
        },
        {
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordLessExcessCard",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
          "heading": "INVENTORY_LESS_EXCESS_DETAILS_HEADING",
          "description": "INVENTORY_LESS_EXCESS_DETAILS_DESCRIPTION",
          "icon": "Assessment",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "FORM",
                "name": "RECORDLESSEXCESS",
                "data": [
                  {"key": "stockEntryType", "value": "LESS_EXCESS"},
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  }
                ]
              }
            }
          ]
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "returnOrIssueSelection",
      "heading": "APP_CONFIG_INVENTORY_returnOrIssueSelection_HEADING",
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "stockSearch",
            "primary": "stock",
            "select": ["stock"],
            "awaitResults": true,
            "skipAccumulatedFilters": true,
            "data": [
              {
                "key": "tenantId",
                "value": "{{singleton.tenantId}}",
                "operation": "equals",
                "root": "stock"
              }
            ]
          }
        }
      ],
      "footer": [
        {
          "format": "button",
          "type": "template",
          "fieldName": "returnOrIssueSelectionNextButton",
          "label":
              "APP_CONFIG_INVENTORY_returnOrIssueSelection_NEXT_BUTTON_LABEL",
          "properties": {
            "type": "primary",
            "size": "large",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "onAction": [
            {
              "condition": {"expression": "transactionType == ISSUED"},
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "type": "FORM",
                    "name": "RECORDSTOCK",
                    "data": [
                      {"key": "stockEntryType", "value": "ISSUED"},
                      {"key": "transactionType", "value": "DISPATCHED"},
                      {"key": "primaryRole", "value": "SENDER"},
                      {"key": "secondaryRole", "value": "RECEIVER"},
                      {
                        "key": "mrnNumber",
                        "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                      },
                      {
                        "key": "stockBalances",
                        "value": "{{fn:getAllStockBalances()}}"
                      }
                    ]
                  }
                }
              ]
            },
            {
              "condition": {"expression": "transactionType == RETURNED"},
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "type": "FORM",
                    "name": "RECORDSTOCK",
                    "data": [
                      {"key": "stockEntryType", "value": "RETURNED"},
                      {"key": "transactionType", "value": "DISPATCHED"},
                      {"key": "primaryRole", "value": "SENDER"},
                      {"key": "secondaryRole", "value": "RECEIVER"},
                      {
                        "key": "mrnNumber",
                        "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                      },
                      {
                        "key": "stockBalances",
                        "value": "{{fn:getAllStockBalances()}}"
                      },
                      {
                        "key": "isDistributor",
                        "value": "{{fn:hasRole('DISTRIBUTOR')}}"
                      }
                    ]
                  }
                }
              ]
            }
          ]
        }
      ],
      "body": [
        {
          "format": "card",
          "type": "template",
          "fieldName": "returnOrIssueSelectionContainerCard",
          "children": [
            {
              "type": "template",
              "format": "dropdownTemplate",
              "label":
                  "APP_CONFIG_INVENTORY_returnOrIssueSelection_TRANSACTION_TYPE_LABEL",
              "fieldName": "transactionType",
              "valueKey": "code",
              "enums": [
                {
                  "name":
                      "APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_ISSUED",
                  "code": "ISSUED"
                },
                {
                  "name":
                      "APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_RETURNED",
                  "code": "RETURNED"
                }
              ],
              "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false"
            },
            {
              "type": "template",
              "format": "dropdownTemplate",
              "label":
                  "APP_CONFIG_INVENTORY_returnOrIssueSelection_TRANSACTION_TYPE_LABEL",
              "fieldName": "transactionType",
              "valueKey": "code",
              "enums": [
                {
                  "name":
                      "APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_RETURNED",
                  "code": "RETURNED"
                }
              ],
              "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
              "showWhenSingleOption": true
            }
          ]
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "scanStockReceipt",
      "heading": "INVENTORY_SCAN_STOCK_RECEIPT_HEADING",
      "description": "INVENTORY_SCAN_STOCK_RECEIPT_DESCRIPTION",
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "initActions": [
        {
          "actionType": "OPEN_SCANNER",
          "properties": {
            "scanType": "qr",
            "fieldName": "scannedMrn",
            "singleValue": true,
            "quantity": 1,
            "isGS1code": false,
            "onSuccess": [
              {
                "actionType": "SEARCH_EVENT",
                "properties": {
                  "type": "SEARCH_EVENT",
                  "name": "stock",
                  "awaitResults": true,
                  "data": [
                    {
                      "key": "additionalFields",
                      "value": "{{scannedMrn}}",
                      "operation": "contains"
                    }
                  ]
                }
              },
              {
                "actionType": "REVERSE_TRANSFORM",
                "properties": {
                  "configName": "stock",
                  "entityTypes": ["StockModel"]
                }
              },
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "type": "FORM",
                  "name": "RECORDSTOCK",
                  "data": [
                    {"key": "stockEntryType", "value": "RECEIPT"},
                    {"key": "transactionType", "value": "RECEIVED"},
                    {"key": "primaryRole", "value": "RECEIVER"},
                    {"key": "secondaryRole", "value": "SENDER"},
                    {"key": "scannedMrn", "value": "577E-52D8-B4F8"},
                    {"key": "isEdit", "value": "true"},
                    {"key": "forceCreate", "value": "true"}
                  ]
                }
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "ScanStockWrapper",
        "groupByType": true,
        "rootEntity": "StockModel",
        "filters": [],
        "relations": [
          {"name": "stock", "entity": "StockModel"}
        ],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"]
        }
      },
      "body": [
        {
          "format": "qrScanner",
          "type": "template",
          "label": "INVENTORY_SCAN_MRN_LABEL",
          "scanType": "qr",
          "fieldName": "scanPage.scannedMrn",
          "properties": {
            "type": "primary",
            "size": "large",
            "mainAxisSize": "max"
          },
          "onChange": [
            {
              "actionType": "SEARCH_EVENT",
              "properties": {
                "type": "SEARCH_EVENT",
                "name": "stock",
                "data": [
                  {
                    "key": "additionalFields",
                    "value": "680C-E975-B27F",
                    "operation": "contains"
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "FORM",
                "name": "RECORDSTOCK",
                "data": [
                  {"key": "stockEntryType", "value": "RECEIPT"},
                  {"key": "transactionType", "value": "RECEIVED"},
                  {"key": "primaryRole", "value": "RECEIVER"},
                  {"key": "secondaryRole", "value": "SENDER"},
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  },
                  {"key": "scannedMrn", "value": "{{scanPage.scannedMrn}}"},
                  {"key": "prefillFromScan", "value": "true"}
                ]
              }
            }
          ]
        }
      ]
    },
    {
      "screenType": "FORM",
      "category": "INVENTORY",
      "name": "RECORDSTOCK",
      "version": 1,
      "disabled": false,
      "isSelected": true,
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "projectFacility",
            "awaitResults": true,
            "skipAccumulatedFilters": true,
            "data": [
              {
                "key": "projectId",
                "value": "{{singleton.selectedProject.id}}",
                "operation": "equals"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "InventoryWrapper",
        "groupByType": true,
        "rootEntity": "ProjectFacilityModel",
        "filters": [],
        "relations": [
          {
            "name": "facility",
            "entity": "FacilityModel",
            "match": {"field": "id", "equalsFrom": "facilityId"}
          },
          {
            "name": "productVariant",
            "entity": "ProductVariantModel",
            "match": {"field": "id", "equalsFrom": "resource"}
          }
        ],
        "searchConfig": {
          "primary": "projectFacility",
          "select": ["projectFacility", "productVariant", "stock"]
        }
      },
      "pages": [
        {
          "page": "warehouseDetails",
          "label": "APPONE_MANAGESTOCK_WAREHOUSE_SCREEN_HEADING",
          "order": 1,
          "type": "object",
          "description": "APPONE_MANAGESTOCK_WAREHOUSE_SCREEN_DESCRIPTION",
          "actionLabel": "APPONE_MANAGESTOCK_WAREHOUSE_ACTION_BUTTON_LABEL_1",
          "properties": [
            {
              "type": "integer",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_dateOfReceipt",
              "order": 1,
              "value": "",
              "format": "date",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "fieldName": "dateOfEntry",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": true,
              "includeInForm": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_dateOfReceipt_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_administrativeArea",
              "order": 2,
              "value": "",
              "format": "locality",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "administrativeArea",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInForm": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_administrativeArea_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "dynamic",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich",
              "order": 3,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText":
                  "MANAGESTOCK_WAREHOUSE_label_facilityToWhich_HELPTEXT_LABEL",
              "infoText": "",
              "readOnly": false,
              "fieldName": "facilityToWhich",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "facilityHierarchy",
                  "value": {
                    "hierarchyMapping": {
                      "Province": {
                        "forReceipt": ["National Warehouse"],
                        "forIssue": ["District Warehouse"]
                      },
                      "District": {
                        "forReceipt": ["State Warehouse"],
                        "forIssue": ["PHU Warehouse"]
                      },
                      "PHU": {
                        "forReceipt": ["District Warehouse"],
                        "forIssue": ["Distribution Point", "DELIVERY_TEAM"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["PHU Warehouse"],
                        "forIssue": ["DELIVERY_TEAM"]
                      }
                    },
                    "useTransactionType": true
                  },
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "includeInForm": true,
              "enums": []
            },
            {
              "type": "string",
              "enums": [],
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "warehouseDetails.facilityToWhich==DELIVERY_TEAM"
                  }
                ]
              },
              "label": "APP_CONFIG_INVENTORY_warehouseDetails_teamCode_LABEL",
              "order": 4,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "teamCode",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInSummary": true,
              "includeInForm": true,
              "validations": [
                {
                  "type": "regex",
                  "value": r"^(?:[^|]+\|\|)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
                  "message": "INVENTORY_DELIVERY_TEAM_QR_INVALID"
                },
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "isGS1Code",
                  "value": false,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_isGS1Code_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "dropDownOptions": []
            }
          ],
          "navigateTo": {"name": "stockDetails", "type": "form"}
        },
        {
          "page": "stockDetails",
          "label": "APPONE_INVENTORY_STOCKDETAILS_SCREEN_HEADING",
          "order": 2,
          "type": "object",
          "format": null,
          "description": "APPONE_INVENTORY_STOCKDETAILS_SCREEN_DESCRIPTION",
          "actionLabel": "APPONE_INVENTORY_STOCKDETAILS_ACTION_BUTTON_LABEL",
          "properties": [
            {
              "type": "dynamic",
              "label": "APPONE_INVENTORY_PRODUCTDETAILS_LABEL",
              "order": 1,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "productdetail",
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "HCM.DELIVERY_COMMENT_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_PRODUCTDETAILS_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": true,
              "enums": []
            },
            {
              "type": "dynamic",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich",
              "order": 2,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText":
                  "Select the facility from which the stock is being received",
              "infoText": "",
              "readOnly": false,
              "fieldName": "facilityFromWhich",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "notEqualTo",
                  "value": "warehouseDetails.facilityToWhich",
                  "message":
                      "INVENTORY_FACILITY_FROM_TO_MUST_BE_DIFFERENT_MESSAGE"
                },
                {
                  "type": "facilityHierarchy",
                  "value": {
                    "hierarchyMapping": {
                      "Province": {
                        "forReceipt": ["National Warehouse"],
                        "forIssue": ["District Warehouse"]
                      },
                      "District": {
                        "forReceipt": ["State Warehouse"],
                        "forIssue": ["Chiefdom Warehouse"]
                      },
                      "Chiefdom": {
                        "forReceipt": ["District Warehouse"],
                        "forIssue": ["PHU Warehouse"]
                      },
                      "PHU": {
                        "forReceipt": ["Chiefdom Warehouse"],
                        "forIssue": ["Distribution Point", "DELIVERY_TEAM"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["PHU Warehouse"],
                        "forIssue": ["DELIVERY_TEAM"]
                      }
                    },
                    "useTransactionType": true
                  },
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich_required"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "includeInForm": true,
              "schemaCode": "HCM.FACILITY_OPTIONS_POPULATOR"
            },
            {
              "type": "string",
              "visibilityCondition": {
                "expression": [
                  {"condition": "stockDetails.facilityFromWhich==DELIVERY_TEAM"}
                ]
              },
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_deliveryTeamCode",
              "order": 4,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_SCAN_TEAM_CODE_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "deliveryTeam",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": []
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_TRANSPORT_LABEL",
              "order": 3,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_TRANSPORT_TYPE_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "transportType",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "BUS", "name": "Bus"},
                {"code": "TRUCK", "name": "Truck"}
              ]
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_VEHICLE_NUMBER_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_VEHICLE_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "vehicleNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "validations": [
                {
                  "type": "pattern",
                  "value": "^[a-zA-Z0-9 ]+\$",
                  "message": "INVENTORY_VEHICLE_NUMBER_HELPTEXT"
                }
              ]
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
          "autoEnable": null,
          "navigateTo": {"name": "stockProductDetails", "type": "form"}
        },
        {
          "page": "stockProductDetails",
          "label": "APPONE_INVENTORY_PRODUCTDETAILS_SCREEN_HEADING",
          "order": 3,
          "type": "object",
          "format": null,
          "description": "APPONE_INVENTORY_PRODUCTDETAILS_SCREEN_DESCRIPTION",
          "actionLabel":
              "APPONE_INVENTORY_PRODUCTDETAILS_ACTION_BUTTON_LABEL_1",
          "multiEntityConfig": {
            "sourcePageKey": "stockDetails",
            "sourceFieldKey": "productdetail"
          },
          "properties": [
            {
              "type": "string",
              "label": "APPONE_INVENTORY_WAYBILL_LABEL",
              "order": 1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "wayBillNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message": "INVENTORY_WAYBILL_NUMBER_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "pattern",
                  "value": "^[a-zA-Z0-9]+\$",
                  "message": "INVENTORY_WAYBILL_NUMBER_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_BATCH_NUMBER_LABEL",
              "order": 2,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "batchNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message": "INVENTORY_BATCH_NUMBER_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "pattern",
                  "value": "^[a-zA-Z0-9 ]+\$",
                  "message": "INVENTORY_BATCH_NUMBER_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantitySent",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_SENT_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_SENT_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'ISSUED'",
                    "type": "custom"
                  }
                ]
              }
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityLost",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_LOST_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_LOST_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'LOSS'",
                    "type": "custom"
                  }
                ]
              }
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityDamaged",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_DAMAGE_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_DAMAGE_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'DAMAGED'",
                    "type": "custom"
                  }
                ]
              }
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityReturned",
              "deleteFlag": false,
              "innerLabel": "",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'RETURNED'",
                    "type": "custom"
                  }
                ]
              },
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_RETURN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_RETURN_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_WASTAGE_LABEL",
              "order": 5,
              "value": "",
              "format": "text",
              "hidden": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityWastage",
              "deleteFlag": false,
              "innerLabel": "",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'RETURNED' && navigation.isDistributor",
                    "type": "custom"
                  }
                ]
              },
              "systemDate": false,
              "validations": [
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_PARTIAL_USED_LABEL",
              "order": 6,
              "value": "",
              "format": "text",
              "hidden": true,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityPartialUsed",
              "deleteFlag": false,
              "innerLabel": "",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'RETURNED' && navigation.isDistributor",
                    "type": "custom"
                  }
                ]
              },
              "systemDate": false,
              "validations": [
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityReceived",
              "deleteFlag": false,
              "innerLabel": "",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'RECEIPT'",
                    "type": "custom"
                  }
                ]
              },
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_RECEIVED_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_COMMENT_LABEL",
              "order": 9,
              "value": "",
              "format": "textArea",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "comment",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "stockProductDetails.quantitySent!=stockProductDetails.quantityReceived"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message": "QUANTITY_DIFFER_COMMENT_REQUIRED_ERROR_MASSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_scanResource",
              "order": 10,
              "value": "",
              "format": "scanner",
              "validations": [
                {
                  "type": "isGS1",
                  "value": true,
                  "message": "APPONE_MANAGESTOCK_WAREHOUSE_label_scanResource"
                }
              ],
              "hidden": false,
              "tooltip": "",
              "comparisonConfig": {
                "model": "stock",
                "extractKey": "scanResource",
                "extractFrom": "additionalFields",
                "filters": [
                  {
                    "key": "senderId",
                    "value": "{{navigation.facilityFromWhich}}",
                    "operation": "equals"
                  },
                  {
                    "key": "receiverId",
                    "value": "{{navigation.facilityToWhich}}",
                    "operation": "equals"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.currentEntityId}}",
                    "operation": "equals"
                  },
                  {
                    "key": "additionalFields.stockEntryType",
                    "value": "{{navigation.stockEntryType}}",
                    "operation": "equals"
                  }
                ],
                "errorMessage": "RESOURCES_ALREADY_SCANNED"
              },
              "helpText": "INVENTORY_SCAN_RESOURCE_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "scanResource",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": []
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
          "autoEnable": null,
          "navigateTo": {"name": "stock-acknowledgement", "type": "template"}
        }
      ],
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "configName": "stock",
            "data": [
              {
                "key": "stockEntryType",
                "value": "{{navigation.stockEntryType}}"
              },
              {
                "key": "transactionType",
                "value": "{{navigation.transactionType}}"
              },
              {"key": "primaryRole", "value": "{{navigation.primaryRole}}"},
              {"key": "secondaryRole", "value": "{{navigation.secondaryRole}}"},
              {
                "key": "senderPartyType",
                "value":
                    "{{fn:getSecondaryType(formData.stockDetails.facilityFromWhich)}}"
              },
              {
                "key": "secondaryType",
                "value":
                    "{{fn:getSecondaryType(formData.stockDetails.facilityFromWhich)}}"
              },
              {
                "key": "receiverPartyType",
                "value":
                    "{{fn:getSecondaryType(formData.warehouseDetails.facilityToWhich)}}"
              },
              {
                "key": "teamCode",
                "value":
                    "{{fn:getStockTeamCode(formData.warehouseDetails.teamCode, formData.stockDetails.deliveryTeam, formData.warehouseDetails.facilityFromWhich)}}"
              },
              {
                "key": "deliveryTeamName",
                "value":
                    "{{fn:getStockTeamName(formData.warehouseDetails.teamCode, formData.stockDetails.deliveryTeam, formData.warehouseDetails.facilityFromWhich)}}"
              },
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "comment",
                "value":
                    "{{fn:getCommentValue(formData.stockProductDetails.comment)}}"
              }
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                  "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                }
              }
            ]
          }
        },
        {
          "actionType": "UPDATE_STOCK_BALANCE",
          "properties": {
            "entity": "STOCK",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "INVENTORY_UPDATE_STOCK_BALANCE_FAILED_MESSAGE"
                }
              }
            ]
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "stockSuccess",
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "manageStock",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "INVENTORY_NAVIGATION_FAILED_MESSAGE"}
              }
            ],
            "data": [
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "transactionDetailsHeading",
                "value":
                    "{{fn:getViewTransactionHeadingCode(navigation.stockEntryType)}}"
              }
            ]
          }
        }
      ]
    },
    {
      "screenType": "FORM",
      "category": "INVENTORY",
      "name": "RECORDLESSEXCESS",
      "version": 1,
      "disabled": false,
      "isSelected": true,
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "projectFacility",
            "awaitResults": true,
            "skipAccumulatedFilters": true,
            "data": [
              {
                "key": "projectId",
                "value": "{{singleton.selectedProject.id}}",
                "operation": "equals"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "InventoryWrapper",
        "groupByType": true,
        "rootEntity": "ProjectFacilityModel",
        "filters": [],
        "relations": [
          {
            "name": "facility",
            "entity": "FacilityModel",
            "match": {"field": "id", "equalsFrom": "facilityId"}
          },
          {
            "name": "productVariant",
            "entity": "ProductVariantModel",
            "match": {"field": "id", "equalsFrom": "resource"}
          }
        ],
        "searchConfig": {
          "primary": "projectFacility",
          "select": ["projectFacility", "productVariant", "stock"]
        }
      },
      "pages": [
        {
          "page": "warehouseDetails",
          "label": "APPONE_MANAGESTOCK_WAREHOUSE_SCREEN_HEADING",
          "order": 1,
          "type": "object",
          "description": "APPONE_MANAGESTOCK_WAREHOUSE_SCREEN_DESCRIPTION",
          "actionLabel": "APPONE_MANAGESTOCK_WAREHOUSE_ACTION_BUTTON_LABEL_1",
          "properties": [
            {
              "type": "integer",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_dateOfReceipt",
              "order": 1,
              "value": "",
              "format": "date",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": true,
              "fieldName": "dateOfEntry",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": true,
              "includeInForm": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_dateOfReceipt_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "string",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_administrativeArea",
              "order": 2,
              "value": "",
              "format": "locality",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "administrativeArea",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInForm": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_administrativeArea_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false
            },
            {
              "type": "dynamic",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich",
              "order": 3,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_SELECT_FACILITY_TO_WHICH_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "facilityToWhich",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "facilityHierarchy",
                  "value": {
                    "hierarchyMapping": {
                      "Province": {
                        "forReceipt": ["National Warehouse"],
                        "forIssue": ["District Warehouse"]
                      },
                      "District": {
                        "forReceipt": ["State Warehouse"],
                        "forIssue": ["PHU Warehouse"]
                      },
                      "PHU": {
                        "forReceipt": ["District Warehouse"],
                        "forIssue": ["Distribution Point", "DELIVERY_TEAM"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["PHU Warehouse"],
                        "forIssue": ["DELIVERY_TEAM"]
                      },
                      "DELIVERY_TEAM": {
                        "forIssue": ["DELIVERY_TEAM"],
                        "forReceipt": ["Distribution Point"]
                      }
                    },
                    "useTransactionType": true
                  },
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "includeInForm": true,
              "enums": []
            },
            {
              "type": "string",
              "enums": [],
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "warehouseDetails.facilityToWhich==DELIVERY_TEAM"
                  }
                ]
              },
              "label": "APP_CONFIG_INVENTORY_warehouseDetails_teamCode_LABEL",
              "order": 4,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "isMdms": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "teamCode",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInSummary": true,
              "validations": [
                {
                  "type": "regex",
                  "value": r"^(?:[^|]+\|\|)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
                  "message": "INVENTORY_DELIVERY_TEAM_QR_INVALID"
                },
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "isGS1Code",
                  "value": false,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_isGS1Code_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "dropDownOptions": []
            }
          ],
          "navigateTo": {"name": "lessExcessDetails", "type": "form"}
        },
        {
          "page": "lessExcessDetails",
          "label": "INVENTORY_LESS_EXCESS_DETAILS_HEADING",
          "order": 2,
          "type": "object",
          "format": null,
          "description": "INVENTORY_LESS_EXCESS_DETAILS_DESCRIPTION",
          "actionLabel": "CORE_COMMON_SUBMIT",
          "properties": [
            {
              "type": "string",
              "label": "INVENTORY_WHAT_ARE_YOU_RECORDING_LABEL",
              "order": 1,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_RECORD_TYPE_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "recordType",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_RECORD_TYPE_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "LESS", "name": "Loss"},
                {"code": "EXCESS", "name": "Excess"}
              ]
            },
            {
              "type": "dynamic",
              "label": "APPONE_INVENTORY_PRODUCTDETAILS_LABEL",
              "order": 2,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_PRODUCT_VARIANT_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "productVariant",
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": "HCM.DELIVERY_COMMENT_OPTIONS_POPULATOR",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_PRODUCT_VARIANT_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": []
            },
            {
              "type": "dynamic",
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich",
              "order": 3,
              "value": "",
              "format": "custom",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_SELECT_FACILITY_FROM_WHICH_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "facilityFromWhich",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityToWhich_mandatory_message"
                },
                {
                  "type": "facilityHierarchy",
                  "value": {
                    "hierarchyMapping": {
                      "Province": {
                        "forReceipt": ["National Warehouse"],
                        "forIssue": ["District Warehouse"]
                      },
                      "District": {
                        "forReceipt": ["State Warehouse"],
                        "forIssue": ["Chiefdom Warehouse"]
                      },
                      "Chiefdom": {
                        "forReceipt": ["District Warehouse"],
                        "forIssue": ["PHU Warehouse"]
                      },
                      "PHU": {
                        "forReceipt": ["Chiefdom Warehouse"],
                        "forIssue": ["Distribution Point", "DELIVERY_TEAM"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["PHU Warehouse"],
                        "forIssue": ["DELIVERY_TEAM"]
                      },
                      "DELIVERY_TEAM": {
                        "forIssue": ["DELIVERY_TEAM"],
                        "forReceipt": ["Distribution Point"]
                      }
                    },
                    "useTransactionType": true
                  },
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "includeInForm": true,
              "schemaCode": "HCM.FACILITY_OPTIONS_POPULATOR"
            },
            {
              "type": "string",
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "lessExcessDetails.facilityFromWhich==DELIVERY_TEAM"
                  }
                ]
              },
              "label": "APPONE_MANAGESTOCK_WAREHOUSE_label_deliveryTeamCode",
              "order": 4,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_SCAN_TEAM_CODE_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "deliveryTeam",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich_mandatory_message"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": []
            },
            {
              "type": "integer",
              "label": "INVENTORY_QUANTITY_LABEL",
              "order": 5,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantity",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_QUANTITY_REQUIRED_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_SENT_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "INVENTORY_VALID_NUMBER_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_REASON_FOR_LESS_EXCESS_LABEL",
              "order": 6,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_REASON_FOR_LESS_EXCESS_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "reasonForLessExcess",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_REASON_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            // The View Reports detail table renders a Waybill Number column
            // for every report type, but Less/Excess captured no waybill at
            // all and the stockLessExcess transformer had no wayBillNumber
            // mapping - so getWayBillNumber fell through both sources and
            // the column was permanently blank on the Loss and Excess
            // reports. Optional, since an adjustment is not always tied to a
            // waybill; same pattern/validation as the receipt flow's own
            // wayBillNumber field.
            {
              "type": "string",
              "label": "APPONE_INVENTORY_WAYBILL_LABEL",
              "order": 7,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "wayBillNumber",
              "mandatory": false,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "pattern",
                  "value": "^[A-Za-z0-9]*\$",
                  "message":
                      "INVENTORY_WAYBILL_NUMBER_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
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
          "autoEnable": null,
          "navigateTo": {"name": "stock-acknowledgement", "type": "template"}
        }
      ],
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "configName": "stockLessExcess",
            "data": [
              {
                "key": "stockEntryType",
                "value": "{{formData.lessExcessDetails.recordType}}"
              },
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "senderId",
                "value": "{{fn:getStockLessExcessPartyValue(formData.lessExcessDetails.recordType, 'senderId', formData.lessExcessDetails.facilityFromWhich, formData.warehouseDetails.facilityToWhich)}}"
              },
              {
                "key": "senderType",
                "value": "{{fn:getStockLessExcessPartyValue(formData.lessExcessDetails.recordType, 'senderType', formData.lessExcessDetails.facilityFromWhich, formData.warehouseDetails.facilityToWhich)}}"
              },
              {
                "key": "receiverId",
                "value": "{{fn:getStockLessExcessPartyValue(formData.lessExcessDetails.recordType, 'receiverId', formData.lessExcessDetails.facilityFromWhich, formData.warehouseDetails.facilityToWhich)}}"
              },
              {
                "key": "receiverType",
                "value": "{{fn:getStockLessExcessPartyValue(formData.lessExcessDetails.recordType, 'receiverType', formData.lessExcessDetails.facilityFromWhich, formData.warehouseDetails.facilityToWhich)}}"
              }
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                  "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                }
              }
            ]
          }
        },
        {
          "actionType": "UPDATE_STOCK_BALANCE",
          "properties": {
            "entity": "STOCK",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "INVENTORY_UPDATE_STOCK_BALANCE_FAILED_MESSAGE"
                }
              }
            ]
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "stockSuccess",
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "manageStock",
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {"message": "INVENTORY_NAVIGATION_FAILED_MESSAGE"}
              }
            ],
            "data": [
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "transactionDetailsHeading",
                "value":
                    "{{fn:getViewTransactionHeadingCode(formData.lessExcessDetails.recordType)}}"
              }
            ]
          }
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "stockSuccess",
      "heading": "",
      "description": "",
      "body": [
        {
          "format": "panelCard",
          "type": "template",
          "fieldName": "stockSuccessPanelCard",
          "label": "INVENTORY_STOCK_SUCCESS_LABEL",
          "description":
              "INVENTORY_STOCK_SUCCESS_MRN_DESCRIPTION {{navigation.mrnNumber}}",
          "properties": {"type": "success"},
          "primaryAction": {
            "label": "INVENTORY_VIEW_TRANSACTION_LABEL",
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "type": "TEMPLATE",
                  "name": "viewTransactionDetails",
                  "navigationMode": "popUntilAndPush",
                  "popUntilPageName": "manageStock",
                  "data": [
                    {
                      "key": "selectedStock",
                      "value": "{{navigation.mrnNumber}}"
                    },
                    {
                      "key": "clientReferenceId",
                      "value": "{{navigation.clientReferenceId}}"
                    },
                    {
                      "key": "transactionDetailsHeading",
                      "value": "{{navigation.transactionDetailsHeading}}"
                    }
                  ]
                }
              }
            ]
          },
          "secondaryAction": {
            "label": "INVENTORY_CREATE_NEW_TRANSACTION_LABEL",
            "onAction": [
              {
                "actionType": "NAVIGATION",
                "properties": {
                  "type": "TEMPLATE",
                  "name": "manageStock",
                  "navigationMode": "popUntilAndReplace",
                  "popUntilPageName": "manageStock"
                }
              }
            ]
          }
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "viewTransactionDetails",
      "heading": "{{navigation.transactionDetailsHeading}}",
      "description": "",
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "footer": [],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "stock",
            "awaitResults": true,
            "skipAccumulatedFilters": true,
            "data": [
              {
                "key": "additionalFields",
                "value": "{{fn:getCommentValue(navigation.selectedStock, '__NO_MATCHING_STOCK_MRN__')}}",
                "operation": "contains"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "ViewStockDetailsWrapper",
        "groupByType": true,
        "rootEntity": "StockModel",
        "filters": [],
        "relations": [
          {"name": "stock", "entity": "StockModel"}
        ],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"]
        }
      },
      "body": [
        {
          "format": "listView",
          "type": "template",
          "fieldName": "stockItems",
          "dataSource": "StockModel",
          "child": {
            "format": "card",
            "type": "template",
            "fieldName": "viewTransactionDetailsCard",
            "children": [
              {
                "format": "labelPairList",
                "type": "template",
                "fieldName": "viewTransactionDetailsLabelPairList",
                "data": [
                  {
                    "key": "INVENTORY_RESOURCE_LABEL",
                    "value": "{{item.additionalFields.fields.sku}}"
                  },
                  {
                    "key": "INVENTORY_TRANSACTION_TYPE_LABEL",
                    "value": "{{item.transactionType}}"
                  },
                  {
                    "key": "INVENTORY_TRANSACTION_REASON_LABEL",
                    // stockEntryType is passed so a LESS/EXCESS adjustment
                    // shows its own reason instead of echoing the RECEIVED
                    // transactionReason it is stored with.
                    "value":
                        "{{fn:getTransactionReasonDisplayCode(item.transactionReason, item.additionalFields.fields.stockEntryType)}}",
                    "hideIfNull": true
                  },
                  // NOTE: Discrepancy Reason is rendered once, lower down,
                  // next to the Actual/Shortfall Quantity rows it explains.
                  // A second identical copy used to sit here; it stayed
                  // invisible only because discrepancyReason was never
                  // populated on the records normally opened from this
                  // screen. Now that an accepted partial receipt carries the
                  // reason too, keeping both would print the row twice.
                  {
                    "key":
                        "{{fn:getSecondPagePartyLabel(item.additionalFields.fields)}}",
                    "value":
                        "{{fn:getSecondPageParty(item.additionalFields.fields, item.senderId, item.receiverId, item.senderType, item.receiverType)}}"
                  },
                  {
                    "key": "INVENTORY_MRN_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.mrnNumber}}"
                  },
                  {
                    "key": "INVENTORY_WAYBILL_NUMBER_LABEL",
                    "value":
                        "{{fn:getWayBillNumber(item.wayBillNumber, item.additionalFields.fields.wayBillNumber)}}",
                    "hideIfNull": true
                  },
                  {
                    "key": "INVENTORY_BATCH_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.batchNumber}}"
                  },
                  {
                    "key": "APPONE_INVENTORY_TRANSPORT_LABEL",
                    "value": "{{item.additionalFields.fields.transportType}}",
                    "hideIfNull": true
                  },
                  {
                    "key": "APPONE_INVENTORY_VEHICLE_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.vehicle_number}}",
                    "hideIfNull": true
                  },
                  {
                    "key":
                        "{{fn:getDetailsPrimaryQuantityLabel(item.additionalFields.fields.stockEntryType, item.transactionReason, item.additionalFields.fields.discrepancyReason, item.additionalFields.fields.originalQuantityReceived, item.additionalFields.fields.actualQuantityReceived, item.quantity, item.additionalFields.fields.originalIssueClientReferenceId, item.additionalFields.fields.status, item.senderId, item.receiverId)}}",
                    "value":
                        "{{fn:coalesceQuantity(item.additionalFields.fields.originalQuantityReceived, item.quantity)}}"
                  },
                  {
                    "key":
                        "{{fn:getDetailsConfirmedQuantityLabel(item.additionalFields.fields.stockEntryType, item.transactionReason, item.additionalFields.fields.discrepancyReason, item.additionalFields.fields.originalQuantityReceived, item.additionalFields.fields.actualQuantityReceived, item.quantity, item.additionalFields.fields.originalIssueClientReferenceId, item.additionalFields.fields.status, item.senderId, item.receiverId)}}",
                    "value":
                        "{{fn:getDetailsConfirmedQuantity(item.additionalFields.fields.stockEntryType, item.transactionReason, item.additionalFields.fields.discrepancyReason, item.additionalFields.fields.originalQuantityReceived, item.additionalFields.fields.actualQuantityReceived, item.quantity, item.additionalFields.fields.originalIssueClientReferenceId, item.additionalFields.fields.status, item.senderId, item.receiverId)}}",
                    "hideIfNull": true
                  },
                  {
                    "key":
                        "{{fn:getDetailsDifferenceLabel(item.additionalFields.fields.stockEntryType, item.transactionReason, item.additionalFields.fields.discrepancyReason, item.additionalFields.fields.originalQuantityReceived, item.additionalFields.fields.actualQuantityReceived, item.quantity, item.additionalFields.fields.originalIssueClientReferenceId, item.additionalFields.fields.status, item.senderId, item.receiverId)}}",
                    "value":
                        "{{fn:getDetailsDifference(item.additionalFields.fields.stockEntryType, item.transactionReason, item.additionalFields.fields.discrepancyReason, item.additionalFields.fields.originalQuantityReceived, item.additionalFields.fields.actualQuantityReceived, item.quantity, item.additionalFields.fields.originalIssueClientReferenceId, item.additionalFields.fields.status, item.senderId, item.receiverId)}}",
                    "hideIfNull": true
                  },
                  {
                    "key": "INVENTORY_DISCREPANCY_REASON_LABEL",
                    "value":
                        "{{fn:getDiscrepancyReasonDisplayCode(item.additionalFields.fields.discrepancyReason)}}",
                    "hideIfNull": true
                  },
                  {
                    "key": "INVENTORY_COMMENTS_LABEL",
                    "value":
                        "{{fn:safeString(item.additionalFields.fields.comments)}}",
                    "hideIfNull": true
                  }
                ]
              }
            ]
          },
          "properties": {"spacing": "spacer4"}
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "incomingTransactions",
      "heading": "INVENTORY_INCOMING_TRANSACTIONS_HEADING",
      "description": "INVENTORY_INCOMING_TRANSACTIONS_DESCRIPTION",
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "footer": [],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "stock",
            "awaitResults": true,
            // Two filters below share the "additionalFields" key
            // (contains/notContains) - SearchStateManager.getAllFilters
            // (used when accumulating filters) deduplicates by key, so
            // without skipping accumulation one of the two would silently
            // clobber the other. This screen has no other SEARCH_EVENT
            // triggers (no dropdowns/filters UI) to accumulate with, so
            // skipping is safe here.
            "skipAccumulatedFilters": true,
            "data": [
              {
                // Incoming transactions are only records addressed to this
                // user/facility. Including senderId also surfaced the
                // distributor's own in-transit returns here; those are not
                // available to accept and intentionally have no discrepancy
                // reason, which made Partial Accept appear broken.
                "key": "receiverId",
                "value": "{{fn:getUserFacilityId()}}",
                "operation": "equals"
              },
              {
                "key": "auditCreatedBy",
                "value": "{{singleton.loggedInUserUuid}}",
                "operation": "notEquals"
              },
              {
                "key": "productVariantId",
                "value": "{{fn:getProjectProductVariantIds()}}",
                "operation": "in"
              },
              {
                "key": "additionalFields",
                "value": "IN_TRANSIT",
                "operation": "contains"
              },
              {
                // "additionalFields contains IN_TRANSIT" was meant to mean
                // "status is still IN_TRANSIT (pending accept)", but it's a
                // raw substring match against the whole stored blob - a
                // record with discrepancyReason "IN_TRANSIT" keeps that
                // literal text in its additionalFields forever, even after
                // its own status flips to ACCEPTED. Without this exclusion,
                // an already-accepted in-transit shortfall return kept
                // reappearing here indefinitely, letting the upper hierarchy
                // re-run Accept on the same resolved transaction over and
                // over.
                "key": "additionalFields",
                "value": "\"key\":\"status\",\"value\":\"ACCEPTED\"",
                "operation": "notContains"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "IncomingStockWrapper",
        "groupByType": true,
        "rootEntity": "StockModel",
        "groupBy": "additionalFields.fields.mrnNumber",
        "filters": [],
        "relations": [
          {"name": "stock", "entity": "StockModel"}
        ],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"],
          "orderBy": {"field": "clientCreatedTime", "order": "DESC"}
        }
      },
      "body": [
        {
          "format": "infoCard",
          "type": "template",
          "fieldName": "incomingTransactionsEmptyStateInfoCard",
          "hidden": null,
          "visible": "{{fn:hasResults('StockModel')}} == false",
          "label": "INVENTORY_NO_INCOMING_TRANSACTIONS_LABEL",
          "description": "INVENTORY_NO_INCOMING_TRANSACTIONS_DESCRIPTION"
        },
        {
          "format": "listView",
          "type": "template",
          "hidden": null,
          "visible": "{{fn:hasResults('StockModel')}} == true",
          "fieldName": "incomingList",
          "dataSource": "StockModel",
          "properties": {"spacing": "spacer4"},
          "child": {
            "format": "card",
            "type": "template",
            "fieldName": "incomingTransactionsListCard",
            "children": [
              {
                "format": "row",
                "type": "template",
                "fieldName": "incomingTransactionsHeaderRow",
                "properties": {
                  "mainAxisAlignment": "spaceBetween",
                  "mainAxisSize": "max"
                },
                "children": [
                  {
                    "format": "tag",
                    "type": "template",
                    "fieldName": "incomingTransactionsMrnTag",
                    "label": "MRN {{item.groupKey}}"
                  },
                  {
                    "format": "textTemplate",
                    "type": "template",
                    "fieldName": "incomingTransactionsDateText",
                    "value":
                        "{{fn:formatDate(item.items[0].dateOfEntry, 'date', dd MMM yyyy)}}"
                  }
                ]
              },
              {
                "format": "row",
                "type": "template",
                "fieldName": "incomingTransactionsPartyRow",
                "properties": {
                  "mainAxisAlignment": "spaceBetween",
                  "mainAxisSize": "max"
                },
                "children": [
                  {
                    "format": "expanded",
                    "type": "template",
                    "fieldName": "incomingTransactionsPartyExpanded",
                    "child": {
                      "format": "column",
                      "type": "template",
                      "fieldName": "incomingTransactionsPartyColumn",
                      "properties": {
                        "mainAxisAlignment": "spaceBetween",
                        "mainAxisSize": "min"
                      },
                      "children": [
                        {
                          "format": "textTemplate",
                          "type": "template",
                          "fieldName": "incomingTransactionsSenderLabelText",
                          "value": "APP_CONFIG_INVENTORY_SENDER_LABEL",
                          "maxLines": 1
                        },
                        {
                          "format": "textTemplate",
                          "type": "template",
                          "fieldName": "incomingTransactionsSenderValueText",
                          "value":
                              "{{fn:getFacilityName(item.items[0].senderId)}}",
                          "maxLines": 2
                        }
                      ]
                    }
                  },
                  {
                    "format": "textTemplate",
                    "type": "template",
                    "fieldName": "incomingTransactionsTransactionTypeText",
                    "value": "{{item.items[0].transactionType}}",
                    "maxLines": 1
                  }
                ]
              },
              {
                "format": "listView",
                "type": "template",
                "fieldName": "incomingTransactionsGroupedItemsList",
                "dataSource": "item.items",
                "child": {
                  "format": "textTemplate",
                  "type": "template",
                  "fieldName": "incomingTransactionsGroupedItemText",
                  "value":
                      "{{item.additionalFields.fields.sku}}: {{item.quantity}}"
                }
              },
              {
                "format": "button",
                "type": "template",
                "fieldName": "incomingTransactionsSelectButton",
                "label": "INVENTORY_SELECT_LABEL",
                "visible": "{{item.items[0].transactionType == 'DISPATCHED'}}",
                "properties": {
                  "type": "primary",
                  "size": "medium",
                  "mainAxisSize": "max",
                  "mainAxisAlignment": "center"
                },
                "onAction": [
                  {
                    "actionType": "NAVIGATION",
                    "properties": {
                      "type": "FORM",
                      "name": "stockReceiptDetails",
                      "data": [
                        {"key": "stockEntryType", "value": "RECEIPT"},
                        {
                          "key": "incomingStockEntryType",
                          "value":
                              "{{item.items[0].additionalFields.fields.stockEntryType}}"
                        },
                        {
                          "key": "discrepancyReason",
                          "value":
                              "{{fn:getStockDiscrepancyReason(item.items)}}"
                        },
                        {
                          "key": "discrepancyReasonDisplay",
                          "value":
                              "{{fn:getDiscrepancyReasonDisplayCode(fn:getStockDiscrepancyReason(item.items))}}"
                        },
                        {
                          "key": "originalIssueClientReferenceId",
                          "value":
                              "{{item.items[0].additionalFields.fields.originalIssueClientReferenceId}}"
                        },
                        {
                          "key": "partial_flow",
                          "value":
                              "{{item.items[0].additionalFields.fields.partial_flow}}"
                        },
                        {"key": "transactionType", "value": "RECEIVED"},
                        {"key": "primaryRole", "value": "RECEIVER"},
                        {"key": "secondaryRole", "value": "SENDER"},
                        {
                          "key": "mrnNumber",
                          "value":
                              "{{fn:getCommentValue(item.items[0].additionalFields.fields.mrnNumber, fn:generateUniqueMaterialNoteNumber())}}"
                        },
                        {
                          "key": "selectedTransactionMrn",
                          "value":
                              "{{item.items[0].additionalFields.fields.mrnNumber}}"
                        },
                        {"key": "isEdit", "value": "true"},
                        {"key": "prefillFromScan", "value": "true"},
                        {
                          "key": "senderFacilityId",
                          "value": "{{item.items[0].senderId}}"
                        },
                        {
                          "key": "receivedFromName",
                          "value":
                              "{{fn:resolveTeamName(item.items[0].additionalFields.fields)}}"
                        },
                        {
                          "key": "senderPartyType",
                          "value": "{{item.items[0].senderType}}"
                        },
                        {
                          "key": "quantity",
                          "value": "{{item.items[0].quantity}}"
                        },
                        {
                          "key": "wayBillNumber",
                          "value":
                              "{{fn:getWayBillNumber(item.items[0].wayBillNumber, item.items[0].additionalFields.fields.wayBillNumber)}}"
                        },
                        {
                          "key": "productVariantId",
                          "value": "{{item.items[0].productVariantId}}"
                        },
                        {
                          "key": "sku",
                          "value":
                              "{{item.items[0].additionalFields.fields.sku}}"
                        },
                        {
                          "key": "batchNumber",
                          "value":
                              "{{item.items[0].additionalFields.fields.batchNumber}}"
                        },
                        {
                          "key": "transportType",
                          "value":
                              "{{item.items[0].additionalFields.fields.transportType}}"
                        },
                        {
                          "key": "vehicleNumber",
                          "value":
                              "{{item.items[0].additionalFields.fields.vehicle_number}}"
                        },
                        {
                          "key": "comment",
                          "value":
                              "{{item.items[0].additionalFields.fields.comments}}"
                        },
                        {
                          "key": "originalComment",
                          "value":
                              "{{item.items[0].additionalFields.fields.comments}}"
                        },
                        {
                          "key": "clientReferenceId",
                          "value": "{{item.items[0].clientReferenceId}}"
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    {
      "screenType": "FORM",
      "category": "INVENTORY",
      "name": "stockReceiptDetails",
      "heading": "INVENTORY_STOCK_RECEIPT_DETAILS_HEADING",
      "description": "",
      "version": 1,
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        },
        {
          "format": "helpLink",
          "type": "template",
          "fieldName": "stockReceiptDetailsHelpLink",
          "label": "CORE_COMMON_HELP"
        }
      ],
      "onAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "configName": "stockReceipt",
            "forceCreate": true,
            "data": [
              {
                "key": "partial_flow",
                "value":
                    "{{fn:isPartialStockFlow(navigation.originalIssueClientReferenceId, navigation.partial_flow)}}"
              },
              {"key": "stockEntryType", "value": "RECEIPT"},
              {"key": "transactionType", "value": "RECEIVED"},
              {"key": "primaryRole", "value": "RECEIVER"},
              {"key": "secondaryRole", "value": "SENDER"},
              {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
              {
                "key": "senderFacilityId",
                "value": "{{navigation.senderFacilityId}}"
              },
              {
                "key": "receivedFromName",
                "value": "{{navigation.receivedFromName}}"
              },
              {
                "key": "senderPartyType",
                "value": "{{navigation.senderPartyType}}"
              },
              {
                "key": "receiverPartyType",
                "value": "{{fn:getUserPartyType()}}"
              },
              {
                "key": "productVariantId",
                "value": "{{navigation.productVariantId}}"
              },
              {"key": "userFacilityId", "value": "{{fn:getUserFacilityId()}}"},
              {"key": "sku", "value": "{{navigation.sku}}"},
              {"key": "quantity", "value": "{{navigation.quantity}}"},
              {"key": "wayBillNumber", "value": "{{navigation.wayBillNumber}}"},
              {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
              {"key": "transportType", "value": "{{navigation.transportType}}"},
              {"key": "vehicleNumber", "value": "{{navigation.vehicleNumber}}"}
            ],
            "onError": [
              {
                "actionType": "SHOW_TOAST",
                "properties": {
                  "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
                }
              }
            ]
          }
        },
        {
          "actionType": "UPDATE_EVENT",
          "properties": {
            "source": "existingModels",
            "entity": "StockModel",
            // Reuse the original incoming transaction's own MRN here (same
            // as the partial-accept branch below already does) instead of
            // generating a fresh one - this record and the "stockReceipt"
            // entity just created above both belong to the SAME accept
            // action, and viewTransactionDetails searches by
            // navigation.selectedStock (set to this MRN when the user taps
            // "View Transaction" on the success screen - see the trailing
            // stockSuccess navigation). Generating a brand new, different
            // MRN here meant neither this record nor the receipt ever
            // matched that search, so the upper hierarchy's View
            // Transactions page came up completely blank after Accept.
            "modify": [
              {
                "key": "StockModel.additionalFields.fields.partial_flow",
                "value":
                    "{{fn:isPartialStockFlow(navigation.originalIssueClientReferenceId, navigation.partial_flow)}}"
              },
              {
                "key":
                    "StockModel.additionalFields.fields.actualQuantityReceived",
                "value": "{{navigation.quantity}}"
              },
              {
                "key": "StockModel.additionalFields.fields.status",
                "value": "ACCEPTED"
              },
              {
                "key": "StockModel.additionalFields.fields.mrnNumber",
                "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"
              },
              {
                "key": "StockModel.additionalFields.fields.comments",
                "value":
                    "{{fn:getCommentValue(formData.stockReceiptDetails.comment, navigation.originalComment)}}"
              },
              {"key": "StockModel.transactionReason", "value": "RECEIVED"}
            ]
          }
        },
        {
          // Product decision: Stock damage now behaves exactly like Stock
          // Loss - a terminal write-off that must never enter any balance,
          // not a quantity that stays "in hand" in a separate Damaged
          // bucket. The discrepancy reason is set by the LOWER hierarchy at
          // the time they partially accepted the original dispatch (see
          // onSecondaryAction's generic partial-accept block below) and is
          // carried down through navigation.discrepancyReason (populated
          // from the incoming record's own additionalFields when this
          // screen is opened - see the "Select" button's NAVIGATION data in
          // this file's incoming-transactions list) - the upper hierarchy
          // does not choose a reason themselves, Accept just resolves
          // whatever reason already arrived with the shortfall. Checked
          // before the generic re-issue block below so damage takes
          // priority over the in-transit/miscount re-issue path. Keep the
          // shortfall quantity on the record for reconciliation/reporting,
          // while deliberately making no UPDATE_STOCK_BALANCE call. The
          // upper facility's stock calculation recognizes this linked
          // shortfall as already accounted for by the original dispatch.
          // stockEntryType is tagged DAMAGED so damage and loss stay distinct
          // in reports.
          "condition": {
            "expression":
                "navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'STOCK_DAMAGE'"
          },
          "actions": [
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "source": "existingModels",
                "entity": "StockModel",
                "modify": [
                  {
                    "key": "StockModel.additionalFields.fields.status",
                    "value": "ACCEPTED"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.stockEntryType",
                    "value": "DAMAGED"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.actualQuantityReceived",
                    "value": "0"
                  },
                  {
                    "key": "StockModel.transactionReason",
                    "value": "STOCK_DAMAGE"
                  }
                ]
              }
            },
            {
              // Same acknowledgment screen shown after creating any other
              // stock transaction (see RECORDSTOCK's "stockSuccess"
              // navigation) - Accept/Partial Accept previously only showed a
              // toast and dropped straight back to manageStock, with no way
              // to review the just-recorded transaction.
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "stockSuccess",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "manageStock",
                "data": [
                  {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
                  {
                    "key": "clientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "transactionDetailsHeading",
                    "value":
                        "{{fn:getAcceptedTransactionHeadingCode(navigation.incomingStockEntryType, navigation.discrepancyReason)}}"
                  }
                ]
              }
            }
          ]
        },
        {
          // Same deal as the DAMAGED block above: the "Stock Loss" reason
          // was chosen by the LOWER hierarchy at step 2b, carried here via
          // navigation.discrepancyReason. Per Stock PRD this is a terminal
          // write-off - the lost quantity must never enter any balance, so
          // there is deliberately no UPDATE_STOCK_BALANCE call in this
          // block.
          "condition": {
            "expression":
                "navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'STOCK_LOSS'"
          },
          "actions": [
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "source": "existingModels",
                "entity": "StockModel",
                "modify": [
                  {
                    "key": "StockModel.additionalFields.fields.status",
                    "value": "ACCEPTED"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.actualQuantityReceived",
                    "value": "0"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.stockEntryType",
                    "value": "LOSS"
                  },
                  {"key": "StockModel.transactionReason", "value": "STOCK_LOSS"}
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "stockSuccess",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "manageStock",
                "data": [
                  {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
                  {
                    "key": "clientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "transactionDetailsHeading",
                    "value":
                        "{{fn:getAcceptedTransactionHeadingCode(navigation.incomingStockEntryType, navigation.discrepancyReason)}}"
                  }
                ]
              }
            }
          ]
        },
        {
          "condition": {
            "expression": "navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'IN_TRANSIT'"
          },
          "actions": [
            {
              // Flip the original incoming RETURNED record's own status from
              // IN_TRANSIT to ACCEPTED, same as the DAMAGE/LOSS branches
              // above. calculateStockMetrics now skips any record addressed
              // to this facility while it's still IN_TRANSIT (so a pending
              // return doesn't get folded into the balance before this
              // Accept step runs) - without this update that status would
              // never change. Shortfall resolutions are excluded from the
              // upper facility's balance because the original dispatch has
              // already deducted this quantity there.
              "actionType": "UPDATE_EVENT",
              "properties": {
                "source": "existingModels",
                "entity": "StockModel",
                "modify": [
                  {
                    "key": "StockModel.additionalFields.fields.status",
                    "value": "ACCEPTED"
                  }
                ]
              }
            },
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "shortfallTransaction",
                "forceCreate": true,
                "data": [
                  {"key": "stockEntryType", "value": "ISSUED"},
                  {
                    "key": "senderFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {
                    "key": "receiverFacilityId",
                    "value": "{{navigation.senderFacilityId}}"
                  },
                  {
                    "key": "senderPartyType",
                    "value": "{{fn:getUserPartyType()}}"
                  },
                  {
                    "key": "receiverPartyType",
                    "value":
                        "{{fn:getPartyTypeForFacilityId(navigation.senderFacilityId)}}"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.productVariantId}}"
                  },
                  {
                    "key": "userFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {"key": "sku", "value": "{{navigation.sku}}"},
                  {
                    "key": "wayBillNumber",
                    "value": "{{navigation.wayBillNumber}}"
                  },
                  {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
                  {
                    "key": "transportType",
                    "value": "{{navigation.transportType}}"
                  },
                  {
                    "key": "vehicleNumber",
                    "value": "{{navigation.vehicleNumber}}"
                  },
                  {"key": "quantity", "value": "{{navigation.quantity}}"},
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  },
                  {
                    "key": "originalIssueClientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "discrepancyReason",
                    "value": "{{navigation.discrepancyReason}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                      "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
          ]
        },
        {
          // Plain Accept of an original dispatch (not resolving any
          // RETURNED shortfall) - none of the branches above matched, so
          // contextData['entities'] still holds the unmodified "stockReceipt"
          // entity built at the very top of this onAction array
          // (transactionType=RECEIVED, quantity=navigation.quantity, the full
          // dispatched amount). This is the ONLY branch that credits a
          // receipt directly. A RETURNED shortfall is already accounted for
          // by the original dispatch and must not credit the upper facility.
          "condition": {"expression": "DEFAULT"},
          "actions": [
            {
              "actionType": "UPDATE_STOCK_BALANCE",
              "properties": {
                "entity": "STOCK",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_UPDATE_STOCK_BALANCE_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            }
          ]
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "stockSuccess",
            "navigationMode": "popUntilAndPush",
            "popUntilPageName": "manageStock",
            "data": [
              {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
              {
                "key": "clientReferenceId",
                "value": "{{navigation.clientReferenceId}}"
              },
              {
                "key": "transactionDetailsHeading",
                "value":
                    "{{fn:getAcceptedTransactionHeadingCode(navigation.incomingStockEntryType, navigation.discrepancyReason)}}"
              }
            ]
          }
        }
      ],
      "onSecondaryAction": [
        {
          // The entered quantity must be strictly greater than 0 and
          // strictly less than the quantity on the record being accepted.
          // 0 means nothing was received (not a partial accept) and a value
          // >= quantity means everything was (that is the primary Accept
          // button / onAction). Checked ahead of the partial-accept block
          // below so an invalid quantity is rejected with a clear error
          // instead of silently matching no branch.
          //
          // This now applies to RETURNED records too: the upper level can
          // partially accept a shortfall return, and whatever it does not
          // accept is re-issued back down.
          "condition": {
            "expression":
                "actualQuantityReceived < 0 || actualQuantityReceived >= quantity"
          },
          "actions": [
            {
              "actionType": "SHOW_TOAST",
              "properties": {
                "message": "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID",
                "type": "error"
              }
            }
          ]
        },
        {
          // Option C: When the upper hierarchy partially accepts an IN_TRANSIT
          // shortfall return (e.g. accepts 30 out of 60), BOTH portions are
          // reissued to the lower facility:
          //   (1) Reissue 1: the accepted in-transit quantity (formData.actualQuantityReceived, e.g. 30)
          //   (2) Reissue 2: the remaining shortfall (subtractQuantity(quantity, actualQuantityReceived), e.g. 30)
          // Total reissued back down = 30 + 30 = 60. Neither reissue deducts from
          // upper facility balance (already deducted in original dispatch).
          "condition": {
            "expression":
                "actualQuantityReceived >= 0 && actualQuantityReceived < quantity && navigation.incomingStockEntryType == 'RETURNED' && navigation.discrepancyReason == 'IN_TRANSIT'"
          },
          "actions": [
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "source": "existingModels",
                "entity": "StockModel",
                "modify": [
                  {
                    "key": "StockModel.additionalFields.fields.partial_flow",
                    "value": true
                  },
                  {
                    "key": "StockModel.additionalFields.fields.status",
                    "value": "ACCEPTED"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.mrnNumber",
                    "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.comments",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.actualQuantityReceived",
                    "value":
                        "{{fn:safeString(formData.actualQuantityReceived)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.originalQuantityReceived",
                    "value": "{{fn:safeString(navigation.quantity)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.discrepancyReason",
                    "value": "IN_TRANSIT"
                  },
                  {"key": "StockModel.transactionReason", "value": "IN_TRANSIT"}
                ]
              }
            },
            {
              // Reissue 1: The accepted in-transit quantity
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "shortfallTransaction",
                "forceCreate": true,
                "data": [
                  {"key": "stockEntryType", "value": "ISSUED"},
                  {
                    "key": "senderFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {
                    "key": "receiverFacilityId",
                    "value": "{{navigation.senderFacilityId}}"
                  },
                  {
                    "key": "senderPartyType",
                    "value": "{{fn:getUserPartyType()}}"
                  },
                  {
                    "key": "receiverPartyType",
                    "value":
                        "{{fn:getPartyTypeForFacilityId(navigation.senderFacilityId)}}"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.productVariantId}}"
                  },
                  {
                    "key": "userFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {"key": "sku", "value": "{{navigation.sku}}"},
                  {
                    "key": "wayBillNumber",
                    "value": "{{navigation.wayBillNumber}}"
                  },
                  {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
                  {
                    "key": "transportType",
                    "value": "{{navigation.transportType}}"
                  },
                  {
                    "key": "vehicleNumber",
                    "value": "{{navigation.vehicleNumber}}"
                  },
                  {
                    "key": "quantity",
                    "value": "{{formData.actualQuantityReceived}}"
                  },
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  },
                  {
                    "key": "originalIssueClientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "discrepancyReason",
                    "value": "IN_TRANSIT"
                  },
                  {
                    "key": "comment",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                      "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
            {
              // Reissue 2: The remaining shortfall quantity
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "shortfallTransaction",
                "forceCreate": true,
                "data": [
                  {"key": "stockEntryType", "value": "ISSUED"},
                  {
                    "key": "senderFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {
                    "key": "receiverFacilityId",
                    "value": "{{navigation.senderFacilityId}}"
                  },
                  {
                    "key": "senderPartyType",
                    "value": "{{fn:getUserPartyType()}}"
                  },
                  {
                    "key": "receiverPartyType",
                    "value":
                        "{{fn:getPartyTypeForFacilityId(navigation.senderFacilityId)}}"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.productVariantId}}"
                  },
                  {
                    "key": "userFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {"key": "sku", "value": "{{navigation.sku}}"},
                  {
                    "key": "wayBillNumber",
                    "value": "{{navigation.wayBillNumber}}"
                  },
                  {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
                  {
                    "key": "transportType",
                    "value": "{{navigation.transportType}}"
                  },
                  {
                    "key": "vehicleNumber",
                    "value": "{{navigation.vehicleNumber}}"
                  },
                  {
                    "key": "quantity",
                    "value":
                        "{{fn:subtractQuantity(navigation.quantity, formData.actualQuantityReceived)}}"
                  },
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  },
                  {
                    "key": "originalIssueClientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "discrepancyReason",
                    "value": "IN_TRANSIT"
                  },
                  {
                    "key": "comment",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                      "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "stockSuccess",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "manageStock",
                "data": [
                  {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
                  {
                    "key": "clientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "transactionDetailsHeading",
                    "value":
                        "{{fn:getAcceptedTransactionHeadingCode(navigation.incomingStockEntryType, navigation.discrepancyReason)}}"
                  }
                ]
              }
            }
          ]
        },
        {
          "condition": {
            "expression":
                "actualQuantityReceived >= 0 && actualQuantityReceived < quantity"
          },
          "actions": [
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "stockReceipt",
                "forceCreate": true,
                "data": [
                  {"key": "partial_flow", "value": true},
                  {"key": "stockEntryType", "value": "RECEIPT"},
                  {"key": "transactionType", "value": "RECEIVED"},
                  {"key": "primaryRole", "value": "RECEIVER"},
                  {"key": "secondaryRole", "value": "SENDER"},
                  {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
                  {
                    "key": "senderFacilityId",
                    "value": "{{navigation.senderFacilityId}}"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.productVariantId}}"
                  },
                  {
                    "key": "userFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {"key": "sku", "value": "{{navigation.sku}}"},
                  {
                    "key": "quantity",
                    "value": "{{formData.actualQuantityReceived}}"
                  },
                  {
                    "key": "wayBillNumber",
                    "value": "{{navigation.wayBillNumber}}"
                  },
                  {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
                  {
                    "key": "transportType",
                    "value": "{{navigation.transportType}}"
                  },
                  {
                    "key": "vehicleNumber",
                    "value": "{{navigation.vehicleNumber}}"
                  },
                  {
                    "key": "comment",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
            {
              "actionType": "UPDATE_EVENT",
              "properties": {
                "source": "existingModels",
                "entity": "StockModel",
                "modify": [
                  {
                    "key": "StockModel.additionalFields.fields.partial_flow",
                    "value": true
                  },
                  {
                    "key": "StockModel.additionalFields.fields.status",
                    "value": "ACCEPTED"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.mrnNumber",
                    "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"
                  },
                  {
                    "key": "StockModel.additionalFields.fields.comments",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.actualQuantityReceived",
                    "value":
                        "{{fn:safeString(formData.actualQuantityReceived)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.originalQuantityReceived",
                    "value": "{{fn:safeString(navigation.quantity)}}"
                  },
                  // StockModel.quantity is deliberately NOT overwritten.
                  // It is what was DISPATCHED, and every stock report is
                  // built on it - shrinking it to the accepted amount made
                  // the sender's own "Stock Issued" stop matching what they
                  // physically sent, so the two sides of one transaction
                  // could never be reconciled. The accepted amount lives in
                  // actualQuantityReceived alongside it.
                  // The Partial Accept popup captures a mandatory
                  // discrepancy reason, but it was only ever written onto
                  // the separate shortfall (RETURNED) record via the
                  // shortfallTransaction transformer. The accepted receipt
                  // itself carried nothing, so viewTransactionDetails' own
                  // Discrepancy Reason row - which reads
                  // additionalFields.discrepancyReason and is hideIfNull -
                  // stayed hidden on the incoming receipt the receiver
                  // actually opens. Stamp it here too so the reason travels
                  // with the record that explains it.
                  {
                    "key":
                        "StockModel.additionalFields.fields.discrepancyReason",
                    "value": "{{fn:safeString(formData.discrepancyReason)}}"
                  },
                  {
                    "key":
                        "StockModel.additionalFields.fields.stockEntryType",
                    "value":
                        "{{fn:getPartialAcceptStockEntryType(navigation.incomingStockEntryType, formData.discrepancyReason)}}"
                  },
                  {
                    "key": "StockModel.transactionReason",
                    "value":
                        "{{fn:getPartialAcceptTransactionReason(navigation.incomingStockEntryType, formData.discrepancyReason)}}"
                  }
                ]
              }
            },
            {
              // UPDATE_STOCK_BALANCE must run here, while contextData['entities']
              // still holds the "Received" entity (qty=actualQuantityReceived)
              // from the FETCH_TRANSFORMER_CONFIG(stockReceipt) call above, and
              // BEFORE the next FETCH_TRANSFORMER_CONFIG(shortfallTransaction)
              // call overwrites entities with the Shortfall Return entity. This
              // correctly credits only the actually-received quantity to the
              // accepting facility's balance. Running it after CREATE_EVENT
              // (its old position) would instead apply the balance delta to the
              // Shortfall Return entity, which - per stock_balance_executor's
              // isDistributorReturn routing - always debits the sender
              // (isSender && stockEntryType=='RETURNED' -> -qty) regardless of
              // role, incorrectly subtracting the shortfall from the accepting
              // facility's own balance.
              "actionType": "UPDATE_STOCK_BALANCE",
              "properties": {
                "entity": "STOCK",
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_UPDATE_STOCK_BALANCE_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
            {
              "actionType": "FETCH_TRANSFORMER_CONFIG",
              "properties": {
                "configName": "shortfallTransaction",
                "forceCreate": true,
                "data": [
                  // Direction-aware: accepting an ISSUED dispatch sends
                  // the remainder UP as RETURNED; accepting a RETURNED
                  // shortfall sends it DOWN as ISSUED (a re-issue). The
                  // sender/receiver ids below need no switch - the record is
                  // always addressed back to whoever sent this one.
                  {
                    "key": "stockEntryType",
                    "value":
                        "{{fn:getShortfallEntryType(navigation.incomingStockEntryType)}}"
                  },
                  {
                    "key": "senderFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {
                    "key": "receiverFacilityId",
                    "value": "{{navigation.senderFacilityId}}"
                  },
                  {
                    "key": "senderPartyType",
                    "value": "{{fn:getUserPartyType()}}"
                  },
                  {
                    "key": "receiverPartyType",
                    "value":
                        "{{fn:getPartyTypeForFacilityId(navigation.senderFacilityId)}}"
                  },
                  {
                    "key": "productVariantId",
                    "value": "{{navigation.productVariantId}}"
                  },
                  {
                    "key": "userFacilityId",
                    "value": "{{fn:getUserFacilityId()}}"
                  },
                  {"key": "sku", "value": "{{navigation.sku}}"},
                  {
                    "key": "wayBillNumber",
                    "value": "{{navigation.wayBillNumber}}"
                  },
                  {"key": "batchNumber", "value": "{{navigation.batchNumber}}"},
                  {
                    "key": "transportType",
                    "value": "{{navigation.transportType}}"
                  },
                  {
                    "key": "vehicleNumber",
                    "value": "{{navigation.vehicleNumber}}"
                  },
                  {
                    "key": "quantity",
                    "value":
                        "{{fn:subtractQuantity(navigation.quantity, formData.actualQuantityReceived)}}"
                  },
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  },
                  {
                    "key": "originalIssueClientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "discrepancyReason",
                    "value": "{{formData.discrepancyReason}}"
                  },
                  {
                    "key": "comment",
                    "value": "{{fn:safeString(formData.rejectComment)}}"
                  }
                ],
                "onError": [
                  {
                    "actionType": "SHOW_TOAST",
                    "properties": {
                      "message": "INVENTORY_FETCH_CONFIG_FAILED_MESSAGE"
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
                      "message": "INVENTORY_CREATE_STOCK_FAILED_MESSAGE"
                    }
                  }
                ]
              }
            },
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "stockSuccess",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "manageStock",
                "data": [
                  {"key": "mrnNumber", "value": "{{fn:getCommentValue(navigation.mrnNumber, navigation.selectedTransactionMrn)}}"},
                  {
                    "key": "clientReferenceId",
                    "value": "{{navigation.clientReferenceId}}"
                  },
                  {
                    "key": "transactionDetailsHeading",
                    "value":
                        "{{fn:getAcceptedTransactionHeadingCode(navigation.incomingStockEntryType, navigation.discrepancyReason)}}"
                  }
                ]
              }
            }
          ]
        },
        {
          "condition": {"expression": "DEFAULT"},
          "actions": [
            {
              "actionType": "SHOW_TOAST",
              "properties": {
                "message": "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID",
                "type": "error"
              }
            }
          ]
        }
      ],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "stock",
            "awaitResults": true,
            "data": [
              {
                "key": "clientReferenceId",
                "value": "{{navigation.clientReferenceId}}",
                "operation": "equals"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "StockReceiptDetailsWrapper",
        "groupByType": false,
        "rootEntity": "StockModel",
        "filters": [],
        "relations": [
          {"name": "stock", "entity": "StockModel"}
        ],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"]
        }
      },
      "pages": [
        {
          "page": "stockReceiptDetails",
          "label": "INVENTORY_STOCK_RECEIPT_DETAILS_HEADING",
          "order": 1,
          "type": "object",
          "description": "",
          "actionLabel": "INVENTORY_ACCEPT_STOCK_LABEL",
          "secondaryActionLabel": "INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL",
          "showAlertPopUp": {
            "title": "INVENTORY_ACCEPT_CONFIRMATION_TITLE",
            "description": "INVENTORY_ACCEPT_CONFIRMATION_DESCRIPTION",
            "primaryActionLabel": "INVENTORY_ACCEPT_CONFIRM_ACTION",
            "secondaryActionLabel": "INVENTORY_ACCEPT_CANCEL_ACTION"
          },
          "showSecondaryAlertPopUp": {
            "title": "INVENTORY_REJECT_CONFIRMATION_TITLE",
            "description": "{{fn:getPartialAcceptDescription(navigation.incomingStockEntryType, navigation.discrepancyReason)}}",
            "primaryActionLabel": "INVENTORY_REJECT_CONFIRM_ACTION",
            "secondaryActionLabel": "INVENTORY_REJECT_CANCEL_ACTION",
            "body": [
              {
                "type": "integer",
                "label": "{{fn:getPartialAcceptQuantityLabel(navigation.incomingStockEntryType, navigation.discrepancyReason)}}",
                "format": "numeric",
                "fieldName": "actualQuantityReceived",
                "mandatory": true,
                "validations": [
                  {
                    "type": "required",
                    "value": true,
                    "message": "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID"
                  },
                  {
                    "type": "min",
                    "value": 0,
                    "message": "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID"
                  }
                ]
              },
              {
                "type": "string",
                "label": "INVENTORY_DISCREPANCY_REASON_LABEL",
                "format": "dropdown",
                "fieldName": "discrepancyReason",
                "mandatory": true,
                "enums": [
                  {
                    "code": "IN_TRANSIT",
                    "name": "INVENTORY_DISCREPANCY_REASON_IN_TRANSIT"
                  },
                  {
                    "code": "STOCK_LOSS",
                    "name": "INVENTORY_DISCREPANCY_REASON_STOCK_LOSS"
                  },
                  {
                    "code": "STOCK_DAMAGE",
                    "name": "INVENTORY_DISCREPANCY_REASON_STOCK_DAMAGE"
                  }
                ]
              },
              {
                "type": "string",
                "label": "INVENTORY_REJECT_COMMENT_LABEL",
                "format": "textArea",
                "fieldName": "rejectComment",
                "mandatory": true
              }
            ]
          },
          "properties": [
            {
              "type": "string",
              "label": "INVENTORY_RESOURCE_LABEL",
              "order": 1,
              "value": "{{sku}}",
              "format": "text",
              "fieldName": "resource",
              "displayOnly": true
            },
            {
              "type": "string",
              "label": "INVENTORY_MATERIAL_ISSUE_NUMBER_LABEL",
              "order": 2,
              "value": "{{mrnNumber}}",
              "format": "text",
              "fieldName": "materialIssueNumber",
              "displayOnly": true
            },
            {
              "type": "string",
              "label": "INVENTORY_RECEIVED_FROM_LABEL",
              "order": 3,
              "value": "{{fn:teamPartyDisplay(navigation.receivedFromName, senderFacilityId)}}",
              "format": "text",
              "fieldName": "receivedFrom",
              "displayOnly": true
            },
            {
              "type": "string",
              "label": "INVENTORY_WAYBILL_NUMBER_LABEL",
              "order": 4,
              "value": "{{navigation.wayBillNumber}}",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_WAYBILL_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": true,
              "fieldName": "wayBillNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {},
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_BATCH_NUMBER_LABEL",
              "order": 5,
              "value": "{{navigation.batchNumber}}",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_BATCH_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": true,
              "fieldName": "batchNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {},
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_DISCREPANCY_REASON_LABEL",
              "order": 6,
              "value":
                  "{{fn:getDiscrepancyReasonDisplayCode(navigation.discrepancyReason)}}",
              "format": "text",
              "fieldName": "discrepancyReasonDisplay",
              "displayOnly": true,
              "hideIfNull": true,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.discrepancyReason != null && navigation.discrepancyReason != '' && navigation.discrepancyReason != 'null'",
                    "type": "custom"
                  }
                ]
              }
            },
            {
              "type": "integer",
              "label": "INVENTORY_QUANTITY_SENT_BY_WAREHOUSE_LABEL",
              "order": 7,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_QUANTITY_SENT_BY_WAREHOUSE_HELPTEXT",
              "infoText": "",
              "readOnly": true,
              "fieldName": "quantity",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {},
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_QUANTITY_REQUIRED_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": "^[0-9]+\$",
                  "message": "INVENTORY_VALID_NUMBER_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_COMMENTS_LABEL",
              "order": 8,
              "value": "{{navigation.originalComment}}",
              "format": "textArea",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_COMMENTS_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "comment",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {},
              "validations": [
                {
                  "type": "required",
                  "value": false,
                  "message": "INVENTORY_COMMENTS_LABEL_required"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            }
          ]
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "category": "INVENTORY",
      "name": "viewTransaction",
      "heading": "INVENTORY_VIEW_TRANSACTION_HEADING",
      "description": "INVENTORY_VIEW_TRANSACTION_DESCRIPTION",
      "header": [
        {
          "format": "backLink",
          "label": "CORE_COMMON_BACK",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "footer": [],
      "initActions": [
        {
          "actionType": "SEARCH_EVENT",
          "properties": {
            "type": "SEARCH_EVENT",
            "name": "stock",
            "data": [
              {
                // Include transactions where the user's UUID is recorded as
                // a party (distributor) or as their facility (warehouse
                // manager), plus adjustments they personally recorded.
                "key": "senderId,receiverId,clientCreatedBy",
                "value": "{{fn:getUserFacilityId()}}",
                "operation": "equalsAny"
              },
              {
                "key": "additionalFields",
                "value": "\"value\":\"REJECTED\"",
                "operation": "notContains"
              }
            ]
          }
        }
      ],
      "wrapperConfig": {
        "wrapperName": "ViewStockWrapper",
        "groupByType": true,
        "rootEntity": "StockModel",
        "groupBy": "additionalFields.fields.mrnNumber",
        "filters": [],
        "relations": [
          {"name": "stock", "entity": "StockModel"}
        ],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"],
          "orderBy": {"field": "clientCreatedTime", "order": "DESC"}
        }
      },
      "body": [
        {
          "format": "infoCard",
          "type": "template",
          "fieldName": "viewTransactionEmptyStateInfoCard",
          "hidden": null,
          "visible": "{{fn:hasResults('StockModel')}} == false",
          "label": "INVENTORY_NO_TRANSACTIONS_LABEL",
          "description": "INVENTORY_NO_TRANSACTIONS_DESCRIPTION"
        },
        {
          "format": "listView",
          "type": "template",
          "hidden": null,
          "visible": "{{ context.stock.isNotEmpty }}",
          "fieldName": "listView",
          "dataSource": "StockModel",
          "child": {
            "format": "card",
            "type": "template",
            "fieldName": "viewTransactionListCard",
            "children": [
              {
                "format": "row",
                "type": "template",
                "fieldName": "viewTransactionHeaderRow",
                "properties": {
                  "mainAxisAlignment": "spaceBetween",
                  "mainAxisSize": "max"
                },
                "children": [
                  {
                    "format": "tag",
                    "type": "template",
                    "fieldName": "viewTransactionMrnTag",
                    "label": "MRN {{item.groupKey}}"
                  },
                  {
                    "format": "textTemplate",
                    "type": "template",
                    "fieldName": "viewTransactionDateText",
                    "value":
                        "{{fn:formatDate(item.items[0].dateOfEntry, 'date', dd MMM yyyy)}}"
                  }
                ]
              },
              {
                "format": "row",
                "type": "template",
                "fieldName": "viewTransactionPartyRow",
                "properties": {
                  "mainAxisAlignment": "spaceBetween",
                  "mainAxisSize": "max"
                },
                "children": [
                  {
                    "format": "expanded",
                    "type": "template",
                    "fieldName": "viewTransactionPartyExpanded",
                    "child": {
                      "format": "column",
                      "type": "template",
                      "fieldName": "viewTransactionPartyColumn",
                      "properties": {
                        "mainAxisAlignment": "spaceBetween",
                        "mainAxisSize": "min"
                      },
                      "children": [
                        {
                          "format": "textTemplate",
                          "type": "template",
                          "fieldName": "viewTransactionPartyLabelText",
                          "value":
                              "{{fn:getFirstPagePartyLabel(item.items[0].additionalFields.fields)}}"
                        },
                        {
                          "format": "textTemplate",
                          "type": "template",
                          "fieldName": "viewTransactionPartyValueText",
                          "value":
                              "{{fn:getFirstPageParty(item.items[0].additionalFields.fields, item.items[0].senderId, item.items[0].receiverId, item.items[0].senderType, item.items[0].receiverType)}}"
                        }
                      ]
                    }
                  },
                  {
                    "format": "actionPopup",
                    "type": "template",
                    "fieldName": "viewTransactionQrPopup",
                    "label": "INVENTORY_VIEW_QR_LABEL",
                    "properties": {
                      "type": "tertiary",
                      "size": "medium",
                      "mainAxisSize": "min",
                      "mainAxisAlignment": "start",
                      "popupConfig": {
                        "type": "default",
                        "title": "INVENTORY_QR_CODE_TITLE",
                        "titleIcon": "qr",
                        "showCloseButton": true,
                        "barrierDismissible": true,
                        "body": [
                          {
                            "format": "qr_view",
                            "type": "template",
                            "fieldName": "viewTransactionQrView",
                            "data":
                                "{{item.items[0].additionalFields.fields.mrnNumber}}",
                            "size": "medium",
                            "errorCorrectionLevel": "M",
                            "dataModuleColor": "black",
                            "backgroundColor": "white",
                            "padding": 16
                          }
                        ],
                        "footerActions": []
                      }
                    },
                    "suffixIcon": "qr"
                  }
                ]
              },
              {
                "format": "listView",
                "type": "template",
                "fieldName": "viewTransactionGroupedItemsList",
                "dataSource": "item.items",
                "child": {
                  "format": "labelPairList",
                  "type": "template",
                  "fieldName": "viewTransactionGroupedItemText",
                  "data": [
                    {
                      "key": "{{fn:getViewTransactionQuantityLabel(item)}}",
                      "value":
                          "{{item.additionalFields.fields.sku}}: {{fn:getViewTransactionQuantity(item)}}"
                    }
                  ]
                }
              },
              {
                "format": "button",
                "type": "template",
                "fieldName": "viewTransactionSelectButton",
                "label": "INVENTORY_SELECT_TRANSACTION_LABEL",
                "properties": {
                  "type": "primary",
                  "size": "medium",
                  "mainAxisSize": "max",
                  "mainAxisAlignment": "center"
                },
                "onAction": [
                  {
                    "actionType": "NAVIGATION",
                    "properties": {
                      "type": "TEMPLATE",
                      "name": "viewTransactionDetails",
                      "navigationMode": "popUntilAndPush",
                      "popUntilPageName": "manageStock",
                      "data": [
                        {"key": "item", "value": "{{item}}"},
                        {"key": "item2", "value": "{{item.items[0]}}"},
                        {"key": "selectedStock", "value": "{{item.groupKey}}"},
                        {
                          "key": "clientReferenceId",
                          "value": "{{item.items[0].clientReferenceId}}"
                        },
                        {
                          "key": "transactionDetailsHeading",
                          "value":
                              "{{fn:getViewTransactionHeadingCode(item.items[0].additionalFields.fields.stockEntryType, item.items[0].transactionReason, item.items[0].additionalFields.fields.discrepancyReason, item.items[0].additionalFields.fields.originalIssueClientReferenceId)}}"
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          },
          "properties": {"spacing": "spacer4"}
        }
      ]
    }
  ]
};
