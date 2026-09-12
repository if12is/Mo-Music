import 'package:estrella_music/app_identity.dart';

class AuthenticationAccessPolicy {
  const AuthenticationAccessPolicy();

  bool canEnterApplication({required bool isAuthenticated}) {
    if (!AppIdentity.requireRemoteAccount) return true;
    return isAuthenticated;
  }
}
