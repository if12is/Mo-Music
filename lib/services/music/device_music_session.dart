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

  Map<String, dynamic> playerContext({String? languageCode}) {
    return {
      'context': {
        'client': {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.29.52',
          'androidSdkVersion': 34,
          'hl': languageCode ?? AppIdentity.defaultLanguageCode,
          'gl': 'US',
          if (visitorId != null && visitorId!.isNotEmpty)
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
    final body = {
      ...playerContext(languageCode: languageCode),
      'videoId': videoId,
    };
    final response = await _dio.post<dynamic>(
      '${_baseUrl}player$_fixedParams',
      data: body,
      options: Options(headers: headers, validateStatus: (_) => true),
    );
    if ((response.statusCode ?? 500) >= 400) {
      throw Exception('Device player request failed (${response.statusCode})');
    }
    return _asMap(response.data);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }
}
