#!/bin/bash

set -e

# Required env vars:
# ZIP_PATH, GIT_TOKEN, BUILD_TIME
# GitHub automatically provides: GITHUB_REPOSITORY

TAG_NAME="${TARGET_DEVICE}-$(date +%s)"
RELEASE_NAME="${TARGET_DEVICE} Port For ${STOCK_DEVICE}"

echo "Uploading to GoFile..."
GOFILE_LINK=$(sudo bash upload.sh "$ZIP_PATH")
echo "🌎 File uploaded here: $GOFILE_LINK"

# File info
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
MD5_SUM=$(md5sum "$ZIP_PATH" | awk '{print $1}')

# Zabezpieczenie zmiennych przed pustymi wartościami
VERSION="${VERSION:-1.0}"
ANDROID_VERSION="${ANDROID_VERSION:-Unknown}"
ONE_UI_VERSION="${ONE_UI_VERSION:-Unknown}"
CPU_ABILIST="${CPU_ABILIST:-Unknown}"
OUTPUT_FILESYSTEM="${OUTPUT_FILESYSTEM:-erofs}"
COMPRESS_IMG_TO_XZ="${COMPRESS_IMG_TO_XZ:-False}"
USE_UI_8_TETHERING_APEX="${USE_UI_8_TETHERING_APEX:-False}"

# Release body
RELEASE_BODY="#### 🌎 Download:
$GOFILE_LINK

#### 📊 File Info:
• Size: $FILE_SIZE
• Build Time: $BUILD_TIME
• MD5: $MD5_SUM

#### 📱 Rom Info:
• Ported For: $STOCK_DEVICE
• Ported From: $TARGET_DEVICE
• Build Version: $VERSION
• Android Version: $ANDROID_VERSION
• One UI Version: $ONE_UI_VERSION
• CPU ABILIST: $CPU_ABILIST

#### ⚙️ Build Options:
• Filesystem: $OUTPUT_FILESYSTEM
• Compressed IMG: $COMPRESS_IMG_TO_XZ
• Used OneUI 8 Tethering APEX: $USE_UI_8_TETHERING_APEX
"

# Convert to JSON-safe string
JSON_BODY=$(printf '%s' "$RELEASE_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Create release
if [ -n "$GIT_TOKEN" ]; then
  echo "Creating GitHub Release..."
  curl -X POST \
    -H "Authorization: token ${GIT_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/${GITHUB_REPOSITORY}/releases \
    -d "{\"tag_name\":\"${TAG_NAME}\",\"target_commitish\":\"main\",\"name\":\"${RELEASE_NAME}\",\"body\":${JSON_BODY},\"draft\":false,\"prerelease\":false}"
else
  echo "Warning: GIT_TOKEN is empty. Skipping GitHub release creation."
fi
