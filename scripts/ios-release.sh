#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
PROJECT_FILE="$IOS_DIR/Nurio.xcodeproj"
SCHEME="Nurio"
ARCHIVE_PATH="$IOS_DIR/build/Nurio.xcarchive"
EXPORT_PATH="$IOS_DIR/build/export"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ ! -d "$IOS_DIR" ]; then
  echo -e "${RED}ERROR: iOS directory not found at $IOS_DIR${NC}"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo -e "${RED}ERROR: xcodebuild not found${NC}"
  exit 1
fi

echo -e "${BLUE}=== iOS App Store Connect Release ===${NC}"
echo

# Check current version
CURRENT_BUILD=$(grep -A 20 "buildSettings = {" "$PROJECT_FILE/project.pbxproj" | grep "CURRENT_PROJECT_VERSION" | head -n 1 | sed 's/.*= \([^;]*\);.*/\1/' | tr -d ' ')
CURRENT_MARKETING=$(grep -A 20 "buildSettings = {" "$PROJECT_FILE/project.pbxproj" | grep "MARKETING_VERSION" | head -n 1 | sed 's/.*= \([^;]*\);.*/\1/' | tr -d ' ')

echo -e "Current version: ${YELLOW}$CURRENT_MARKETING${NC} (build: ${YELLOW}$CURRENT_BUILD${NC})"
echo

# Ask if version bump is needed
read -r -p "Bump build number for this release? [y/N] " SHOULD_BUMP
if [[ "$SHOULD_BUMP" =~ ^[Yy]$ ]]; then
  NEW_BUILD=$((CURRENT_BUILD + 1))
  echo -e "Bumping build number: ${YELLOW}$CURRENT_BUILD${NC} → ${GREEN}$NEW_BUILD${NC}"

  # Update build number
  sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE/project.pbxproj"
  CURRENT_BUILD=$NEW_BUILD
  echo -e "${GREEN}✓ Build number updated to $NEW_BUILD${NC}"
  echo
fi

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild clean -project "$PROJECT_FILE" -scheme "$SCHEME" -quiet
echo -e "${GREEN}✓ Clean complete${NC}"
echo

# Build archive
echo -e "${BLUE}Building archive...${NC}"
echo "This may take several minutes..."

if xcodebuild archive \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  -allowProvisioningUpdates \
  -quiet; then
  echo -e "${GREEN}✓ Archive created successfully${NC}"
else
  echo -e "${RED}ERROR: Archive build failed${NC}"
  exit 1
fi

# Verify archive was created
if [ ! -d "$ARCHIVE_PATH" ]; then
  echo -e "${RED}ERROR: Archive not found at $ARCHIVE_PATH${NC}"
  exit 1
fi

echo
echo -e "${GREEN}Archive: $ARCHIVE_PATH${NC}"

# Get archive info for display
IPA_PATH="$ARCHIVE_PATH/Products/Applications/Nurio.app"
if [ -d "$IPA_PATH" ]; then
  SIZE=$(du -sh "$ARCHIVE_PATH" | cut -f1)
  echo -e "${GREEN}Archive size: $SIZE${NC}"
fi

echo
echo -e "${BLUE}=== Archive Build Complete ===${NC}"
echo -e "Version: ${GREEN}$CURRENT_MARKETING${NC} (build: ${GREEN}$CURRENT_BUILD${NC})"
echo -e "Archive: ${GREEN}$ARCHIVE_PATH${NC}"
echo

# Ask about uploading to App Store Connect
echo -e "${YELLOW}Next steps for App Store Connect submission:${NC}"
echo "1. Open Xcode:"
echo "   open \"$ARCHIVE_PATH\""
echo
echo "2. Or upload via command line:"
echo "   xcodebuild -exportArchive -archivePath \"$ARCHIVE_PATH\" -exportPath \"$EXPORT_PATH\" -exportOptionsPlist export-options.plist"
echo
echo "3. Or use Transporter app:"
echo "   open -a Transporter \"$ARCHIVE_PATH\""
echo

read -r -p "Open archive in Xcode now? [y/N] " SHOULD_OPEN
if [[ "$SHOULD_OPEN" =~ ^[Yy]$ ]]; then
  open "$ARCHIVE_PATH"
  echo -e "${GREEN}✓ Opened archive in Xcode${NC}"
fi

# Optional commit
if [[ "$SHOULD_BUMP" =~ ^[Yy]$ ]]; then
  echo
  read -r -p "Commit version bump now? [y/N] " SHOULD_COMMIT
  if [[ "$SHOULD_COMMIT" =~ ^[Yy]$ ]]; then
    cd "$PROJECT_ROOT"
    git add "$PROJECT_FILE/project.pbxproj"

    if git diff --cached --quiet -- "$PROJECT_FILE/project.pbxproj"; then
      echo -e "${YELLOW}No changes to commit.${NC}"
    else
      COMMIT_MESSAGE="chore(ios): bump version to $CURRENT_MARKETING (build $CURRENT_BUILD)"
      git commit -m "$COMMIT_MESSAGE" -- "$PROJECT_FILE/project.pbxproj"
      echo -e "${GREEN}✓ Committed: $COMMIT_MESSAGE${NC}"
    fi
  fi
fi
