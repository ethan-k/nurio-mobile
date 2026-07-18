#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
workspace_root=$(cd "${study_root}/../.." && pwd)
source_config="${workspace_root}/nurio_study/mobile_certs/nurio-study-google-services.json"
staged_config="${study_root}/android/app/google-services.json"

test -f "${source_config}"
test "$(jq -r '.project_info.project_id' "${source_config}")" = "nurio-prod"
jq -e '.client[].client_info.android_client_info.package_name == "com.nurio.study.android"' \
  "${source_config}" >/dev/null

(cd "${study_root}/android" && ./gradlew :app:prepareStudyFirebaseConfig)
cmp -s "${source_config}" "${staged_config}"
(cd "${study_root}/android" && ./gradlew testDebugUnitTest assembleDebug assembleRelease)

for variant in Debug Release; do
  values="${study_root}/android/app/build/generated/res/process${variant}GoogleServices/values/values.xml"
  test -f "${values}"
  rg -q '<string name="project_id" translatable="false">nurio-prod</string>' "${values}"
done
