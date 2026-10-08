import 'dart:io';

/// Central place for platform gating.
///
/// Current tier:
///   Tier 1 (working now): Linux, Android
///   Tier 2 (planned): macOS, Windows
class PlatformInfo {
  const PlatformInfo._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isLinux => Platform.isLinux;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;

  /// True when the platform has a real native DSP path wired in.
  /// Today: none — [MockEqEngine] is used everywhere. Flip per-platform
  /// as native engines land.
  static bool get hasNativeDsp => false;

  static String get label {
    if (isAndroid) return 'Android';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS (planned)';
    if (isWindows) return 'Windows (planned)';
    return Platform.operatingSystem;
  }
}
