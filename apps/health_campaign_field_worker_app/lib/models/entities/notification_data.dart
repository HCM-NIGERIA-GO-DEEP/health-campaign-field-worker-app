enum NotificationType {
  stockSync,
  hfReferralSync;

  static NotificationType? fromValue(String? value) {
    switch (value) {
      case 'stock_sync':
        return NotificationType.stockSync;
      case 'hf_referral_sync':
        return NotificationType.hfReferralSync;
      default:
        return null;
    }
  }

  String toValue() {
    switch (this) {
      case NotificationType.stockSync:
        return 'stock_sync';
      case NotificationType.hfReferralSync:
        return 'hf_referral_sync';
    }
  }
}

enum NotificationScreenName {
  home,
  profile,
  boundarySelection;

  static NotificationScreenName? fromValue(String? value) {
    switch (value) {
      case 'home':
        return NotificationScreenName.home;
      case 'profile':
        return NotificationScreenName.profile;
      case 'boundary_selection':
        return NotificationScreenName.boundarySelection;
      default:
        return null;
    }
  }

  String toValue() {
    switch (this) {
      case NotificationScreenName.home:
        return 'home';
      case NotificationScreenName.profile:
        return 'profile';
      case NotificationScreenName.boundarySelection:
        return 'boundary_selection';
    }
  }
}

class NotificationData {
  final NotificationScreenName screenName;
  final NotificationType? notificationType;

  const NotificationData({
    required this.screenName,
    this.notificationType,
  });

  factory NotificationData.fromMap(Map<String, dynamic> data) {
    return NotificationData(
      screenName: NotificationScreenName.fromValue(data['screen']) ??
          NotificationScreenName.home,
      notificationType: NotificationType.fromValue(data['notificationType']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'screen': screenName.toValue(),
      if (notificationType != null)
        'notificationType': notificationType!.toValue(),
    };
  }
}
