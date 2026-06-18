import 'package:shared_preferences/shared_preferences.dart';

class AppSharedPreferences {
  static const String isFirstLaunchKey = 'isFirstLaunch';
  static const String userSelectedLocale = 'userSelectedLocale';

  // The MDMS app config for the `ba` tenant declares the language locale as
  // `en_NG`, and the bauchi server stores all localization data under `en_NG`
  // too, so no normalization is needed. This alias map is kept as the single
  // chokepoint for any future locale remapping; leave it empty for an identity
  // mapping so every consumer reads the locale the data actually lives under.
  static const Map<String, String> _localeAliases = <String, String>{};

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
