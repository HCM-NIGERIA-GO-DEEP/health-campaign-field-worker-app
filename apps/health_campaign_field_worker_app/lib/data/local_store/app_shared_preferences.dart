import 'package:shared_preferences/shared_preferences.dart';

class AppSharedPreferences {
  static const String isFirstLaunchKey = 'isFirstLaunch';
  static const String userSelectedLocale = 'userSelectedLocale';

  // The MDMS app config for the `ba` tenant declares the language locale as
  // `en_MZ`, but the server stores all localization data under `en_NG`. Every
  // consumer of the selected locale (flow builder, boundary selection, app
  // localization) must use the locale the data actually lives under, otherwise
  // localized lookups miss and raw keys are shown. Normalize at this single
  // chokepoint so reads/writes are always consistent with the stored data.
  static const Map<String, String> _localeAliases = {'en_MZ': 'en_NG'};

  static String _resolveLocale(String locale) =>
      _localeAliases[locale] ?? locale;

  SharedPreferences? _sharedPreferences;

  SharedPreferences get sharedPreferences {
    if (_sharedPreferences == null) {
      throw Exception('SharedPreferences not initialized');
    }

    return _sharedPreferences!;
  }

  static final AppSharedPreferences _instance =
      AppSharedPreferences._internal();

  factory AppSharedPreferences() {
    return _instance;
  }

  AppSharedPreferences._internal();

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  bool get isFirstLaunch => sharedPreferences.getBool(isFirstLaunchKey) ?? true;

  String? get getSelectedLocale {
    final stored = sharedPreferences.getString(userSelectedLocale);
    return stored != null ? _resolveLocale(stored) : null;
  }

  Future<void> appLaunchedFirstTime() async {
    await sharedPreferences.setBool(
      isFirstLaunchKey,
      false,
    );
  }

  Future<void> setSelectedLocale(String localeString) async {
    await sharedPreferences.setString(
      userSelectedLocale,
      _resolveLocale(localeString),
    );
  }
}
