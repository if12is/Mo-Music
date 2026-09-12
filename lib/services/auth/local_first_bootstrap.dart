import 'package:get/get.dart';

import 'package:estrella_music/app_identity.dart';
import 'package:estrella_music/generated/l10n.dart';
import 'package:estrella_music/music_provider/music_provider_manager.dart';
import 'package:estrella_music/profiles/music_profile.dart';
import 'package:estrella_music/profiles/profile_manager.dart';
import 'package:estrella_music/services/storage/sqlite_store.dart';
import 'package:estrella_music/ui/profiles/profile_switcher.dart';

/// Ensures the app can start in offline local mode without login or onboarding.
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

    final profileManager = Get.find<ProfileManager>();
    final providerManager = Get.find<MusicProviderManager>();
    final localProviderId = providerManager.localProviderId;

    MusicProfile? localProfile;
    for (final profile in profileManager.profiles) {
      if (profile.isFallback || profile.providerId == localProviderId) {
        localProfile = profile;
        break;
      }
    }

    if (localProfile != null &&
        profileManager.activeProfile.value?.providerId != localProviderId) {
      await profileManager.switchProfile(localProfile.id);
    }

    if (localProfile != null &&
        (localProfile.name == 'Local' || localProfile.name.trim().isEmpty)) {
      await profileManager.saveProfile(
        localProfile.copyWith(name: S.current.welcomeDefaultLocalProfileName),
      );
    }

    final box = await SqliteStore.openBox('AppPrefs');
    await box.put('welcomeProfileOnboardingCompleted', true);
    await box.close();

    await ProfileSwitcher.refreshActiveContext();
  }
}
