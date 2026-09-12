# Mo Music GitHub sideload signing

`momusic-github.jks` is a dedicated keystore for GitHub Releases and in-app
updates. It is **not** a Play Store upload key.

CI prefers repository secrets when they are present:

- `KEYSTORE_BASE64`
- `KEYSTORE_PASSWORD`
- `KEY_ALIAS`
- `KEY_PASSWORD`

If those secrets are missing, Gradle signs with this committed sideload key so
`MoMusic-android-universal.apk` can be published and the in-app updater can
download a consistently signed build.

To replace this key later, keep the same alias or publish a fresh first-install
APK. Users cannot update over an APK signed with a different certificate.
