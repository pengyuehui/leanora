#!/usr/bin/env python3
"""Validate bundled foods, preserved legacy values, and optional official ZIP."""
import hashlib
import json
from pathlib import Path
import sys
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def main():
    catalog = json.loads((ROOT / "ios/Leanora/Resources/Catalog/foods.json").read_text())
    entries = catalog["entries"]
    assert catalog["version"] == 1 and len(entries) == 500
    by_id = {e["id"]: e for e in entries}
    assert len(by_id) == 500
    chinese = sum(any("\u4e00" <= c <= "\u9fff" for c in e["name"]) for e in entries)
    assert chinese >= 150
    legacy = json.loads((ROOT / "content/food-legacy-manifest.json").read_text())["records"]
    for old in legacy:
        entry = by_id[old["id"]]
        assert digest(entry["nutrients"]) == old["nutrients_sha256"], entry["name"]
        assert digest(entry["units"]) == old["units_sha256"], entry["name"]
    nested = set(by_id)
    for e in entries:
        assert str(uuid.uuid5(uuid.NAMESPACE_URL, e["reference"])) == e["id"]
        assert e["category"] and e["aliases"]
        for value in e["nutrients"].values():
            assert isinstance(value, (float, int)) and 0 <= value <= 100_000
        for unit in e["units"]:
            assert unit["id"] not in nested and 0 < unit["grams"] <= 100_000
            assert unit["conversionSource"] == e["reference"]
            nested.add(unit["id"])
    source_checked = False
    if len(sys.argv) > 1:
        source = Path(sys.argv[1])
        manifest = json.loads((ROOT / "docs/food-catalog-manifest.json").read_text())
        assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest["sha256"]
        with zipfile.ZipFile(source) as archive:
            raw = json.loads(archive.read(archive.namelist()[0]))["SRLegacyFoods"]
        foods = {f["fdcId"]: f for f in raw}
        for e in entries:
            f = foods[int(e["reference"].split("/")[-2])]
            assert f["description"] in e["aliases"]
            values = {v["nutrient"]["id"]: v.get("amount") for v in f["foodNutrients"]}
            expected = {k: values[n] for k, n in [("energyKcal", 1008), ("proteinGrams", 1003), ("carbohydrateGrams", 1005), ("fatGrams", 1004)] if values.get(n) is not None}
            assert e["nutrients"] == expected, e["name"]
            portions = {str(uuid.uuid5(uuid.NAMESPACE_URL, f"{e['reference']}/portion/{p['id']}")): p for p in f.get("foodPortions", [])[:8]}
            for unit in e["units"]:
                assert unit["grams"] == portions[unit["id"]]["gramWeight"]
        source_checked = True
    result = {"date": "2026-10-30", "foods": 500, "chinese_names": chinese, "legacy_values_preserved": len(legacy), "official_source_all_values_checked": source_checked}
    (ROOT / "docs/food-catalog-verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
