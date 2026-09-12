import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:estrella_music/app_identity.dart';

class UpdateService {
  static Future<bool> checkForUpdate() async {
    try {
      final latestVersion = await fetchLatestVersion();
      if (latestVersion == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (kDebugMode) {
        print(
            "Checking updates: Latest=$latestVersion, Current=$currentVersion");
      }

      return _isVersionGreater(latestVersion, currentVersion);
    } catch (e) {
      if (kDebugMode) print("Error checking updates: $e");
      return false;
    }
  }

  /// Prefers UPDATE_CHECK_URL, then the committed repo manifest, then GitHub
  /// tags on if12is/Mo-Music — never the upstream Estrella Music fork.
  static Future<String?> fetchLatestVersion() async {
    final dio = Dio();
    final candidates = <String>{
      if ((dotenv.env['UPDATE_CHECK_URL'] ?? '').trim().isNotEmpty)
        dotenv.env['UPDATE_CHECK_URL']!.trim(),
      AppIdentity.updateManifestUrl,
      AppIdentity.latestReleaseApiUrl,
      AppIdentity.tagsApiUrl,
    };

    for (final url in candidates) {
      try {
        final response = await dio.get(url);
        if (response.statusCode != 200) continue;
        final version = _extractVersion(response.data);
        if (version != null && version.isNotEmpty) return version;
      } catch (e) {
        if (kDebugMode) print("Update source failed ($url): $e");
      }
    }
    return null;
  }

  static String? _extractVersion(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in const ['Version', 'version', 'tag_name', 'name']) {
        final value = map[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value.replaceFirst(RegExp(r'^[vV]'), '');
        }
      }
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      final value = (data.first as Map)['name']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value.replaceFirst(RegExp(r'^[vV]'), '');
      }
    }
    return null;
  }

  static bool _isVersionGreater(String latestVersion, String currentVersion) {
    List<String> latestParts =
        latestVersion.toLowerCase().replaceAll('v', '').split('.');
    List<String> currentParts =
        currentVersion.toLowerCase().replaceAll('v', '').split('.');

    while (latestParts.length < currentParts.length) {
      latestParts.add('0');
    }
    while (currentParts.length < latestParts.length) {
      currentParts.add('0');
    }

    for (int i = 0; i < latestParts.length; i++) {
      int latestPart =
          int.tryParse(latestParts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int currentPart =
          int.tryParse(currentParts[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }
}
