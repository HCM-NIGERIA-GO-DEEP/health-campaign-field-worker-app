import 'package:flutter/material.dart';

import 'localization_delegates.dart';

// Class responsible for handling attendance localization
class FlowBuilderLocalization {
  final Locale locale;
  final Future<dynamic> localizedStrings;
  final List<dynamic> languages;

  FlowBuilderLocalization(this.locale, this.localizedStrings, this.languages);

  // Method to get the current localization instance from context
  static FlowBuilderLocalization of(BuildContext context) {
    return Localizations.of<FlowBuilderLocalization>(
        context, FlowBuilderLocalization)!;
  }

  static final List<dynamic> _localizedStrings = <dynamic>[];

  static const Map<String, String> _hardcodedFallbacks = {
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_TITLE_LABEL': 'Filtre',
    'REGISTRATION_BENEFICIARY_REFERRED': 'bénéficiaire orienté',
    'REGISTRATION_ADMINISTRATION_SUCCESS': 'administrer',
    'REGISTRATION_INELIGIBLE': 'Bénéficiaire inéligible',
    'REGISTRATION_CLOSED_HOUSEHOLD': 'foyer fermé',
    'REGISTRATION_NOT_ADMINISTERED': 'non administré',
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_CLEAR_LABEL': 'effacer',
    'REGISTRATION_SEARCH_BENEFICIARY_FILTER_FILTER_LABEL': 'appliquer',
    'APPONE_REGISTRATION_BENEFICIARYLOCATION_label_administrativeArea_helpText':
        'zone administrative',
    'APPONE_REGISTRATION_BENEFICIARYLOCATION_label_latlong_helpText': ' ',
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
    'REDOSE_ADMINISTRATION': 'administrer une nouvelle dose',
    'REGISTRATION_VIEW_DETAILS': 'Voir les informations enregistrées',
    'REGISTRATION_EDIT_INDIVIDUAL_BUTTON_LABEL': "Modifier l'individu",
    'GENDER': 'genre',
    'AGE_OF_BENEFICIARY': 'âge',
  };

  // Method to get the delegate for localization
  static LocalizationsDelegate<FlowBuilderLocalization> getDelegate(
          Future<dynamic> localizedStrings, List<dynamic> languages) =>
      FlowBuilderLocalizationDelegate(localizedStrings, languages);

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

  String translate(String localizedValues) {
    if (_localizedStrings.isEmpty) {
      return _hardcodedFallbacks[localizedValues] ?? localizedValues;
    } else {
      final index = _localizedStrings.indexWhere(
        (medium) => medium.code == localizedValues,
      );

      return index != -1 
          ? _localizedStrings[index].message 
          : (_hardcodedFallbacks[localizedValues] ?? localizedValues);
    }
  }
}
