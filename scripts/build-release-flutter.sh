#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_DIR="$PROJECT_ROOT/flutter_app"
PUBSPEC_FILE="$FLUTTER_DIR/pubspec.yaml"
PUBSPEC_FILE_REL="flutter_app/pubspec.yaml"
OUTPUT_DIR="$FLUTTER_DIR/build/app/outputs/bundle/release"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter command not found in PATH."
  exit 1
fi

if [ ! -f "$PUBSPEC_FILE" ]; then
  echo "ERROR: Missing $PUBSPEC_FILE"
  exit 1
fi

CURRENT_VERSION_LINE=$(grep -E '^version:' "$PUBSPEC_FILE" | head -n1 | tr -d ' ')

if [[ ! "$CURRENT_VERSION_LINE" =~ ^version:([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  echo "ERROR: Could not parse version from $PUBSPEC_FILE"
  echo "Expected format: version: x.y.z+n"
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"
BUILD="${BASH_REMATCH[4]}"

NEW_PATCH=$((PATCH + 1))
NEW_BUILD=$((BUILD + 1))

CURRENT_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD"
NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH+$NEW_BUILD"
NEW_NAME="$MAJOR.$MINOR.$NEW_PATCH"

echo "=== Nurio Flutter Release Build ==="
echo "Version: $CURRENT_VERSION -> $NEW_VERSION"
echo

# Update pubspec version
sed -i '' "s/^version: $CURRENT_VERSION$/version: $NEW_VERSION/" "$PUBSPEC_FILE"

echo "Updated flutter_app/pubspec.yaml"
echo

echo "Running flutter pub get..."
(
  cd "$FLUTTER_DIR"
  flutter pub get >/dev/null
)

echo "Building release AAB..."
(
  cd "$FLUTTER_DIR"
  flutter build appbundle --release
)

AAB_FILE="$OUTPUT_DIR/app-release.aab"
if [ -f "$AAB_FILE" ]; then
  RENAMED_AAB_FILE="$OUTPUT_DIR/nurio-flutter-release-v${NEW_NAME}-${NEW_BUILD}.aab"
  mv -f "$AAB_FILE" "$RENAMED_AAB_FILE"
  SIZE=$(du -h "$RENAMED_AAB_FILE" | cut -f1)
  echo
  echo "=== Build Successful ==="
  echo "Version: $NEW_VERSION"
  echo "Output:  $RENAMED_AAB_FILE"
  echo "Size:    $SIZE"
else
  echo
  echo "ERROR: AAB file not found at $AAB_FILE"
  exit 1
fi

echo
read -r -p "Commit Flutter version bump now? [y/N] " SHOULD_COMMIT
if [[ "$SHOULD_COMMIT" =~ ^[Yy]$ ]]; then
  cd "$PROJECT_ROOT"
  git add "$PUBSPEC_FILE_REL"

  if git diff --cached --quiet -- "$PUBSPEC_FILE_REL"; then
    echo "No changes in $PUBSPEC_FILE_REL to commit."
  else
    COMMIT_MESSAGE="chore(release): bump Flutter to $NEW_VERSION"
    git commit -m "$COMMIT_MESSAGE" -- "$PUBSPEC_FILE_REL"
    echo "Committed: $COMMIT_MESSAGE"
  fi
else
  echo "Skipped commit. Version bump remains uncommitted."
fi
