#!/usr/bin/env python3
"""Check content provenance, legacy compatibility and exact offline media coverage."""

from hashlib import sha256
import json
from pathlib import Path
from uuid import UUID

APP = Path(__file__).resolve().parent.parent
RESOURCES = APP / "ios/Leanora/Resources"


if __name__ == "__main__":
    catalog = json.loads((RESOURCES / "Catalog/exercises.json").read_text())
    legacy = json.loads((APP / "content/exercises/leanora-v1.json").read_text())
    assert catalog["entries"][:100] == legacy["entries"], "Legacy data changed"
    assert catalog["source"] == legacy["source"]
    entries = {entry["id"]: entry for entry in catalog["entries"]}
    assert len(entries) == len(catalog["entries"]) == 882
    for uid in entries:
        UUID(uid)
    guides = json.loads((RESOURCES / "Catalog/exercise-guides.json").read_text())["entries"]
    assert {guide["exerciseID"] for guide in guides} == set(entries)
    assert len(guides) == len(entries)
    referenced = set()
    for guide in guides:
        assert guide["images"] and guide["credit"] and guide["sourceURL"].startswith("https://")
        assert guide["license"] in {"Unlicense", "CC BY-SA 4.0"}
        for image in guide["images"]:
            assert not Path(image).is_absolute() and ".." not in Path(image).parts
            referenced.add(image)
    root = RESOURCES / "ExerciseMedia"
    media = json.loads((root / "manifest.json").read_text())
    assert referenced == {image["path"] for image in media["images"]}
    actual = {str(file.relative_to(root)) for folder in (root / "free", root / "workout") for file in folder.rglob("*") if file.is_file()}
    assert actual == referenced, "Unused or missing bundled media"
    for image in media["images"]:
        data = (root / image["path"]).read_bytes()
        assert len(data) == image["bytes"] and sha256(data).hexdigest() == image["sha256"]
    assert len(list((root / "Notices").iterdir())) == 3
    assert all(guide["instructions"] for guide in guides[:100])
    assert not any("gymvisual" in image.lower() or "opengym" in image.lower() for image in referenced)
    print(json.dumps({"exercises": len(entries), "guides": len(guides), "images": len(referenced),
                      "legacyEntriesUnchanged": True, "mediaHashesValid": True,
                      "imageBytes": sum(image["bytes"] for image in media["images"])}, ensure_ascii=False))
