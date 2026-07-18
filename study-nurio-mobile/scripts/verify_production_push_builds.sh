#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)

bash "${script_dir}/test_android_production_push_build.sh"
bash "${script_dir}/test_ios_production_push_build.sh"

xcodebuild test -quiet \
  -derivedDataPath /tmp/nurio-study-production-push-ios-tests \
  -project "${study_root}/ios/NurioStudy.xcodeproj" \
  -scheme NurioStudy \
  -destination 'platform=iOS Simulator,id=5192666C-2A65-4B3B-B7CF-D34A9ABC0D24' \
  CODE_SIGNING_ALLOWED=NO
