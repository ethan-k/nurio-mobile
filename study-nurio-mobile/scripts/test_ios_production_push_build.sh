#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
repo_root=$(cd "${study_root}/.." && pwd)
workspace_root=$(cd "${repo_root}/.." && pwd)
source_config="${workspace_root}/nurio_study/mobile_certs/nurio-study-GoogleService-Info.plist"

test -f "${source_config}"
test "$(plutil -extract PROJECT_ID raw "${source_config}")" = "nurio-prod"
test "$(plutil -extract BUNDLE_ID raw "${source_config}")" = "com.nurio.study.ios"

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
done
