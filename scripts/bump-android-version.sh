#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GRADLE_FILE="$PROJECT_ROOT/android/app/build.gradle.kts"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ ! -f "$GRADLE_FILE" ]; then
  echo -e "${RED}ERROR: $GRADLE_FILE not found${NC}"
  exit 1
fi

# Extract current versions
CURRENT_CODE=$(sed -n 's/.*versionCode = \([0-9]*\)/\1/p' "$GRADLE_FILE")
CURRENT_NAME=$(sed -n 's/.*versionName = "\([^"]*\)"/\1/p' "$GRADLE_FILE")

if [ -z "$CURRENT_CODE" ]; then
  echo -e "${RED}ERROR: Could not find versionCode in $GRADLE_FILE${NC}"
  exit 1
fi

if [ -z "$CURRENT_NAME" ]; then
  echo -e "${RED}ERROR: Could not find versionName in $GRADLE_FILE${NC}"
  exit 1
fi

# Parse arguments
# Unlike iOS (which resets the build number to 1 on a marketing bump), Android
# versionCode must be strictly increasing — Play rejects reused codes. So every
# bump here increments versionCode, and versionName only changes for
# major/minor/patch. The Play-anchored logic in the fastlane android:beta lane
# remains the monotonic source of truth and will raise this code further if Play
# is already ahead.
BUMP_TYPE="${1:-code}"
NEW_CODE=""
NEW_NAME=""

case "$BUMP_TYPE" in
  code)
    # Only increment versionCode; versionName unchanged
    NEW_CODE=$((CURRENT_CODE + 1))
    NEW_NAME="$CURRENT_NAME"
    ;;
  major|minor|patch)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_NAME"

    case "$BUMP_TYPE" in
      major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_NAME="$NEW_MAJOR.0.0"
        ;;
      minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_NAME="$MAJOR.$NEW_MINOR.0"
        ;;
      patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_NAME="$MAJOR.$MINOR.$NEW_PATCH"
        ;;
    esac
    # Always strictly increase versionCode (never reset on Android)
    NEW_CODE=$((CURRENT_CODE + 1))
    ;;
  *)
    echo -e "${RED}ERROR: Invalid bump type '$BUMP_TYPE'${NC}"
    echo "Usage: $0 [code|major|minor|patch]"
    echo "  code   - Increment versionCode only (default)"
    echo "  major  - Bump major version (1.0.0 -> 2.0.0) and increment versionCode"
    echo "  minor  - Bump minor version (1.0.0 -> 1.1.0) and increment versionCode"
    echo "  patch  - Bump patch version (1.0.0 -> 1.0.1) and increment versionCode"
    exit 1
    ;;
esac

echo -e "${BLUE}=== Android Version Bump ===${NC}"
echo -e "Current:  ${YELLOW}$CURRENT_NAME${NC} (code: ${YELLOW}$CURRENT_CODE${NC})"
echo -e "New:      ${GREEN}$NEW_NAME${NC} (code: ${GREEN}$NEW_CODE${NC})"
echo

# Confirm
read -r -p "Continue with version bump? [y/N] " SHOULD_PROCEED
if [[ ! "$SHOULD_PROCEED" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# Update versionCode
sed -i '' "s/versionCode = $CURRENT_CODE/versionCode = $NEW_CODE/" "$GRADLE_FILE"

# Update versionName if changed
if [ "$NEW_NAME" != "$CURRENT_NAME" ]; then
  sed -i '' "s/versionName = \"$CURRENT_NAME\"/versionName = \"$NEW_NAME\"/" "$GRADLE_FILE"
fi

echo -e "${GREEN}✓ Updated $GRADLE_FILE${NC}"
echo

# Show updated version
echo -e "${GREEN}New version: $NEW_NAME (code: $NEW_CODE)${NC}"
echo

# Optional commit
read -r -p "Commit version bump now? [y/N] " SHOULD_COMMIT
if [[ "$SHOULD_COMMIT" =~ ^[Yy]$ ]]; then
  cd "$PROJECT_ROOT"
  git add "android/app/build.gradle.kts"

  if git diff --cached --quiet -- "android/app/build.gradle.kts"; then
    echo -e "${YELLOW}No changes to commit.${NC}"
  else
    COMMIT_MESSAGE="chore(android): bump version to $NEW_NAME (code $NEW_CODE)"
    git commit -m "$COMMIT_MESSAGE" -- "android/app/build.gradle.kts"
    echo -e "${GREEN}✓ Committed: $COMMIT_MESSAGE${NC}"
  fi
else
  echo "Skipped commit. Version bump remains uncommitted."
fi
