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

  /// Stored as a String so a zero-padded prefix keeps the width the backend
  /// issued ("0255", not 255).
  ///
  /// setInt/getInt normalised the padding away, which would have undone the
  /// String handling in BoundaryBeneficiaryIdMap one layer further down - the
  /// map parsed "0255" correctly and the cache then wrote 255 back.
  String? getBoundaryNumericId(String scope, String code) {
    final key = _beneficiaryKey(scope, code, 'prefix');
    try {
      return sharedPreferences.getString(key);
    } on TypeError {
      // An install from before this change still holds an int under this key,
      // and getString throws on the type mismatch rather than returning null.
      // Treat it as absent: it is then re-fetched and rewritten as a String,
      // and the un-padded int was the wrong value to begin with.
      return null;
    }
  }

  Future<void> setBoundaryNumericId(
      String scope, String code, String value) async {
    await (await _ensureInstance())
        .setString(_beneficiaryKey(scope, code, 'prefix'), value);
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
