import 'package:flutter/services.dart';

/// The one place this channel name is written on the Dart side.
///
/// Must stay in sync with `SecurityHelper.CHANNEL` in
/// `android/app/src/main/kotlin/com/digit/hcm/SecurityHelper.kt`.
const MethodChannel securityChannel = MethodChannel('com.digit.hcm/security');
