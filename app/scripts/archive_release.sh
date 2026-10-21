#!/bin/bash
# Produces a local unsigned iPhone archive. No upload, credentials or account changes.
set -euo pipefail
leanora_root="$(cd "$(dirname "$0")/.." && pwd)"
leanora_archive="${1:-$leanora_root/build/Release/Leanora.xcarchive}"
if [[ -e "$leanora_archive" ]]; then
  echo "Archive already exists; choose a new path: $leanora_archive" >&2
  exit 2
fi
xcodebuild -project "$leanora_root/ios/Leanora.xcodeproj" -scheme Leanora \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$leanora_root/build/ReleaseDerivedData" \
  -archivePath "$leanora_archive" CODE_SIGNING_ALLOWED=NO archive
echo "Unsigned archive: $leanora_archive"
echo 'For TestFlight, sign a new archive with your registered Bundle ID and Developer Team, then validate in Xcode Organizer.'
