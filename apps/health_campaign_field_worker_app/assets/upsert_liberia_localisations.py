import json
import requests

# Upserts localisation messages for the Liberia campaign.
#
# A code only resolves on screen if the module holding it is one of the modules
# the app fetches for that screen (home.dart passes the module list to
# triggerLocalization). AppLocalizations then flattens every stored module into
# a single map, so WHICH module a code lives in does not matter for lookup --
# only whether that module is fetched before the screen renders. Hence codes are
# grouped per module below: each code must sit in a module the screen it appears
# on actually loads.
#
# Module names used by the app (home.dart):
#     hcm-registration-${referenceID}     house-to-house registration flow
#     hcm-inventory-${referenceID}        manage stock flow
#     hcm-closehousehold-${referenceID}   closed household flow
#     hcm-complaints-${referenceID}       file complaint flow
#     hcm-beneficiary                     Beneficiary ID down-sync page
#     hcm-boundary-${hierarchyType}       boundary pickers
#     hcm-dashboard / hcm-transit-post    dashboard / transit post
# The ${referenceID} ones are per-campaign and must match the campaign currently
# selected on the device; the unsuffixed ones are campaign-independent.
#
# Unlike the Sierra Leone script, this one does not read the Gombe export or
# scan the config - the bulk of Liberia's localisations are already loaded.
# Only the codes listed in MESSAGES_BY_MODULE below are sent.

TO_ENV_HOST = "https://liberia-hcm-uat.digit.org/localization/messages/v1/_upsert"

CAMPAIGN = "CMP-2026-10-23-001344"

# Campaigns the checklist has to render on. The checklist module is
# hcm-checklist-${project.referenceID} (home.dart:2576), so one module per
# campaign - a supervisor logged into the older campaign loads a different
# module and would otherwise see raw codes. Same text in each.
CHECKLIST_CAMPAIGNS = [
    CAMPAIGN,
    "CMP-2026-10-07-001258",
]
TENANT_ID = "liberia"
LOCALE = "en_LIBERIA"

UPSERT_REQUEST_BODY = {
    "RequestInfo": {
        "authToken": "be05cd71-e392-472c-ba61-39c2dae2cdd6",
        "userInfo": {
            "id": 91,
            "uuid": "09a3ada4-6b14-4948-92b6-01ce5c4dc099",
            "userName": "TEST-CM-1"
        }
    }
}

headers = {"Content-Type": "application/json"}

# AppLocalizations.translate is `_localizedMap[key] ?? key`, so a code that is
# absent renders as the raw key and a code present with an empty message
# renders as nothing at all. A blank button therefore means the code exists
# with an empty value and needs overwriting, not adding.
# Already upserted - kept for reference, commented out so a re-run sends only
# the active set below.
# MESSAGES = {
#     "REGISTER_NEW_BENEFICIARY": "Register new household",
#     "DOWNLOAD_BENEFICIARY_IDS": "Download Beneficiary IDs",
# }

# Already upserted - commented out so a re-run sends only the active set below.
# MESSAGES = {
#     # Blank on the Registrar's screens - present in the module with an empty
#     # message, so they render as nothing rather than as the raw key.
#     "REGISTER_NEW_BENEFICIARY": "Register new household",
#     "DOWNLOAD_BENEFICIARY_IDS": "Download Beneficiary IDs",
#
#     # "e-Token" is being retired in favour of plain "Token".
#     "E_TOKEN": "Token",
#     "NO_BENEFICIARY_ID": "No Token assigned",
#
#     # Household overview / member card
#     "IS_HEAD": "Head of household",
#     "HOUSEHOLD_MOBILE_NUMBER": "Mobile Number",
#
#     # Children under 5
#     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount": "Number of children under 5",
#     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_helpText": "Children under 5 years of age living in the household",
#     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_mandatory_message": "Number of children under 5 is required",
#     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_min_message": "Number of children under 5 cannot be negative",
#     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message": "Number of children under 5 cannot exceed the household member count",
#     "REGISTRATION_SEARCH_BENEFICIARY_CHILDREN_COUNT_EXCEEDED": "Number of children under 5 cannot exceed the household member count",
#
#     "MOBILE_LENGTH_10_DIGIT_ERROR": "Mobile number must be 10 digits",
# }

# Stock keeping unit differs by role: a warehouse manager moves ITNs in bales,
# a distributor hands out loose pieces. Both use the same quantity fields on
# the same page, so the config picks the label code by role via
# `labelConditions` (PropertySchema) - the plain *_LABEL codes stay as the
# fallback for any other role and are already upserted.
#
# Sent in BOTH the campaign module and the base bednet module below, with
# identical text, so a new campaign inherits them.
QUANTITY_UNIT_LABELS = {
    "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_BALES": "Quantity Received (Bales)",
    "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL_PIECES": "Quantity Received (Pieces)",
    "APPONE_INVENTORY_QUANTITY_SENT_LABEL_BALES": "Quantity Sent (Bales)",
    "APPONE_INVENTORY_QUANTITY_SENT_LABEL_PIECES": "Quantity Sent (Pieces)",
    "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_BALES": "Quantity Returned (Bales)",
    "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL_PIECES": "Quantity Returned (Pieces)",
    "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_BALES": "Quantity Damaged (Bales)",
    "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL_PIECES": "Quantity Damaged (Pieces)",
    "APPONE_INVENTORY_QUANTITY_LOST_LABEL_BALES": "Quantity Lost (Bales)",
    "APPONE_INVENTORY_QUANTITY_LOST_LABEL_PIECES": "Quantity Lost (Pieces)",
}

