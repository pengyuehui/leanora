#!/usr/bin/env python3
"""Validate deterministic exports; optionally inspect a locally built Release app."""
import argparse
from datetime import date
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import plistlib
import struct
from urllib.parse import unquote, urlsplit

parser = argparse.ArgumentParser()
parser.add_argument("--release-app", type=Path)
parser.add_argument("--report", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
store = root / "store"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def png(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return {"width": width, "height": height, "bit_depth": depth, "color_type": color, "sha256": digest(path)}

shots = json.loads((store / "screenshots.json").read_text())
assert len(shots) == 7
exports = {}
for folder, size in [("iphone-medium", (1206, 2622)), ("iphone-large", (1320, 2868))]:
    for shot in shots:
        path = store / "zh-Hans" / folder / f'{shot["id"]}.png'
        info = png(path)
        assert (info["width"], info["height"]) == size
        assert info["color_type"] == 2, "Store assets must be RGB without alpha"
        exports[str(path.relative_to(store))] = info
sources = {}
for shot in shots:
    path = store / "zh-Hans/source" / f'{shot["source"]}.png'
    info = png(path)
    assert (info["width"], info["height"]) == (1398, 2034)
    sources[str(path.relative_to(store))] = info
icon = png(store / "brand/app-icon-1024.png")
assert (icon["width"], icon["height"], icon["color_type"]) == (1024, 1024, 2)
assert icon["sha256"] == digest(root / "ios/Leanora/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
metadata = json.loads((store / "metadata.json").read_text())
assert len(metadata["app_name"]) <= 30
lengths = {}
for locale, values in metadata["locales"].items():
    counts = {"subtitle_characters": len(values["subtitle"]), "promotional_text_characters": len(values["promotional_text"]), "description_characters": len(values["description"]), "keyword_utf8_bytes": len(values["keywords"].encode()), "whats_new_characters": len(values["whats_new"])}
    assert counts["subtitle_characters"] <= 30 and counts["promotional_text_characters"] <= 170
    assert counts["description_characters"] <= 4000 and counts["whats_new_characters"] <= 4000 and counts["keyword_utf8_bytes"] <= 100
    assert all(len(keyword) > 2 for keyword in values["keywords"].split(","))
    lengths[locale] = counts
class References(HTMLParser):
    def __init__(self):
        super().__init__(); self.local = []
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in ["src", "href"] and value:
                url = urlsplit(value)
                if not url.scheme and url.path: self.local.append(unquote(url.path))
references = References(); references.feed((store / "index.html").read_text())
assert all((store / name).resolve().is_file() for name in references.local)
summary = json.loads((store / "screenshot-test-summary.json").read_text())
assert summary["result"] == "Passed" and summary["passedTests"] == 1 and summary["failedTests"] == 0
report = {"checked_date": date.today().isoformat(), "upload_asset_count": 15, "store_screenshots": exports, "native_sources": sources, "app_icon": icon, "metadata_lengths": lengths, "local_html_references": len(references.local), "capture_test_result": summary["result"], "capture_test_count": 1, "browser_proof": {"path": "preview-desktop.png", "sha256": digest(store / "preview-desktop.png")}, "publication": "local_asset_validation_only; live submission status is in " + metadata["release_record"], "release_archive": None}
if args.release_app:
    app = args.release_app.resolve()
    info = plistlib.loads((app / "Info.plist").read_bytes())
    binary = (app / info["CFBundleExecutable"]).read_bytes()
    markers = ["--store-screenshots", "Store capture:", "createStoreSamples", "上肢力量 A"]
    assert not any(marker.encode() in binary for marker in markers)
    assert info["CFBundleIdentifier"] == "ai.leanora.fitness" and info["MinimumOSVersion"] == "18.0"
    assert info["CFBundleIcons"]["CFBundlePrimaryIcon"]["CFBundleIconName"] == "AppIcon"
    report["release_archive"] = {"app_path": str(app.relative_to(root)), "bundle_id": info["CFBundleIdentifier"], "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"], "minimum_os": info["MinimumOSVersion"], "executable_sha256": hashlib.sha256(binary).hexdigest(), "debug_markers_absent": markers, "signed": False, "uploaded": False}
if args.report:
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"store_screenshots": len(exports), "native_sources": len(sources), "icon": "1024x1024 RGB", "metadata_lengths": lengths, "local_html_references": len(references.local), "release_checked": bool(args.release_app)}, ensure_ascii=False))
