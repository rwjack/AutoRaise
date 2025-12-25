#!/bin/bash

set -e

APP_NAME="AutoRaise"
APP_PATH="${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_TEMP="${DMG_NAME}.tmp.dmg"

# Check if app exists
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: ${APP_PATH} not found. Run 'make gui-app' first."
    exit 1
fi

# Calculate size needed for DMG
SIZE=$(du -sm "${APP_PATH}" | cut -f1)
SIZE=$((SIZE + 20)) # Add 20MB buffer

echo "Creating DMG: ${DMG_NAME}"

# Create temporary DMG
hdiutil create -srcfolder "${APP_PATH}" -volname "${VOLUME_NAME}" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size ${SIZE}M "${DMG_TEMP}"

# Mount the DMG
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | \
    egrep '^/dev/' | sed 1q | awk '{print $1}')

# Wait for mount
sleep 2

# Unmount
hdiutil detach "${DEVICE}"

# Convert to compressed read-only DMG
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"

# Remove temporary DMG
rm -f "${DMG_TEMP}"

echo "Successfully created ${DMG_NAME}"

