#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
repo_root=$(cd "${study_root}/.." && pwd)
workspace_root=$(cd "${repo_root}/.." && pwd)
source_config="${workspace_root}/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist"
production_auth_config="${study_root}/ios/Config/NativeAuth.xcconfig"
debug_auth_config="${study_root}/ios/Config/NativeAuth.debug.xcconfig"

xcconfig_value() {
  local key=$1

  awk -F= -v key="${key}" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${production_auth_config}"
}

test -f "${source_config}"
test "$(plutil -extract PROJECT_ID raw "${source_config}")" = "nurio-prod"
test "$(plutil -extract BUNDLE_ID raw "${source_config}")" = "com.nurio.study.ios"
! rg -q '^[[:space:]]*#include\??[[:space:]]+"NativeAuth\.local\.xcconfig"' "${production_auth_config}"
rg -q '^#include "NativeAuth\.xcconfig"$' "${debug_auth_config}"
rg -q '^#include\? "NativeAuth\.local\.xcconfig"$' "${debug_auth_config}"

for configuration in Debug Release; do
  derived="/tmp/nurio-study-production-push-ios-${configuration}"
  xcodebuild build -quiet \
    -derivedDataPath "${derived}" \
    -project "${study_root}/ios/NurioStudy.xcodeproj" \
    -scheme NurioStudy \
    -configuration "${configuration}" \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO

  bundled="${derived}/Build/Products/${configuration}-iphonesimulator/NurioStudy.app/GoogleService-Info.plist"
  test -f "${bundled}"
  test "$(plutil -extract PROJECT_ID raw "${bundled}")" = "nurio-prod"
  test "$(plutil -extract BUNDLE_ID raw "${bundled}")" = "com.nurio.study.ios"

  if [[ "${configuration}" == "Release" ]]; then
    info_plist="${derived}/Build/Products/${configuration}-iphonesimulator/NurioStudy.app/Info.plist"
    test "$(plutil -extract GIDClientID raw "${info_plist}")" = "$(xcconfig_value GOOGLE_IOS_CLIENT_ID)"
    test "$(plutil -extract GIDServerClientID raw "${info_plist}")" = "$(xcconfig_value GOOGLE_SERVER_CLIENT_ID)"
    plutil -p "${info_plist}" | rg -Fq "$(xcconfig_value GOOGLE_REVERSED_CLIENT_ID)"
  fi
done
