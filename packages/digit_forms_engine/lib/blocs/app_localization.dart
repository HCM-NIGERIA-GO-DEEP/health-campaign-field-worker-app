import 'package:flutter/material.dart';

import 'localization_delegates.dart';


// Class responsible for handling attendance localization
class FormLocalization {
  final Locale locale;
  final Future<dynamic> localizedStrings;
  final List<dynamic> languages;

  FormLocalization(this.locale, this.localizedStrings, this.languages);

  // Method to get the current localization instance from context
  static FormLocalization of(BuildContext context) {
    return Localizations.of<FormLocalization>(context, FormLocalization)!;
  }

  static final List<dynamic> _localizedStrings = <dynamic>[];
  // O(1) lookup index (code -> message), rebuilt on each load(); avoids an
  // O(n) linear scan per translate over a large localization set.
  static final Map<String, String> _localizedMap = <String, String>{};

  // Method to get the delegate for localization
  static LocalizationsDelegate<FormLocalization> getDelegate(
      Future<dynamic> localizedStrings, List<dynamic> languages) =>
      FormLocalizationDelegate(localizedStrings, languages);

  // Method to load localized strings
  Future<bool> load() async {
    // Build the new lists first and swap them in afterwards. Clearing the
    // shared lists before awaiting the rows left them empty for the whole
    // read, so any form drawn meanwhile showed raw keys.
    final rows = await localizedStrings;
    final strings = <dynamic>[];
    final map = <String, String>{};
    // Iterate over localized strings and filter based on locale
    for (var element in rows) {
      if (element.locale == '${locale.languageCode}_${locale.countryCode}') {
        strings.add(element);
        final code = element.code as String;
        final message = element.message as String;
        // Rows arrive from every module at once in no guaranteed order, and
        // this map is keyed by code alone - so a code defined in two modules
        // resolves to whichever row is read last. An empty message carries no
        // information and must never displace one that has text (see the
        // matching comment in the app's AppLocalizations.load).
        if (message.trim().isEmpty && (map[code]?.trim().isNotEmpty ?? false)) {
          continue;
        }
        map[code] = message;
      }
    }

    _localizedStrings
      ..clear()
      ..addAll(strings);
    _localizedMap
      ..clear()
      ..addAll(map);
    return true;
  }

  // Method to translate a given localized value
  String translate(String localizedValues) {
    return _localizedMap[localizedValues] ?? localizedValues;
  }
}
