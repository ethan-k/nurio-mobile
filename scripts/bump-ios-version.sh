#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
PROJECT_FILE="$IOS_DIR/Nurio.xcodeproj/project.pbxproj"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ ! -f "$PROJECT_FILE" ]; then
  echo -e "${RED}ERROR: $PROJECT_FILE not found${NC}"
  exit 1
fi

# Extract current versions
CURRENT_BUILD=$(grep -A 20 "buildSettings = {" "$PROJECT_FILE" | grep "CURRENT_PROJECT_VERSION" | head -n 1 | sed 's/.*= \([^;]*\);.*/\1/' | tr -d ' ')
CURRENT_MARKETING=$(grep -A 20 "buildSettings = {" "$PROJECT_FILE" | grep "MARKETING_VERSION" | head -n 1 | sed 's/.*= \([^;]*\);.*/\1/' | tr -d ' ')

if [ -z "$CURRENT_BUILD" ]; then
  echo -e "${RED}ERROR: Could not find CURRENT_PROJECT_VERSION in $PROJECT_FILE${NC}"
  exit 1
fi

if [ -z "$CURRENT_MARKETING" ]; then
  echo -e "${RED}ERROR: Could not find MARKETING_VERSION in $PROJECT_FILE${NC}"
  exit 1
fi

# Parse arguments
BUMP_TYPE="${1:-build}"
NEW_BUILD=""
NEW_MARKETING=""

case "$BUMP_TYPE" in
  build)
    # Only increment build number
    NEW_BUILD=$((CURRENT_BUILD + 1))
    NEW_MARKETING="$CURRENT_MARKETING"
    ;;
  major|minor|patch)
    # Bump marketing version and reset build to 1
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_MARKETING"

    case "$BUMP_TYPE" in
      major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_MARKETING="$NEW_MAJOR.0.0"
        ;;
      minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_MARKETING="$MAJOR.$NEW_MINOR.0"
        ;;
      patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_MARKETING="$MAJOR.$MINOR.$NEW_PATCH"
        ;;
    esac
    NEW_BUILD=1
    ;;
  *)
    echo -e "${RED}ERROR: Invalid bump type '$BUMP_TYPE'${NC}"
    echo "Usage: $0 [build|major|minor|patch]"
    echo "  build  - Increment build number only (default)"
    echo "  major  - Increment major version and reset build (1.0.0 -> 2.0.0)"
    echo "  minor  - Increment minor version and reset build (1.0.0 -> 1.1.0)"
    echo "  patch  - Increment patch version and reset build (1.0.0 -> 1.0.1)"
    exit 1
    ;;
esac

echo -e "${BLUE}=== iOS Version Bump ===${NC}"
echo -e "Current:  ${YELLOW}$CURRENT_MARKETING${NC} (build: ${YELLOW}$CURRENT_BUILD${NC})"
echo -e "New:      ${GREEN}$NEW_MARKETING${NC} (build: ${GREEN}$NEW_BUILD${NC})"
echo

# Confirm
read -r -p "Continue with version bump? [y/N] " SHOULD_PROCEED
if [[ ! "$SHOULD_PROCEED" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

# Update build number in all Debug and Release configurations
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

# Update marketing version if changed
if [ "$NEW_MARKETING" != "$CURRENT_MARKETING" ]; then
  sed -i '' "s/MARKETING_VERSION = $CURRENT_MARKETING;/MARKETING_VERSION = $NEW_MARKETING;/g" "$PROJECT_FILE"
fi

echo -e "${GREEN}✓ Updated $PROJECT_FILE${NC}"
echo

# Show updated version
echo -e "${GREEN}New version: $NEW_MARKETING (build: $NEW_BUILD)${NC}"
echo

# Optional commit
read -r -p "Commit version bump now? [y/N] " SHOULD_COMMIT
if [[ "$SHOULD_COMMIT" =~ ^[Yy]$ ]]; then
  cd "$PROJECT_ROOT"
  git add "ios/Nurio.xcodeproj/project.pbxproj"

  if git diff --cached --quiet -- "ios/Nurio.xcodeproj/project.pbxproj"; then
    echo -e "${YELLOW}No changes to commit.${NC}"
  else
    COMMIT_MESSAGE="chore(ios): bump version to $NEW_MARKETING (build $NEW_BUILD)"
    git commit -m "$COMMIT_MESSAGE" -- "ios/Nurio.xcodeproj/project.pbxproj"
    echo -e "${GREEN}✓ Committed: $COMMIT_MESSAGE${NC}"
  fi
else
  echo "Skipped commit. Version bump remains uncommitted."
fi
