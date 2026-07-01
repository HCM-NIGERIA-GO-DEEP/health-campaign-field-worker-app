class CddUser {
  final String name;
  final String username;

  /// The user's UUID. Used to build a value that matches the scanned
  /// deliveryTeamCode format so a CDD user picked from the dropdown is
  /// interchangeable with a scanned team code.
  final String userId;

  const CddUser({
    required this.name,
    required this.username,
    required this.userId,
  });

  /// Value written into the `deliveryTeam` form control when this user is
  /// selected from the dropdown. Mirrors the scanned QR format
  /// (`<name>||<userId>`); downstream `getTeamCode()` splits on `||` and uses
  /// the userId as the stock sender/receiver id.
  String get deliveryTeamCode => '$name||$userId';
}

class HFReferralCddSingleton {
  static final HFReferralCddSingleton _singleton =
      HFReferralCddSingleton._internal();

  factory HFReferralCddSingleton() => _singleton;

  HFReferralCddSingleton._internal();

  List<CddUser> _cddUsers = [];

  void setCddUsers(List<CddUser> users) {
    _cddUsers = users;
  }

  List<CddUser> get cddUsers => _cddUsers;
}
