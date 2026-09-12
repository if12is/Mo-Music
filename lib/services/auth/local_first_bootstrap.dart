import 'package:get/get.dart';

import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/music_provider/music_provider_manager.dart';
import 'package:estrella_music/music_provider/providers/streaming_provider.dart';
import 'package:estrella_music/profiles/music_profile.dart';
import 'package:estrella_music/profiles/profile_manager.dart';
import 'package:estrella_music/services/auth/auth_service.dart';
import 'package:estrella_music/services/music/device_music_session.dart';
import 'package:estrella_music/services/storage/sqlite_store.dart';
import 'package:estrella_music/ui/profiles/profile_switcher.dart';

/// Starts the app like the original player: online catalog per device,
/// without Joss Red login or the old-server sync hang.
class LocalFirstBootstrap {
  const LocalFirstBootstrap();

  static bool get isEnabled => !AppIdentity.requireRemoteAccount;

  Future<bool> isWelcomeCompleted() async {
    return SqliteStore.box('AppPrefs')
            .get('welcomeProfileOnboardingCompleted', defaultValue: false)
        as bool;
  }

  Future<void> ensureReady() async {
    if (!isEnabled) return;

    if (Get.isRegistered<AuthService>()) {
      Get.find<AuthService>().disableRemoteSession();
    }

    await DeviceMusicSession.resolve().ensureReady();

    final profileManager = Get.find<ProfileManager>();
    final providerManager = Get.find<MusicProviderManager>();
    final localProviderId = providerManager.localProviderId;

    MusicProfile? localProfile;
    MusicProfile? streamingProfile;
    for (final profile in profileManager.profiles) {
      if (localProfile == null &&
          (profile.isFallback || profile.providerId == localProviderId)) {
        localProfile = profile;
      }
      if (streamingProfile == null &&
          (profile.providerId == StreamingProvider.providerId ||
              profile.providerId == StreamingProvider.legacyProviderId)) {
        streamingProfile = profile;
      }
    }

    if (localProfile != null &&
        (localProfile.name == 'Local' || localProfile.name.trim().isEmpty)) {
      await profileManager.saveProfile(
        localProfile.copyWith(name: S.current.welcomeDefaultLocalProfileName),
      );
    }

    streamingProfile ??= await profileManager.createProfile(
      name: S.current.deviceOnlineProfileName,
      providerId: StreamingProvider.providerId,
    );

    if (profileManager.activeProfile.value?.id != streamingProfile.id) {
      await profileManager.switchProfile(streamingProfile.id);
    }

    final box = await SqliteStore.openBox('AppPrefs');
    await box.put('welcomeProfileOnboardingCompleted', true);
    await box.close();

    await ProfileSwitcher.refreshActiveContext();
  }
}
