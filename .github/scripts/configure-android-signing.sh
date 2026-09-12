#!/usr/bin/env bash
set -euo pipefail

# Prefer private upload secrets. Otherwise use the committed GitHub sideload key
# so release APKs can be published without Estrella Music keystore secrets.

keystore_dir="android/app"
properties_path="android/key.properties"

if [[ -n "${KEYSTORE_BASE64:-}" && -n "${KEYSTORE_PASSWORD:-}" && -n "${KEY_ALIAS:-}" && -n "${KEY_PASSWORD:-}" ]]; then
  printf '%s' "$KEYSTORE_BASE64" | tr -d '\r\n ' | base64 --decode > "$keystore_dir/upload.keystore"
  {
    echo "storeFile=upload.keystore"
    echo "storePassword=$KEYSTORE_PASSWORD"
    echo "keyAlias=$KEY_ALIAS"
    echo "keyPassword=$KEY_PASSWORD"
  } > "$properties_path"
  echo "Using GitHub Actions signing secrets."
  exit 0
fi

if [[ ! -f "$keystore_dir/momusic-github.jks" ]]; then
  echo "::error::Committed GitHub sideload keystore is missing and no signing secrets were provided."
  exit 1
fi

{
  echo "storeFile=momusic-github.jks"
  echo "storePassword=MoMusicGitHubSideload2026"
  echo "keyAlias=momusic"
  echo "keyPassword=MoMusicGitHubSideload2026"
} > "$properties_path"

echo "Using committed Mo Music GitHub sideload keystore."
