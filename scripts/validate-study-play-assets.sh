#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
res_dir="$repo_root/study-nurio-mobile/android/app/src/main/res"
manifest="$repo_root/study-nurio-mobile/android/app/src/main/AndroidManifest.xml"
build_gradle="$repo_root/study-nurio-mobile/android/app/build.gradle.kts"
keystore_props="$repo_root/study-nurio-mobile/android/keystore.properties"
android_app_dir="$repo_root/study-nurio-mobile/android/app"
strings="$res_dir/values/strings.xml"
launcher="$res_dir/mipmap-xxxhdpi/ic_launcher.png"
monochrome="$res_dir/mipmap-xxxhdpi/ic_launcher_monochrome.png"
store_icon="$res_dir/play_store_512.png"
bundle="${1:-$repo_root/study-nurio-mobile/android/app/build/outputs/bundle/release/app-release.aab}"
expected_study_sha1="79:6C:0D:B4:A1:73:64:D2:E1:FE:BD:BC:EF:6E:D2:D2:C0:ED:39:06"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

command -v magick >/dev/null 2>&1 || fail "ImageMagick 'magick' is required"
command -v keytool >/dev/null 2>&1 || fail "JDK 'keytool' is required"

property_value() {
  local file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key {print substr($0, index($0, "=") + 1)}' "$file" \
    | tr -d '\r'
}

grep -q 'android:label="@string/app_name"' "$manifest" \
  || fail "Study launcher label must come from @string/app_name"
grep -q 'android:icon="@mipmap/ic_launcher"' "$manifest" \
  || fail "Study launcher icon must use @mipmap/ic_launcher"
grep -q 'android:roundIcon="@mipmap/ic_launcher_round"' "$manifest" \
  || fail "Study launcher round icon must use @mipmap/ic_launcher_round"
grep -q '<string name="app_name">Nurio Study</string>' "$strings" \
  || fail "Study app_name must match the Play listing title"
grep -q 'versionCode = 2' "$build_gradle" \
  || fail "Study release versionCode must be bumped for the corrected Play upload"
grep -q 'versionName = "1.0.1"' "$build_gradle" \
  || fail "Study release versionName must describe the corrected Play upload"

[[ -f "$keystore_props" ]] \
  || fail "Study keystore.properties is required to verify Play signing identity"

store_file="$(property_value "$keystore_props" "storeFile")"
key_alias="$(property_value "$keystore_props" "keyAlias")"
store_password="$(property_value "$keystore_props" "storePassword")"
case "$store_file" in
  /*) store_path="$store_file" ;;
  *) store_path="$android_app_dir/$store_file" ;;
esac

[[ -f "$store_path" ]] \
  || fail "Study signing keystore does not resolve from Gradle app module"

keystore_sha1="$(keytool -list -v \
  -keystore "$store_path" \
  -alias "$key_alias" \
  -storepass "$store_password" 2>/dev/null \
  | awk '/SHA1:/ {print $2; exit}')"

[[ "$keystore_sha1" == "$expected_study_sha1" ]] \
  || fail "Study signing keystore SHA1 is $keystore_sha1, expected $expected_study_sha1"

if [[ -f "$bundle" ]]; then
  bundle_sha1="$(keytool -printcert -jarfile "$bundle" 2>/dev/null \
    | awk '/SHA1:/ {print $2; exit}')"
  [[ "$bundle_sha1" == "$expected_study_sha1" ]] \
    || fail "AAB SHA1 is $bundle_sha1, expected Study SHA1 $expected_study_sha1"
fi

[[ "$(magick identify -format '%wx%h' "$store_icon")" == "512x512" ]] \
  || fail "Play Store icon must be 512x512"
[[ "$(magick identify -format '%wx%h' "$launcher")" == "192x192" ]] \
  || fail "xxxhdpi legacy launcher icon must be 192x192"
[[ "$(magick identify -format '%wx%h' "$monochrome")" == "432x432" ]] \
  || fail "xxxhdpi monochrome launcher mask must be 432x432"

alpha_at() {
  local image="$1"
  local point="$2"
  magick "$image" -format "%[pixel:p{$point}]" info: \
    | sed -E 's/^.*,//; s/\)//'
}

background_alpha="$(alpha_at "$monochrome" "90,90")"
logo_alpha="$(alpha_at "$monochrome" "216,216")"

[[ "$background_alpha" == "0" ]] \
  || fail "Monochrome launcher mask must not include an opaque square background"
[[ "$logo_alpha" == "1" ]] \
  || fail "Monochrome launcher mask must keep the Nurio logo shape opaque"

printf 'Study Play asset validation passed.\n'
