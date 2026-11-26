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
              "condition": {
                "expression":
                    "{{fn:hasRole('WAREHOUSE_MANAGER')}} == true || {{fn:hasRole('DISTRIBUTOR')}} == true"
              },
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "type": "FORM",
                    "name": "RECORDSTOCK",
                    "data": [
                      // Stock keeping unit for the logged-in role. Resolved in the
                      // flow layer because the forms engine has its OWN function
                      // registry, which has no hasRole - an fn: call inside the
                      // form's labelConditions reaches FormulaParser as literal
                      // text and silently never matches. Read as
                      // navigation.stockUnit.
                      {
                        "key": "stockUnit",
                        "value": "{{fn:stockUnitForRole()}}"
                      },
                      {"key": "stockEntryType", "value": "RECEIPT"},
                      {"key": "transactionType", "value": "RECEIVED"},
                      {"key": "primaryRole", "value": "RECEIVER"},
                      {"key": "secondaryRole", "value": "SENDER"},
                      {
                        "key": "mrnNumber",
                        "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                      }
                    ]
                  }
                }
              ]
            },
            {
              "condition": {
                "expression":
                    "{{fn:hasRole('WAREHOUSE_MANAGER')}} == false && {{fn:hasRole('DISTRIBUTOR')}} == false"
              },
              "actions": [
                {
                  "actionType": "NAVIGATION",
                  "properties": {
                    "type": "TEMPLATE",
                    "name": "incomingTransactions",
                    "data": []
                  }
                }
              ]
            }
          ]
        },
        {
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordStockIssuedCard",
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
          "fieldName": "manageStockRecordStockDamagedCard",
          "heading":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_DAMAGED_HEADING",
          "description":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_DAMAGED_DESCRIPTION",
          "icon": "ReportProblem",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "FORM",
                "name": "RECORDSTOCK",
                "data": [
                  // Stock keeping unit for the logged-in role. Resolved in the
                  // flow layer because the forms engine has its OWN function
                  // registry, which has no hasRole - an fn: call inside the
                  // form's labelConditions reaches FormulaParser as literal
                  // text and silently never matches. Read as
                  // navigation.stockUnit.
                  {"key": "stockUnit", "value": "{{fn:stockUnitForRole()}}"},
                  {"key": "stockEntryType", "value": "DAMAGED"},
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
          "format": "menu_card",
          "type": "template",
          "fieldName": "manageStockRecordStockLossCard",
          "heading":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_LOSS_HEADING",
          "description":
              "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_LOSS_DESCRIPTION",
          "icon": "Warning",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "FORM",
                "name": "RECORDSTOCK",
                "data": [
                  // Stock keeping unit for the logged-in role. Resolved in the
                  // flow layer because the forms engine has its OWN function
                  // registry, which has no hasRole - an fn: call inside the
                  // form's labelConditions reaches FormulaParser as literal
                  // text and silently never matches. Read as
                  // navigation.stockUnit.
                  {"key": "stockUnit", "value": "{{fn:stockUnitForRole()}}"},
                  {"key": "stockEntryType", "value": "LOSS"},
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
                      // Stock keeping unit for the logged-in role. Resolved in the
                      // flow layer because the forms engine has its OWN function
                      // registry, which has no hasRole - an fn: call inside the
                      // form's labelConditions reaches FormulaParser as literal
                      // text and silently never matches. Read as
                      // navigation.stockUnit.
                      {
                        "key": "stockUnit",
                        "value": "{{fn:stockUnitForRole()}}"
                      },
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
                      // Stock keeping unit for the logged-in role. Resolved in the
                      // flow layer because the forms engine has its OWN function
                      // registry, which has no hasRole - an fn: call inside the
                      // form's labelConditions reaches FormulaParser as literal
                      // text and silently never matches. Read as
                      // navigation.stockUnit.
                      {
                        "key": "stockUnit",
                        "value": "{{fn:stockUnitForRole()}}"
                      },
                      {"key": "stockEntryType", "value": "RETURNED"},
                      {"key": "transactionType", "value": "DISPATCHED"},
                      {"key": "primaryRole", "value": "RECEIVER"},
                      {"key": "secondaryRole", "value": "SENDER"},
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
              "enums": "{{fn:getIssueReturnOptions()}}",
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
                    // Stock keeping unit for the logged-in role. Resolved in the
                    // flow layer because the forms engine has its OWN function
                    // registry, which has no hasRole - an fn: call inside the
                    // form's labelConditions reaches FormulaParser as literal
                    // text and silently never matches. Read as
                    // navigation.stockUnit.
                    {"key": "stockUnit", "value": "{{fn:stockUnitForRole()}}"},
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
                  // Stock keeping unit for the logged-in role. Resolved in the
                  // flow layer because the forms engine has its OWN function
                  // registry, which has no hasRole - an fn: call inside the
                  // form's labelConditions reaches FormulaParser as literal
                  // text and silently never matches. Read as
                  // navigation.stockUnit.
                  {"key": "stockUnit", "value": "{{fn:stockUnitForRole()}}"},
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
                      // The ITN supply chain is
                      //   IDA Foundation -> Country -> District
                      //   -> Distribution Point (DP/PPS) -> DELIVERY_TEAM
                      // It deliberately SKIPS two geographic levels that the
                      // boundary hierarchy still carries: County, and Health
                      // Facility (the HHR registration role maps there and
                      // has no stock flow at all). Only this mapping drops
                      // them - the boundaryTypes derivation in project.dart
                      // reads the boundary tree and is unaffected.
                      //
                      // Country's forReceipt names a facility USAGE, not a
                      // boundary type, and is the ONLY entry that does. The
                      // national warehouse sits on the root boundary, so it
                      // has no parent level the ProjectFacility FacilityMap
                      // could ever key a source under; its source is instead
                      // identified by the usage on the facility record. It
                      // was "Central Facility", which is the national
                      // warehouse's own usage - i.e. it pointed the user at
                      // themselves and no source was ever offered. Every
                      // other level names a boundary type here, which matches
                      // no facility usage, so they resolve nothing and keep
                      // using FacilityMap/ProjectFacilities unchanged.
                      "Country": {
                        "forReceipt": ["IDA Foundation"],
                        "forIssue": ["District"]
                      },
                      "District": {
                        "forReceipt": ["Country"],
                        "forIssue": ["Distribution Point"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["District"],
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
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "includeInSummary": true,
              "includeInForm": true,
              "validations": [
                {
                  "type": "allowManualEntry",
                  "value": false
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
              "readOnly": true,
              "fieldName": "productdetail",
              "deleteFlag": false,
              "innerLabel": "",
              "schemaCode": null,
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
                      // The ITN supply chain is
                      //   IDA Foundation -> Country -> District
                      //   -> Distribution Point (DP/PPS) -> DELIVERY_TEAM
                      // It deliberately SKIPS two geographic levels that the
                      // boundary hierarchy still carries: County, and Health
                      // Facility (the HHR registration role maps there and
                      // has no stock flow at all). Only this mapping drops
                      // them - the boundaryTypes derivation in project.dart
                      // reads the boundary tree and is unaffected.
                      //
                      // Country's forReceipt names a facility USAGE, not a
                      // boundary type, and is the ONLY entry that does. The
                      // national warehouse sits on the root boundary, so it
                      // has no parent level the ProjectFacility FacilityMap
                      // could ever key a source under; its source is instead
                      // identified by the usage on the facility record. It
                      // was "Central Facility", which is the national
                      // warehouse's own usage - i.e. it pointed the user at
                      // themselves and no source was ever offered. Every
                      // other level names a boundary type here, which matches
                      // no facility usage, so they resolve nothing and keep
                      // using FacilityMap/ProjectFacilities unchanged.
                      "Country": {
                        "forReceipt": ["IDA Foundation"],
                        "forIssue": ["District"]
                      },
                      "District": {
                        "forReceipt": ["Country"],
                        "forIssue": ["Distribution Point"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["District"],
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
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich_mandatory_message"
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
              "enums": []
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_TRANSPORT_LABEL",
              "order": 5,
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
                {"code": "CANOE", "name": "INVENTORY_TRANSPORT_TYPE_CANOE"},
                {"code": "KEKEH", "name": "INVENTORY_TRANSPORT_TYPE_KEKEH"},
                {
                  "code": "MOTORBIKE",
                  "name": "INVENTORY_TRANSPORT_TYPE_MOTORBIKE"
                }
              ],
              "mandatory": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_TRANSPORT_TYPE_REQUIRED_MESSAGE"
                }
              ]
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_VEHICLE_NUMBER_LABEL",
              "order": 6,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_VEHICLE_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "vehicleNumber",
              "mandatory": true,
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_VEHICLE_NUMBER_REQUIRED_MESSAGE"
                },
                {
                  "type": "pattern",
                  "value": r"^[a-zA-Z0-9 ]+$",
                  "message": "INVENTORY_VEHICLE_NUMBER_HELPTEXT"
                }
              ]
            },
            {
              "type": "string",
              "label": "INVENTORY_WAYBILL_NUMBER_LABEL",
              "order": 7,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_WAYBILL_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "wayBillNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "mandatory": true,
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_WAYBILL_NUMBER_REQUIRED_MESSAGE"
                },
                {
                  "type": "pattern",
                  "value": r"^[a-zA-Z0-9 ]+$",
                  "message": "INVENTORY_WAYBILL_NUMBER_HELPTEXT"
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
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL",
              // Warehouse managers count ITNs in bales; distributors count
              // loose pieces. Same field, same page, so the label code is
              // chosen by role rather than the field being duplicated.
              // Stock going to or coming from a delivery team moves as loose
              // nets, so a warehouse manager types it in pieces too (the
              // second BALES entry). Typed bales are saved as pieces through
              // the Pieces row below.
              "labelConditions": [
                {
                  "condition":
                      "navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                  "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL_BALES"
                },
                {
                  "condition": "navigation.stockUnit == 'BALES'",
                  "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL_PIECES"
                },
                {
                  "condition": "navigation.stockUnit == 'PIECES'",
                  "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL_PIECES"
                }
              ],
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
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
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
              // Pieces equivalent of quantitySent, saved as the stock quantity -
              // same rule as quantityReceivedPieces below.
              "type": "string",
              "label": "APPONE_INVENTORY_QUANTITY_SENT_LABEL_PIECES",
              "order": 4.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantitySentPieces",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'ISSUED' && navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantitySent",
                "multiplyBy": 50,
                "decimals": 0
              },
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL",
              // Warehouse managers count ITNs in bales; distributors count
              // loose pieces. Same field, same page, so the label code is
              // chosen by role rather than the field being duplicated.
              // Stock going to or coming from a delivery team moves as loose
              // nets, so a warehouse manager types it in pieces too (the
              // second BALES entry). Typed bales are saved as pieces through
              // the Pieces row below.
              "labelConditions": [
                {
                  "condition":
                      "navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                  "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL_BALES"
                },
                {
                  "condition": "navigation.stockUnit == 'BALES'",
                  "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL_PIECES"
                },
                {
                  "condition": "navigation.stockUnit == 'PIECES'",
                  "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL_PIECES"
                }
              ],
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
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
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
              // Pieces equivalent of quantityLost, saved as the stock quantity -
              // same rule as quantityReceivedPieces below.
              "type": "string",
              "label": "APPONE_INVENTORY_QUANTITY_LOST_LABEL_PIECES",
              "order": 4.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityLostPieces",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'LOSS' && navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantityLost",
                "multiplyBy": 50,
                "decimals": 0
              },
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_LOSS_DECLARATION_LABEL",
              "order": 5,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "lossDeclaration",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'LOSS'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_INVENTORY_LOSS_DECLARATION_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "DECLARED_LOSS", "name": "DECLARED_LOSS"},
                {"code": "UNDECLARED_LOSS", "name": "UNDECLARED_LOSS"}
              ]
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_NATURE_OF_LOSS_LABEL",
              "order": 6,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "natureOfLoss",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'LOSS'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_INVENTORY_NATURE_OF_LOSS_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "LOSS_IN_STORE", "name": "LOSS_IN_STORE"},
                {"code": "LOSS_BY_FIELD_TEAMS", "name": "LOSS_BY_FIELD_TEAMS"},
                {"code": "LOSS_BY_THEFT", "name": "LOSS_BY_THEFT"}
              ]
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL",
              // Warehouse managers count ITNs in bales; distributors count
              // loose pieces. Same field, same page, so the label code is
              // chosen by role rather than the field being duplicated.
              // Stock going to or coming from a delivery team moves as loose
              // nets, so a warehouse manager types it in pieces too (the
              // second BALES entry). Typed bales are saved as pieces through
              // the Pieces row below.
              "labelConditions": [
                {
                  "condition":
                      "navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                  "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_BALES"
                },
                {
                  "condition": "navigation.stockUnit == 'BALES'",
                  "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_PIECES"
                },
                {
                  "condition": "navigation.stockUnit == 'PIECES'",
                  "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_PIECES"
                }
              ],
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
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
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
              // Pieces equivalent of quantityDamaged, saved as the stock quantity -
              // same rule as quantityReceivedPieces below.
              "type": "string",
              "label": "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_PIECES",
              "order": 4.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityDamagedPieces",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'DAMAGED' && navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantityDamaged",
                "multiplyBy": 50,
                "decimals": 0
              },
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "APPONE_INVENTORY_DAMAGE_REASON_LABEL",
              "order": 5,
              "value": "",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "transactionReason",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'DAMAGED'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message":
                      "APPONE_INVENTORY_DAMAGE_REASON_REQUIRED_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "DAMAGED_IN_TRANSIT", "name": "DAMAGED_IN_TRANSIT"},
                {"code": "DAMAGED_IN_STORAGE", "name": "DAMAGED_IN_STORAGE"}
              ]
            },
            {
              // On a return the user picks the unit for each product, whatever
              // their role: Pieces (the default) shows quantityReturned in
              // pieces; Bales shows it in bales plus the read-only Pieces row
              // below. The "stock" transformer saves pieces either way, and
              // records the choice as additionalFields "stockUnit".
              // _$tabIndex is this product's own copy of the field.
              "type": "string",
              "label": "APPONE_INVENTORY_RETURN_UNIT_LABEL",
              "order": 3.9,
              "value": "PIECES",
              "format": "dropdown",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "returnUnit",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.stockEntryType == 'RETURNED'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "APPONE_INVENTORY_RETURN_UNIT_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": [
                {"code": "BALES", "name": "APPONE_INVENTORY_UNIT_BALES"},
                {"code": "PIECES", "name": "APPONE_INVENTORY_UNIT_PIECES"}
              ]
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL",
              // Labelled with the unit picked in returnUnit above.
              "labelConditions": [
                {
                  "condition":
                      r"stockProductDetails.returnUnit_$tabIndex == 'BALES'",
                  "label": "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_BALES"
                },
                {
                  "condition":
                      r"stockProductDetails.returnUnit_$tabIndex == 'PIECES'",
                  "label": "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_PIECES"
                }
              ],
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
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              // Pieces equivalent of quantityReturned, saved as the stock
              // quantity when returned in bales - shown only when Bales is
              // picked in returnUnit. Read-only for the same reason as
              // quantityReceivedPieces below.
              "type": "string",
              "label": "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_PIECES",
              "order": 4.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityReturnedPieces",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        r"navigation.stockEntryType == 'RETURNED' && stockProductDetails.returnUnit_$tabIndex == 'BALES'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantityReturned",
                "multiplyBy": 50,
                "decimals": 0
              },
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL",
              // Warehouse managers count ITNs in bales; distributors count
              // loose pieces. Same field, same page, so the label code is
              // chosen by role rather than the field being duplicated.
              // Stock going to or coming from a delivery team moves as loose
              // nets, so a warehouse manager types it in pieces too (the
              // second BALES entry). Typed bales are saved as pieces through
              // the Pieces row below.
              "labelConditions": [
                {
                  "condition":
                      "navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                  "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_BALES"
                },
                {
                  "condition": "navigation.stockUnit == 'BALES'",
                  "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES"
                },
                {
                  "condition": "navigation.stockUnit == 'PIECES'",
                  "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES"
                }
              ],
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
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_RECEIVED_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              // A warehouse manager types the received quantity in bales;
              // this row shows it in pieces (50 per bale), worked out
              // automatically and greyed out, and the stock transformer saves
              // it as the quantity, so stock is stored in pieces. Only when
              // the quantity is typed in bales: a distributor, and anyone
              // receiving from or sending to a delivery team, types pieces
              // into quantityReceived itself, which is saved as typed. The
              // same rule as fn:stockEntryUnit, which tells the transformer
              // which one to save.
              //
              // readOnly stays false on purpose: computedValue already makes
              // the field read-only, and this multi-product page gives each
              // product its own copy of a field (quantityReceivedPieces_item_0)
              // only when readOnly is false. With true, every product tab
              // would share one value.
              "type": "string",
              "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES",
              "order": 4.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityReceivedPieces",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition":
                        "navigation.stockEntryType == 'RECEIPT' && navigation.stockUnit == 'BALES' && warehouseDetails.facilityToWhich != 'DELIVERY_TEAM' && stockDetails.facilityFromWhich != 'DELIVERY_TEAM'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantityReceived",
                "multiplyBy": 50,
                "decimals": 0
              },
              "validations": [],
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
                },
                {
                  "type": "minLength",
                  "value": "3",
                  "message": "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE"
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
                    "{{fn:getStockTeamCode(navigation.stockEntryType, navigation.primaryRole, formData.warehouseDetails.teamCode, formData.warehouseDetails.facilityToWhich, formData.stockDetails.facilityFromWhich, formData.stockDetails.deliveryTeam)}}"
              },
              {
                "key": "senderId",
                "value":
                    "{{fn:getStockSenderId(navigation.stockEntryType, navigation.primaryRole, formData.stockDetails.facilityFromWhich, formData.warehouseDetails.teamCode, formData.stockDetails.deliveryTeam, singleton.loggedInUserUuid)}}"
              },
              {
                "key": "receiverId",
                "value":
                    "{{fn:getStockReceiverId(navigation.stockEntryType, navigation.primaryRole, formData.warehouseDetails.facilityToWhich, formData.warehouseDetails.teamCode, formData.stockDetails.deliveryTeam)}}"
              },
              // The delivery team member's user name, saved on the stock
              // as additionalFields "deliveryTeamName" so the transaction
              // screens can show a name for a STAFF party, not the uuid.
              // Same arguments as teamCode above: the name is read from
              // the team code that gives the id.
              {
                "key": "deliveryTeamName",
                "value":
                    "{{fn:getStockTeamName(navigation.stockEntryType, navigation.primaryRole, formData.warehouseDetails.teamCode, formData.warehouseDetails.facilityToWhich, formData.stockDetails.facilityFromWhich, formData.stockDetails.deliveryTeam)}}"
              },
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "transactionReason",
                "value":
                    "{{fn:getTransactionReason(navigation.stockEntryType)}}"
              },
              {
                "key": "transportType",
                "value": "{{formData.stockDetails.transportType}}"
              },
              {
                "key": "vehicleNumber",
                "value": "{{formData.stockDetails.vehicleNumber}}"
              },
              // The unit the product details quantities were typed in: BALES
              // or PIECES (see fn:stockEntryUnit). Saved on the stock as
              // additionalFields "stockUnit", and it picks what the "stock"
              // transformer saves as quantity - the Pieces row when typed in
              // bales - so stock is always stored in pieces.
              {
                "key": "stockUnit",
                "value":
                    "{{fn:stockEntryUnit(navigation.stockUnit, formData.warehouseDetails.facilityToWhich, formData.stockDetails.facilityFromWhich)}}"
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
              "helpText": "INVENTORY_DATE_OF_RECEIPT_HELPTEXT",
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
              "helpText": "INVENTORY_ADMINISTRATIVE_AREA_HELPTEXT",
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
                      // The ITN supply chain is
                      //   IDA Foundation -> Country -> District
                      //   -> Distribution Point (DP/PPS) -> DELIVERY_TEAM
                      // It deliberately SKIPS two geographic levels that the
                      // boundary hierarchy still carries: County, and Health
                      // Facility (the HHR registration role maps there and
                      // has no stock flow at all). Only this mapping drops
                      // them - the boundaryTypes derivation in project.dart
                      // reads the boundary tree and is unaffected.
                      //
                      // Country's forReceipt names a facility USAGE, not a
                      // boundary type, and is the ONLY entry that does. The
                      // national warehouse sits on the root boundary, so it
                      // has no parent level the ProjectFacility FacilityMap
                      // could ever key a source under; its source is instead
                      // identified by the usage on the facility record. It
                      // was "Central Facility", which is the national
                      // warehouse's own usage - i.e. it pointed the user at
                      // themselves and no source was ever offered. Every
                      // other level names a boundary type here, which matches
                      // no facility usage, so they resolve nothing and keep
                      // using FacilityMap/ProjectFacilities unchanged.
                      "Country": {
                        "forReceipt": ["IDA Foundation"],
                        "forIssue": ["District"]
                      },
                      "District": {
                        "forReceipt": ["Country"],
                        "forIssue": ["Distribution Point"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["District"],
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
              "validations": [
                {
                  "type": "allowManualEntry",
                  "value": false
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
                {"code": "LESS", "name": "Less"},
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
              "schemaCode": null,
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
                      // The ITN supply chain is
                      //   IDA Foundation -> Country -> District
                      //   -> Distribution Point (DP/PPS) -> DELIVERY_TEAM
                      // It deliberately SKIPS two geographic levels that the
                      // boundary hierarchy still carries: County, and Health
                      // Facility (the HHR registration role maps there and
                      // has no stock flow at all). Only this mapping drops
                      // them - the boundaryTypes derivation in project.dart
                      // reads the boundary tree and is unaffected.
                      //
                      // Country's forReceipt names a facility USAGE, not a
                      // boundary type, and is the ONLY entry that does. The
                      // national warehouse sits on the root boundary, so it
                      // has no parent level the ProjectFacility FacilityMap
                      // could ever key a source under; its source is instead
                      // identified by the usage on the facility record. It
                      // was "Central Facility", which is the national
                      // warehouse's own usage - i.e. it pointed the user at
                      // themselves and no source was ever offered. Every
                      // other level names a boundary type here, which matches
                      // no facility usage, so they resolve nothing and keep
                      // using FacilityMap/ProjectFacilities unchanged.
                      "Country": {
                        "forReceipt": ["IDA Foundation"],
                        "forIssue": ["District"]
                      },
                      "District": {
                        "forReceipt": ["Country"],
                        "forIssue": ["Distribution Point"]
                      },
                      "Distribution Point": {
                        "forReceipt": ["District"],
                        "forIssue": ["DELIVERY_TEAM"]
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
              "helpText": "INVENTORY_QUANTITY_HELPTEXT",
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
                  "type": "regex",
                  "value": r"^[0-9]+$",
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
                },
                {
                  "type": "minLength",
                  "value": "3",
                  "message": "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE"
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
                "key": "transactionReason",
                "value":
                    "{{fn:getTransactionReason(formData.lessExcessDetails.recordType)}}"
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
                "key": "clientCreatedBy,clientModifiedBy",
                "value": "{{singleton.loggedInUserUuid}}",
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
                  "format": "textTemplate",
                  "type": "template",
                  "fieldName": "viewTransactionGroupedItemText",
                  "value":
                      "{{item.additionalFields.fields.sku}}: {{item.quantity}}"
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
                        {"key": "selectedStock", "value": "{{item.groupKey}}"},
                        {
                          "key": "clientReferenceId",
                          "value": "{{item.items[0].clientReferenceId}}"
                        },
                        {
                          "key": "transactionDetailsHeading",
                          "value":
                              "{{fn:getViewTransactionHeadingCode(item.items[0].additionalFields.fields)}}"
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
            {
              "actionType": "NAVIGATION",
              "properties": {"type": "TEMPLATE", "name": "manageStock"}
            }
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
                "key": "additionalFields",
                "value": "{{navigation.selectedStock}}",
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
                    "value": "{{item.transactionReason}}"
                  },
                  {
                    "key":
                        "{{fn:getSecondPagePartyLabel(item.additionalFields.fields)}}",
                    "previewLabel": "INVENTORY_TRANSACTING_PARTY_LABEL",
                    "value":
                        "{{fn:getSecondPageParty(item.additionalFields.fields, item.senderId, item.receiverId, item.senderType, item.receiverType)}}"
                  },
                  {
                    "key": "INVENTORY_MRN_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.mrnNumber}}"
                  },
                  {
                    "key": "INVENTORY_WAYBILL_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.wayBillNumber}}"
                  },
                  {
                    "key": "INVENTORY_TRANSPORT_TYPE_LABEL",
                    "value": "{{item.additionalFields.fields.transportType}}"
                  },
                  {
                    "key": "INVENTORY_VEHICLE_NUMBER_LABEL",
                    "value": "{{item.additionalFields.fields.vehicleNumber}}"
                  },
                  {
                    "key":
                        "{{fn:getStockQuantityLabel(item.additionalFields.fields)}}",
                    "previewLabel": "INVENTORY_QUANTITY_LABEL",
                    "value": "{{item.quantity}}"
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
      "footer": [
        {
          "format": "button",
          "type": "template",
          "fieldName": "recordReceiptManuallyButton",
          "label": "INVENTORY_RECORD_RECEIPT_MANUALLY",
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
                "type": "FORM",
                "name": "RECORDSTOCK",
                "navigationMode": "popUntilAndPush",
                "popUntilPageName": "RECORDSTOCK",
                "data": [
                  // Stock keeping unit for the logged-in role. Resolved in the
                  // flow layer because the forms engine has its OWN function
                  // registry, which has no hasRole - an fn: call inside the
                  // form's labelConditions reaches FormulaParser as literal
                  // text and silently never matches. Read as
                  // navigation.stockUnit.
                  {"key": "stockUnit", "value": "{{fn:stockUnitForRole()}}"},
                  {"key": "stockEntryType", "value": "RECEIPT"},
                  {"key": "transactionType", "value": "RECEIVED"},
                  {"key": "primaryRole", "value": "RECEIVER"},
                  {"key": "secondaryRole", "value": "SENDER"},
                  {
                    "key": "mrnNumber",
                    "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
                  }
                ]
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
                        "value": "APP_CONFIG_INVENTORY_SENDER_LABEL"
                      },
                      {
                        "format": "textTemplate",
                        "type": "template",
                        "fieldName": "incomingTransactionsSenderValueText",
                        "value":
                            "{{fn:getFacilityName(item.items[0].senderId, item.items[0].additionalFields.fields, item.items[0].senderType)}}"
                      }
                    ]
                  },
                  {
                    "format": "textTemplate",
                    "type": "template",
                    "fieldName": "incomingTransactionsTransactionTypeText",
                    "value": "{{item.items[0].transactionType}}"
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
                        // How the logged-in user takes this stock in: PIECES
                        // for a registrar or distributor, who type the
                        // pieces received; BALES for everyone else, who
                        // accept it as sent. Read as navigation.receiptUnit.
                        {
                          "key": "receiptUnit",
                          "value": "{{fn:stockReceiptUnit()}}"
                        },
                        {
                          "key": "stockEntryType",
                          "value":
                              "{{fn:getStockEntryTypeFromFields(item.items[0].additionalFields.fields)}}"
                        },
                        {"key": "transactionType", "value": "RECEIVED"},
                        {"key": "primaryRole", "value": "RECEIVER"},
                        {"key": "secondaryRole", "value": "SENDER"},
                        {
                          "key": "mrnNumber",
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
                          "key": "quantity",
                          "value": "{{item.items[0].quantity}}"
                        },
                        {
                          "key": "wayBillNumber",
                          "value":
                              "{{item.items[0].additionalFields.fields.wayBillNumber}}"
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
                          "key": "comment",
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
                "key": "stockEntryType",
                "value": "{{navigation.stockEntryType}}"
              },
              {
                "key": "transactionType",
                "value": "{{navigation.transactionType}}"
              },
              {"key": "primaryRole", "value": "RECEIVER"},
              {"key": "secondaryRole", "value": "SENDER"},
              {
                "key": "mrnNumber",
                "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
              },
              {
                "key": "senderFacilityId",
                "value": "{{navigation.senderFacilityId}}"
              },
              {
                "key": "productVariantId",
                "value": "{{navigation.productVariantId}}"
              },
              {"key": "userFacilityId", "value": "{{fn:getUserFacilityId()}}"},
              {"key": "sku", "value": "{{navigation.sku}}"},
              {
                "key": "quantity",
                "value": "{{fn:bottlesToMl(navigation.quantity)}}"
              },
              {
                // PIECES saves the pieces typed on the page (quantityReceived)
                // instead of the dispatched quantity.
                "key": "receiptUnit",
                "value": "{{navigation.receiptUnit}}"
              },
              {
                "key": "transactionReason",
                "value":
                    "{{fn:getTransactionReason(navigation.stockEntryType)}}"
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
                "key": "StockModel.additionalFields.numberedScans",
                "value": "{{formData.stockReceiptDetails.scannedStock}}"
              },
              {
                "key": "StockModel.additionalFields.fields.status",
                "value": "ACCEPTED"
              },
              {
                "key": "StockModel.additionalFields.fields.mrnNumber",
                "value": "{{fn:generateUniqueMaterialNoteNumber()}}"
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
          "actionType": "SHOW_TOAST",
          "properties": {
            "message": "INVENTORY_STOCK_ACCEPTED_SUCCESS",
            "type": "success"
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "manageStock",
            "navigationMode": "popUntilAndReplace",
            "popUntilPageName": "manageStock"
          }
        }
      ],
      "onSecondaryAction": [
        {
          "actionType": "FETCH_TRANSFORMER_CONFIG",
          "properties": {
            "configName": "stockReject",
            "forceCreate": true,
            "data": [
              {"key": "transactionType", "value": "DISPATCHED"},
              {"key": "primaryRole", "value": "SENDER"},
              {"key": "secondaryRole", "value": "RECEIVER"},
              {"key": "mrnNumber", "value": "{{navigation.mrnNumber}}"},
              {
                "key": "senderFacilityId",
                "value": "{{fn:getUserFacilityId()}}"
              },
              {
                "key": "receiverFacilityId",
                "value": "{{navigation.senderFacilityId}}"
              },
              {
                "key": "productVariantId",
                "value": "{{navigation.productVariantId}}"
              },
              {"key": "userFacilityId", "value": "{{fn:getUserFacilityId()}}"},
              {"key": "sku", "value": "{{navigation.sku}}"},
              {
                "key": "quantity",
                "value": "{{fn:bottlesToMl(navigation.quantity)}}"
              },
              {"key": "transactionReason", "value": "REJECTED"}
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
                "key": "StockModel.additionalFields.fields.status",
                "value": "REJECTED"
              }
            ]
          }
        },
        {
          "actionType": "SHOW_TOAST",
          "properties": {
            "message": "INVENTORY_STOCK_REJECTED_SUCCESS",
            "type": "success"
          }
        },
        {
          "actionType": "NAVIGATION",
          "properties": {
            "type": "TEMPLATE",
            "name": "manageStock",
            "navigationMode": "popUntilAndReplace",
            "popUntilPageName": "manageStock"
          }
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
          "secondaryActionLabel": "INVENTORY_DECLINE_STOCK_LABEL",
          "showAlertPopUp": {
            "title": "INVENTORY_ACCEPT_CONFIRMATION_TITLE",
            "description": "INVENTORY_ACCEPT_CONFIRMATION_DESCRIPTION",
            "primaryActionLabel": "INVENTORY_ACCEPT_CONFIRM_ACTION",
            "secondaryActionLabel": "INVENTORY_ACCEPT_CANCEL_ACTION"
          },
          "showSecondaryAlertPopUp": {
            "title": "INVENTORY_REJECT_CONFIRMATION_TITLE",
            "description": "INVENTORY_REJECT_CONFIRMATION_DESCRIPTION",
            "primaryActionLabel": "INVENTORY_REJECT_CONFIRM_ACTION",
            "secondaryActionLabel": "INVENTORY_REJECT_CANCEL_ACTION",
            "body": [
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
              "value": "{{senderFacilityId}}",
              "format": "text",
              "fieldName": "receivedFrom",
              "displayOnly": true
            },
            {
              "type": "string",
              "label": "INVENTORY_WAYBILL_NUMBER_LABEL",
              "order": 4,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_WAYBILL_NUMBER_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "wayBillNumber",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {},
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_WAYBILL_NUMBER_REQUIRED_MESSAGE"
                },
                {
                  "type": "minLength",
                  "value": "3",
                  "message": "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE"
                },
                {
                  "type": "pattern",
                  "value": r"^[a-zA-Z0-9 ]+$",
                  "message": "INVENTORY_WAYBILL_NUMBER_HELPTEXT"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null,
              "mandatory": true
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
              // A registrar or distributor gets quantityReceived below, which
              // they can edit, in place of this and the bales row.
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.receiptUnit != 'PIECES'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "INVENTORY_QUANTITY_REQUIRED_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
                  "message": "INVENTORY_VALID_NUMBER_REQUIRED_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              // A registrar or distributor always receives stock in pieces:
              // this starts at the pieces sent and they correct it to what
              // arrived. The "stockReceipt" transformer saves it as the
              // quantity when navigation.receiptUnit is PIECES.
              "type": "integer",
              "label": "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES",
              "order": 7.05,
              "value": "{{navigation.quantity}}",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "",
              "infoText": "",
              "readOnly": false,
              "fieldName": "quantityReceived",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.receiptUnit == 'PIECES'",
                    "type": "custom"
                  }
                ]
              },
              "validations": [
                {
                  "type": "required",
                  "value": true,
                  "message": "QUANTITY_RECEIVED_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "min",
                  "value": 1,
                  "message": "QUANTITY_RECEIVED_MIN_REQUIRED_ERROR_MESSAGE"
                },
                {
                  "type": "max",
                  "value": 10000000,
                  "message": "QUANTITY_MAX_ERROR_MESSAGE"
                },
                {
                  "type": "regex",
                  "value": r"^[0-9]+$",
                  "message": "QUANTITY_VALID_NUMBER_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_QUANTITY_IN_BALES_LABEL",
              "order": 7.1,
              "value": "",
              "format": "text",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_QUANTITY_IN_BALES_HELPTEXT",
              "infoText": "",
              "readOnly": true,
              "fieldName": "bales",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "visibilityCondition": {
                "expression": [
                  {
                    "condition": "navigation.receiptUnit != 'PIECES'",
                    "type": "custom"
                  }
                ]
              },
              "computedValue": {
                "sourceField": "quantity",
                "divideBy": 50,
                "decimals": 2
              },
              "validations": [],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            },
            {
              "type": "string",
              "label": "INVENTORY_SCAN_STOCK_LABEL",
              "order": 7.2,
              "value": "",
              "format": "scanner",
              "hidden": false,
              "tooltip": "",
              "helpText": "INVENTORY_SCAN_STOCK_HELPTEXT",
              "infoText": "",
              "readOnly": false,
              "fieldName": "scannedStock",
              "deleteFlag": false,
              "innerLabel": "",
              "systemDate": false,
              "validations": [
                {
                  "type": "isGS1",
                  "value": true,
                  "message": "INVENTORY_SCAN_STOCK_LABEL"
                },
                {
                  "type": "scanTypes",
                  "value": [
                    {
                      "type": "bale",
                      "ai": "00",
                      "saveKey": "baleScannedStock",
                      "label": "INVENTORY_SCAN_TYPE_BALE"
                    },
                    {
                      "type": "piece",
                      "ai": "21",
                      "saveKey": "piecesScannedStock",
                      "label": "INVENTORY_SCAN_TYPE_PIECE"
                    }
                  ],
                  "message": "INVENTORY_SCAN_UNKNOWN_STOCK_CODE"
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
              "value": "",
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
                },
                {
                  "type": "minLength",
                  "value": "3",
                  "message": "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE"
                }
              ],
              "errorMessage": "",
              "isMultiSelect": false,
              "enums": null
            }
          ]
        }
      ]
    }
  ]
};
