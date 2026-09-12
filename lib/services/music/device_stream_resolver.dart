import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/music_provider/models/playback_source.dart';
import 'package:estrella_music/services/music/device_music_session.dart';
import 'package:estrella_music/utils/helpers/helper.dart';

/// Resolves a progressive audio URL without a Joss Red session.
/// Innertube clients first, then youtube_explode (original Harmony path),
/// then public Piped/Invidious mirrors as a last resort.
class DeviceStreamResolver extends GetxService {
  DeviceStreamResolver({Dio? client, YoutubeExplode? explode})
      : _dio = client ?? Dio(),
        _explode = explode;

  static const _pipedInstances = <String>[
    'https://pipedapi.private.coffee',
    'https://api.piped.private.coffee',
    'https://pipedapi.adminforge.de',
    'https://pipedapi.reallyaweso.me',
  ];

  static const _invidiousInstances = <String>[
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yt.artemislena.eu',
  ];

  final Dio _dio;
  YoutubeExplode? _explode;

  static DeviceStreamResolver resolve() {
    if (Get.isRegistered<DeviceStreamResolver>()) {
      return Get.find<DeviceStreamResolver>();
    }
    final resolver = DeviceStreamResolver();
    Get.put(resolver, permanent: true);
    return resolver;
  }

  Future<PlaybackSource?> resolveSource(
    String sourceId, {
    String? requestedFormat,
    required PlaybackSource? Function(Map<String, dynamic> response)
        parsePlayerResponse,
  }) async {
    final videoId = DeviceMusicSession.normalizeVideoId(sourceId);
    if (videoId.isEmpty) return null;

    try {
      final response = await DeviceMusicSession.resolve().player(videoId);
      final parsed = parsePlayerResponse(response);
      if (parsed != null) return parsed;
    } catch (error) {
      printINFO('[DeviceStreamResolver] Innertube player failed: $error');
    }

    final explodeSource = await _resolveViaExplode(
      videoId,
      requestedFormat: requestedFormat,
    );
    if (explodeSource != null) return explodeSource;

    return _resolveViaPublicMirrors(
      videoId,
      requestedFormat: requestedFormat,
    );
  }

  Future<PlaybackSource?> _resolveViaExplode(
    String videoId, {
    String? requestedFormat,
  }) async {
    try {
      _explode ??= YoutubeExplode();
      late final StreamManifest manifest;
      try {
        manifest = await _explode!.videos.streamsClient.getManifest(
          videoId,
          requireWatchPage: true,
        );
      } catch (error) {
        printINFO(
          '[DeviceStreamResolver] androidSdkless explode failed: $error',
        );
        manifest = await _explode!.videos.streamsClient.getManifest(
          videoId,
          ytClients: [
            YoutubeApiClient.androidVr,
            YoutubeApiClient.ios,
          ],
          requireWatchPage: true,
        );
      }
      final audio = manifest.audioOnly.toList();
      final StreamInfo chosen;
      if (audio.isNotEmpty) {
        final requested = (requestedFormat ?? '').toLowerCase();
        final filtered = requested == 'm4a'
            ? audio
                .where((stream) =>
                    '${stream.container}'.contains('mp4') ||
                    stream.audioCodec.contains('mp4a'))
                .toList()
            : requested == 'opus'
                ? audio
                    .where((stream) =>
                        '${stream.container}'.contains('webm') ||
                        stream.audioCodec.contains('opus'))
                    .toList()
                : audio;
        chosen = (filtered.isEmpty ? audio : filtered).withHighestBitrate();
      } else if (manifest.muxed.isNotEmpty) {
        chosen = manifest.muxed.withHighestBitrate();
      } else {
        return null;
      }
      final uri = chosen.url;
      final isOpus = '${chosen.codec}'.toLowerCase().contains('opus');
      return PlaybackSource(
        type: PlaybackSourceType.authorizedStream,
        uri: uri,
        headers: {
          'user-agent':
              'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
          'accept': '*/*',
        },
        mimeType: isOpus ? 'audio/webm' : 'audio/mp4',
        bitrate: chosen.bitrate.bitsPerSecond,
        contentLength: chosen.size.totalBytes,
        expiresAt: _expiryFromUri(uri),
      );
    } catch (error) {
      printINFO('[DeviceStreamResolver] youtube_explode failed: $error');
      return null;
    }
  }

