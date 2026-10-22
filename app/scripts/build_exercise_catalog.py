#!/usr/bin/env python3
"""Build the exercise catalog and offline media from pinned, licensed sources.

Build dependency only: Pillow 12.3.0. Never executes upstream code.
Use --download to fetch missing source images; otherwise rebuild from the cache.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
from hashlib import sha1, sha256
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
from urllib.parse import quote
from urllib.request import urlopen
from uuid import UUID, uuid5
from zipfile import ZipFile

from PIL import Image, ImageOps

APP = Path(__file__).resolve().parent.parent
CONTENT = APP / "content/exercises"
CATALOG = APP / "ios/Leanora/Resources/Catalog"
MEDIA = APP / "ios/Leanora/Resources/ExerciseMedia"
CACHE = APP / "build/exercise-sources"
LOCK = json.loads((CONTENT / "source-lock.json").read_text())
NAMESPACE = UUID("858ff2ad-50c0-4d1a-8a1e-6242b942a24a")

MUSCLES = {
    "abdominals": "腹肌", "abductors": "髋外展肌群", "adductors": "髋内收肌群",
    "biceps": "肱二头肌", "calves": "小腿", "chest": "胸部", "forearms": "前臂",
    "glutes": "臀部", "hamstrings": "腘绳肌", "lats": "背阔肌", "lower back": "下背部",
    "middle back": "中背部", "neck": "颈部", "quadriceps": "股四头肌", "shoulders": "肩部",
    "traps": "斜方肌", "triceps": "肱三头肌", "core": "核心", "quads": "股四头肌", "cardio": "心肺",
}
GROUPS = {"腹肌": "核心", "髋外展肌群": "下肢", "髋内收肌群": "下肢", "小腿": "下肢",
          "臀部": "下肢", "腘绳肌": "下肢", "股四头肌": "下肢", "背阔肌": "背部",
          "下背部": "背部", "中背部": "背部", "斜方肌": "背部", "肱二头肌": "手臂",
          "肱三头肌": "手臂", "前臂": "手臂"}
EQUIPMENT = {"bands": "弹力带", "barbell": "杠铃", "body only": "自重", "cable": "绳索器械",
             "dumbbell": "哑铃", "e-z curl bar": "曲杆", "exercise ball": "健身球",
             "foam roll": "泡沫轴", "kettlebells": "壶铃", "machine": "固定器械",
             "medicine ball": "药球", "other": "其他器械", None: "未注明"}
CATEGORIES = {"cardio": "有氧", "olympic weightlifting": "举重", "plyometrics": "爆发力",
              "powerlifting": "力量举", "strength": "力量", "stretching": "拉伸", "strongman": "大力士"}
LEVELS = {"beginner": "初级", "intermediate": "中级", "expert": "高级"}
TIMED = {"Plank", "Side_Bridge", "One_Handed_Hang", "Stomach_Vacuum", "Balance_Board",
         "Isometric_Neck_Exercise_-_Front_And_Back", "Isometric_Neck_Exercise_-_Sides",
         "Farmers_Walk", "Yoke_Walk", "Sled_Overhead_Backward_Walk"}
BODYWEIGHT_REPS = {"Band_Assisted_Pull-Up", "Bodyweight_Flyes", "Dips_-_Chest_Version", "Parallel_Bar_Dip",
                   "Ring_Dips", "Inverted_Row_with_Straps", "Suspended_Row", "Suspended_Push-Up", "V-Bar_Pullup",
                   "Plyo_Kettlebell_Pushups", "Close-Grip_Push-Up_off_of_a_Dumbbell",
                   "Barbell_Ab_Rollout", "Barbell_Ab_Rollout_-_On_Knees", "Muscle_Up"}
EQUIPMENT_OVERRIDES = {"Band_Assisted_Pull-Up": "弹力带", "Ring_Dips": "吊环", "V-Bar_Pullup": "单杠",
                       "Parallel_Bar_Dip": "双杠", "Dips_-_Chest_Version": "双杠", "Rope_Climb": "攀爬绳",
                       "Suspended_Row": "悬吊带", "Suspended_Push-Up": "悬吊带", "Inverted_Row_with_Straps": "悬吊带"}
# Keep only visually checked positions, without interpolating a synthetic animation.
WORKOUT_FRAMES = {"dumbbell-romanian-deadlift": (3, 1), "kettlebell-swing": (3, 1)}


def read_json(name, checksum):
    data = (CONTENT / "sources" / name).read_bytes()
    assert sha256(data).hexdigest() == checksum, f"Source changed: {name}"
    return json.loads(data)


def rows(name):
    with (CONTENT / name).open() as source:
        return list(csv.reader((line for line in source if not line.startswith("#") and line.strip()), delimiter="\t"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def safe_path(value):
    path = PurePosixPath(value)
    assert not path.is_absolute() and not any(p in {"..", "."} for p in path.parts), value
    return path


def measurement(entry):
    if entry["category"] == "cardio":
        return "cardio"
    if entry["category"] == "stretching" or entry["id"] in TIMED:
        return "duration"
    if entry["id"] in BODYWEIGHT_REPS:
        return "bodyweight"
    if "Weighted" in entry["id"] or "Dumbbell" in entry["id"] or "Barbell" in entry["id"]:
        return "externalLoad"
    return "bodyweight" if entry["equipment"] in {"body only", None} else "externalLoad"


def translated_muscles(values):
    return [MUSCLES[value.lower()] for value in values]


def download_workout(path, allow_download):
    target = CACHE / "workout-guide" / safe_path(path)
    if not target.exists():
        if not allow_download:
            raise RuntimeError(f"Missing {target}; use --download")
        revision = LOCK["workoutGuide"]["revision"]
        url = f"https://raw.githubusercontent.com/bryllim/workout-guide/{revision}/{quote(path)}"
        with urlopen(url, timeout=45) as response:
            data = response.read(5_000_001)
        assert len(data) <= 5_000_000
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    data = target.read_bytes()
    blob = sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
    assert blob == LOCK["workoutGuide"]["blobs"][path], f"Upstream blob mismatch: {path}"
    return data


def build(archive, allow_download):
    assert sha256(archive.read_bytes()).hexdigest() == LOCK["freeExerciseDB"]["archiveSHA256"], "Archive mismatch"
    free = read_json("free-exercise-db.json", LOCK["freeExerciseDB"]["dataSHA256"])
    workout = read_json("workout-guide.json", LOCK["workoutGuide"]["dataSHA256"])
    by_free = {entry["id"]: entry for entry in free}
    by_workout = {entry["slug"]: entry for entry in workout}
    names = dict(rows("chinese-names.tsv"))
    assert set(names) <= set(by_free), "Unknown Chinese-name mapping"
    legacy = json.loads((CONTENT / "leanora-v1.json").read_text())
    mappings = {int(number): (source, key, instructions.split("|"))
                for number, source, key, instructions in rows("legacy-guides.tsv")}
    assert set(mappings) == set(range(1, 101))
    entries, guides, used_free, needed_free, needed_workout = [], [], set(), set(), set()

    def guide(exercise_id, source, key, instructions):
        if source == "free":
            entry = by_free[key]
            assert entry["images"], f"No teaching images: {key}"
            needed_free.update(entry["images"])
            used_free.add(key)
            return {"exerciseID": exercise_id, "demoName": entry["name"], "category": CATEGORIES[entry["category"]],
                    "level": LEVELS[entry["level"]], "primaryMuscles": translated_muscles(entry["primaryMuscles"]),
                    "secondaryMuscles": translated_muscles(entry["secondaryMuscles"]), "instructions": instructions,
                    "originalInstructions": entry["instructions"], "images": ["free/" + image for image in entry["images"]],
                    "sourceName": "Free Exercise DB", "sourceURL": f"https://github.com/yuhonas/free-exercise-db/tree/{LOCK['freeExerciseDB']['revision']}/exercises/{quote(key)}",
                    "license": "Unlicense", "licenseURL": "https://unlicense.org/", "credit": "yuhonas / free-exercise-db contributors",
                    "modifications": "图片缩放至最长边 640 像素，重新压缩并移除元数据；中文提示由 Leanora 整理。"}
        entry = by_workout[key]
        frames = WORKOUT_FRAMES.get(key, (1, 2, 3))
        needed_workout.update(f"packages/workout-guide/assets/{key}/frame-{i}.png" for i in frames)
        return {"exerciseID": exercise_id, "demoName": entry["name"], "category": "力量", "level": "未分级",
                "primaryMuscles": translated_muscles([entry["primaryMuscle"]]), "secondaryMuscles": translated_muscles(entry["secondaryMuscles"]),
                "instructions": instructions, "originalInstructions": [],
                "images": [f"workout/{key}/frame-{i}.png" for i in frames], "sourceName": "Workout Guide",
                "sourceURL": f"https://github.com/bryllim/workout-guide/tree/{LOCK['workoutGuide']['revision']}/packages/workout-guide/assets/{key}",
                "license": "CC BY-SA 4.0", "licenseURL": "https://creativecommons.org/licenses/by-sa/4.0/",
                "credit": "Bryl Lim；原始姿态素材来自 Everkinetic（CC BY-SA 4.0）",
                "modifications": "PNG 图片未修改；中文提示由 Leanora 独立整理。", "upstreamAttribution": entry["attribution"]}

    for number, entry in enumerate(legacy["entries"], 1):
        entries.append(entry)
        source, key, instructions = mappings[number]
        guides.append(guide(entry["id"], source, key, instructions))
    excluded = []
    for entry in free:
        if not entry["images"]:
            excluded.append({"id": entry["id"], "reason": "上游没有指导图片"})
            continue
        if entry["id"] in used_free:
            continue
        uid = str(uuid5(NAMESPACE, "free-exercise-db:" + entry["id"]))
        primary = translated_muscles(entry["primaryMuscles"])
        muscles = list(dict.fromkeys(primary + [GROUPS[muscle] for muscle in primary if muscle in GROUPS]))
        if entry["category"] == "cardio":
            muscles.append("心肺")
        value = {"id": uid, "name": names.get(entry["id"], entry["name"]), "aliases": [entry["name"]],
                 "measurement": measurement(entry), "equipment": EQUIPMENT_OVERRIDES.get(entry["id"], EQUIPMENT[entry["equipment"]]), "muscles": muscles,
                 "source": {"name": "Free Exercise DB · 固定版本", "license": "Unlicense",
                            "reference": f"https://github.com/yuhonas/free-exercise-db/blob/{LOCK['freeExerciseDB']['revision']}/exercises/{quote(entry['id'])}.json"}}
        entries.append(value)
        guides.append(guide(uid, "free", entry["id"], []))
    assert len(set(e["id"] for e in entries)) == len(entries)
    guides[31]["variantNote"] = "图片展示无辅助的基础双杠动作轨迹；辅助器械的设置请查看下方步骤。"
    write_json(CATALOG / "exercises.json", {"version": 1, "source": legacy["source"], "entries": entries})
    write_json(CATALOG / "exercise-guides.json", {"version": 1, "entries": guides})
    print(f"Data: {len(entries)} exercises; all 100 legacy entries retained; {len(guides)} guides", flush=True)

    manifest = []
    MEDIA.mkdir(parents=True, exist_ok=True)
    prefix = f"free-exercise-db-{LOCK['freeExerciseDB']['revision']}/"
    with ZipFile(archive) as bundle:
        for image in sorted(needed_free):
            original = bundle.read(prefix + "exercises/" + str(safe_path(image)))
            target = MEDIA / "free" / image
            target.parent.mkdir(parents=True, exist_ok=True)
            with Image.open(BytesIO(original)) as photo:
                photo = ImageOps.exif_transpose(photo).convert("RGB")
                photo.thumbnail((640, 640), Image.Resampling.LANCZOS)
                photo.save(target, format="JPEG", quality=82, optimize=True)
            manifest.append({"path": "free/" + image, "sourceSHA256": sha256(original).hexdigest(),
                             "sha256": sha256(target.read_bytes()).hexdigest(), "bytes": target.stat().st_size,
                             "license": "Unlicense"})
        notices = MEDIA / "Notices"
        notices.mkdir(exist_ok=True)
        (notices / "FreeExerciseDB-Unlicense.txt").write_bytes(bundle.read(prefix + "LICENSE.md"))

    def copy_workout(path):
        data = download_workout(path, allow_download)
        relative = path.removeprefix("packages/workout-guide/assets/")
        target = MEDIA / "workout" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(BytesIO(data)) as image:
            image.verify()
        target.write_bytes(data)
        return {"path": "workout/" + relative, "sha256": sha256(data).hexdigest(), "sourceSHA256": sha256(data).hexdigest(),
                "bytes": len(data), "license": "CC-BY-SA-4.0"}

    with ThreadPoolExecutor(max_workers=4) as pool:
        manifest.extend(pool.map(copy_workout, sorted(needed_workout)))
    for upstream, local in (("LICENSE-ASSETS", "WorkoutGuide-CC-BY-SA-4.0.txt"), ("ATTRIBUTION.md", "WorkoutGuide-Attribution.md")):
        (notices / local).write_bytes(download_workout(upstream, allow_download))
    expected_images = {item["path"] for item in manifest}
    for directory in (MEDIA / "free", MEDIA / "workout"):
        for file in directory.rglob("*"):
            if file.is_file() and str(file.relative_to(MEDIA)) not in expected_images:
                file.unlink()
    write_json(MEDIA / "manifest.json", {"version": 1, "sources": LOCK, "images": manifest})
    write_json(APP / "docs/exercise-catalog-manifest.json", {
        "exercises": len(entries), "legacyEntriesPreserved": 100, "guides": len(guides), "uniqueImages": len(manifest),
        "imageBytes": sum(item["bytes"] for item in manifest), "chineseNames": sum(any('\u4e00' <= c <= '\u9fff' for c in e["name"]) for e in entries),
        "chineseInstructions": sum(bool(g["instructions"]) for g in guides), "excluded": excluded, "sources": LOCK,
        "mediaProcessing": "Pillow 12.3.0; JPEG longest edge 640px, quality 82, EXIF stripped; Workout Guide PNG unchanged",
    })
    print(f"Media: {len(manifest)} unique images; {sum(item['bytes'] for item in manifest) / 1024**2:.1f} MiB", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, default=CACHE / "free-exercise-db.zip")
    parser.add_argument("--download", action="store_true")
    args = parser.parse_args()
    build(args.archive, args.download)
