import 'package:flutter_test/flutter_test.dart';
import 'package:estrella_music/services/music/device_music_session.dart';
import 'package:estrella_music/services/music/device_stream_resolver.dart';

void main() {
  test('strips Music prefixes and watch URLs down to a video id', () {
    expect(DeviceMusicSession.normalizeVideoId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    expect(
      DeviceMusicSession.normalizeVideoId('MPEDdQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      DeviceMusicSession.normalizeVideoId(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      ),
      'dQw4w9WgXcQ',
    );
    expect(
      DeviceMusicSession.normalizeVideoId('https://youtu.be/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      DeviceMusicSession.normalizeVideoId('RDAMVMdQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
  });

  test('detects playable audio URLs in a player response', () {
    expect(
      DeviceMusicSession.hasPlayableAudio({
        'playabilityStatus': {'status': 'LOGIN_REQUIRED'},
      }),
      isFalse,
    );
    expect(
      DeviceMusicSession.hasPlayableAudio({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'adaptiveFormats': [
            {
              'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
              'url': 'https://googlevideo.com/videoplayback?id=1',
            },
          ],
        },
      }),
      isTrue,
    );
    expect(
      DeviceMusicSession.hasPlayableAudio({
        'playabilityStatus': {'status': 'OK'},
        'streamingData': {
          'hlsManifestUrl': 'https://manifest.googlevideo.com/api/manifest/hls',
        },
      }),
      isTrue,
    );
  });

  test('rejects HLS manifests that just_audio cannot start', () {
    expect(
      DeviceStreamResolver.isProgressiveAudioUri(
        Uri.parse('https://manifest.googlevideo.com/api/manifest/hls_playlist'),
        mimeType: 'application/x-mpegURL',
      ),
      isFalse,
    );
    expect(
      DeviceStreamResolver.isProgressiveAudioUri(
        Uri.parse('https://example.com/audio.m3u8'),
      ),
      isFalse,
    );
    expect(
      DeviceStreamResolver.isProgressiveAudioUri(
        Uri.parse('https://googlevideo.com/videoplayback?id=1'),
        mimeType: 'audio/mp4',
      ),
      isTrue,
    );
  });
}
