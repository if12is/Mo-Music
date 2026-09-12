import 'package:flutter/material.dart';

/// User-facing Mo Music identity. Internal Dart package names stay stable
/// so existing imports and JNI bindings keep working.
class AppIdentity {
  static const String appName = 'Mo Music';
  static const String appNameAr = 'مو ميوزك';
  static const String shortName = 'Mo';
  static const String defaultLanguageCode = 'ar';
  static const String githubOwner = 'if12is';
  static const String githubRepo = 'Mo-Music';
  static const String githubSlug = '$githubOwner/$githubRepo';
  static const String githubUrl = 'https://github.com/$githubSlug';
  static const String latestReleaseUrl = '$githubUrl/releases/latest';
  static const String latestDownloadBase =
      '$githubUrl/releases/latest/download/';
  static const String tagsApiUrl =
      'https://api.github.com/repos/$githubSlug/tags';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/$githubSlug/releases/latest';
  static const String updateManifestUrl =
      'https://raw.githubusercontent.com/$githubSlug/dev/distribution/update-check.json';
  static const String artifactPrefix = 'MoMusic';
  static const String androidApplicationId = 'com.if12is.momusic';
  static const String urlScheme = 'momusic';
  static const String userAgent = 'MoMusic/2.5.0';
  static const String homepage = githubUrl;
  static const String developerName = 'Ahmed Elsayed';

  /// Sampled from the official logo background.
  static const Color brandBlue = Color(0xFF3332CE);
  static const Color brandBlueDeep = Color(0xFF1E1B8A);
  static const Color brandBlueSoft = Color(0xFF5A59E6);

  static String localizedName([String? languageCode]) {
    final code = (languageCode ?? defaultLanguageCode).toLowerCase();
    return code.startsWith('ar') ? appNameAr : appName;
  }

  static String androidApkName({bool universal = true}) =>
      universal ? '$artifactPrefix-android-universal.apk' : '$artifactPrefix-android.apk';

  static String windowsInstallerName() => '$artifactPrefix-windows-installer.exe';

  static String linuxTarballName() => '$artifactPrefix-linux-x64.tar.gz';

  static String macosZipName() => '$artifactPrefix-macos.zip';

  static String iosIpaName() => '$artifactPrefix-ios-unsigned.ipa';
}
