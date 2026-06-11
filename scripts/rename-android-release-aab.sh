#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle.kts"
OUTPUT_DIR="$PROJECT_ROOT/android/app/build/outputs/bundle/release"
AAB_FILE="$OUTPUT_DIR/app-release.aab"

CODE=$(sed -n 's/.*versionCode = \([0-9]*\)/\1/p' "$GRADLE_FILE")
NAME=$(sed -n 's/.*versionName = "\([^"]*\)"/\1/p' "$GRADLE_FILE")

if [[ -z "$CODE" || -z "$NAME" ]]; then
    echo "ERROR: Could not read versionName/versionCode from $GRADLE_FILE"
    exit 1
fi

if [[ ! -f "$AAB_FILE" ]]; then
    echo "ERROR: AAB file not found at $AAB_FILE"
    exit 1
fi

RENAMED_AAB_FILE="$OUTPUT_DIR/nurio-android-release-v${NAME}-${CODE}.aab"
mv -f "$AAB_FILE" "$RENAMED_AAB_FILE"
echo "$RENAMED_AAB_FILE"
