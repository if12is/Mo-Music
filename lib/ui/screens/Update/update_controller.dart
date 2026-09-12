import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/services/system/update_service.dart';

enum DownloadState { idle, downloading, done, installing, error }

class UpdateController extends GetxController {
  final updateInfo = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;
  final error = ''.obs;
  final currentVersion = ''.obs;

  final downloadProgress = 0.0.obs;
  final downloadedBytes = 0.obs;
  final totalBytes = 0.obs;
  final downloadState = DownloadState.idle.obs;
  final downloadError = ''.obs;

  String? _localFilePath;
  CancelToken? _cancelToken;

  final _notifications = FlutterLocalNotificationsPlugin();

  String get latestVersion =>
      updateInfo.value?['Version']?.toString() ?? '';

  String get notes {
    final raw = updateInfo.value?['Notas']?.toString() ?? '';
    return raw.trim();
  }

  bool get canInstallInApp =>
      GetPlatform.isAndroid || GetPlatform.isWindows;

  bool get canOpenDownloadedFile =>
      _localFilePath != null && File(_localFilePath!).existsSync();

  String get progressLabel {
    if (totalBytes.value > 0) {
      return '${_formatBytes(downloadedBytes.value)} / ${_formatBytes(totalBytes.value)}';
    }
    if (downloadedBytes.value > 0) {
      return _formatBytes(downloadedBytes.value);
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    _initNotifications();
    fetchUpdateInfo();
  }

  @override
  void onClose() {
    _cancelToken?.cancel();
    super.onClose();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );
    await _notifications.initialize(initSettings);
  }

  Future<void> fetchUpdateInfo() async {
    try {
      isLoading(true);
      error('');
      final package = await PackageInfo.fromPlatform();
      currentVersion.value = package.version;

      final info = await _loadUpdateInfo();
      if (info == null) {
        error(S.current.updateCheckUnavailable);
        return;
      }
      updateInfo.value = info;
    } catch (e) {
      error(S.current.updateDownloadFailed);
    } finally {
      isLoading(false);
    }
  }

  Future<Map<String, dynamic>?> _loadUpdateInfo() async {
    final dio = Dio(
      BaseOptions(
        followRedirects: true,
        headers: {'user-agent': AppIdentity.userAgent},
      ),
    );
    final candidates = <String>{
      if ((dotenv.env['UPDATE_CHECK_URL'] ?? '').trim().isNotEmpty)
        dotenv.env['UPDATE_CHECK_URL']!.trim(),
      AppIdentity.updateManifestUrl,
      AppIdentity.latestReleaseApiUrl,
    };

    for (final url in candidates) {
      try {
        final response = await dio.get(url);
        if (response.statusCode != 200) continue;
        final data = response.data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final version = map['Version'] ??
              map['version'] ??
              map['tag_name'] ??
              map['name'];
          if (version == null) continue;
          return {
            'Version': version.toString().replaceFirst(RegExp(r'^[vV]'), ''),
            'Descarga': map['Descarga'] ?? AppIdentity.latestDownloadBase,
            'Notas': (map['Notas'] ?? map['body'] ?? '').toString(),
          };
        }
      } catch (_) {}
    }