# View Reports quantity column. TEMPLATE tables, not forms: the header runs
# through resolveTemplate BEFORE translate, so the config wraps the code in
# {{fn:unitLabel('...')}} and the suffixed code below is what finally gets
# translated.
#
# Only the generic reports table is role-driven - Stock Received / Returned /
# Damaged / Loss are ungated, so a distributor reaches them and must see
# Pieces. Dates, SKU, MRN and waybill carry no unit and stay untouched.
REPORT_UNIT_LABELS = {
    "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_4_LABEL_BALES": "Quantity (Bales)",
    "STOCKREPORTS_REPORT_DETAILS_TABLE_HEADER_4_LABEL_PIECES": "Quantity (Pieces)",
}

# Reconciliation report columns. The reconciliation card is not published as
# a role action item, so only warehouse users ever open this report - the
# unit is always bales and the base codes carry it directly rather than going
# through unitLabel. Plain overwrites of existing codes, not new ones.
RECON_REPORT_LABELS = {
    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_2_LABEL": "Stock Received (Bales)",
    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_3_LABEL": "Stock Issued (Bales)",
    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_4_LABEL": "Stock Returned (Bales)",
    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_7_LABEL": "Physical Count (Bales)",
    "STOCKRECON_REPORT_DETAILS_TABLE_HEADER_8_LABEL": "Calculated Count (Bales)",
}

# Reconciliation form. Warehouse-only for the same reason, so the base code
# carries the unit directly and the field needs no labelConditions.
RECON_FORM_LABELS = {
    "STOCKRECONCILIATION_STOCKRECONCILIATION_manualCount_LABEL":
        "Manual Count (Bales)",
}

# ---------------------------------------------------------------- checklist
# Supervisor in-process distribution checklist (curl-checklist.json).
#
# The service definition is `${projectTypeCode}.${checklistType}.${ROLE}`
# (service_definition.dart:33-39) and every label on the checklist screen is
# translated as `${serviceDefinition.code}.${attribute.code}`
# (survey_form_view.dart:744, 800, 851, 890) - so each question's localisation
# code is the FULL service definition code plus a dot plus the attribute code,
# not the bare attribute code. Option labels follow the same rule on the option
# value (survey_form_view.dart:906, 1170-1172), and the screen heading
# translates the service definition code on its own (survey_form_view.dart:683).
#
# The one exception is the "required" validation message: it is translated as
# `${attribute.code}_REQUIRED` with NO service definition prefix
# (survey_form_view.dart:731, 1303), so those codes are bare.
#
# Module: home.dart:2576 fetches `hcm-checklist-${project.referenceID}` before
# pushing the checklist route, and hcm-checklist (unsuffixed) is in the common
# list at home.dart:3102. Both are sent below with identical text, so a new
# campaign inherits the wording.
#
# The question text is taken verbatim from each attribute's
# additionalDetails.secDesc in curl-checklist.json.

CHECKLIST_SERVICE_DEFINITION = "demo_bednet_october_2026.TRAINING_SUPERVISION.HEALTH_FACILITY_WORKER"