  Future<PlaybackSource?> _resolveViaPublicMirrors(
    String videoId, {
    String? requestedFormat,
  }) async {
    for (final host in _pipedInstances) {
      final source = await _resolvePiped(
        host,
        videoId,
        requestedFormat: requestedFormat,
      );
      if (source != null) return source;
    }
    for (final host in _invidiousInstances) {
      final source = await _resolveInvidious(
        host,
        videoId,
        requestedFormat: requestedFormat,
      );
      if (source != null) return source;
    }
    return null;
  }

  Future<PlaybackSource?> _resolvePiped(
    String host,
    String videoId, {
    String? requestedFormat,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '$host/streams/$videoId',
        options: Options(
          headers: {
            'user-agent': AppIdentity.userAgent,
            'accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
      if ((response.statusCode ?? 500) >= 400) return null;
      final data = _asMap(response.data);
      final streams = data['audioStreams'];
      if (streams is! List || streams.isEmpty) return null;
      return _bestAudioFromList(
        streams.whereType<Map>().map(_asMap),
        urlKeys: const ['url'],
        mimeKeys: const ['mimeType', 'type', 'codec'],
        bitrateKeys: const ['bitrate', 'bitRate'],
        requestedFormat: requestedFormat,
      );
    } catch (error) {
      printINFO('[DeviceStreamResolver] Piped $host failed: $error');
      return null;
    }
  }

  Future<PlaybackSource?> _resolveInvidious(
    String host,
    String videoId, {
    String? requestedFormat,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '$host/api/v1/videos/$videoId',
        options: Options(
          headers: {
            'user-agent': AppIdentity.userAgent,
            'accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
      if ((response.statusCode ?? 500) >= 400) return null;
      final data = _asMap(response.data);
      final streams = data['adaptiveFormats'];
      if (streams is! List || streams.isEmpty) return null;
      return _bestAudioFromList(
        streams.whereType<Map>().map(_asMap),
        urlKeys: const ['url'],
        mimeKeys: const ['type', 'mimeType'],
        bitrateKeys: const ['bitrate', 'averageBitrate'],
        requestedFormat: requestedFormat,
        audioOnly: true,
      );
    } catch (error) {
      printINFO('[DeviceStreamResolver] Invidious $host failed: $error');
      return null;
    }
  }

  PlaybackSource? _bestAudioFromList(
    Iterable<Map<String, dynamic>> streams, {
    required List<String> urlKeys,
    required List<String> mimeKeys,
    required List<String> bitrateKeys,
    String? requestedFormat,
    bool audioOnly = false,
  }) {
    Map<String, dynamic>? selected;
    Map<String, dynamic>? fallback;
    var selectedBitrate = -1;
    var fallbackBitrate = -1;
    final requested = (requestedFormat ?? '').toLowerCase();

    for (final stream in streams) {
      final url = _first(stream, urlKeys);
      if (url == null) continue;
      final mime = _first(stream, mimeKeys) ?? '';
      if (audioOnly && !mime.contains('audio')) continue;
      final bitrate = int.tryParse('${stream[bitrateKeys.first] ?? ''}') ??
          _firstInt(stream, bitrateKeys) ??
          0;
      if (fallback == null || bitrate > fallbackBitrate) {
        fallback = stream;
        fallbackBitrate = bitrate;
      }
      final matches = requested.isEmpty ||
          (requested == 'm4a' && (mime.contains('mp4') || mime.contains('m4a'))) ||
          (requested == 'opus' && mime.contains('opus'));
      if (matches && bitrate > selectedBitrate) {
        selected = stream;
        selectedBitrate = bitrate;
      }
    }

    final target = selected ?? fallback;
    final url = target == null ? null : _first(target, urlKeys);
    if (target == null || url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final mime = _first(target, mimeKeys);
    return PlaybackSource(
      type: PlaybackSourceType.authorizedStream,
      uri: uri,
      mimeType: mime,
      bitrate: selectedBitrate > 0
          ? selectedBitrate
          : (fallbackBitrate > 0 ? fallbackBitrate : null),
      expiresAt: _expiryFromUri(uri),
    );
  }

  static DateTime? _expiryFromUri(Uri uri) {
    final raw = uri.queryParameters['expire'] ?? uri.queryParameters['expiry'];
    if (raw == null || raw.isEmpty) return null;
    final unix = int.tryParse(raw);
    if (unix == null) return DateTime.tryParse(raw);
    final milliseconds = unix > 9999999999 ? unix : unix * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  static String? _first(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  @override
  void onClose() {
    _explode?.close();
    super.onClose();
  }
}
