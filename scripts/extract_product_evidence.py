"""Produce focused product evidence from already decoded local artifacts."""
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "analysis/evidence"
all_strings = [json.loads(line) for line in (OUT / "xunji-hermes-strings.jsonl").open()]
sql = [r for r in all_strings if re.search(r"\b(?:CREATE TABLE|ALTER TABLE|INSERT INTO|UPDATE localtrains|UPDATE movements)", r["text"], re.I)]
(OUT / "xunji-sql-literals.json").write_text(json.dumps(sql, ensure_ascii=False, indent=2))
with (OUT / "xunji-schema-literals.sql").open("w") as handle:
    handle.write("-- Observed HBC literals; NOT a verified live schema or an executable migration.\n")
    for record in sql:
        if re.search(r"\b(?:CREATE TABLE|ALTER TABLE)", record["text"], re.I):
            handle.write(f"\n-- HBC string {record['id']}, byte offset {record['offset']}\n{record['text']}\n")

decoded = (OUT / "boohee-resources.txt").read_text()
resources = {}
for match in re.finditer(r"^    resource (0x[0-9a-f]+) ([^\s]+)([^\n]*)\n((?:(?!    resource |  type ).*\n)*)", decoded, re.M):
    resources[match[1]] = {"name": match[2], "declarations": match[4].strip()}
(OUT / "boohee-resource-map.json").write_text(json.dumps(resources, ensure_ascii=False, indent=2))
with (OUT / "boohee-product-resource-excerpts.txt").open("w") as handle:
    for rid, record in resources.items():
        if re.search(r"^(string|id|layout)/.*(?:food|diet|meal|calor|weight|fat|protein|carbo|nutri|record|sport|water|fasting|target)", record["name"], re.I):
            handle.write(rid + " " + record["name"] + "\n" + record["declarations"] + "\n")

archive = json.loads((OUT / "boohee-archive.json").read_text())
layouts = [r["path"] for r in archive if re.match(r"res/layout/", r["path"]) and re.search(r"(?:food|diet|sport|weight|record|ai_|nutrition|nutrient|custom|search|fasting|new_user)", r["path"])]
(OUT / "boohee-product-layouts.json").write_text(json.dumps(layouts, ensure_ascii=False, indent=2))

selected = [
    "res/layout/act_food_nutrition_information_v2.xml",
    "res/layout/act_new_user_evaluating.xml",
    "res/layout/act_new_user_evaluating_confirm.xml",
    "res/layout/act_ai_chat.xml",
    "res/layout/activity_add_food_list_new.xml",
    "res/layout/activity_add_costom_food.xml",
    "res/layout/activity_food_search.xml",
    "res/layout/fragment_base_diet.xml",
    "res/layout/view_eat_weight.xml",
    "res/layout/view_diet_unit.xml",
    "res/layout/dialog_diet_quick_record.xml",
    "res/layout/item_food_search_result.xml",
    "res/layout/fragment_diet_calendar.xml",
]
for pattern in [r"^res/layout/.*(?:activity|act)_.*(?:custom_food|diet_camera|diet_record|search_food|food_detail|nutrition_proportion|weight_record|sport_record|diet_sport|food_quantity|food_unit).*\.xml$"]:
    selected.extend(name for name in layouts if re.search(pattern, name))
aapt = "/Users/pengyuehui/Library/Android/sdk/build-tools/35.0.0/aapt2"
layout_out = OUT / "boohee-layouts"
layout_out.mkdir(exist_ok=True)
manifest = []
for name in dict.fromkeys(selected):
    if name not in {r["path"] for r in archive}:
        continue
    result = subprocess.run([aapt, "dump", "xmltree", "/Users/pengyuehui/Downloads/com.boohee.one_15.8.1.apk", "--file", name], check=True, capture_output=True, text=True)
    text = result.stdout
    for rid, record in resources.items():
        if rid in text:
            text = text.replace("@" + rid, "@" + record["name"] + "[" + rid + "]")
    filename = layout_out / (Path(name).stem + ".txt")
    filename.write_text(text)
    manifest.append({"apk_member": name, "decoded_path": str(filename.relative_to(ROOT))})
(OUT / "boohee-decoded-layout-index.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))

connection = sqlite3.connect(f"file:{ROOT}/analysis/inputs/bhdb.sqlite?mode=ro", uri=True)
tables = []
for name, declaration in connection.execute("SELECT name,sql FROM sqlite_master WHERE type='table' ORDER BY name"):
    identifier = '"' + name.replace('"', '""') + '"'
    rows = connection.execute(f"SELECT * FROM {identifier} LIMIT 5").fetchall()
    tables.append({"table": name, "sql": declaration, "row_count": connection.execute(f"SELECT COUNT(*) FROM {identifier}").fetchone()[0], "sample": rows})
connection.close()
(OUT / "boohee-database-inventory.json").write_text(json.dumps(tables, ensure_ascii=False, indent=2))
print(json.dumps({"sql_literals": len(sql), "resource_ids": len(resources), "product_layout_candidates": len(layouts), "decoded_layouts": len(manifest), "database_tables": len(tables)}))
