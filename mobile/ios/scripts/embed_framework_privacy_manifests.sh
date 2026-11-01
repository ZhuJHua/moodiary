#!/bin/sh
# Flutter has no native-assets privacy manifest support (flutter/flutter#140966,
# flutter/flutter#147186), so inject manifests after embedding and repair signatures.
set -eu

frameworks_dir="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
templates_dir="$SRCROOT/PrivacyManifests"

embed_manifest() {
    fw=$1
    if [ ! -d "$fw" ]; then
        echo "error: Missing framework: $fw" >&2
        exit 1
    fi
    cp "$templates_dir/$2" "$fw/PrivacyInfo.xcprivacy"
    if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
        codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --preserve-metadata=identifier,entitlements -- "$fw"
    fi
}

found_fast=0
for fw in "$frameworks_dir"/fast*.framework; do
    [ -d "$fw" ] || continue
    found_fast=1
    embed_manifest "$fw" rust.xcprivacy
done
if [ "$found_fast" -eq 0 ]; then
    echo "error: No fast*.framework found in $frameworks_dir" >&2
    exit 1
fi

embed_manifest "$frameworks_dir/sqlite3.framework" sqlite3.xcprivacy
embed_manifest "$frameworks_dir/IsarPlusCore.framework" isar.xcprivacy