CHECKLIST_QUESTIONS = {
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_1": "Are all D2D or DP team members present?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_2": "Have all team members been recruited locally and trained?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_3": "How many members of the team were trained? (write number)",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_4": "Are there tables for the retrieval of vouchers and distribution of nets at DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_5": "Is there a rope or line for crowd control at DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_6": "Is distribution being orderly done?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_7": "Is there a banner hanging to identify the distribution point?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_8": "Are vouchers being verified and scanned by the voucher verifier (D2D or DP)?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_9": "Is there a priority line for people that are aged, pregnant women or physically challenged?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OVERALL_ORG_10": "Is the DP supervisor present?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_11": "Are devices available at the District?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_12": "Is there a safe place for storage of the devices?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_13": "Is there a secured charging area in the HF catchment area for the devices?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_14": "Are devices available at the DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_15": "Are there sufficient devices for all of the planned DPs?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_16": "Are all of the devices sufficiently charged for the day's work?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_17": "Has the team experienced any challenges with the devices?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_18": "If yes, choose an option: 1-charging, 2-synching, 3-network, others",
    f"{CHECKLIST_SERVICE_DEFINITION}.DEVICES_19": "If the answers to any of the above question is NO, what corrective actions/solutions are been taken?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_20": "Is the District warehouse secure for the storage of ITNs?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_21": "Is the stocksheet being used at the District warehouse?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_22": "If yes, is the stocksheet up to date?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_23": "Has the ITN stock been properly recorded in the device?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_24": "Has the PPS/DP supervisor made arrangements for net movement to households, outreach and mobile DPs?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_25": "Has the PPS supervisors communicated to community leaders about the D2D distribution?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_26": "Is there a safe storage for the ITNs at the PPS/DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_27": "Are nets available at the PPS/DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_28": "Is there a plan for re-stocking when supplies are running low?",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOGISTICS_29": "If the answers to any of the above question is NO, what corrective actions/solutions are been taken?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DISTRIBUTION_30": "Observe the process. Is the DP team following the tasks for receiving vouchers and issuing nets using the device?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DISTRIBUTION_31": "Is a line being drawn across each voucher to indicate it has been received and ITN issued?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DISTRIBUTION_32": "Are the valid vouchers being put into a separate voucher box from the invalid vouchers?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DISTRIBUTION_33": "Are children under 18 being served at the DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DISTRIBUTION_34": "If the answers to any of the above question is NO, what corrective actions/solutions are been taken?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DATA_COLLECTION_35": "Check the data on the device. Are the DP teams scanning the vouchers and providing nets accurately?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DATA_COLLECTION_36": "Check the data on the device. Does the data on the device align to the physical stock of nets remaining?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DATA_COLLECTION_37": "Do vouchers received from household tally with the nets given to them?",
    f"{CHECKLIST_SERVICE_DEFINITION}.DATA_COLLECTION_38": "If the answers to any of the above question is NO, what corrective actions/solutions are been taken?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_39": "Were Health Educators demonstration site appropriately set up?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_40": "Are health education activities being carried out at demonstration site?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_41": "Is there a net hanging at the demonstration area?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_42": "Is the Health Educator giving the key messages on the use and care of the ITN?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_43": "Is the health educator using the flash cards to demonstrate ITN use and care?",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_BEHAVIOR_44": "If the answers to any of the above question is NO, what corrective actions/solutions are been taken?",
    f"{CHECKLIST_SERVICE_DEFINITION}.OBSERVATIONS_45": "List three good practices that were observed at the DP.",
    f"{CHECKLIST_SERVICE_DEFINITION}.OBSERVATIONS_46": "Were there any additional problems observed at this DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_47": "Have you gone to the DP to redeem your net?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_48": "If no, why you have not done so? 1-was not registered, 2-lost my voucher, 3-Do not know where to go, 4-DP is too far",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_49": "Are you satisfied with the ITN distribution?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_50": "If No, what problem did you experience? 1-DP is too crowded, 2-Wait time is too long, 3-Didn't get the right number of nets, 4-DP staff not attentive, 5-Nets are dirty, 6-Distance to the DP location too far, 7-other",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_51": "Did you receive the right quantity of nets?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_52": "If No, how many did you receive? Choose from the option 1-5",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_53": "How many did you expect to receive? Choose from the option 1-10",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_54": "Did you receive any message about the nets or malaria at the DP?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_55": "If yes what message did you receive?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_56": "Did you receive any message from any other channel about the campaign?",
    f"{CHECKLIST_SERVICE_DEFINITION}.EXIT_INTERVIEW_57": "If yes, what medium? Choose from options: 1-Radio, 2-Street announcement, 3-Town criers, 4-TV, 5-CSOs, 6-Social media",
}

CHECKLIST_OPTIONS = {
    f"{CHECKLIST_SERVICE_DEFINITION}.1": "1",
    f"{CHECKLIST_SERVICE_DEFINITION}.2": "2",
    f"{CHECKLIST_SERVICE_DEFINITION}.3": "3",
    f"{CHECKLIST_SERVICE_DEFINITION}.4": "4",
    f"{CHECKLIST_SERVICE_DEFINITION}.5": "5",
    f"{CHECKLIST_SERVICE_DEFINITION}.6": "6",
    f"{CHECKLIST_SERVICE_DEFINITION}.7": "7",
    f"{CHECKLIST_SERVICE_DEFINITION}.8": "8",
    f"{CHECKLIST_SERVICE_DEFINITION}.9": "9",
    f"{CHECKLIST_SERVICE_DEFINITION}.10": "10",
    f"{CHECKLIST_SERVICE_DEFINITION}.CHARGING": "Charging",
    f"{CHECKLIST_SERVICE_DEFINITION}.CSOS": "CSOs",
    f"{CHECKLIST_SERVICE_DEFINITION}.DONT_KNOW_LOCATION": "Do not know where to go",
    f"{CHECKLIST_SERVICE_DEFINITION}.DP_TOO_CROWDED": "DP is too crowded",
    f"{CHECKLIST_SERVICE_DEFINITION}.DP_TOO_FAR": "DP is too far",
    f"{CHECKLIST_SERVICE_DEFINITION}.LOST_VOUCHER": "Lost my voucher",
    f"{CHECKLIST_SERVICE_DEFINITION}.NETS_DIRTY": "Nets are dirty",
    f"{CHECKLIST_SERVICE_DEFINITION}.NETWORK": "Network",
    f"{CHECKLIST_SERVICE_DEFINITION}.NOT_REGISTERED": "Was not registered",
    f"{CHECKLIST_SERVICE_DEFINITION}.NOT_SELECTED": "Not Selected",
    f"{CHECKLIST_SERVICE_DEFINITION}.OTHER": "Other",
    f"{CHECKLIST_SERVICE_DEFINITION}.RADIO": "Radio",
    f"{CHECKLIST_SERVICE_DEFINITION}.SOCIAL_MEDIA": "Social media",
    f"{CHECKLIST_SERVICE_DEFINITION}.STAFF_NOT_ATTENTIVE": "DP staff not attentive",
    f"{CHECKLIST_SERVICE_DEFINITION}.STREET_ANNOUNCEMENT": "Street announcement",
    f"{CHECKLIST_SERVICE_DEFINITION}.SYNCHING": "Synching",
    f"{CHECKLIST_SERVICE_DEFINITION}.TOWN_CRIERS": "Town criers",
    f"{CHECKLIST_SERVICE_DEFINITION}.TV": "TV",
    f"{CHECKLIST_SERVICE_DEFINITION}.WAIT_TIME_LONG": "Wait time is too long",
    f"{CHECKLIST_SERVICE_DEFINITION}.WRONG_NET_QUANTITY": "Didn't get the right number of nets",
    f"{CHECKLIST_SERVICE_DEFINITION}.no": "No",
    f"{CHECKLIST_SERVICE_DEFINITION}.yes": "Yes",
}

