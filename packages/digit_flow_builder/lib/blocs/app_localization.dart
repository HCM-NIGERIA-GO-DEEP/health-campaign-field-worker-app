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
  // O(1) lookup index (code -> message), rebuilt on each load(); avoids an
  // O(n) linear scan per translate over a large localization set.
  static final Map<String, String> _localizedMap = <String, String>{};

  // Method to get the delegate for localization
  static LocalizationsDelegate<FlowBuilderLocalization> getDelegate(
          Future<dynamic> localizedStrings, List<dynamic> languages) =>
      FlowBuilderLocalizationDelegate(localizedStrings, languages);

  // Method to load localized strings
  Future<bool> load() async {
    _localizedStrings.clear();
    _localizedMap.clear();
    // Iterate over localized strings and filter based on locale
    for (var element in await localizedStrings) {
      if (element.locale == '${locale.languageCode}_${locale.countryCode}') {
        _localizedStrings.add(element);
        _localizedMap[element.code as String] = element.message as String;
      }
    }

    return true;
  }

  // Method to translate a given localized value
  String translate(String localizedValues) {
    return _localizedMap[localizedValues] ?? localizedValues;
  }
}
