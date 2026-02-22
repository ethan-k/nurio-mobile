#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle.kts"
GRADLE_FILE_REL="android/app/build.gradle.kts"
ANDROID_DIR="$PROJECT_ROOT/android"
OUTPUT_DIR="$ANDROID_DIR/app/build/outputs/bundle/release"

# Keep the current JAVA_HOME. Gradle daemon JVM is pinned in
# android/gradle/gradle-daemon-jvm.properties.

# Verify keystore exists
if [ ! -f "$ANDROID_DIR/keystore.properties" ]; then
    echo "ERROR: android/keystore.properties not found. Create it with:"
    echo "  storePassword=YOUR_PASSWORD"
    echo "  keyPassword=YOUR_PASSWORD"
    echo "  keyAlias=nurio"
    echo "  storeFile=../nurio-release.jks"
    exit 1
fi

# Read current versionCode and versionName
CURRENT_CODE=$(sed -n 's/.*versionCode = \([0-9]*\)/\1/p' "$GRADLE_FILE")
CURRENT_NAME=$(sed -n 's/.*versionName = "\([^"]*\)"/\1/p' "$GRADLE_FILE")

NEW_CODE=$((CURRENT_CODE + 1))

# Bump patch version: 1.0.0 -> 1.0.1
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_NAME"
NEW_PATCH=$((PATCH + 1))
NEW_NAME="$MAJOR.$MINOR.$NEW_PATCH"

echo "=== Nurio Release Build ==="
echo "Version: $CURRENT_NAME ($CURRENT_CODE) -> $NEW_NAME ($NEW_CODE)"
echo ""

# Update build.gradle.kts
sed -i '' "s/versionCode = $CURRENT_CODE/versionCode = $NEW_CODE/" "$GRADLE_FILE"
sed -i '' "s/versionName = \"$CURRENT_NAME\"/versionName = \"$NEW_NAME\"/" "$GRADLE_FILE"

echo "Updated build.gradle.kts"

# Build release AAB
echo ""
echo "Building release AAB..."
cd "$ANDROID_DIR"
./gradlew bundleRelease

AAB_FILE="$OUTPUT_DIR/app-release.aab"
if [ -f "$AAB_FILE" ]; then
    RENAMED_AAB_FILE="$OUTPUT_DIR/nurio-android-release-v${NEW_NAME}-${NEW_CODE}.aab"
    mv -f "$AAB_FILE" "$RENAMED_AAB_FILE"
    SIZE=$(du -h "$RENAMED_AAB_FILE" | cut -f1)
    echo ""
    echo "=== Build Successful ==="
    echo "Version: $NEW_NAME ($NEW_CODE)"
    echo "Output:  $RENAMED_AAB_FILE"
    echo "Size:    $SIZE"
else
    echo ""
    echo "ERROR: AAB file not found at $AAB_FILE"
    exit 1
fi

echo ""
read -r -p "Commit version bump change now? [y/N] " SHOULD_COMMIT
if [[ "$SHOULD_COMMIT" =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    git add "$GRADLE_FILE_REL"

    if git diff --cached --quiet -- "$GRADLE_FILE_REL"; then
        echo "No changes in $GRADLE_FILE_REL to commit."
    else
        COMMIT_MESSAGE="chore(release): bump Android to $NEW_NAME ($NEW_CODE)"
        git commit -m "$COMMIT_MESSAGE" -- "$GRADLE_FILE_REL"
        echo "Committed: $COMMIT_MESSAGE"
    fi
else
    echo "Skipped commit. Version bump remains uncommitted."
fi
