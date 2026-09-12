import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/services/system/update_service.dart';

/// Estados posibles del proceso de descarga/instalación.
enum DownloadState { idle, downloading, done, installing, error }

class UpdateController extends GetxController {
  final updateInfo = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;
  final error = ''.obs;

  // — Descarga —
  final downloadProgress = 0.0.obs;
  final downloadState = DownloadState.idle.obs;
  final downloadError = ''.obs;

  String? _localFilePath;

  final _notifications = FlutterLocalNotificationsPlugin();

  // ──────────────────────────────────────────────
  // Ciclo de vida
  // ──────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _initNotifications();
    fetchUpdateInfo();
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

  // ──────────────────────────────────────────────
  // Datos de actualización
  // ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> _loadUpdateInfo() async {
    final dio = Dio();
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
            'Descarga': map['Descarga'] ??
                map['html_url'] ??
                AppIdentity.latestDownloadBase,
            'Notas': map['Notas'] ?? map['body'] ?? '',
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

  Future<void> fetchUpdateInfo() async {
    try {
      isLoading(true);
      error('');

      final info = await _loadUpdateInfo();
      if (info == null) {
        error(S.current.updateCheckUnavailable);
        return;
      }
      updateInfo.value = info;
    } catch (e) {
      error(e.toString());
    } finally {
      isLoading(false);
    }
  }

  // ──────────────────────────────────────────────
  // URLs y nombres por plataforma
  // ──────────────────────────────────────────────

  /// Extrae la URL de descarga correcta según la plataforma actual.
  /// Usa el campo [Descarga] de la API como base para derivar el path de releases.
  String? get platformDownloadUrl {
    final data = updateInfo.value;
    if (data == null) return null;

    final baseUrl = _extractDownloadBase(data['Descarga'] as String?);
    if (baseUrl == null) return null;

    if (GetPlatform.isAndroid) {
      return '${baseUrl}${AppIdentity.androidApkName()}';
    }
    if (GetPlatform.isWindows) {
      return '${baseUrl}${AppIdentity.windowsInstallerName()}';
    }
    if (GetPlatform.isLinux) return '${baseUrl}${AppIdentity.linuxTarballName()}';
    if (GetPlatform.isMacOS) return '${baseUrl}${AppIdentity.macosZipName()}';

    return data['Descarga'] as String? ?? AppIdentity.latestReleaseUrl;
  }

  /// Nombre del archivo que se descargará en la plataforma actual.
  String get platformFileName {
    if (GetPlatform.isAndroid) return AppIdentity.androidApkName();
    if (GetPlatform.isWindows) return AppIdentity.windowsInstallerName();
    if (GetPlatform.isLinux) return AppIdentity.linuxTarballName();
    if (GetPlatform.isMacOS) return AppIdentity.macosZipName();
    return AppIdentity.artifactPrefix;
  }

  /// Etiqueta legible del botón de acción principal según plataforma.
  String get platformActionLabel {
    if (GetPlatform.isIOS) return S.current.updateIosGuide;
    if (GetPlatform.isLinux || GetPlatform.isMacOS) {
      return S.current.updateDownloadGithub;
    }
    return S.current.updateAction;
  }

  /// Devuelve el directorio base de GitHub Releases terminado en '/'.
  /// Ejemplo: https://github.com/if12is/Mo-Music/releases/latest/download/
  String? _extractDownloadBase(String? rawUrl) {
    if (rawUrl == null) return null;
    try {
      final uri = Uri.parse(rawUrl);
      final segments = uri.pathSegments.toList();
      final idx = segments.indexOf('download');
      if (idx < 0) return '$rawUrl/';
      final base = uri.replace(pathSegments: segments.sublist(0, idx + 1));
      return '${base.toString()}/';
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // Acción principal según plataforma
  // ──────────────────────────────────────────────

  Future<void> startUpdate() async {
    if (GetPlatform.isAndroid) {
      final url = platformDownloadUrl ?? AppIdentity.latestReleaseUrl;
      await _openBrowser(url);
      return;
    }

    if (GetPlatform.isIOS) {
      final data = updateInfo.value;
      final url = data?['Descarga'] as String? ?? AppIdentity.latestReleaseUrl;
      await _openBrowser(url);
      return;
    }

    // Linux / macOS → descarga desde el navegador
    if (GetPlatform.isLinux || GetPlatform.isMacOS) {
      final url = platformDownloadUrl;
      if (url != null) await _openBrowser(url);
      return;
    }

    // Windows → descarga dentro de la app
    await _downloadInApp();
  }

  /// Lanza la instalación del archivo ya descargado (Windows).
  Future<void> installUpdate() async {
    if (_localFilePath == null) return;

    try {
      downloadState.value = DownloadState.installing;

      if (GetPlatform.isWindows) {
        // En Windows ejecutamos directamente el .exe descargado
        await Process.start(
          _localFilePath!,
          [],
          runInShell: false,
          mode: ProcessStartMode.detached,
        );
        downloadState.value = DownloadState.idle;
      }
    } catch (e) {
      downloadError(e.toString());
      downloadState.value = DownloadState.error;
    }
  }

  /// Reinicia el estado de descarga para permitir reintentar.
  void retryDownload() {
    downloadState.value = DownloadState.idle;
    downloadError('');
    downloadProgress.value = 0.0;
    _localFilePath = null;
  }

  // ──────────────────────────────────────────────
  // Descarga in-app (Android y Windows)
  // ──────────────────────────────────────────────

  Future<void> _downloadInApp() async {
    final url = platformDownloadUrl;
    if (url == null) {
      downloadError(S.current.updateDownloadUnavailable);
      downloadState.value = DownloadState.error;
      return;
    }

    try {
      downloadState.value = DownloadState.downloading;
      downloadProgress.value = 0.0;
      downloadError('');

      // Elegir directorio de guardado
      final Directory saveDir;
      if (GetPlatform.isAndroid) {
        // Android permite escribir aquí sin pedir almacenamiento: es el
        // directorio externo privado de la app.
        saveDir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${saveDir.path}/$platformFileName';
      _localFilePath = filePath;

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = received / total;
          }
        },
      );

      downloadState.value = DownloadState.done;

      // Notificación al terminar en Android
      if (GetPlatform.isAndroid) {
        await _showDownloadCompleteNotification();
      }
    } on DioException catch (e) {
      downloadError(S.current.updateNetworkError(e.message ?? ''));
      downloadState.value = DownloadState.error;
    } catch (e) {
      downloadError(e.toString());
      downloadState.value = DownloadState.error;
    }
  }

  // ──────────────────────────────────────────────
  // Notificaciones
  // ──────────────────────────────────────────────

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
    final notifDetails = NotificationDetails(android: androidDetails);
    await _notifications.show(
      1001,
      S.current.updateReadyTitle,
      S.current.updateReadyBody,
      notifDetails,
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  Future<void> _openBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
