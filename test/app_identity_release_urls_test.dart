import 'package:flutter_test/flutter_test.dart';
import 'package:estrella_music/app_identity.dart';

void main() {
  test('builds versioned GitHub download URLs', () {
    expect(
      AppIdentity.releaseDownloadBase('2.5.7'),
      'https://github.com/if12is/Mo-Music/releases/download/v2.5.7/',
    );
    expect(
      AppIdentity.releaseDownloadBase('v2.5.7'),
      'https://github.com/if12is/Mo-Music/releases/download/v2.5.7/',
    );
    expect(
      AppIdentity.releaseApiUrl('2.5.7'),
      'https://api.github.com/repos/if12is/Mo-Music/releases/tags/v2.5.7',
    );
  });
}
