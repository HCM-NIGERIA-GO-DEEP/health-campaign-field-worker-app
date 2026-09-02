/// The individually selectable security mitigations.
///
/// Not all are enforceable at runtime. Selecting a build-time feature is a
/// *declaration of intent* that `BuildConfigurationAudit` checks against the
/// shipped APK — no Dart flag can switch on obfuscation or rewrite the
/// manifest. See [AppSecurityFeatureInfo.isRuntimeEnforced].
enum AppSecurityFeature {
  // ---- Runtime enforced -------------------------------------------------

  /// Pin TLS connections to the bundled certificate.
  sslPinning,

  /// Root / jailbreak detection (library check plus native `su` probing).
  rootDetection,

  /// Emulator detection.
  emulatorDetection,

  /// Hooking framework detection (Frida, Xposed, Substrate).
  hookDetection,

  /// Attached-debugger detection.
  debuggerDetection,

  /// Repackaging detection via signing certificate comparison. Inert until an
  /// expected signature is supplied.
  repackagingDetection,

  /// Silence `debugPrint` in non-debug builds so release logs leak nothing.
  debugPrintSuppression,

  // ---- Build-time: declared here, verified, never enforced from Dart ----

  /// R8 obfuscation and resource shrinking, from the app module's release
  /// build type (`minifyEnabled` / `shrinkResources`).
  codeObfuscation,

  /// Non-exported components and receivers, from `AndroidManifest.xml`
  /// (`android:exported`, `tools:replace`) and `registerReceiver` flags.
  broadcastReceiverHardening,

  /// `android:allowBackup="false"`, the cleartext-blocking network security
  /// config, and encrypted local storage.
  platformUsageHardening,
}

/// Features no runtime flag can switch on, because the APK decides them.
const Set<AppSecurityFeature> buildTimeFeatures = {
  AppSecurityFeature.codeObfuscation,
  AppSecurityFeature.broadcastReceiverHardening,
  AppSecurityFeature.platformUsageHardening,
};

/// The device-integrity checks, i.e. those driven by `DeviceIntegrityService`.
const Set<AppSecurityFeature> deviceIntegrityFeatures = {
  AppSecurityFeature.rootDetection,
  AppSecurityFeature.emulatorDetection,
  AppSecurityFeature.hookDetection,
  AppSecurityFeature.debuggerDetection,
  AppSecurityFeature.repackagingDetection,
};

extension AppSecurityFeatureInfo on AppSecurityFeature {
  /// Whether toggling this actually changes runtime behaviour.
  ///
  /// `false` means the mitigation is decided at build time and the flag only
  /// controls whether it gets *verified*.
  bool get isRuntimeEnforced => !buildTimeFeatures.contains(this);

  /// Human-readable name, used in audit output.
  String get label {
    switch (this) {
      case AppSecurityFeature.sslPinning:
        return 'SSL Pinning';
      case AppSecurityFeature.rootDetection:
        return 'Root Detection';
      case AppSecurityFeature.emulatorDetection:
        return 'Emulator Detection';
      case AppSecurityFeature.hookDetection:
        return 'Hooking Framework Detection';
      case AppSecurityFeature.debuggerDetection:
        return 'Debugger Detection';
      case AppSecurityFeature.repackagingDetection:
        return 'Repackaging Detection';
      case AppSecurityFeature.debugPrintSuppression:
        return 'Release Log Suppression';
      case AppSecurityFeature.codeObfuscation:
        return 'Code Obfuscation';
      case AppSecurityFeature.broadcastReceiverHardening:
        return 'Insecure Broadcast Receiver Mitigation';
      case AppSecurityFeature.platformUsageHardening:
        return 'Improper Platform Usage Mitigation';
    }
  }
}