CHECKLIST_VALIDATION = {
    "OVERALL_ORG_1_REQUIRED": "This field is required",
    "OVERALL_ORG_2_REQUIRED": "This field is required",
    "OVERALL_ORG_3_REQUIRED": "This field is required",
    "OVERALL_ORG_4_REQUIRED": "This field is required",
    "OVERALL_ORG_5_REQUIRED": "This field is required",
    "OVERALL_ORG_6_REQUIRED": "This field is required",
    "OVERALL_ORG_7_REQUIRED": "This field is required",
    "OVERALL_ORG_8_REQUIRED": "This field is required",
    "OVERALL_ORG_9_REQUIRED": "This field is required",
    "OVERALL_ORG_10_REQUIRED": "This field is required",
    "DEVICES_11_REQUIRED": "This field is required",
    "DEVICES_12_REQUIRED": "This field is required",
    "DEVICES_13_REQUIRED": "This field is required",
    "DEVICES_14_REQUIRED": "This field is required",
    "DEVICES_15_REQUIRED": "This field is required",
    "DEVICES_16_REQUIRED": "This field is required",
    "DEVICES_17_REQUIRED": "This field is required",
    "LOGISTICS_20_REQUIRED": "This field is required",
    "LOGISTICS_21_REQUIRED": "This field is required",
    "LOGISTICS_23_REQUIRED": "This field is required",
    "LOGISTICS_24_REQUIRED": "This field is required",
    "LOGISTICS_25_REQUIRED": "This field is required",
    "LOGISTICS_26_REQUIRED": "This field is required",
    "LOGISTICS_27_REQUIRED": "This field is required",
    "LOGISTICS_28_REQUIRED": "This field is required",
    "DISTRIBUTION_30_REQUIRED": "This field is required",
    "DISTRIBUTION_31_REQUIRED": "This field is required",
    "DISTRIBUTION_32_REQUIRED": "This field is required",
    "DISTRIBUTION_33_REQUIRED": "This field is required",
    "DATA_COLLECTION_35_REQUIRED": "This field is required",
    "DATA_COLLECTION_36_REQUIRED": "This field is required",
    "DATA_COLLECTION_37_REQUIRED": "This field is required",
    "SOCIAL_BEHAVIOR_39_REQUIRED": "This field is required",
    "SOCIAL_BEHAVIOR_40_REQUIRED": "This field is required",
    "SOCIAL_BEHAVIOR_41_REQUIRED": "This field is required",
    "SOCIAL_BEHAVIOR_42_REQUIRED": "This field is required",
    "SOCIAL_BEHAVIOR_43_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_47_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_49_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_51_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_53_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_54_REQUIRED": "This field is required",
    "EXIT_INTERVIEW_56_REQUIRED": "This field is required",
}

# Screen heading - survey_form_view.dart:683 translates the service definition
# code by itself and appends the localised "Checklist" word after it.
CHECKLIST_HEADING = {
    CHECKLIST_SERVICE_DEFINITION: "Training Supervision",
}

CHECKLIST_MESSAGES = {
    **CHECKLIST_HEADING,
    **CHECKLIST_QUESTIONS,
    **CHECKLIST_OPTIONS,
    **CHECKLIST_VALIDATION,
}

