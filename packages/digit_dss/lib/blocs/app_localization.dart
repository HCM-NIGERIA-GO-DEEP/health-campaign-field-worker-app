import 'package:flutter/material.dart';

import 'dashboard_localization_delegate.dart';

// Class responsible for handling attendance localization
class DashboardLocalization {
  final Locale locale;
  final Future<dynamic> localizedStrings;
  final List<dynamic> languages;

  DashboardLocalization(this.locale, this.localizedStrings, this.languages);

  // Method to get the current localization instance from context
  static DashboardLocalization of(BuildContext context) {
    return Localizations.of<DashboardLocalization>(
        context, DashboardLocalization)!;
  }

  static final List<dynamic> _localizedStrings = <dynamic>[];

  // Method to get the delegate for localization
  static const Map<String, String> _hardcodedFallbacks = {
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_TITLE_LABEL':
        'Filtrer les bénéficiaires',
    'REGISTRATION_BENEFICIARY_REFERRED': 'Bénéficiaire référé',
    'REGISTRATION_ADMINISTRATION_SUCCESS': 'Administration réussie',
    'REGISTRATION_INELIGIBLE': 'Non éligible',
    'REGISTRATION_CLOSED_HOUSEHOLD': 'Ménage fermé',
    'REGISTRATION_NOT_ADMINISTERED': 'Non administré',
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_CLEAR_LABEL': 'Effacer',
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_FILTER_LABEL': 'appliquer',
    'APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_helpText':
        'zone administrative',
    'APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_helpText':
        'latitude et longitude les plus proches',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_HEADING_addmember':
        'Inscrire un membre',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_addmember':
        'nom du membre',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_nameOfIndividual_helpText_addmember':
        'nom légal du membre',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_dobPicker_addmember':
        'date de naissance',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_gender_addmember': 'genre',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_ACTION_BUTTON_LABEL_addmember':
        'suivant',
    'APPONE_ELIGIBILITYCHECKLIST_ALERT_TITLE': 'pret a soumettre',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_SCREEN_DESCRIPTION_addmember':
        'Assurez-vous de vérifier tous les détails avant de cliquer sur le bouton de envoi. Cliquez sur le bouton Annuler pour revenir à la page précédente.',
    'ACTION_SUBMIT': 'soumettre',
    'ACTION_CANCEL': 'Annuler',
    'HOME_SUMMARY_REPORT_LABEL': 'voir le résumé',
    'REDOSE_ADMINISTRATION': 'Administration de la redose',
    'REGISTRATION_VIEW_DETAILS': 'Voir les détails',
    'REGISTRATION_EDIT_INDIVIDUAL_BUTTON_LABEL': "Modifier l'individu",
    'GENDER': 'Genre',
    'AGE_OF_BENEFICIARY': 'âge',
    'DELIVERY_SUCCESSFUL_PANEL_CARD_HEADING':
        'Distribution effectuée avec succès',
    'DELIVERY_SUCCESSFUL_PANEL_CARD_DESC':
        'La distribution a été enregistrée avec succès.',
    'VIEW_HOUSEHOLD_DETAILS': 'Voir les détails du ménage',
    'GO_BACK': 'Retour',
    'DELIVERY_BACK': 'Retour',
    'REDOSE_SUCCESSFUL_PANEL_CARD_HEADING': 'Redose enregistrée avec succès',
    'REDOSE_SUCCESSFUL_PANEL_CARD_DESC':
        'La redose a été enregistrée avec succès.',
    'REDOSE_BACK': 'Retour',
    'BENEFICIARY_DETAILS_HEADING': 'Détails du bénéficiaire',
    'BENEFICIARY_DETAILS_DESC': 'Informations du bénéficiaire',
    'NAME_OF_INDIVIDUAL': "Nom de l'individu",
    'ID_TYPE': "Type d'identifiant",
    'ID_NUMBER': "Numéro d'identifiant",
    'AGE': 'Âge',
    'MOBILE_NUMBER': 'Numéro de téléphone portable',
    'DATE_OF_REGISTRATION': "Date d'enregistrement",
    'DOSE': 'Dose',
    'DELIVERY_STATUS': 'Statut de distribution',
    'COMPLETED_ON': 'Complété le',
    'RECORD_CYCLE_DOSE': 'Enregistrer une dose du cycle',
    'INSUFFICIENT_STOCK_TITLE': 'Stock insuffisant',
    'REGISTRATION_CURRENT_DOSE_STATUS_PENDING': 'En attente',
    'REGISTRATION_CURRENT_DOSE_STATUS_ADMINISTERED': 'Administrée',
    'REGISTRATION_CURRENT_DOSE_STATUS_TOBE_ADMINISTERED': 'À administrer',
    'REGISTRATION_PAST_DOSE_STATUS_PENDING': 'En attente',
    'REGISTRATION_PAST_DOSE_STATUS_ADMINISTERED': 'Administrée',
    'REGISTRATION_VIEW_PAST_CYCLES': 'Voir les cycles précédents',
    'REGISTRATION_HIDE_PAST_CYCLES': 'Masquer les cycles précédents',
    'REDOSE_DETAILS_SCREEN_HEADING': 'Détails de la redose',
    'REDOSE_DETAILS_SCREEN_DESCRIPTION':
        'Veuillez saisir les détails de la redose.',
    'REDOSE_DATE_OF_ADMINISTRATION': "Date d'administration",
    'REDOSE_RESOURCE_DELIVERED': 'Ressource distribuée',
    'REDOSE_REASON': 'Motif de la redose',
    'REDOSE_SUBMIT_BUTTON_LABEL': 'Soumettre',
    'REFERRAL_SUCCESSFUL_PANEL_CARD_HEADING':
        'Référence enregistrée avec succès',
    'REFERRAL_SUCCESSFUL_PANEL_CARD_DESC':
        'La référence a été enregistrée avec succès.',
    'REFERRAL_VIEW_HOUSEHOLD_DETAILS': 'Voir les détails du ménage',
    'REFERRAL_BACK': 'Retour',
    'HOUSEHOLD_HEAD_NAME': 'Nom du chef de ménage',
    'HOUSEHOLD_LOCALITY': 'Localité',
    'MEMBER_COUNT': 'Nombre de membres',
    'NO_BENEFICIARY_ID': 'Aucun identifiant bénéficiaire',
    'IS_HEAD': 'Chef de famille',
    'NOT_ELIGIBLE': 'Non éligible',
    'ADMINISTERED_SUCCESS': 'Administré avec succès',
    'REDOSE_COMPLETED': 'Redose effectuée',
    'NOT_VISITED': 'Non visité',
    'DELIVERY': 'Distribution',
    'ADD_MEMBER': 'Ajouter un membre',
    'HOUSEHOLD_BACK': 'Retour',
    'REGISTRATION_HOUSEHOLD_OVERVIEW_HEADING': "Vue d'ensemble du ménage",
    'REGISTRATION_HOUSEHOLD_OVERVIEW_DESC': 'Informations du ménage',
    'UNABLETODELIVERY_FLOW_SCREEN_HEADING': 'Impossible de distribuer',
    'UNABLETODELIVERY_FLOW_DESCRIPTION': 'Veuillez indiquer la raison.',
    'UNABLETODELIVERY_FLOW_reason_LABEL': 'Motif',
    'UNABLETODELIVERY_FLOW_comment_LABEL': 'Commentaire',
    'BENEFICIARY_ABSENT': 'Bénéficiaire absent',
    'BENEFICIARY_REFUSED': 'Bénéficiaire refusé',
    'SIDE_EFFECT': 'Effet secondaire',
    'ADVERSE_EFFECT': 'Effet indésirable',
    'REFERENCE': 'Référence',
    'UNABLETODELIVER_FLOW_ALERT_TITLE': 'Confirmation',
    'UNABLETODELIVER_FLOW_ACTION_SUBMIT': 'Soumettre',
    'UNABLETODELIVER_FLOW_ACTION_CANCEL': 'Annuler',
    'PROXIMITY_SEARCH_REGISTRATION': 'Recherche de proximité',
    'ID_SEARCH_REGISTRATION': 'Recherche par identifiant',
    'ID_OF_INDIVIDUAL': "Identifiant de l'individu",
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_LABEL': 'Filtrer',
    'COMPLAINT_INBOX_HEADING': 'Réclamations',
    'COMPLAINT_INBOX_DESCRIPTION': 'Consultez et gérez les réclamations.',
    'COMPLAINT_INBOX_BACK': 'Retour',
    'COMPLAINT_INBOX_PRIMARY_ACTION': 'Déposer une réclamation',
    'COMPLAINT_INBOX_SEARCH_LABEL': 'Rechercher',
    'COMPLAINT_INBOX_SEARCH_COMPLAINT_NUMBER_LABEL': 'Numéro de réclamation',
    'COMPLAINT_INBOX_SEARCH_MOBILE_NUMBER_LABEL': 'Numéro de téléphone',
    'COMPLAINT_INBOX_SEARCH_PRIMARY_ACTION_LABEL': 'Rechercher',
    'COMPLAINT_INBOX_SEARCH_SECONDARY_ACTION_LABEL': 'Effacer',
    'COMPLAINT_INBOX_FILTER_LABEL': 'Filtrer',
    'COMPLAINT_INBOX_FILTER_COMPLAINT_TYPE_LABEL': 'Type de réclamation',
    'COMPLAINT_INBOX_FILTER_LOCALITY_TYPE_LABEL': 'Localité',
    'COMPLAINT_INBOX_FILTER_PRIMARY_ACTION_LABEL': 'Appliquer',
    'COMPLAINT_INBOX_FILTER_SECONDARY_ACTION_LABEL': 'Effacer',
    'COMPLAINT_INBOX_SORT_LABEL': 'Trier',
    'COMPLAINT_INBOX_SORT_POPUP_LABEL': 'Trier les réclamations',
    'COMPLAINT_INBOX_SORT_LATEST_FIRST': 'Plus récentes en premier',
    'COMPLAINT_INBOX_SORT_LATEST_LAST': 'Plus anciennes en premier',
    'COMPLAINT_INBOX_SORT_PRIMARY_ACTION_LABEL': 'Appliquer',
    'COMPLAINT_INBOX_SORT_SECONDARY_ACTION_LABEL': 'Effacer',
    'ASSIGN_TO_ME': 'Attribuées à moi',
    'ASSIGN_TO_ALL': 'Toutes',
    'COMPLAINT_INBOX_COMPLAINT_NUMBER': 'Numéro de réclamation',
    'COMPLAINT_INBOX_COMPLAINT_TYPE': 'Type de réclamation',
    'COMPLAINT_INBOX_COMPLAINT_DATE': 'Date',
    'COMPLAINT_INBOX_COMPLAINT_AREA': 'Zone',
    'COMPLAINT_INBOX_COMPLAINT_STATUS': 'Statut',
    'COMPLAINT_DETAILS_VIEW_ACTION_LABEL': 'Voir les détails',
    'COMPLAINT_TYPE_HEADING': 'Type de réclamation',
    'COMPLAINT_TYPE_complaintType_LABEL': 'Sélectionnez un type de réclamation',
    'COMPLAINT_TYPE_complaintType_REQUIRED_ERROR':
        'Le type de réclamation est obligatoire.',
    'COMPLAINT_TYPE_otherReason_LABEL': 'Autre motif',
    'COMPLAINT_TYPE_otherReason_REQUIRED_ERROR': 'Veuillez préciser le motif.',
    'APPONE_COMPLAINTTYPE_DESCRIPTION': 'Sélectionnez le type de réclamation.',
    'LOCATION_DETAILS_HEADING': 'Détails de localisation',
    'LOCATION_DETAILS_DESCRIPTION':
        'Fournissez les informations de localisation.',
    'LOCATION_DETAILS_ACTION_LABEL': 'Continuer',
    'COMPLAINT_DETAILS_administrativeArea_LABEL': 'Zone administrative',
    'COMPLAINT_DETAILS_administrativeArea_REQUIRED_ERROR':
        'La zone administrative est obligatoire.',
    'LOCATION_DETAILS_addressLine1_LABEL': 'Adresse ligne 1',
    'LOCATION_DETAILS_addressLine2_LABEL': 'Adresse ligne 2',
    'LOCATION_DETAILS_landmark_LABEL': 'Point de repère',
    'LOCATION_DETAILS_pincode_LABEL': 'Code postal',
    'LOCATION_DETAILS_typeOfAddress_LABEL': 'Type d\'adresse',
    'COMPLAINT_DETAILS_HEADING': 'Détails de la réclamation',
    'COMPLAINT_DETAILS_DESCRIPTION':
        'Fournissez les détails de la réclamation.',
    'COMPLAINT_DETAILS_ACTION_LABEL': 'Soumettre',
    'COMPLAINT_DETAILS_complaintRaisedFor_LABEL': 'Réclamation soumise pour',
    'COMPLAINTFLOW_RAISED_FOR_MYSELF': 'Moi-même',
    'COMPLAINTFLOW_RAISED_FOR_ANOTHER_USER': 'Un autre utilisateur',
    'COMPLAINT_DETAILS_complaintRaisedFor_REQUIRED_ERROR':
        'Veuillez sélectionner une option.',
    'COMPLAINT_DETAILS_name_LABEL': 'Nom',
    'COMPLAINT_DETAILS_name_REQUIRED_ERROR': 'Le nom est obligatoire.',
    'COMPLAINT_DETAILS_name_LABEL_MIN_VALIDATION':
        'Le nom doit comporter au moins 2 caractères.',
    'COMPLAINT_DETAILS_name_LABEL_MAX_VALIDATION':
        'Le nom ne peut pas dépasser 63 caractères.',
    'COMPLAINT_DETAILS_name_LABEL_PATTERN_VALIDATION':
        'Le nom contient des caractères non valides.',
    'COMPLAINT_DETAILS_contactNumber_LABEL': 'Numéro de téléphone',
    'COMPLAINT_DETAILS_contactNumber_REQUIRED_ERROR':
        'Le numéro de téléphone est obligatoire.',
    'COMPLAINT_DETAILS_supervisorName_LABEL': 'Nom du superviseur',
    'SUPERVISOR_name_LABEL_MIN_VALIDATION':
        'Le nom du superviseur doit comporter au moins 2 caractères.',
    'SUPERVISOR_DETAILS_name_LABEL_MAX_VALIDATION':
        'Le nom du superviseur ne peut pas dépasser 63 caractères.',
    'SUPERVISOR_DETAILS_name_LABEL_PATTERN_VALIDATION':
        'Le nom du superviseur contient des caractères non valides.',
    'COMPLAINT_DETAILS_supervisorContactNumber_LABEL': 'Numéro du superviseur',
    'COMPLAINT_DETAILS_complaintDescription_LABEL':
        'Description de la réclamation',
    'COMPLAINT_DETAILS_complaintDescription_REQUIRED_ERROR':
        'La description de la réclamation est obligatoire.',
    'COMPLAINT_ACKNOWLEDGEMENT_SUCCESS_PANEL_CARD_LABEL':
        'Réclamation enregistrée avec succès',
    'COMPLAINT_ACKNOWLEDGEMENT_SUCCESS_PANEL_CARD_DESCRIPTION':
        'Votre réclamation a été soumise avec succès.',
    'COMPLAINT_ACKNOWLEDGEMENT_SUCCESS_PANEL_CARD_ACTION_LABEL':
        'Retour aux réclamations',
    'COMPLAINT_VIEW_HEADING': 'Détails de la réclamation',
    'COMPLAINT_VIEW_COMPLAINTS_NUMBER': 'Numéro de réclamation',
    'COMPLAINT_VIEW_COMPLAINTS_TYPE': 'Type de réclamation',
    'COMPLAINT_VIEW_COMPLAINTS_DATE': 'Date',
    'COMPLAINT_VIEW_COMPLAINTS_AREA': 'Zone',
    'COMPLAINT_VIEW_COMPLAINANT_CONTACT': 'Téléphone du déclarant',
    'COMPLAINT_VIEW_COMPLAINT_STATUS': 'Statut',
    'COMPLAINT_VIEW_COMPLAINT_DESCRIPTION': 'Description',
    'COMPLAINT_VIEW_ACTION_LABEL': 'Fermer',
    'SUMMARY_REPORT_HEADING': 'Rapport récapitulatif',
    'SUMMARY_REPORT_DESCRIPTION':
        'Consultez les ménages enregistrés, les bénéficiaires traités et les mouvements de stock par date.',
    'SUMMARY_REPORT_INFO_TITLE': 'Informations',
    'SUMMARY_REPORT_INFO_DESCRIPTION':
        'Ce rapport présente un résumé quotidien des enregistrements, des traitements effectués et de l\'utilisation des stocks.',
    'SUMMARY_REPORT_DATE': 'Date',
    'SUMMARY_REPORT_HOUSEHOLDS_REGISTERED': 'Ménages enregistrés',
    'SUMMARY_REPORT_CHILDREN_TREATED': 'Enfants traités',
    'SUMMARY_REPORT_CHILDREN_TREATED_PERCENT': 'Pourcentage d\'enfants traités',
    'SUMMARY_REPORT_BACK_TO_HOME': 'Retour à l\'accueil',
    'SUMMARY_REPORT_STOCK_RECEIVED': 'Stock reçu',
    'SUMMARY_REPORT_STOCK_CONSUMED': 'Stock consommé',
    'SUMMARY_REPORT_STOCK_RETURNED': 'Stock retourné',
    'SUMMARY_REPORT_STOCK_BALANCE': 'Solde du stock',
    'NON_MOBILE_USER_LABEL': 'Utilisateur sans appareil mobile',
    'NON_MOBILE_USER_QR_BTN_LABEL': 'Afficher le code QR',
    'NON_MOBILE_USER_QR_LABEL':
        'Scannez ce code QR pour accéder à l\'application',
    'DATABASE_ERROR_TITLE': 'Erreur de base de données',
    'DATABASE_ERROR_MESSAGE':
        'Une erreur est survenue lors de l\'accès à la base de données. Veuillez réessayer.',
    'DATABASE_ERROR_CLOSE_APP': 'Fermer l\'application',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_HEADING': 'Clôture du ménage',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_DESCRIPTION':
        'Veuillez confirmer les informations du ménage avant sa clôture.',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_administrativeArea_LABEL':
        'Zone administrative',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_administrativearea_help_text':
        'Sélectionnez la zone administrative du ménage.',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_latLng_LABEL':
        'Précision des coordonnées GPS',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_headName_LABEL':
        'Nom du chef de ménage',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDDETAILS_ACTION_LABEL': 'Soumettre',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_HEADING':
        'Ménage clôturé avec succès',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_DESCRIPTION':
        'Le ménage a été clôturé avec succès.',
    'CLOSEHOUSEHOLD_CLOSEHOUSEHOLDSUCCESS_ACTION_LABEL':
        'Voir les détails du ménage',
    'SYNC_DIALOG_NO_DATA_TO_SYNC_TITLE': 'Aucune donnée à synchronizer',
    'CORE_COMMON_MAX_BOUNDARY_SELECTION_REACHED':
        'Sélection de zone maximale atteinte',
    'MOBILE_NUMBER_8_DIGIT_ERROR':
        'Le numéro de téléphone doit comporter 8 chiffres',
    'APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_HEADING':
        'Détails de la distribution',
    'APPONE_REGISTRATION_DELIVERYDETAILS_ACTION_BUTTON_LABEL_1': 'Suivant',
    'APPONE_REGISTRATION_DELIVERYDETAILS_label_dateOfDelivery':
        'Date de distribution',
    'APPONE_REGISTRATION_DELIVERYDETAILS_label_resource':
        'Ressource distribuée',
    'APPONE_REGISTRATION_DELIVERYDETAILS_label_scanner':
        'Scanner le code-barres',
    'APPONE_REGISTRATION_DELIVERYDETAILS_SCREEN_DESCRIPTION':
        'Veuillez saisir les détails de la distribution.',
    'ADMIN_Ward': 'Quartier',
    'ADMIN_Health Facility': 'Établissement de santé',
    'ADMIN_Community': 'Communauté',
    'APPONE_REGISTRATION_BENEFICIARYDETAILS_label_deliveryComments':
        'Commentaires de distribution',
    'CORE_COMMON_QUANTITY_DISTRIBUTED': 'Quantité distribuée',
    'MOBILE_LENGTH_8_DIGIT_ERROR': 'Le numéro de téléphone doit comporter 8 chiffres',

  };

  static LocalizationsDelegate<DashboardLocalization> getDelegate(
          Future<dynamic> localizedStrings, List<dynamic> languages) =>
      DashboardLocalizationDelegate(localizedStrings, languages);

  // Method to load localized strings
  Future<bool> load() async {
    _localizedStrings.clear();
    // Iterate over localized strings and filter based on locale
    for (var element in await localizedStrings) {
      if (element.locale == '${locale.languageCode}_${locale.countryCode}') {
        _localizedStrings.add(element);
      }
    }

    return true;
  }

  // Method to translate a given localized value
  String translate(String localizedValues) {
    if (_hardcodedFallbacks.containsKey(localizedValues)) {
      return _hardcodedFallbacks[localizedValues]!;
    }

    if (_localizedStrings.isEmpty) {
      return localizedValues;
    } else {
      final index = _localizedStrings.indexWhere(
        (medium) => medium.code == localizedValues,
      );

      return index != -1 &&
              _localizedStrings[index].message != null &&
              _localizedStrings[index].message.toString().isNotEmpty
          ? _localizedStrings[index].message
          : localizedValues;
    }
  }
}
