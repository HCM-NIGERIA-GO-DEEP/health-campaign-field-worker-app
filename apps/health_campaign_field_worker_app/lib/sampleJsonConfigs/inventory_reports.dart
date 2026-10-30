final dynamic inventoryReportFlows = {
  "name": "STOCKREPORTS",
  "initialPage": "viewReports",
  "order": 5,
  "project": "LLIN-mz",
  "version": 1,
  "disabled": false,
  "isSelected": true,
  "flows": [
    {
      "screenType": "TEMPLATE",
      "name": "viewReports",
      "heading": "STOCKREPORTS_VIEW_REPORTS_HEADING",
      "description": "STOCKREPORTS_VIEW_REPORTS_DESCRIPTION",
      "header": [
        {
          "type": "template",
          "format": "backLink",
          "label": "STOCKREPORTS_VIEW_REPORTS_BACK_BUTTON_LABEL",
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
            "name": "projectFacility",
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
          "select": ["projectFacility", "facility", "productVariant"]
        }
      },
      "body": [
        {
          "type": "template",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_RECIEVE_HEADING",
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_RECIEVE_DESCRIPTION",
          "fieldName": "stockRecieved",
          "properties": {"icon": "Assessment"},
          "icon": "Assessment",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "reportDetails",
                "data": [
                  {"key": "reportType", "value": "receipt"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_STOCK_RECEIPT_DETAILS_HEADING"
                  },
                  {
                    "key": "facilities",
                    "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"
                  },
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ]
              }
            }
          ]
        },
        {
          "type": "template",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_ISSUED_HEADING",
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_ISSUED_DESCRIPTION",
          "icon": "Assessment",
          "fieldName": "stockIssued",
          "properties": {"icon": "Assessment"},
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "reportDetails",
                "data": [
                  {"key": "reportType", "value": "dispatch"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_STOCK_ISSUE_DETAILS_HEADING"
                  },
                  {
                    "key": "facilities",
                    "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"
                  },
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ]
              }
            }
          ]
        },
        {
          "type": "template",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_RETURNED_HEADING",
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_RETURNED_DESCRIPTION",
          "icon": "Assessment",
          "fieldName": "stockReturned",
          "properties": {"icon": "Assessment"},
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "reportDetails",
                "data": [
                  {"key": "reportType", "value": "returned"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_STOCK_RETURN_DETAILS_HEADING"
                  },
                  {
                    "key": "facilities",
                    "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"
                  },
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ]
              }
            }
          ]
        },
        {
          "icon": "Assessment",
          "type": "template",
          "label": "STOCKREPORTS_VIEW_REPORTS_STOCK_DAMAGED_HEADING",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_DAMAGED_HEADING",
          // Damage here represents a discrepancy reported by a lower
          // hierarchy. A distributor has no lower hierarchy to report to.
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {"key": "reportType", "value": "damage"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_STOCK_DAMAGED_DETAILS_HEADING"
                  },
                  {"key": "facilities", "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"},
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ],
                "name": "reportDetails",
                "type": "TEMPLATE"
              }
            }
          ],
          "fieldName": "stockDamaged",
          "properties": {"icon": "Assessment"},
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_DAMAGED_DESCRIPTION"
        },
        {
          "icon": "Assessment",
          "type": "template",
          "label": "STOCKREPORTS_VIEW_REPORTS_STOCK_LOSS_HEADING",
          "format": "menu_card",
          "hidden": false,
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_LOSS_HEADING",
          // For distributors, this lists their own stock-loss records. For
          // upper hierarchy users, it lists lower-level loss discrepancies.
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {"key": "reportType", "value": "loss"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_STOCK_LOSS_DETAILS_HEADING"
                  },
                  {"key": "facilities", "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"},
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ],
                "name": "reportDetails",
                "type": "TEMPLATE"
              }
            }
          ],
          "fieldName": "stockLoss",
          "properties": {"icon": "Assessment"},
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_LOSS_DESCRIPTION"
        },
        {
          "icon": "Assessment",
          "type": "template",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_EXCESS_HEADING",
          // Excess is a count adjustment created by the distributor.
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "data": [
                  {"key": "reportType", "value": "excess"},
                  {
                    "key": "reportDetailsHeading",
                    "value": "INVENTORY_REPORT_DETAILS_EXCESS_REPORT_TITLE"
                  },
                  {"key": "facilities", "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"},
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ],
                "name": "reportDetails",
                "type": "TEMPLATE"
              }
            }
          ],
          "fieldName": "stockExcess",
          "properties": {"icon": "Assessment"},
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_EXCESS_DESCRIPTION"
        },
        {
          "type": "template",
          "format": "menu_card",
          "heading": "STOCKREPORTS_VIEW_REPORTS_STOCK_RECON_HEADING",
          "description": "STOCKREPORTS_VIEW_REPORTS_STOCK_RECON_DESCRIPTION",
          "icon": "Assessment",
          "fieldName": "stockReconciliation",
          "properties": {"icon": "Assessment"},
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "onAction": [
            {
              "actionType": "NAVIGATION",
              "properties": {
                "type": "TEMPLATE",
                "name": "reckonReportDetails",
                "data": [
                  {"key": "reportType", "value": "reconciliation"},
                  {
                    "key": "facilities",
                    "value": "{{fn:getCurrentFacilities(ProjectFacilityModel)}}"
                  },
                  {"key": "productVariants", "value": "{{ProductVariantModel}}"}
                ]
              }
            }
          ]
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "name": "reportDetails",
      "heading": "{{navigation.reportDetailsHeading}}",
      "description": "STOCKREPORTS_REPORT_DETAILS_DESCRIPTION",
      "initActions": [],
      "wrapperConfig": {
        "wrapperName": "StockReportWrapper",
        "groupByType": true,
        "rootEntity": "Stock",
        "filters": [],
        "relations": [],
        "searchConfig": {
          "primary": "stock",
          "select": ["stock"],
          "orderBy": {"field": "clientCreatedTime", "order": "DESC"}
        }
      },
      "header": [
        {
          "type": "template",
          "format": "backLink",
          "label": "STOCKREPORTS_REPORT_DETAILS_BACK_BUTTON_LABEL",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "footer": [
        {
          "type": "template",
          "format": "button",
          "fieldName": "reportDetailsBackToHomeButton",
          "label": "STOCKREPORTS_REPORT_DETAILS_SECONDARY_ACTION_LABEL",
          "properties": {
            "type": "secondary",
            "size": "large",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"type": "HOME", "name": "HOME"}
            }
          ]
        }
      ],
      "body": [
        {
          "type": "template",
          "format": "card",
          "fieldName": "reportDetailsFilterCard",
          "children": [
            {
              "type": "template",
              "format": "dropdownTemplate",
              "fieldName": "reportDetailsFacilityDropdown",
              "label": "STOCKREPORTS_REPORT_DETAILS_SELECT_WAREHOUSE_LABEL",
              "required": false,
              "key": "selectedFacility",
              "source": "{{navigation.facilities}}",
              "displayPrefix": "FAC_",
              "displayKey": "facilityId",
              "showWhenSingleOption": true,
              "valueKey": "facilityId",
              // Distributors filter by their user UUID and do not have a
              // facility selector. Warehouse managers choose a facility.
              "visible":
                  "{{fn:hasRole('WAREHOUSE_MANAGER')}} == true && {{fn:hasRole('DISTRIBUTOR')}} == false",
              "onChange": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "type": "SEARCH_EVENT",
                    "name": "stock",
                    "skipAccumulatedFilters": true,
                    "data": [
                      {
                        "key": "tenantId",
                        "value": "{{singleton.selectedProject.tenantId}}",
                        "operation": "equals"
                      },
                      {
                        "key": "productVariantId",
                        "value": "{{selectedProduct}}",
                        "operation": "equals"
                      },
                      {
                        "key": "additionalFields",
                        "value":
                            "{{fn:getReportStockEntryFilter(navigation.reportType)}}",
                        "operation": "containsAny"
                      },
                      {
                        "key": "{{fn:getReportTransactionReasonFilterKey(navigation.reportType)}}",
                        "value":
                            "{{fn:getReportTransactionReasonFilter(navigation.reportType)}}",
                        "operation": "containsAny"
                      },
                      {
                        "key": "additionalFields",
                        "value": "\"key\":\"status\",\"value\":\"ACCEPTED\"",
                        "operation": "contains",
                        "applyIf":
                            "{{fn:isResolvedDamageReport(navigation.reportType)}}"
                      },
                      {
                        "key":
                            "{{fn:getSenderOrReceiver(navigation.reportType)}}",
                        "value":
                            "{{fn:getReportFacilityId(navigation.reportType, selectedFacility)}}",
                        "operation": "equalsAny"
                      }
                    ]
                  }
                }
              ]
            },
            {
              "type": "template",
              "format": "dropdownTemplate",
              "fieldName": "reportDetailsProductDropdown",
              "label": "STOCKREPORTS_REPORT_DETAILS_SELECT_PRODUCT_LABEL",
              "required": false,
              "key": "selectedProduct",
              "source": "{{navigation.productVariants}}",
              "displayKey": "sku",
              "valueKey": "id",
              "showWhenSingleOption": true,
              "onChange": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "type": "SEARCH_EVENT",
                    "name": "stock",
                    "skipAccumulatedFilters": true,
                    "data": [
                      {
                        "key": "tenantId",
                        "value": "{{singleton.selectedProject.tenantId}}",
                        "operation": "equals"
                      },
                      {
                        "key": "productVariantId",
                        "value": "{{selectedProduct}}",
                        "operation": "equals"
                      },
                      {
                        "key": "additionalFields",
                        "value":
                            "{{fn:getReportStockEntryFilter(navigation.reportType)}}",
                        "operation": "containsAny"
                      },
                      {
                        "key": "{{fn:getReportTransactionReasonFilterKey(navigation.reportType)}}",
                        "value":
                            "{{fn:getReportTransactionReasonFilter(navigation.reportType)}}",
                        "operation": "containsAny"
                      },
                      {
                        "key": "additionalFields",
                        "value": "\"key\":\"status\",\"value\":\"ACCEPTED\"",
                        "operation": "contains",
                        "applyIf":
                            "{{fn:isResolvedDamageReport(navigation.reportType)}}"
                      },
                      {
                        "key":
                            "{{fn:getSenderOrReceiver(navigation.reportType)}}",
                        "value":
                            "{{fn:getReportFacilityId(navigation.reportType, selectedFacility)}}",
                        "operation": "equalsAny"
                      }
                    ]
                  }
                }
              ]
            }
          ]
        },
        {
          "type": "template",
          "format": "infoCard",
          "label": "STOCK_REPORT_DETAILS_INFO_CARD_LABEL",
          "description": "STOCK_REPORT_DETAILS_INFO_CARD_DESCRIPTION",
          "properties": {"type": "info"},
          "fieldName": "infoCardReportDetails",
          "visible":
              "{{fn:isEmpty(selectedFacility)}} && {{fn:isEmpty(selectedProduct)}}"
        },
        {
          "type": "template",
          "format": "infoCard",
          "label": "STOCK_REPORT_DETAILS_NO_RECORD_FOUND_INFO",
          "description": "STOCK_REPORT_DETAILS_NO_RECORD_FOUND_DESCRIPTION",
          "properties": {"type": "info"},
          "fieldName": "noRecordFoundInfoReportDetails",
          "visible":
              "{{fn:isEmpty(stock)}} && {{fn:isNotEmpty(selectedProduct)}}"
        },
        {
          "type": "template",
          "format": "table",
          "fieldName": "tableInfoReportDetails",
          "fitToContent": true,
          "data": {
            "source": "StockModel",
            "columns": [
              {
                "header": "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_1_LABEL",
                "cellValue":
                    "{{fn:formatDate(item.dateOfEntry, 'date', 'dd MMM yyyy')}}"
              },
              {
                "header":
                    "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_PRODUCT_LABEL",
                "cellValue": "{{item.additionalFields.fields.sku}}"
              },
              {
                "header": "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_2_LABEL",
                "cellValue": "{{item.additionalFields.fields.mrnNumber}}"
              },
              {
                "header": "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_3_LABEL",
                "cellValue":
                    "{{fn:getWayBillNumber(item.wayBillNumber, item.additionalFields.fields.wayBillNumber)}}"
              },
              {
                "header": "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_4_LABEL",
                "cellValue":
                    "{{fn:getReportStockQuantity(navigation.reportType, item)}}"
              }
            ],
            "rows": "{{contextData.0.StockModel}}"
          }
        }
      ]
    },
    {
      "screenType": "TEMPLATE",
      "name": "reckonReportDetails",
      "heading": "STOCKRECON_REPORT_DETAILS_HEADING",
      "description": "STOCKRECON_REPORT_DETAILS_DESCRIPTION",
      "initActions": [],
      "wrapperConfig": {
        "wrapperName": "StockReconciliationReportWrapper",
        "groupByType": true,
        "rootEntity": "StockReconciliation",
        "filters": [],
        "relations": [],
        "searchConfig": {
          "primary": "stockReconciliation",
          "select": ["stockReconciliation"],
          "orderBy": {"field": "clientCreatedTime", "order": "DESC"}
        }
      },
      "header": [
        {
          "type": "template",
          "format": "backLink",
          "label": "STOCKRECON_REPORT_DETAILS_BACK_BUTTON_LABEL",
          "onAction": [
            {"actionType": "BACK_NAVIGATION", "properties": {}}
          ]
        }
      ],
      "footer": [
        {
          "type": "template",
          "format": "button",
          "fieldName": "reckonReportDetailsBackToHomeButton",
          "label": "STOCKRECON_REPORT_DETAILS_SECONDARY_ACTION_LABEL",
          "properties": {
            "type": "secondary",
            "size": "large",
            "mainAxisSize": "max",
            "mainAxisAlignment": "center"
          },
          "onAction": [
            {
              "actionType": "BACK_NAVIGATION",
              "properties": {"type": "HOME", "name": "HOME"}
            }
          ]
        }
      ],
      "body": [
        {
          "type": "template",
          "format": "card",
          "fieldName": "reckonReportDetailsFilterCard",
          "children": [
            {
              "type": "template",
              "format": "dropdownTemplate",
              "fieldName": "reckonReportDetailsFacilityDropdown",
              "label": "STOCKRECON_REPORT_DETAILS_SELECT_WAREHOUSE_LABEL",
              "required": false,
              "key": "selectedReconFacility",
              "source": "{{navigation.facilities}}",
              "displayKey": "facilityId",
              "displayPrefix": "FAC_",
              "showWhenSingleOption": true,
              "valueKey": "facilityId",
              // Distributors' reconciliation rows use their user UUID as
              // facilityId and therefore have no facility dropdown option.
              "visible":
                  "{{fn:hasRole('WAREHOUSE_MANAGER')}} == true && {{fn:hasRole('DISTRIBUTOR')}} == false",
              "onChange": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "type": "SEARCH_EVENT",
                    "name": "stockReconciliation",
                    "data": [
                      {
                        "key": "tenantId",
                        "value": "{{singleton.selectedProject.tenantId}}",
                        "operation": "equals"
                      },
                      {
                        "key": "productVariantId",
                        "value": "{{selectedReckonProduct}}",
                        "operation": "equals"
                      },
                      {
                        "key": "facilityId",
                        "value": "{{fn:getReportFacilityId('reconciliation', selectedReconFacility)}}",
                        "operation": "equals"
                      }
                    ]
                  }
                }
              ]
            },
            {
              "type": "template",
              "format": "dropdownTemplate",
              "fieldName": "reckonReportDetailsProductDropdown",
              "label": "STOCKRECONREPORTS_REPORT_DETAILS_SELECT_PRODUCT_LABEL",
              "required": true,
              "key": "selectedReckonProduct",
              "source": "{{navigation.productVariants}}",
              "displayKey": "sku",
              "valueKey": "id",
              "onChange": [
                {
                  "actionType": "SEARCH_EVENT",
                  "properties": {
                    "type": "SEARCH_EVENT",
                    "name": "stockReconciliation",
                    "data": [
                      {
                        "key": "tenantId",
                        "value": "{{singleton.selectedProject.tenantId}}",
                        "operation": "equals"
                      },
                      {
                        "key": "productVariantId",
                        "value": "{{selectedReckonProduct}}",
                        "operation": "equals"
                      },
                      {
                        "key": "facilityId",
                        "value": "{{fn:getReportFacilityId('reconciliation', selectedReconFacility)}}",
                        "operation": "equals"
                      }
                    ]
                  }
                }
              ]
            }
          ]
        },
        {
          "type": "template",
          "format": "infoCard",
          "fieldName": "infoCardReckonReportDetails",
          "label": "STOCKRECON_REPORT_DETAILS_INFO_CARD_LABEL",
          "description": "STOCKRECON_REPORT_DETAILS_INFO_CARD_DESCRIPTION",
          "properties": {"type": "info"},
          "visible":
              "{{fn:isEmpty(selectedReconFacility)}} && {{fn:isEmpty(selectedReckonProduct)}}"
        },
        {
          "type": "template",
          "format": "infoCard",
          "fieldName": "noRecordFoundInfoReckonReportDetails",
          "label": "STOCKRECON_REPORT_DETAILS_NO_RECORD_FOUND_INFO",
          "description":
              "STOCKRECON_REPORT_DETAILS_NO_RECORD_FOUND_DESCRIPTION",
          "properties": {"type": "info"},
          "visible":
              "{{fn:isEmpty(stockReconciliation)}} && {{fn:isNotEmpty(selectedReckonProduct)}}"
        },
        {
          "type": "template",
          "format": "table",
          "fieldName": "tableInfoReckonReportDetails",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == false",
          "fitToContent": true,
          "data": {
            "source": "StockReconciliationModel",
            "columns": [
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_1_LABEL",
                "cellValue":
                    "{{fn:formatDate(item.dateOfReconciliation, 'date', 'dd MMM yyyy')}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_2_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockReceived}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_3_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockIssued}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_4_LABEL",
                "cellValue":
                    "{{fn:absoluteValue(item.additionalFields.fields.stockReturned)}}"
              },
              {
                "header": "STOCK_RECONCILIATION_WAREHOUSE_STOCK_LOST",
                "cellValue": "{{fn:getWarehouseWriteOffQuantity(item.additionalFields.fields.stockLost, item.additionalFields.fields.lowerFacilityLostShortfall)}}"
              },
              {
                "header": "STOCK_RECONCILIATION_WAREHOUSE_STOCK_DAMAGED",
                "cellValue":
                    "{{fn:getWarehouseWriteOffQuantity(item.additionalFields.fields.stockDamaged, item.additionalFields.fields.lowerFacilityDamagedShortfall)}}"
              },
              {
                "header": "STOCK_RECONCILIATION_REPORTED_SHORTFALL_LOST",
                "cellValue":
                    "{{fn:coalesceQuantity(item.additionalFields.fields.reportedLostShortfall, item.additionalFields.fields.lowerFacilityLostShortfall, 0)}}"
              },
              {
                "header": "STOCK_RECONCILIATION_REPORTED_SHORTFALL_DAMAGED",
                "cellValue":
                    "{{fn:coalesceQuantity(item.additionalFields.fields.reportedDamagedShortfall, item.additionalFields.fields.lowerFacilityDamagedShortfall, 0)}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_7_LABEL",
                "cellValue": "{{item.physicalCount}}"
              },
              {
                // Captured when the manual count does not match the
                // calculated one. Stored on the model's own
                // commentsOnReconciliation column, NOT in additionalFields,
                // so it is read directly off the item.
                "header":
                    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_COMMENTS_LABEL",
                "cellValue":
                    "{{fn:safeString(item.commentsOnReconciliation)}}"
              }
            ],
            "rows": "{{contextData.0.StockReconciliationModel}}"
          }
        },
        {
          "type": "template",
          "format": "table",
          "fieldName": "distributorTableInfoReckonReportDetails",
          "visible": "{{fn:hasRole('DISTRIBUTOR')}} == true",
          "fitToContent": true,
          "data": {
            "source": "StockReconciliationModel",
            "columns": [
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_1_LABEL",
                "cellValue":
                    "{{fn:formatDate(item.dateOfReconciliation, 'date', 'dd MMM yyyy')}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_2_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockReceived}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_3_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockIssued}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_4_LABEL",
                "cellValue":
                    "{{fn:absoluteValue(item.additionalFields.fields.stockReturned)}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_5_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockLost}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_6_LABEL",
                "cellValue": "{{item.additionalFields.fields.stockExcess}}"
              },
              {
                "header": "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_7_LABEL",
                "cellValue": "{{item.physicalCount}}"
              },
              {
                // Captured when the manual count does not match the
                // calculated one. Stored on the model's own
                // commentsOnReconciliation column, NOT in additionalFields,
                // so it is read directly off the item.
                "header":
                    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_COMMENTS_LABEL",
                "cellValue":
                    "{{fn:safeString(item.commentsOnReconciliation)}}"
              }
            ],
            "rows": "{{contextData.0.StockReconciliationModel}}"
          }
        }
      ]
    }
  ]
};