# Active set: codes added or changed since the last run, keyed by the module
# they belong in. Add a new module by adding a key - nothing else changes.
MESSAGES_BY_MODULE = {
    # f"hcm-registration-{CAMPAIGN}": {
        # Blank on the Registrar's screens - present in the module with an empty
        # message, so they render as nothing rather than as the raw key.
        # "REGISTER_NEW_BENEFICIARY": "Register new household",
        # "DOWNLOAD_BENEFICIARY_IDS": "Download Beneficiary IDs",
        # "BENEFICIARY_ID_SEARCH_REGISTRATION": "Search by Beneficiary ID",
        # "ACKNOWLEDGEMENT_SUCCESS_LABEL_TEXT": "Back to Search",

#         # Keep minimum-length validation separate from the 200-character
        # maximum message for both household registration and added members.
        # "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_min_message": "First name must be at least 2 characters",
        # "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_min_message": "Last name must be at least 2 characters",
        # "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_min_message_addmember": "First name must be at least 2 characters",
        # "APPONE_REGISTRATION_BENEFICIARYDETAILS_label_familyname_min_message_addmember": "Last name must be at least 2 characters",

#         # "e-Token" is being retired in favour of plain "Token".
        # "E_TOKEN": "Token",
        # "NO_BENEFICIARY_ID": "No Token assigned",

#         # Household overview / member card
        # "IS_HEAD": "Head of household",
        # "HOUSEHOLD_MOBILE_NUMBER": "Mobile Number",

#         # Children under 5
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount": "Number of children under 5",
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_helpText": "Children under 5 years of age living in the household",
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_mandatory_message": "Number of children under 5 is required",
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_min_message": "Number of children under 5 cannot be negative",
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_max_message": "Number of children under 5 cannot exceed the household member count",
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenCount_maxField_message": "Number of children cannot exceed total household members",
        # "REGISTRATION_SEARCH_BENEFICIARY_CHILDREN_COUNT_EXCEEDED": "Number of children under 5 cannot exceed the household member count",

#         # Household members
        # "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_memberCount_max_message": "Household member count cannot exceed 10",

#         # Home beneficiary card label shown only to Registrar roles.
        # "HOME_REGISTRAR_BENEFICIARY_LABEL": "House-House",
        # "HOME_DISTRIBUTION_LABEL": "Distribution",

#         # The phone field's pattern is ^0\d{9}$ - it *requires* a leading zero
        # and exactly 10 digits. The old wording ("Mobile number cannot start
        # with 0") said the opposite of what the rule enforces, so a
        # valid-looking entry was rejected with a message telling the user to do
        # what they had already done. The rule is unchanged; only the wording is
        # corrected to describe it.
        # "MOBILE_NUMBER_START_WITH_ZERO_ERROR": "Mobile number should start with 0 and should have 10 digits",

#         # Caregiver consent before collecting household registration details.
    #     "APPONE_REGISTRATION_CAREGIVER_CONSENT_SCREEN_HEADING": "Caregiver Consent",
    #     "APPONE_REGISTRATION_CAREGIVER_CONSENT_label_consentToParticipate": "Does the caregiver consent to participate in the ITN campaign?",
    #     "APPONE_REGISTRATION_CAREGIVER_CONSENT_label_consentToParticipate_mandatory_message": "Please record the caregiver's consent",
    #     "APPONE_CAREGIVER_CONSENT_YES": "Yes",
    #     "APPONE_CAREGIVER_CONSENT_NO": "No",
    #     "APPONE_REGISTRATION_CAREGIVER_CONSENT_ACTION_BUTTON_LABEL_1": "Continue",
    #     "APPONE_REGISTRATION_HOUSEHOLDDETAILS_label_childrenAndPregnantWomen_maxFieldSum_message":
    #         "The combined number of children and pregnant women must not exceed the total number of household members.",
    #     "CAREGIVER_CONSENT_DECLINED_PANEL_HEADING": "Household Marked as Closed",
    #     "CAREGIVER_CONSENT_DECLINED_PANEL_DESC":
    #         "The caregiver did not consent to participate in the ITN campaign. The household has been marked as closed, and no ITNs will be distributed. You may search for the household again if consent is obtained later.",
    #     "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_HEADING":
    #         "Household Registered Successfully",
    #     "HOUSEHOLD_REGISTERED_SUCCESSFUL_PANEL_CARD_DESC":
    #         "The household has been registered and the health talk checklist has been recorded.",

#         # Summary Report: "Children under 5" column, shown only to Registrars.
        # The Summary Report route does not call triggerLocalization at all
        # (home.dart pushes SummaryReportRoute directly), so this code has to
        # live in a module that is already cached by the time the screen
        # renders. All flow modules are fetched post project selection, and
        # AppLocalizations flattens every stored module into one map, so the
        # registration module - which any Registrar necessarily has - resolves
        # it. Matches i18.summaryReport.numberOfChildrenUnder5.
        # "NUMBER_OF_CHILDREN_UNDER_5": "Number of children under 5 registered",

#         # Shown when a scanned or manually typed code fails the scanner's
        # "pattern" validation. Surfaced via DigitScannerEvent.patternMessage.
        # Re-enabled: the live config attaches this code to the scanner's
        # pattern rule, and with no localisation row the raw key was being
        # rendered on screen as the error toast.
        # "SCANNER_INVALID_CODE_MESSAGE": "Invalid code. Please scan or enter a valid code.",

#         # Product name shown on the delivery resource card. The code here is
        # the backend value itself, not a key: resource_beneficiary_card.dart:77
        # renders `localizations.translate(value.name)`, where `name` is
        # DeliveryProductVariant.name straight from the project type's
        # doseCriteria. So the only way to display "ITN" instead of the raw
        # "ITN - Grade - 1" is to localise that literal string. It must match
        # the backend value byte-for-byte, spaces included, or translate()
        # falls through and renders the raw name again.
        # "ITN - Grade - 1": "ITN",
    # },

    # DOWNLOAD_BENEFICIARY_IDS is deliberately in BOTH modules above and below,
    # with the same message.
    #
    # The Beneficiary ID down-sync page is opened straight from home with only
    # "hcm-beneficiary" fetched (home.dart), so the code has to exist here or
    # that page cannot resolve it. But it ALSO already exists in
    # hcm-registration-<campaign> with an empty message, and the app's cache is
    # keyed by code alone across all modules - so that empty row could win the
    # race and blank the button no matter what this module says. Setting the
    # same correct text in both modules removes the race entirely.
    #
    # Re-enabled: the duplicate-key rejection that forced this to be commented
    # out came from sending both modules in ONE request. The loop below now
    # sends one request per module, so the two entries no longer collide.
    # "hcm-beneficiary": {
    #     "DOWNLOAD_BENEFICIARY_IDS": "Download Beneficiary IDs",
    # },

    # Already upserted - commented out so a re-run sends only the checklist.
    # f"hcm-inventory-{CAMPAIGN}": {
        # Facility names rendered through the FAC_{facilityId} localization key.
        # "FAC_F-2026-10-07-024415": "HF Warehouse",
        # "FAC_F-2026-10-07-024416": "District Warehouse",
        # "FAC_F-2026-10-07-024417": "DP Warehouse",
        # "FAC_F-2026-10-07-024418": "County Warehouse",
        # "FAC_F-2026-10-07-024419": "Community Warehouse",
        # "FAC_F-2026-10-07-024420": "National Warehouse",
        # "F-2026-10-07-024415": "HF Warehouse",
        # "F-2026-10-07-024416": "District Warehouse",
        # "F-2026-10-07-024417": "DP Warehouse",
        # "F-2026-10-07-024418": "County Warehouse",
        # "F-2026-10-07-024419": "Community Warehouse",
        # "F-2026-10-07-024420": "National Warehouse",

        # Inventory upsert fields shown in the stock view-transition flow.
        # "APPONE_INVENTORY_TRANSPORT_LABEL": "Transport Type",
        # "APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL": "Quantity Received",
        # "APPONE_INVENTORY_QUANTITY_RETURNED_LABEL": "Quantity Returned",
        # "APPONE_INVENTORY_QUANTITY_SENT_LABEL": "Quantity Sent",
        # "APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL": "Quantity Damaged",
        # "APPONE_INVENTORY_QUANTITY_LOST_LABEL": "Quantity Lost",
        # "INVENTORY_TRANSPORT_TYPE_HELPTEXT": "Select the transport type",
        # "INVENTORY_TRANSPORT_TYPE_LABEL": "Transport Type",
        # "INVENTORY_TRANSPORT_TYPE_TRUCK": "Truck",
        # "INVENTORY_TRANSPORT_TYPE_VAN": "Van",
        # "INVENTORY_TRANSPORT_TYPE_PICK_UP": "Pick-up",
        # "INVENTORY_TRANSPORT_TYPE_JEEP": "Jeep",
        # "TRUCK": "Truck",
        # "VAN": "Van",
        # "PICK_UP": "Pick-up",
        # "JEEP": "Jeep",

        # reportDetails' heading used to be the same static
        # STOCKREPORTS_REPORT_DETAILS_HEADING for every report type (Receipt,
        # Issued, Returned, Damaged, Loss, Excess, Less), so Loss reports
        # showed the Receipt wording. Each viewReports card now passes its
        # own reportDetailsHeading. Receipt/Dispatch/Returned/Damage/Loss
        # reuse the existing INVENTORY_STOCK_*_DETAILS_HEADING codes already
        # upserted below for viewTransactionDetails (same wording fits both
        # screens) - only Excess and Less needed genuinely new codes, since
        # there's no equivalent single-transaction heading for either.
        # "INVENTORY_REPORT_DETAILS_EXCESS_REPORT_TITLE": "Stock Excess Details",
        # "INVENTORY_REPORT_DETAILS_LESS_REPORT_TITLE": "Stock Less Details",
        # "INVENTORY_REPORT_DETAILS_RECEIPT_REPORT_TITLE": "Stock Received Details",
        # "INVENTORY_REPORT_DETAILS_DISPATCH_REPORT_TITLE": "Stock Issued Details",
        # "INVENTORY_REPORT_DETAILS_RETURNED_REPORT_TITLE": "Stock Returned Details",
        # "INVENTORY_REPORT_DETAILS_DAMAGE_REPORT_TITLE": "Stock Damaged Details",
        # "INVENTORY_REPORT_DETAILS_LOSS_REPORT_TITLE": "Stock Loss Details",
        # "INVENTORY_REPORT_DETAILS_RECONCILIATION_REPORT_TITLE": "Stock Reconciliation Details",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_RECIEVE_HEADING": "Stock Received",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_RECIEVE_DESCRIPTION": "View stock received by this facility",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_ISSUED_HEADING": "Stock Issued",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_ISSUED_DESCRIPTION": "View stock issued by this facility",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_RETURNED_HEADING": "Stock Returned",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_RETURNED_DESCRIPTION": "View stock returned by this facility",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_DAMAGED_HEADING": "Stock Damaged",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_DAMAGED_DESCRIPTION": "View stock reported as damaged",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_LOSS_HEADING": "Stock Loss",
        # "STOCKREPORTS_VIEW_REPORTS_STOCK_LOSS_DESCRIPTION": "View stock reported as lost",

        # "APPONE_INVENTORY_VEHICLE_NUMBER_LABEL": "Vehicle Number",
        # "INVENTORY_VEHICLE_NUMBER_LABEL": "Vehicle Number",
        # "INVENTORY_VEHICLE_NUMBER_HELPTEXT": "Enter a vehicle number using letters, numbers, or spaces",
        # "APPONE_INVENTORY_WAYBILL_LABEL": "Waybill Number",
        # "INVENTORY_WAYBILL_NUMBER_REQUIRED_ERROR_MESSAGE": "Waybill number can contain letters and numbers only",
        # "INVENTORY_CREATE_NEW_TRANSACTION_LABEL": "Create new transaction",

        # Loss declaration and nature of loss fields
        # "APPONE_INVENTORY_LOSS_DECLARATION_LABEL": "Loss Declaration",
        # "APPONE_INVENTORY_LOSS_DECLARATION_REQUIRED_ERROR_MESSAGE": "Loss declaration is required",
        # "DECLARED_LOSS": "Declared Loss",
        # "UNDECLARED_LOSS": "Undeclared Loss",
        # "APPONE_INVENTORY_NATURE_OF_LOSS_LABEL": "Nature of Loss",
        # "APPONE_INVENTORY_NATURE_OF_LOSS_REQUIRED_ERROR_MESSAGE": "Nature of loss is required",
        # "LOSS_IN_STORE": "Loss in Store",
        # "LOSS_BY_FIELD_TEAMS": "Loss by Field Teams",
        # "LOSS_BY_THEFT": "Loss by Theft",

        # Existing inventory transaction overrides are unrelated to this upsert flow.
        # "INVENTORY_RECEIVED_FROM_LABEL": "Received from",
        # "INVENTORY_SENDER_LABEL": "Received from",
        # "INVENTORY_RECEIVER_LABEL": "Sent to",
        # "APP_CONFIG_INVENTORY_SENDER_LABEL": "Received from",
        # This is the code actually rendered on the stock "from" field (manage_stock.dart) -
        # the codes above were already "Received from" but weren't the ones in use.
        # "APPONE_MANAGESTOCK_WAREHOUSE_label_facilityFromWhich": "Received from",

        # Damage reason dropdown added for the DAMAGED transaction flow
        # "APPONE_INVENTORY_DAMAGE_REASON_LABEL": "Reason for damage",
        # "APPONE_INVENTORY_DAMAGE_REASON_REQUIRED_ERROR_MESSAGE": "Reason for damage is required",
        # "DAMAGED_IN_TRANSIT": "Damaged in Transit",
        # "DAMAGED_IN_STORAGE": "Damaged in Storage",

        # Stock damaged and stock loss descriptions
        # "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_DAMAGED_DESCRIPTION": "Create records for stock that is damaged",
        # "APP_CONFIG_INVENTORY_manageStock_RECORD_STOCK_LOSS_DESCRIPTION": "Create records for stock that is lost",

        # Incoming transactions footer button
        # "INVENTORY_RECORD_RECEIPT_MANUALLY": "Record Receipt Manually",

        # Transaction detail headings for different stock entry types
        # "INVENTORY_STOCK_RECEIPT_DETAILS_HEADING": "Stock Receipt Details",
        # "INVENTORY_STOCK_ISSUE_DETAILS_HEADING": "Stock Issued Details",
        # "INVENTORY_STOCK_RETURN_DETAILS_HEADING": "Stock Return Details",
        # "INVENTORY_STOCK_DAMAGED_DETAILS_HEADING": "Stock Damaged Details",
        # "INVENTORY_STOCK_LOSS_DETAILS_HEADING": "Stock Loss Details",

        # Text field minimum length error message
        # "INVENTORY_TEXT_MIN_LENGTH_ERROR_MESSAGE": "This field must have at least 3 characters",

        # Same product rename as in the registration module, but the inventory
        # screens translate ProductVariantModel.sku rather than the delivery
        # variant's name (custom_product_selection_card.dart:876,
        # stock_balance_card.dart:441, stock_reconciliation_card.dart:310 all
        # call `translate(product.sku ?? product.id)`). The sku carries the
        # same "ITN - Grade - 1" text, so the entry is duplicated here to cover
        # the stock screens. Safe to repeat across modules: the loop below
        # sends one request per module, so the two rows never collide.
        # "ITN - Grade - 1": "ITN",

    # **QUANTITY_UNIT_LABELS,
    # },

    # Base (campaign-independent) bednet modules. Each code lives here AND in
    # its campaign module with identical text, so a new campaign inherits it
    # without a second upsert. Duplicating a code across modules is safe - the
    # loop below sends one request per module, and the app's cache is keyed by
    # code alone, so holding the SAME message in both is what makes the
    # resolved value deterministic.
    #
    # NOTE: the base modules are not in any triggerLocalization list
    # (home.dart), so the app never fetches them. They are a seed for new
    # campaigns; what actually renders today comes from the campaign modules.
    # "hcm-base-inventory-bednet": {
    # **QUANTITY_UNIT_LABELS,
    # },

    # View Reports screen fetches hcm-stockreports-<campaign> (home.dart), so
    # both the role-driven quantity column and the bales-only reconciliation
    # columns belong here.
    # f"hcm-stockreports-{CAMPAIGN}": {
    # **REPORT_UNIT_LABELS,
    # **RECON_REPORT_LABELS,
    # },
    # "hcm-base-stockreports-bednet": {
    # **REPORT_UNIT_LABELS,
    # **RECON_REPORT_LABELS,
    # },

    # Reconciliation flow fetches hcm-stockreconciliation-<campaign>.
    # f"hcm-stockreconciliation-{CAMPAIGN}": {
    # **RECON_FORM_LABELS,
    # },
    # "hcm-base-stockreconciliation-bednet": {
    # **RECON_FORM_LABELS,
    # },
    # Scanner error toast on the delivery screen. The GS1 "pattern" rule that
    # referenced this code has been removed from the Liberia config - it was
    # matched against the RAW barcode payload (scanner_utils.dart:233), which
    # carries the 0x1D group separator between AIs, so the anchored serial
    # pattern could never match and every valid net was rejected. The code is
    # still upserted because the scanner falls back to patternMessage for any
    # other pattern rule, and an unlocalised row renders the raw key on screen
    # (which is exactly what the field team saw).
    f"hcm-registration-{CAMPAIGN}": {
        "SCANNER_INVALID_CODE_MESSAGE":
            "Invalid code. Please scan or enter a valid code.",
    },

    # Supervisor checklist. home.dart:2576 fetches
    # hcm-checklist-<project.referenceID> right before pushing the checklist
    # route; hcm-checklist (unsuffixed) is in the common module list at
    # home.dart:3102 and is campaign-independent, so the same text goes in both
    # - the campaign modules are what render today, the base one seeds the next
    # campaign. Safe to duplicate: one request per module, identical message.
    **{
        f"hcm-checklist-{campaign}": {**CHECKLIST_MESSAGES}
        for campaign in CHECKLIST_CAMPAIGNS
    },
    "hcm-checklist": {
        **CHECKLIST_MESSAGES,
    },

    # The checklist codes are ALSO sent to hcm-peer-to-peer, which is not where
    # they belong - it is a piggyback on a module the app already fetches.
    #
    # Device logs show the startup fetch list is hcm-common, hcm-transit-post,
    # hcm-peer-to-peer, hcm-dashboard, hcm-login, hcm-beneficiary,
    # digit-privacy-policy, hcm-attendance - no checklist module in it. The
    # only code path that requests hcm-checklist-<referenceID> is the home tile
    # (home.dart:2576), and on the shipped APK the checklist is reached by a
    # route that never runs it, so the module is never fetched and every label
    # renders as its raw key.
    #
    # Lookup does not care which module a code lives in: AppLocalizations
    # flattens every STORED module into one map keyed by code alone. So putting
    # the codes in a module that is already fetched makes them resolve without
    # an app change - which matters because the APK is already distributed.
    #
    # This is a workaround, not the fix. The fix is to add
    # hcm-checklist-<referenceID> to the localisation module list in the MDMS
    # app config (backendInterface -> localizationModule); once that is done
    # these entries can be dropped.
    "hcm-peer-to-peer": {
        **CHECKLIST_MESSAGES,
    },

    # Every code in this module is already upserted, so the module itself is
    # commented out - an empty dict would send a request with no messages.
    # f"hcm-closehousehold-{CAMPAIGN}": {
    #     "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_MIN_LENGTH_ERROR":
    #         "Name must be at least 3 characters",
    #     "CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_lastName_MIN_LENGTH_ERROR":
    #         "Name must be at least 3 characters",
    # },

    # Boundary dropdown FIELD labels (the heading above each dropdown, e.g.
    # "Distribution Point", "Community"). boundary_selection.dart builds this code as
    # '${runtimeHierarchyType()}_$label', where label is BoundaryModel.label,
    # set verbatim to the node's boundaryType from the boundary tree
    # (boundary.dart:113 `label: e.boundaryType`) - i.e. "Distribution Point",
    # "Community" for this hierarchy (boundary_hierarchy.txt). runtimeHierarchyType()
    # resolves to "LIBERIA" (from the hierarchyType in boundary_hierarchy.txt).
    # One entry per level covers every dropdown on this screen, regardless of which
    # node is selected under it.
    #
    # Boundary dropdown ITEM labels - localizations.translate(e.code) on each
    # boundary node's own unique code, scoped to the boundary nodes from
    # boundary_hierarchy.txt.
    #
    # Already upserted, so the module is commented out rather than left as an
    # empty dict - see the closehousehold note above.
    # "hcm-boundary-liberia": {
    #     # Field labels
    #     "LIBERIA_Distribution Point": "Distribution Point",
    #     "LIBERIA_Community": "Community",
    #
    #     # Item labels
    #     "LIBERIA_LI_01_04_05_06_ALASALA_TOWN__PRIMARY_FIXED_DP_": "Alasala Town Primary Fixed DP",
    #     "LIBERIA_LI_01_04_05_06_13_WONNIE_TOWN": "Wonnies Town",
    #     "LIBERIA_LI_01_04_05_06_12_JAHQUAYE_TOWN_LIB_01": "Jahquaye Town",
    #     "LIBERIA_LI_01_04_05_06_11_NEW_GBEHBEAYE": "New Gehbeaye",
    #     "LIBERIA_LI_01_04_05_06_10_MOIWAH_TOWN": "Moiwah Town",
    #     "LIBERIA_LI_01_04_05_06_09_GINJABU_TOWN": "Ginjabu Town",
    #     "LIBERIA_LI_01_04_05_06_08_KPANNIE_TOWN": "Kpannie Town",
    #     "LIBERIA_LI_01_04_05_06_07_ZALAMU_TOWN_LIB_01": "Zalamu Town",
    #     "LIBERIA_LI_01_04_05_06_06_TOE_TOWN": "Toe Town",
    #     "LIBERIA_LI_01_04_05_06_05_KAWAH_TOWN": "Kawah Town",
    #     "LIBERIA_LI_01_04_05_06_04_GISSI_CAMP": "Gissi Camp",
    #     "LIBERIA_LI_01_04_05_06_03_WULENLA_TOWN": "Wulenla Town",
    #     "LIBERIA_LI_01_04_05_06_02_GEORGE_MOORE_TOWN": "George Moore Town",
    #     "LIBERIA_LI_01_04_05_06_01_ALASALA_TOWN": "Alasala Town",
    # },
}

# ONE REQUEST PER MODULE - never a single batched request for all of them.
# The server de-duplicates the messages array by CODE alone, ignoring the
# module, so a batch carrying the same code for two modules is rejected
# outright:
#
#   Duplicate key DOWNLOAD_BENEFICIARY_IDS (attempted merging values
#   ... module=hcm-registration-<campaign>) and (... module=hcm-beneficiary))
#
# That is precisely the case we need to send: the app's localisation cache is
# keyed by code alone across every module (AppLocalizations.load), so when a
# code exists in two modules the row read last wins. Keeping the SAME correct
# message in both modules is what makes the outcome deterministic, and the only
# way to send it is one request per module.
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
