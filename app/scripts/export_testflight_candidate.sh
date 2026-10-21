#!/bin/bash
# Export a local App Store Connect IPA. This does not upload a build.
set -euo pipefail
leanora_root="$(cd "$(dirname "$0")/.." && pwd)"
leanora_archive="${1:?Usage: export_testflight_candidate.sh signed.xcarchive new-export-directory}"
leanora_export="${2:?Usage: export_testflight_candidate.sh signed.xcarchive new-export-directory}"
if [[ ! -f "$leanora_archive/Info.plist" ]]; then
  echo "Archive not found: $leanora_archive" >&2
  exit 2
fi
if [[ -e "$leanora_export" ]]; then
  echo "Export directory already exists; choose a new path: $leanora_export" >&2
  exit 2
fi
xcodebuild -exportArchive -archivePath "$leanora_archive" \
  -exportPath "$leanora_export" \
  -exportOptionsPlist "$leanora_root/config/ExportOptions-AppStore.plist" \
  -allowProvisioningUpdates
echo "Local App Store Connect candidate: $leanora_export"
