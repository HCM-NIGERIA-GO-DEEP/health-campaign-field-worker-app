import json
import requests

# Upserts Sierra Leone campaign localisations, grouped by the module that
# each screen fetches. Keep country-specific upsert entries in this file.
#
# Modelled on upsert_liberia_localisations.py: codes are grouped per module
# below, and the module a screen reads from is what decides whether a code
# resolves there - NOT which script happened to send it. See that file's
# header comment for the full module list used by the app (home.dart).
#
# Already upserted - kept for reference, commented out so a re-run sends only
# the active set below.
CAMPAIGN = "CMP-2026-10-12-001274"
TENANT_ID = "si"
LOCALE = "en_NG"
TO_ENV_HOST = "https://sierraleone-hcm-uat.digit.org/localization/messages/v1/_upsert"

UPSERT_REQUEST_BODY = {
    "RequestInfo": {
        "authToken": "3594134e-8ae8-43b4-83c5-10a41eb4c64a",
        "userInfo": {
            "id": 91,
            "uuid": "1c0f99dc-6a89-4f04-9b1e-a15f29c6a3ba",
            "userName": "si-uat-admin-1"
        }
    }
}

headers = {"Content-Type": "application/json"}

# Older localisations are retained below as comments for reference. Only
# entries added or changed recently are active in MESSAGES_BY_MODULE.
# # MESSAGES_BY_MODULE = {
# #     "digit-privacy-policy": {
# #         # Login page: the clickable link text AND the fullscreen privacy
# #         # notice popup both use this single heading/link code.
# #         "PRIVACY_NOTICE": "Privacy Notice",
# #     },
# #
# #     f"hcm-inventory-{CAMPAIGN}": {
# #         # Facility names rendered through the FAC_{facilityId} localization
# #         # key (see getFacilityName in function_registries.dart). Both the
# #         # prefixed and bare forms are sent, same as Liberia, since some call
# #         # sites prefix the id themselves and some don't.
# #         "FAC_F-2026-09-10-024187": "National Warehouse",
# #         "FAC_F-2026-09-10-024188": "State Warehouse",
# #         "FAC_F-2026-09-10-024186": "Chiefdom Warehouse",
# #         "FAC_F-2026-09-10-024185": "District Warehouse",
# #         "FAC_F-2026-09-10-024184": "PHU Warehouse",
# #         "FAC_F-2026-09-10-024183": "DP Warehouse",
# #         "F-2026-09-10-024187": "National Warehouse",
# #         "F-2026-09-10-024188": "State Warehouse",
# #         "F-2026-09-10-024186": "Chiefdom Warehouse",
# #         "F-2026-09-10-024185": "District Warehouse",
# #         "F-2026-09-10-024184": "PHU Warehouse",
# #         "F-2026-09-10-024183": "DP Warehouse",
# #     },
# #
# #     # Boundary dropdown FIELD labels (the heading above each dropdown, e.g.
# #     # "Chiefdom", "Community"). boundary_selection.dart builds this code as
# #     # '${runtimeHierarchyType()}_$label', where label is BoundaryModel.label,
# #     # set verbatim to the node's boundaryType from the boundary tree
# #     # (boundary.dart:113 `label: e.boundaryType`) - i.e. "Country", "Province",
# #     # "District", "Chiefdom", "PHU", "Distribution Point", "Community" for
# #     # this hierarchy (boundary_hirarchy.txt). runtimeHierarchyType() resolves
# #     # to "ADMIN_KAMBIA" (.env HIERARCHY_TYPE, confirmed by the project's
# #     # additionalDetails too). One entry per level covers every dropdown on
# #     # this screen, regardless of which node is selected under it.
# #     "hcm-boundary-admin_kambia": {
# #         "ADMIN_KAMBIA_Country": "Country",
# #         "ADMIN_KAMBIA_Province": "Province",
# #         "ADMIN_KAMBIA_District": "District",
# #         "ADMIN_KAMBIA_Chiefdom": "Chiefdom",
# #         "ADMIN_KAMBIA_PHU": "PHU",
# #         "ADMIN_KAMBIA_Distribution Point": "Distribution Point",
# #         "ADMIN_KAMBIA_Community": "Community",
# #     },
# #
# #     # Boundary dropdown ITEM labels - localizations.translate(e.code) on each
# #     # boundary node's own unique code, scoped to exactly the boundary nodes
# #     # the 9 UAT users (userCredential.pdf) are mapped to.
# #     "hcm-boundary-admin_kambia": {
# #         "ADMIN_KAMBIA_SI": "Sierra Leone",
# #         "ADMIN_KAMBIA_SI_01_NORTH_WEST": "North West",
# #         "ADMIN_KAMBIA_SI_01_01_KAMBIA": "Kambia",
# #         "ADMIN_KAMBIA_SI_01_01_09_TONKO_LIMBA_CHIEFDOM": "Tonko Limba Chiefdom",
# #         "ADMIN_KAMBIA_SI_01_01_09_17_YEBAYA_MCHP": "Yebaya Mchp",
# #         "ADMIN_KAMBIA_SI_01_01_09_17_03_YEBAYA_MCHP": "Yebaya Mchp",
# #         "ADMIN_KAMBIA_SI_01_01_09_17_03_03_YEBAYA": "Yebaya",
# #     },
# #
# #     f"hcm-inventory-{CAMPAIGN}": {
# #         # viewTransactionDetails's heading now resolves via
# #         # getViewTransactionHeadingCode() (function_registries.dart) based on
# #         # stockEntryType, carried through navigation as a plain code - so
# #         # Issue and Return get their own heading instead of always showing
# #         # "Stock Receipt Details".
# #         "INVENTORY_STOCK_RECEIPT_DETAILS_HEADING": "Stock Receipt Details",
# #         "INVENTORY_STOCK_ISSUE_DETAILS_HEADING": "Stock Issue Details",
# #         "INVENTORY_STOCK_RETURN_DETAILS_HEADING": "Stock Return Details",
# #
# #         # New row on the view-transaction screen (hideIfNull, so it only
# #         # shows up for partially-accepted receipts).
# #         "INVENTORY_ORIGINAL_QUANTITY_RECEIVED_LABEL": "Quantity Sent",
# #     },
# #
# #     f"hcm-closehousehold-{CAMPAIGN}": {
# #         # CLOSEHOUSEHOLD.json's headName (first name) already had
# #         # minLength:3; familyname (last name) only had minLength:1, which
# #         # let 1-2 character names through and fail sync server-side.
# #         "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_MIN_LENGTH_ERROR":
# #             "First name must be at least 3 characters",
# #         "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_lastName_MIN_LENGTH_ERROR":
# #             "Last name must be at least 3 characters",
# #     },
# # }
#
# # Active set: codes added or changed since the last run, keyed by the module
# # they belong in. Add a new module by adding a key - nothing else changes.
# MESSAGES_BY_MODULE = {
#     f"hcm-inventory-{CAMPAIGN}": {
#         # Commodity Management names this product "ITN", but the field app
#         # should read "Bednet" everywhere that code is shown - every value in
#         # labelPairList goes through _safeTranslateValue, so this one entry
#         # covers all of them without a code change.
#         "ITN": "Bednet",
#
#         # manageStock screen - heading/back/footer and the two entry cards.
#         # Was entirely untranslated (raw codes showing in the UI).
#         "APP_CONFIG_INVENTORY_manageStock_HEADING": "Manage Stock",
#         "APP_CONFIG_INVENTORY_manageStock_BACK_BUTTON_LABEL": "Back",
#         "APP_CONFIG_INVENTORY_manageStock_VIEW_TRANSACTIONS_FOOTER_BUTTON_LABEL": "View Transactions",
#         "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_RECEIPT_HEADING": "Record Stock Receipt",
#         "APP_CONFIG_INVENTORY_manageStock_CREATE_RECORDS_FOR_STOCK_RECEIVED_AT_THE_WAREHOUSE_DESCRIPTION":
#             "Create records for stock received at the warehouse",
#         "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_ISSUED_HEADING": "Record Stock Issued",
#         "APP_CONFIG_INVENTORY_manageStock_CREATE_RECORDS_FOR_STOCK_SENT_OUT_FROM_THE_WAREHOUSE_DESCRIPTION":
#             "Create records for stock sent out from the warehouse",
#         # New Distributor-only card (INVENTORY.json manageStockRecordStockReturnedCard) -
#         # Distributor can only ever Return stock from this entry point (the
#         # Issued option is hidden for them on returnOrIssueSelection), so the
#         # card now reads "Returned" instead of the warehouse-facing "Issued".
#         "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_RETURNED_HEADING": "Record Stock Returned",
#
#         # returnOrIssueSelection screen - heading, next button, dropdown
#         # label and its two option names.
#         "APP_CONFIG_INVENTORY_returnOrIssueSelection_HEADING": "Select Transaction Type",
#         "APP_CONFIG_INVENTORY_returnOrIssueSelection_NEXT_BUTTON_LABEL": "Next",
#         "APP_CONFIG_INVENTORY_returnOrIssueSelection_TRANSACTION_TYPE_LABEL": "Transaction Type",
#         "APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_ISSUED": "Issued",
#         "APP_CONFIG_INVENTORY_returnOrIssueSelection_OPTION_RETURNED": "Returned",
#
#         # RECORDLESSEXCESS screen's recordType helper text - "What are you
#         # recording?" was showing as the raw code.
#         "INVENTORY_WHAT_ARE_YOU_RECORDING_LABEL": "What are you recording?",
#         "INVENTORY_RECORD_TYPE_HELPTEXT": "Select whether you are recording a loss or an excess",
#
#         # viewTransactionDetails labelPairList keys - stock receipt/issue/
#         # return details screen was showing raw codes for every row.
#         "INVENTORY_RESOURCE_LABEL": "Resource",
#         "INVENTORY_TRANSACTION_TYPE_LABEL": "Transaction Type",
#         "INVENTORY_TRANSACTION_REASON_LABEL": "Transaction Reason",
#         "INVENTORY_MRN_NUMBER_LABEL": "MRN Number",
#         "INVENTORY_WAYBILL_NUMBER_LABEL": "Waybill Number",
#         "INVENTORY_BATCH_NUMBER_LABEL": "Batch Number",
#         "INVENTORY_COMMENTS_LABEL": "Comments",
#
#         # Partial Accept popup's new mandatory reason dropdown (Shortfall
#         # Return PRD FR-04) - stockReceiptDetails.showSecondaryAlertPopUp.
#         "INVENTORY_DISCREPANCY_REASON_LABEL": "Discrepancy Reason",
#         "INVENTORY_DISCREPANCY_REASON_IN_TRANSIT": "In Transit",
#         "INVENTORY_DISCREPANCY_REASON_STOCK_LOSS": "Stock Loss",
#         "INVENTORY_DISCREPANCY_REASON_STOCK_DAMAGE": "Stock Damage",
#         "INVENTORY_DISCREPANCY_REASON_OTHERS": "Others",
#         "INVENTORY_DISCREPANCY_REASON_OTHERS_DETAIL_LABEL": "Other Reason",
#         "INVENTORY_SHORTFALL_QUANTITY_LABEL": "Shortfall Quantity",
#         "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_UNACCOUNTED_LABEL": "Unaccounted Quantity",
#
#         # Partial receipt dialog and its result message.
#         "INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL": "Partially Accept",
#         "INVENTORY_REJECT_CONFIRMATION_TITLE": "Partially Accept Stock",
#         "INVENTORY_REJECT_CONFIRMATION_DESCRIPTION":
#             "Enter the quantity you actually received and the reason it differs from the quantity sent.",
#         "INVENTORY_REJECT_CONFIRM_ACTION": "Confirm",
#         "INVENTORY_REJECT_CANCEL_ACTION": "Cancel",
#         "INVENTORY_ACTUAL_QUANTITY_RECEIVED_LABEL": "Actual Quantity Received",
#         "INVENTORY_REJECT_COMMENT_LABEL": "Reason for Difference",
#         "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID":
#             "Actual received quantity must be greater than zero and no greater than the quantity sent.",
#         "INVENTORY_STOCK_REJECTED_SUCCESS": "Stock partially accepted",
#
#         # Transport, vehicle and waybill fields.
#         "APPONE_INVENTORY_TRANSPORT_LABEL": "Transport Type",
#         "INVENTORY_TRANSPORT_TYPE_HELPTEXT": "Select the transport type",
#         "INVENTORY_TRANSPORT_TYPE_LABEL": "Transport Type",
#         "INVENTORY_TRANSPORT_TYPE_TRUCK": "Truck",
#         "INVENTORY_TRANSPORT_TYPE_VAN": "Van",
#         "INVENTORY_TRANSPORT_TYPE_PICK_UP": "Pick-up",
#         "INVENTORY_TRANSPORT_TYPE_JEEP": "Jeep",
#         "APPONE_INVENTORY_VEHICLE_NUMBER_LABEL": "Vehicle Number",
#         "INVENTORY_VEHICLE_NUMBER_LABEL": "Vehicle Number",
#         "INVENTORY_VEHICLE_NUMBER_HELPTEXT":
#             "Enter a vehicle number using letters, numbers, or spaces",
#         "APPONE_INVENTORY_WAYBILL_LABEL": "Waybill Number",
#         "INVENTORY_WAYBILL_NUMBER_REQUIRED_ERROR_MESSAGE":
#             "Waybill number can contain letters and numbers only",
#         "INVENTORY_CREATE_NEW_TRANSACTION_LABEL": "Create new transaction",
#
#         # Loss and damage transaction fields.
#         "APPONE_INVENTORY_LOSS_DECLARATION_LABEL": "Loss Declaration",
#         "APPONE_INVENTORY_LOSS_DECLARATION_REQUIRED_ERROR_MESSAGE": "Loss declaration is required",
#         "DECLARED_LOSS": "Declared Loss",
#         "UNDECLARED_LOSS": "Undeclared Loss",
#         "APPONE_INVENTORY_NATURE_OF_LOSS_LABEL": "Nature of Loss",
#         "APPONE_INVENTORY_NATURE_OF_LOSS_REQUIRED_ERROR_MESSAGE": "Nature of loss is required",
#         "LOSS_IN_STORE": "Loss in Store",
#         "LOSS_BY_FIELD_TEAMS": "Loss by Field Teams",
#         "LOSS_BY_THEFT": "Loss by Theft",
#         "INVENTORY_RECEIVED_FROM_LABEL": "Received from",
#         "INVENTORY_SENDER_LABEL": "Received from",
#         "INVENTORY_RECEIVER_LABEL": "Sent to",
#         "APP_CONFIG_INVENTORY_SENDER_LABEL": "Received from",
#         "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich": "Received from",
#         "APPONE_INVENTORY_DAMAGE_REASON_LABEL": "Reason for damage",
#         "APPONE_INVENTORY_DAMAGE_REASON_REQUIRED_ERROR_MESSAGE": "Reason for damage is required",
#         "DAMAGED_IN_TRANSIT": "Damaged in Transit",
#         "DAMAGED_IN_STORAGE": "Damaged in Storage",
#         "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_DAMAGED_DESCRIPTION":
#             "Create records for stock that is damaged",
#         "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_LOSS_DESCRIPTION":
#             "Create records for stock that is lost",
#         "INVENTORY_RECORD_RECEIPT_MANUALLY": "Record Receipt Manually",
#         "INVENTORY_STOCK_DAMAGED_DETAILS_HEADING": "Stock Damaged Details",
#         "INVENTORY_STOCK_LOSS_DETAILS_HEADING": "Stock Loss Details",
#         "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE":
#             "This field must have at least 3 characters",
#     },
#
#     f"hcm-registration-{CAMPAIGN}": {
#         # Cross-field household-count validation messages are grouped here
#         # with the other registration localisations for this campaign.
#
#         # Last Name validation messages were wrongly reusing the First Name
#         # (nameOfIndividual) codes - minLength even reused the _max_message
#         # code by copy-paste. REGISTRATION.json now points at these
#         # lastName-specific codes instead.
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_mandatory_message":
#             "Last name is required",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_min_message":
#             "Last name must be at least 2 characters",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_lastName_max_message":
#             "Last name must be at most 200 characters",
#         "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_expectedBednetCodes": "Scan Voucher",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText":
#             "Enter the first name of the household head",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_mandatory_message":
#             "Identification number is required",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationType_helpText":
#             "Optional - select the type of ID the household has, if any",
#         "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_identificationNumber_helpText":
#             "Optional. National ID: 8 letters/numbers (e.g. KJ00AQ5R). "
#             "Voter's ID: 7 digits (e.g. 2009765). "
#             "Driver's License: 2 letters followed by 9 digits (e.g. AQ000011576).",
#         "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_maxField_message":
#             "Number of children cannot exceed total household members",
#         "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_pregnantWomenCount_maxField_message":
#             "Number of pregnant women cannot exceed total household members",
#
#         # childrenCount and pregnantWomenCount each already validate against
#         # memberCount individually, but their SUM could still exceed it (e.g.
#         # 3 children + 3 pregnant women in a 5-member household). New
#         # maxFieldSum validation on both fields catches that combined case.
#         "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenAndPregnantWomen_maxFieldSum_message":
#             "Number of children and pregnant women combined cannot exceed total household members",
#     },
# }

