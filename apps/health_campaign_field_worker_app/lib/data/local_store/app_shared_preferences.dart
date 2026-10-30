import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSharedPreferences {
  static const String isFirstLaunchKey = 'isFirstLaunch';
  static const String userSelectedLocale = 'userSelectedLocale';

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

  int? getStockDownsyncTime(String key) => sharedPreferences.getInt(key);

  Future<void> setStockDownsyncTime(String key, int value) async {
    await sharedPreferences.setInt(key, value);
  }

  String _beneficiaryKey(String scope, String code, String kind) =>
      'beneficiary_${kind}_${Uri.encodeComponent(scope)}_${Uri.encodeComponent(code)}';

  int? getBoundaryNumericId(String scope, String code) =>
      sharedPreferences.getInt(_beneficiaryKey(scope, code, 'prefix'));

  Future<void> setBoundaryNumericId(
      String scope, String code, int value) async {
    await (await _ensureInstance())
        .setInt(_beneficiaryKey(scope, code, 'prefix'), value);
  }

  Map<String, String>? getBeneficiaryDistributionPoint(
      String scope, String code) {
    final value =
        sharedPreferences.getString(_beneficiaryKey(scope, code, 'dp'));
    if (value == null) return null;
    try {
      return Map<String, String>.from(jsonDecode(value) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBeneficiaryDistributionPoint(
      String scope, String code, Map<String, String> value) async {
    await (await _ensureInstance())
        .setString(_beneficiaryKey(scope, code, 'dp'), jsonEncode(value));
  }
}
