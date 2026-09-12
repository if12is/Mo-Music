import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/services/storage/sqlite_store.dart';
import 'package:estrella_music/services/system/utils.dart';
import 'package:estrella_music/utils/helpers/helper.dart';

/// Per-device YouTube Music identity, same as the original Harmony/Estrella
/// client. This is not a Joss Red account — each install gets its own visitor
/// id so catalog and playback work without login.
class DeviceMusicSession extends GetxService {
  DeviceMusicSession({Dio? client}) : _dio = client ?? Dio();

  static const domain = 'https://music.youtube.com/';
  static const _baseUrl = '${domain}youtubei/v1/';
  static const _apiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
  static const _fixedParams =
      '?prettyPrint=false&alt=json&key=$_apiKey';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  static const _fallbackVisitorId =
      'CgttN24wcmd5UzNSWSi2lvq2BjIKCgJKUBIEGgAgYQ%3D%3D';

  final Dio _dio;
  String? visitorId;

  static DeviceMusicSession resolve() {
    if (Get.isRegistered<DeviceMusicSession>()) {
      return Get.find<DeviceMusicSession>();
    }
    final session = DeviceMusicSession();
    Get.put(session, permanent: true);
    return session;
  }

  Map<String, String> get headers => {
        'user-agent': _userAgent,
        'accept': '*/*',
        'accept-encoding': 'gzip, deflate',
        'content-type': 'application/json',
        'origin': domain,
        'referer': domain,
        'cookie': 'CONSENT=YES+1',
        if (visitorId != null && visitorId!.isNotEmpty)
          'X-Goog-Visitor-Id': visitorId!,
      };

