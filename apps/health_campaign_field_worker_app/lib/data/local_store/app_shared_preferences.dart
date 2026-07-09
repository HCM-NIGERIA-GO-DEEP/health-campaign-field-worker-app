import 'package:shared_preferences/shared_preferences.dart';

class AppSharedPreferences {
  static const String isFirstLaunchKey = 'isFirstLaunch';
  static const String userSelectedLocale = 'userSelectedLocale';
  static const String showPrivacyNoticeAfterLoginKey =
      'showPrivacyNoticeAfterLogin';

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

  Future<SharedPreferences> _ensureInstance() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  bool get isFirstLaunch => sharedPreferences.getBool(isFirstLaunchKey) ?? true;

  String? get getSelectedLocale =>
      sharedPreferences.getString(userSelectedLocale);

  bool get shouldShowPrivacyNoticeAfterLogin =>
      sharedPreferences.getBool(showPrivacyNoticeAfterLoginKey) ?? false;

  Future<bool> shouldShowPrivacyNoticeAfterLoginAsync() async {
    final prefs = await _ensureInstance();
    return prefs.getBool(showPrivacyNoticeAfterLoginKey) ?? false;
  }

  Future<bool> consumeShowPrivacyNoticeAfterLogin() async {
    final prefs = await _ensureInstance();
    final shouldShow = prefs.getBool(showPrivacyNoticeAfterLoginKey) ?? false;

    if (shouldShow) {
      await prefs.setBool(showPrivacyNoticeAfterLoginKey, false);
    }

    return shouldShow;
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
      localeString,
    );
  }

  Future<void> setShowPrivacyNoticeAfterLogin(bool value) async {
    final prefs = await _ensureInstance();
    await prefs.setBool(showPrivacyNoticeAfterLoginKey, value);
  }
}
