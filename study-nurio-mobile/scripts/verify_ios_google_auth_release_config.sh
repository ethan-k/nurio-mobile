#!/usr/bin/env bash
set -euo pipefail

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
  exit 0
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
study_root=$(cd "${script_dir}/.." && pwd)
production_config="${study_root}/ios/Config/NativeAuth.xcconfig"

if grep -Eq '^[[:space:]]*#include\??[[:space:]]+"NativeAuth\.local\.xcconfig"' "${production_config}"; then
  echo "Release Google auth configuration must not include NativeAuth.local.xcconfig" >&2
  exit 1
fi

xcconfig_value() {
  local key=$1

  awk -F= -v key="${key}" '
    $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${production_config}"
}

for key in GOOGLE_IOS_CLIENT_ID GOOGLE_SERVER_CLIENT_ID GOOGLE_REVERSED_CLIENT_ID; do
  canonical=$(xcconfig_value "${key}")
  resolved=${!key:-}

  if [[ -z "${canonical}" || -z "${resolved}" || "${canonical}" == *'$('* ]]; then
    echo "Release Google auth configuration is missing ${key}" >&2
    exit 1
  fi

  if [[ "${resolved}" != "${canonical}" ]]; then
    echo "Release ${key} differs from the canonical production value; local overrides are Debug-only" >&2
    exit 1
  fi
done

if [[ "${GOOGLE_IOS_CLIENT_ID}" == "${GOOGLE_SERVER_CLIENT_ID}" ]]; then
  echo "Release Google iOS and server client IDs must be distinct" >&2
  exit 1
fi

expected_reversed_client_id=$(
  printf '%s' "${GOOGLE_IOS_CLIENT_ID}" |
    awk -F. '{ for (i = NF; i >= 1; i--) printf "%s%s", $i, (i > 1 ? "." : "") }'
)

if [[ "${GOOGLE_REVERSED_CLIENT_ID}" != "${expected_reversed_client_id}" ]]; then
  echo "Release Google reversed client ID does not match the iOS client ID" >&2
  exit 1
fi

echo "Study iOS Release Google auth configuration verified"