# Legacy localization payload retained as comments above. The active entries
# cover the member-sum validation and consent-declined success screen wording.
MESSAGES_BY_MODULE = {
    f"hcm-inventory-{CAMPAIGN}": {
        "INVENTORY_ORIGINAL_QUANTITY_RECEIVED_LABEL": "Quantity Sent",
        "INVENTORY_DISCREPANCY_REASON_LABEL": "Discrepancy Reason",
        "INVENTORY_DISCREPANCY_REASON_IN_TRANSIT": "In Transit",
        "INVENTORY_DISCREPANCY_REASON_STOCK_LOSS": "Stock Loss",
        "INVENTORY_DISCREPANCY_REASON_STOCK_DAMAGE": "Stock Damage",
        "INVENTORY_DISCREPANCY_REASON_OTHERS": "Others",
        "INVENTORY_DISCREPANCY_REASON_OTHERS_DETAIL_LABEL": "Other Reason",
        "INVENTORY_SHORTFALL_QUANTITY_LABEL": "Shortfall Quantity",
        "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_UNACCOUNTED_LABEL": "Unaccounted Quantity",
        "INVENTORY_PARTIALLY_ACCEPT_STOCK_LABEL": "Partially Accept",
        "INVENTORY_REJECT_CONFIRMATION_TITLE": "Partially Accept Stock",
        "INVENTORY_REJECT_CONFIRMATION_DESCRIPTION":
            "Enter the quantity you actually received and the reason it differs from the quantity sent.",
        "INVENTORY_REJECT_CONFIRM_ACTION": "Confirm",
        "INVENTORY_REJECT_CANCEL_ACTION": "Cancel",
        "INVENTORY_ACTUAL_QUANTITY_RECEIVED_LABEL": "Actual Quantity Received",
        "INVENTORY_REJECT_COMMENT_LABEL": "Reason for Difference",
        "INVENTORY_PARTIAL_ACCEPT_QUANTITY_INVALID":
            "Actual received quantity must be greater than zero and less than the quantity sent. "
            "To record the full quantity, use Accept instead.",
        "INVENTORY_STOCK_REJECTED_SUCCESS": "Stock partially accepted",

        # Stock PRD: Accept/Partial Accept on an incoming Shortfall Return.
        "INVENTORY_STOCK_DAMAGE_RECORDED_SUCCESS":
            "Stock recorded as damaged",
        "INVENTORY_STOCK_LOSS_RECORDED_SUCCESS":
            "Stock loss recorded",
        "INVENTORY_RETURN_RESOLVED_VIA_ACCEPT":
            "This return resolves automatically based on the reason the sender reported - use Accept instead.",

        # viewReports' reportDetails heading, per report type. Receipt/
        # Dispatch/Returned/Damage/Loss reuse the INVENTORY_STOCK_*_DETAILS_
        # HEADING codes already upserted above for viewTransactionDetails
        # (same wording fits both screens) - only Excess and Less need their
        # own codes here, since no single-transaction equivalent exists.
        "INVENTORY_REPORT_DETAILS_EXCESS_REPORT_TITLE": "Stock Excess Details",
        "INVENTORY_REPORT_DETAILS_LESS_REPORT_TITLE": "Stock Less Details",
    },
    f"hcm-registration-{CAMPAIGN}": {
        "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenAndPregnantWomen_maxFieldSum_message":
            "The combined number of children and pregnant women must not exceed the total number of household members.",
        "CAREGIVER_CONSENT_DECLINED_PANEL_HEADING": "Household Marked as Closed",
        "CAREGIVER_CONSENT_DECLINED_PANEL_DESC":
            "This household was marked as closed because consent was not provided. You can search for it again if consent is obtained later.",
        "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_HEADING":
            "Household Registered Successfully",
        "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_DESC":
            "The household has been registered and the health talk checklist has been recorded.",
    },
    f"hcm-closehousehold-{CAMPAIGN}": {
        # headName only had a minLength before - sync fails server-side past
        # 200 chars (same cap registration_flows.dart enforces on its own
        # name fields), so add a matching maxLength here too.
        "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_MAX_LENGTH_ERROR":
            "Name must be at most 200 characters",
    },
}
# ONE REQUEST PER MODULE - never a single batched request for all of them.
# The server de-duplicates the messages array by CODE alone, ignoring the
# module, so a batch carrying the same code for two modules is rejected
# outright.
modules = list(MESSAGES_BY_MODULE)
total = sum(len(codes) for codes in MESSAGES_BY_MODULE.values())
print(f"📤 Upserting {total} message(s) across {len(modules)} module(s), one request each")

failed = []
for module, codes in MESSAGES_BY_MODULE.items():
    messages = [
        {
            "code": code,
            "message": message,
            "module": module,
            "locale": LOCALE,
        }
        for code, message in sorted(codes.items())
    ]

    body = dict(UPSERT_REQUEST_BODY)
    body["tenantId"] = TENANT_ID
    body["messages"] = messages

    print(f"\n   [{module}]")
    for m in messages:
        print(f"   {m['code']:<45} -> {m['message']}")

    try:
        upsert_res = requests.post(TO_ENV_HOST, data=json.dumps(body), headers=headers)
        upsert_json = upsert_res.json()

        if upsert_res.status_code != 200 or "Errors" in upsert_json:
            failed.append(module)
            print(f"   ❌ Failed ({upsert_res.status_code})")
            print(f"   🔴 Response: {upsert_json}")
        else:
            print(f"   ✅ Upserted ({upsert_res.status_code})")
    except Exception as e:
        failed.append(module)
        print(f"   ❌ Exception: {e}")

if failed:
    print(f"\n❌ Failed module(s): {', '.join(failed)}")
else:
    print(f"\n✅ Successfully upserted all {len(modules)} module(s)")

print("\n✅ Script completed")