    final latest = await UpdateService.fetchLatestVersion();
    if (latest == null) return null;
    return {
      'Version': latest,
      'Descarga': AppIdentity.latestDownloadBase,
      'Notas': '',
    };
  }

  List<String> get _wantedAssetNames {
    if (GetPlatform.isAndroid) {
      return [
        AppIdentity.androidApkName(),
        'app-release.apk',
        AppIdentity.androidApkName(universal: false),
      ];
    }
    if (GetPlatform.isWindows) {
      return [
        AppIdentity.windowsInstallerName(),
        'MoMusicInstaller.exe',
      ];
    }
    if (GetPlatform.isLinux) {
      return [
        AppIdentity.linuxTarballName(),
        'MoMusic_Linux_Portable.tar.gz',
      ];
    }
    if (GetPlatform.isMacOS) {
      return [
        AppIdentity.macosZipName(),
        'MoMusic_macOS_Portable.zip',
      ];
    }
    if (GetPlatform.isIOS) {
      return [
        AppIdentity.iosIpaName(),
        'MoMusic.ipa',
      ];
    }
    return const [];
  }

  List<String> get platformDownloadUrls {
    final names = _wantedAssetNames;
    if (names.isEmpty) return const [];

    final bases = <String>{
      if (latestVersion.isNotEmpty)
        AppIdentity.releaseDownloadBase(latestVersion),
      AppIdentity.latestDownloadBase,
    };
    final extracted =
        _extractDownloadBase(updateInfo.value?['Descarga'] as String?);
    if (extracted != null && extracted.isNotEmpty) {
      bases.add(extracted);
    }

    return [
      for (final base in bases)
        for (final name in names) '$base$name',
    ];
  }

  String get platformFileName {
    if (GetPlatform.isAndroid) return AppIdentity.androidApkName();
    if (GetPlatform.isWindows) return AppIdentity.windowsInstallerName();
    if (GetPlatform.isLinux) return AppIdentity.linuxTarballName();
    if (GetPlatform.isMacOS) return AppIdentity.macosZipName();
    if (GetPlatform.isIOS) return AppIdentity.iosIpaName();
    return AppIdentity.artifactPrefix;
  }

  String? _extractDownloadBase(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return AppIdentity.latestDownloadBase;
    }
    try {
      final uri = Uri.parse(rawUrl);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      final idx = segments.indexOf('download');
      if (idx >= 0) {
        final base = uri.replace(pathSegments: segments.sublist(0, idx + 1));
        return '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/';
      }
      if (segments.contains('releases') || segments.contains('tags')) {
        return AppIdentity.latestDownloadBase;
      }
      return rawUrl.endsWith('/') ? rawUrl : '$rawUrl/';
    } catch (_) {
      return AppIdentity.latestDownloadBase;
    }
  }

  Future<void> startUpdate() async {
    await _downloadInApp();
    if (downloadState.value == DownloadState.done && canInstallInApp) {
      await installUpdate();
    }
  }

  Future<void> installUpdate() async {
    if (_localFilePath == null || !File(_localFilePath!).existsSync()) {
      downloadError(S.current.updateInstallFailed);
      downloadState.value = DownloadState.error;
      return;
    }

    try {
      downloadState.value = DownloadState.installing;

      if (GetPlatform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
        }
        final result = await OpenFile.open(
          _localFilePath!,
          type: 'application/vnd.android.package-archive',
        );
        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      } else if (GetPlatform.isWindows) {
        await Process.start(
          _localFilePath!,
          const [],
          runInShell: false,
          mode: ProcessStartMode.detached,
        );
      } else {
        final result = await OpenFile.open(_localFilePath!);
        if (result.type != ResultType.done) {
          throw Exception(result.message);
        }
      }
      downloadState.value = DownloadState.done;
    } catch (e) {
      downloadError(S.current.updateInstallFailed);
      downloadState.value = DownloadState.error;
    }
  }

  void retryDownload() {
    downloadState.value = DownloadState.idle;
    downloadError('');
    downloadProgress.value = 0.0;
    downloadedBytes.value = 0;
    totalBytes.value = 0;
    _localFilePath = null;
  }

  Future<void> _downloadInApp() async {
    downloadState.value = DownloadState.downloading;
    downloadProgress.value = 0.0;
    downloadedBytes.value = 0;
    totalBytes.value = 0;
    downloadError('');
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final urls = await _resolveDownloadUrls();
    if (urls.isEmpty) {
      downloadError(S.current.updateFileNotReady);
      downloadState.value = DownloadState.error;
      return;
    }

    final Directory saveDir;
    if (GetPlatform.isAndroid) {
      saveDir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }
    final filePath = '${saveDir.path}/$platformFileName';
    _localFilePath = filePath;

    var sawNotFound = false;
    Object? lastError;
    for (final url in urls) {
      try {
        final dio = Dio(
          BaseOptions(
            followRedirects: true,
            maxRedirects: 5,
            receiveTimeout: const Duration(minutes: 8),
            validateStatus: (status) => status != null && status < 400,
            headers: {
              'user-agent': AppIdentity.userAgent,
              'accept': '*/*',
            },
          ),
        );
        await dio.download(
          url,
          filePath,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            downloadedBytes.value = received;
            if (total > 0) {
              totalBytes.value = total;
              downloadProgress.value = received / total;
            }
          },
        );
        final file = File(filePath);
        if (!file.existsSync() || file.lengthSync() < 2048) {
          throw Exception('empty download');
        }
        downloadProgress.value = 1;
        downloadState.value = DownloadState.done;
        if (GetPlatform.isAndroid) {
          await _showDownloadCompleteNotification();
        }
        return;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) return;
        if (e.response?.statusCode == 404) {
          sawNotFound = true;
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    downloadError(_friendlyDownloadError(lastError, sawNotFound: sawNotFound));
    downloadState.value = DownloadState.error;
  }

  Future<List<String>> _resolveDownloadUrls() async {
    final resolved = <String>[];
    final seen = <String>{};

    void addUrl(String? url) {
      final value = url?.trim() ?? '';
      if (value.isEmpty || !seen.add(value)) return;
      resolved.add(value);
    }

    for (final url in await _assetUrlsFromGithub()) {
      addUrl(url);
    }
    for (final url in platformDownloadUrls) {
      addUrl(url);
    }
    return resolved;
  }

  Future<List<String>> _assetUrlsFromGithub() async {
    final wanted = _wantedAssetNames.map((name) => name.toLowerCase()).toSet();
    if (wanted.isEmpty) return const [];

    final dio = Dio(
      BaseOptions(
        followRedirects: true,
        headers: {
          'user-agent': AppIdentity.userAgent,
          'accept': 'application/vnd.github+json',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final endpoints = <String>{
      if (latestVersion.isNotEmpty) AppIdentity.releaseApiUrl(latestVersion),
      AppIdentity.latestReleaseApiUrl,
    };

    final found = <String>[];
    for (final endpoint in endpoints) {
      try {
        final response = await dio.get(endpoint);
        if (response.statusCode != 200 || response.data is! Map) continue;
        final assets = response.data['assets'];
        if (assets is! List) continue;
        for (final raw in assets) {
          if (raw is! Map) continue;
          final name = raw['name']?.toString().toLowerCase() ?? '';
          final url = raw['browser_download_url']?.toString();
          if (url != null && wanted.contains(name)) {
            found.add(url);
          }
        }
        if (found.isNotEmpty) return found;
      } catch (_) {}
    }
    return found;
  }

  String _friendlyDownloadError(Object? error, {required bool sawNotFound}) {
    if (sawNotFound ||
        (error is DioException && error.response?.statusCode == 404)) {
      return S.current.updateFileNotReady;
    }
    return S.current.updateDownloadFailed;
  }

  Future<void> _showDownloadCompleteNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'mo_update_channel',
      S.current.updateNotificationChannel,
      channelDescription: S.current.updateNotificationChannelDes,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );
    await _notifications.show(
      1001,
      S.current.updateReadyTitle,
      S.current.updateReadyBody,
      NotificationDetails(android: androidDetails),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