  Map<String, dynamic> catalogContext({String? languageCode}) {
    final date = DateTime.now();
    return {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion':
              '1.${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.01.00',
          'hl': languageCode ?? AppIdentity.defaultLanguageCode,
          if (visitorId != null && visitorId!.isNotEmpty)
            'visitorData': visitorId,
        },
        'user': {},
      }
    };
  }

  /// ANDROID_MUSIC now returns LOGIN_REQUIRED for almost every track.
  /// These clients match youtube_explode / yt-dlp payloads that still
  /// return progressive audio URLs on a normal device IP.
  static const _playerClients = <_DevicePlayerClient>[
    _DevicePlayerClient(
      name: 'ANDROID',
      url: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent:
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      client: {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.38',
        'userAgent':
            'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
        'osName': 'Android',
        'osVersion': '11',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
        'gl': 'US',
      },
    ),
    _DevicePlayerClient(
      name: 'ANDROID_VR',
      url: 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      userAgent:
          'com.google.android.apps.youtube.vr.oculus/1.62.27 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      client: {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.62.27',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
        'androidSdkVersion': 32,
        'osName': 'Android',
        'osVersion': '12L',
        'userAgent':
            'com.google.android.apps.youtube.vr.oculus/1.62.27 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
        'gl': 'US',
      },
    ),
    _DevicePlayerClient(
      name: 'IOS',
      url:
          'https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false',
      userAgent:
          'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      client: {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent':
            'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
        'platform': 'MOBILE',
        'osName': 'IOS',
        'osVersion': '18.1.0.22B83',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
        'gl': 'US',
      },
    ),
    _DevicePlayerClient(
      name: 'ANDROID_MUSIC',
      url: '${_baseUrl}player$_fixedParams',
      userAgent:
          'com.google.android.apps.youtube.music/7.29.52 (Linux; U; Android 13) gzip',
      client: {
        'clientName': 'ANDROID_MUSIC',
        'clientVersion': '7.29.52',
        'androidSdkVersion': 34,
        'userAgent':
            'com.google.android.apps.youtube.music/7.29.52 (Linux; U; Android 13) gzip',
        'gl': 'US',
      },
    ),
  ];

  Map<String, dynamic> playerContext({String? languageCode}) {
    return _playerBody(_playerClients.last, languageCode: languageCode);
  }

  Map<String, dynamic> _playerBody(
    _DevicePlayerClient client, {
    String? languageCode,
    bool includeVisitor = true,
  }) {
    return {
      'context': {
        'client': {
          ...client.client,
          'hl': languageCode ?? AppIdentity.defaultLanguageCode,
          if (includeVisitor && visitorId != null && visitorId!.isNotEmpty)
            'visitorData': visitorId,
        },
      },
      'contentCheckOk': true,
      'racyCheckOk': true,
      'playbackContext': {
        'contentPlaybackContext': {
          'signatureTimestamp': getDatestamp() - 1,
        },
      },
    };
  }

  /// YouTube Music sometimes prefixes official-audio ids with MPED.
  static String normalizeVideoId(String raw) {
    var id = raw.trim();
    if (id.toUpperCase().startsWith('MPED')) {
      id = id.substring(4);
    }
    final queryId = Uri.tryParse(id)?.queryParameters['v'];
    if (queryId != null && queryId.isNotEmpty) {
      id = queryId;
    }
    final match = RegExp(r'(?:youtu\.be/|v=|/vi/|/embed/)([A-Za-z0-9_-]{11})')
        .firstMatch(id);
    if (match != null) return match.group(1)!;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return id;
    if (id.length > 11) {
      final tail = id.substring(id.length - 11);
      if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(tail)) return tail;
    }
    return id;
  }

  Future<void> ensureReady() async {
    final prefs = SqliteStore.box('AppPrefs');
    final stored = prefs.get('visitorId');
    if (stored is Map) {
      final id = stored['id']?.toString();
      final exp = int.tryParse('${stored['exp']}');
      if (id != null && id.isNotEmpty && !isExpired(epoch: exp)) {
        visitorId = id;
        prefs.put('visitorId', {
          'id': id,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2590200,
        });
        return;
      }
    } else if (stored is String && stored.isNotEmpty) {
      visitorId = stored;
      return;
    }

    visitorId = await generateVisitorId() ?? _fallbackVisitorId;
    prefs.put('visitorId', {
      'id': visitorId,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2592000,
    });
    printINFO('Device visitor id ready ($visitorId)');
  }

  Future<String?> generateVisitorId() async {
    try {
      final response = await _dio.get<dynamic>(
        domain,
        options: Options(headers: headers, validateStatus: (_) => true),
      );
      final match =
          RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;').firstMatch('${response.data}');
      if (match == null) return null;
      final ytcfg = json.decode(match.group(1)!);
      if (ytcfg is Map) {
        final id = ytcfg['VISITOR_DATA']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (error) {
      printINFO('Visitor id generation failed: $error');
    }
    return null;
  }

  Future<String?> regenerateVisitorId() async {
    final generated = await generateVisitorId();
    if (generated == null || generated.isEmpty) return null;
    visitorId = generated;
    SqliteStore.box('AppPrefs').put('visitorId', {
      'id': generated,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2592000,
    });
    return generated;
  }

  Future<Map<String, dynamic>> request(
    String action,
    Map<dynamic, dynamic> payload,
    String additionalParams,
  ) async {
    await ensureReady();
    final body = Map<String, dynamic>.from(payload);
    final context = body['context'];
    if (context is! Map) {
      body.addAll(catalogContext());
    } else {
      final client = (context['client'] is Map)
          ? Map<String, dynamic>.from(context['client'] as Map)
          : <String, dynamic>{};
      if (visitorId != null && visitorId!.isNotEmpty) {
        client['visitorData'] = visitorId;
      }
      body['context'] = {
        ...Map<String, dynamic>.from(context),
        'client': client,
      };
    }

    final response = await _dio.post<dynamic>(
      '$_baseUrl$action$_fixedParams$additionalParams',
      data: body,
      options: Options(headers: headers, validateStatus: (_) => true),
    );
    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        'Device catalog request failed for $action (${response.statusCode})',
      );
    }
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> player(String videoId, {String? languageCode}) async {
    await ensureReady();
    final id = normalizeVideoId(videoId);
    Map<String, dynamic> last = {};
    for (final client in _playerClients) {
      for (final includeVisitor in const [true, false]) {
        if (!includeVisitor && (visitorId == null || visitorId!.isEmpty)) {
          continue;
        }
        try {
          final result = await _playerWithClient(
            id,
            client,
            languageCode: languageCode,
            includeVisitor: includeVisitor,
          );
          last = result;
          if (hasPlayableAudio(result)) return result;
          final status =
              _asMap(result['playabilityStatus'])['status']?.toString();
          printINFO(
            'Device player ${client.name} '
            '${includeVisitor ? 'with' : 'without'} visitor '
            'status=$status for $id',
          );
        } catch (error) {
          printINFO('Device player ${client.name} failed: $error');
        }
      }
    }
    return last;
  }

  Future<Map<String, dynamic>> _playerWithClient(
    String videoId,
    _DevicePlayerClient client, {
    String? languageCode,
    bool includeVisitor = true,
  }) async {
    final body = {
      ..._playerBody(
        client,
        languageCode: languageCode,
        includeVisitor: includeVisitor,
      ),
      'videoId': videoId,
    };
    final response = await _dio.post<dynamic>(
      client.url,
      data: body,
      options: Options(
        headers: _playerHeaders(client, includeVisitor: includeVisitor),
        validateStatus: (_) => true,
      ),
    );
    if ((response.statusCode ?? 500) >= 400) {
      throw Exception(
        'Device player ${client.name} failed (${response.statusCode})',
      );
    }
    return _asMap(response.data);
  }

  Map<String, String> _playerHeaders(
    _DevicePlayerClient client, {
    required bool includeVisitor,
  }) {
    final origin = client.url.contains('music.youtube.com')
        ? domain
        : 'https://www.youtube.com';
    return {
      'user-agent': client.userAgent,
      'accept': '*/*',
      'accept-encoding': 'gzip, deflate',
      'content-type': 'application/json',
      'origin': origin,
      'referer': origin,
      'cookie': 'CONSENT=YES+1',
      if (includeVisitor && visitorId != null && visitorId!.isNotEmpty)
        'X-Goog-Visitor-Id': visitorId!,
    };
  }

  static bool hasPlayableAudio(Map<String, dynamic> response) {
    final playability = _asMap(response['playabilityStatus']);
    final status = playability['status']?.toString();
    if (status != null && status != 'OK') return false;
    final streamingData = _asMap(response['streamingData']);
    final formats = <dynamic>[
      ..._asList(streamingData['adaptiveFormats']),
      ..._asList(streamingData['formats']),
      ..._asList(response['adaptiveFormats']),
      ..._asList(response['formats']),
    ];
    for (final raw in formats) {
      final fmt = _asMap(raw);
      final url = fmt['url']?.toString();
      final mime = fmt['mimeType']?.toString() ?? '';
      if (url != null && url.isNotEmpty && mime.contains('audio/')) {
        return true;
      }
    }
    return (streamingData['hlsManifestUrl']?.toString().isNotEmpty ?? false);
  }

  static List<dynamic> _asList(dynamic value) =>
      value is List ? value : const [];

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }
}

class _DevicePlayerClient {
  const _DevicePlayerClient({
    required this.name,
    required this.url,
    required this.userAgent,
    required this.client,
  });

  final String name;
  final String url;
  final String userAgent;
  final Map<String, dynamic> client;
}
