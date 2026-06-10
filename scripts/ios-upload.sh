#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
ARCHIVE_PATH="$IOS_DIR/build/Nurio.xcarchive"
EXPORT_PATH="$IOS_DIR/build/export"
EXPORT_OPTIONS_PLIST="$IOS_DIR/export-options-app-store.plist"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo -e "${RED}ERROR: Archive not found at $ARCHIVE_PATH${NC}"
  echo -e "${YELLOW}Run 'task ios:archive' first${NC}"
  exit 1
fi

if [ ! -f "$EXPORT_OPTIONS_PLIST" ]; then
  echo -e "${RED}ERROR: Export options plist not found at $EXPORT_OPTIONS_PLIST${NC}"
  exit 1
fi

echo -e "${BLUE}=== Uploading to App Store Connect ===${NC}"
echo

# Export IPA from archive
echo -e "${BLUE}Exporting IPA from archive...${NC}"
rm -rf "$EXPORT_PATH"

if xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -quiet; then
  echo -e "${GREEN}✓ Export complete${NC}"
else
  echo -e "${RED}ERROR: Export failed${NC}"
  exit 1
fi

# Find the IPA file
IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" -type f | head -n 1)

if [ -z "$IPA_FILE" ]; then
  echo -e "${RED}ERROR: IPA file not found in $EXPORT_PATH${NC}"
  exit 1
fi

echo -e "${GREEN}IPA: $IPA_FILE${NC}"
SIZE=$(du -h "$IPA_FILE" | cut -f1)
echo -e "${GREEN}Size: $SIZE${NC}"
echo

# Check for altool availability
if ! command -v xcrun >/dev/null 2>&1 || ! xcrun altool --help >/dev/null 2>&1; then
  echo -e "${YELLOW}ALERT: xcrun altool not available${NC}"
  echo -e "${YELLOW}Please use one of these alternatives:${NC}"
  echo
  echo "1. Open archive in Xcode:"
  echo "   open \"$ARCHIVE_PATH\""
  echo
  echo "2. Use Transporter app:"
  echo "   open -a Transporter \"$IPA_FILE\""
  echo
  echo "3. Upload via Application Loader (deprecated but may still work)"
  echo
  exit 0
fi

# Prompt for Apple ID credentials
echo -e "${BLUE}App Store Connect Upload${NC}"
echo
read -r -p "Apple ID: " APPLE_ID
read -r -s -p "App-specific password: " APP_PASSWORD
echo
echo

# Upload to App Store Connect
echo -e "${BLUE}Uploading to App Store Connect...${NC}"
echo "This may take several minutes depending on your internet speed..."
echo

if xcrun altool --upload-app \
  --type ios \
  --file "$IPA_FILE" \
  --username "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --output-format xml; then
  echo
  echo -e "${GREEN}✓ Upload successful!${NC}"
  echo -e "${GREEN}Check App Store Connect for processing status${NC}"
else
  EXIT_CODE=$?
  echo
  if [ $EXIT_CODE -eq 231 ]; then
    echo -e "${RED}ERROR: Invalid credentials${NC}"
    echo -e "${YELLOW}Create app-specific password: https://appleid.apple.com${NC}"
  else
    echo -e "${RED}ERROR: Upload failed (code: $EXIT_CODE)${NC}"
  fi
  exit 1
fi
