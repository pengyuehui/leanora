"""Read HBC 96 string tables, without executing the application.

Layout reference: facebook/hermes include/hermes/BCGen/HBC/BytecodeFileFormat.h.
Output records retain string IDs and byte ranges. They establish literals,
not which code paths run or a production database schema.
"""
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "analysis/inputs/xunji-index.android.bundle"
data = source.read_bytes()
magic, version = struct.unpack_from("<QI", data)
assert magic == 0x1F1903C103BC1FC6 and version == 96
assert hashlib.sha1(data[:-20]).digest() == data[-20:], "HBC footer mismatch"
keys = "fileLength globalCodeIndex functionCount stringKindCount identifierCount stringCount overflowStringCount stringStorageSize bigIntCount bigIntStorageSize regExpCount regExpStorageSize arrayBufferSize objKeyBufferSize objValueBufferSize segmentID cjsModuleCount functionSourceCount debugInfoOffset".split()
header = dict(zip(keys, struct.unpack_from("<19I", data, 32)))
assert header["fileLength"] == len(data)
table = 128 + header["functionCount"] * 16 + header["stringKindCount"] * 4 + header["identifierCount"] * 4
overflow = table + header["stringCount"] * 4
storage = overflow + header["overflowStringCount"] * 8
records = []
for sid in range(header["stringCount"]):
    value = struct.unpack_from("<I", data, table + sid * 4)[0]
    utf16, offset, length = value & 1, (value >> 1) & 0x7FFFFF, value >> 24
    if length == 255:
        assert offset < header["overflowStringCount"]
        offset, length = struct.unpack_from("<II", data, overflow + offset * 8)
    size = length * (2 if utf16 else 1)
    assert offset + size <= header["stringStorageSize"]
    text = data[storage + offset:storage + offset + size].decode("utf-16-le" if utf16 else "latin-1", errors="surrogatepass")
    records.append({"id": sid, "offset": storage + offset, "bytes": size, "encoding": "utf16le" if utf16 else "latin1", "text": text})
out = ROOT / "analysis/evidence"
(out / "xunji-hermes-header.json").write_text(json.dumps({"version": version, "sha256": hashlib.sha256(data).hexdigest(), "footer_sha1_valid": True, "header": header, "string_table_offset": table, "string_storage_offset": storage}, indent=2))
with (out / "xunji-hermes-strings.jsonl").open("w") as handle:
    for record in records:
        handle.write(json.dumps(record, ensure_ascii=True) + "\n")
patterns = {
    "pages": r"(?:Screen|Page|Stack|Navigator|Tabs|Modal)$|^(?:[A-Z][a-z]+){1,4}(?:Detail|History|Setting|Edit)$",
    "storage": r"CREATE TABLE|create table|\b(?:schemaVersion|primaryKey|objectType|properties)\b|realm|watermelon|sqlite|persist|mmkv",
    "training_fields": r"(?:workout|exercise|muscle|training|plan|routine|set|rep|weight|rest|duration|record|volume|rpe|rir|body|food|protein|carbohydrate|calorie|fat|meal|nutrition|diet|sync)[_A-Z]|^(?:get|add|update|delete|save)(?:Workout|Exercise|Training|Plan|Record|Diet|Food|Body|Set)",
    "product_copy": r"训练计划|训练记录|训练容量|超级组|递减组|热身组|力竭|休息计时|组间休息|动作库|动作详情|饮食记录|饮食计划|食物库|营养目标|身体数据|围度|体脂|历史记录|个人纪录|最大重量|训练统计|同步|离线",
    "endpoints": r"^https?://[^\s]{1,180}$|^/(?:api/|v[1-9]/)",
}
for group, pattern in patterns.items():
    selected = [r for r in records if re.search(pattern, r["text"], re.I if group in {"storage", "training_fields"} else 0) and len(r["text"]) < 1600]
    (out / f"xunji-{group}.json").write_text(json.dumps(selected, ensure_ascii=False, indent=2), errors="backslashreplace")
    print(group, len(selected))
print("Validated strings:", len(records))
