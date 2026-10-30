#!/usr/bin/env python3
"""Build the bundled CC0 subset from the official SR Legacy 2018 JSON ZIP.

Usage: python3 app/scripts/build_food_catalog.py /path/to/official.zip
Source: https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip
No APIs, keys, generated nutrient values, or third-party product databases.
"""
import hashlib
import json
from pathlib import Path
import sys
import uuid
import zipfile

TRANSLATIONS = {
    168878: "米饭（熟，长粒白米）", 173424: "水煮全蛋", 171688: "苹果（带皮，生）",
    173944: "香蕉（生）", 171477: "鸡胸肉（去皮，烤熟）", 172475: "硬豆腐（硫酸钙凝固）",
    171265: "全脂牛奶（添加维生素 D）", 170379: "西兰花（生）",
}
COMMON = {
    "Oranges, raw, all commercial varieties": "橙子（生）",
    "Strawberries, raw": "草莓（生）", "Blueberries, raw": "蓝莓（生）",
    "Grapes, red or green (European type, such as Thompson seedless), raw": "葡萄（红或绿，生）",
    "Carrots, raw": "胡萝卜（生）", "Spinach, raw": "菠菜（生）",
    "Cucumber, with peel, raw": "黄瓜（带皮，生）", "Tomatoes, red, ripe, raw, year round average": "番茄（生）",
    "Cabbage, raw": "卷心菜（生）", "Onions, raw": "洋葱（生）",
    "Sweet potato, raw, unprepared": "红薯（生）", "Oats": "燕麦（生）",
    "Quinoa, cooked": "藜麦（熟）", "Lentils, mature seeds, cooked, boiled, without salt": "小扁豆（煮熟，无盐）",
    "Peanuts, all types, raw": "花生（生）", "Nuts, almonds": "杏仁",
    "Nuts, walnuts, english": "核桃", "Oil, olive, salad or cooking": "橄榄油",
    "Salmon, Atlantic, farmed, cooked, dry heat": "养殖大西洋三文鱼（干热熟制）",
    "Crustaceans, shrimp, cooked": "虾（熟）", "Egg, white, raw, fresh": "鸡蛋清（生）",
    "Yogurt, plain, whole milk": "原味全脂酸奶", "Cheese, cheddar": "切达奶酪",
    "Beverages, coffee, brewed, prepared with tap water": "黑咖啡（冲煮）",
    "Beverages, tea, green, brewed, regular": "绿茶（冲泡）",
}
CATEGORIES = ["Cereal Grains and Pasta", "Dairy and Egg Products", "Fruits and Fruit Juices",
              "Vegetables and Vegetable Products", "Legumes and Legume Products", "Nut and Seed Products",
              "Poultry Products", "Finfish and Shellfish Products", "Pork Products", "Beef Products",
              "Fats and Oils", "Beverages", "Baked Products", "Spices and Herbs"]


def main():
    source = Path(sys.argv[1])
    with zipfile.ZipFile(source) as archive:
        foods = json.loads(archive.read(archive.namelist()[0]))["SRLegacyFoods"]
    root = Path(__file__).resolve().parents[1]
    localization = json.loads((root / "content/food-localization.json").read_text())
    legacy = json.loads((root / "content/food-legacy-manifest.json").read_text())["records"]
    old_names = {f["fdcId"]: f["name"] for f in legacy if any("\u4e00" <= c <= "\u9fff" for c in f["name"])}
    translations = dict(TRANSLATIONS)
    for food in foods:
        if food["description"] in COMMON:
            translations[food["fdcId"]] = COMMON[food["description"]]
    translations.update({int(k): v for k, v in localization["names"].items()})
    translations.update(old_names)
    required = {f["fdcId"] for f in legacy} | set(translations)
    selected = {food["fdcId"]: food for food in foods if food["fdcId"] in required}
    assert set(selected) == required, "Unknown curated FDC IDs"
    for category in CATEGORIES:
        candidates = sorted([food for food in foods if food.get("foodCategory", {}).get("description") == category], key=lambda f: f["description"])
        for food in candidates[:20]:
            selected[food["fdcId"]] = food
    for food in sorted(foods, key=lambda f: f["fdcId"]):
        if len(selected) >= 500:
            break
        selected[food["fdcId"]] = food
    assert len(selected) == 500, "Curated and legacy union must fit 500 foods"
    entries = []
    for fdc_id, food in sorted(selected.items()):
        description = food["description"]
        reference = f"https://fdc.nal.usda.gov/food-details/{fdc_id}/nutrients"
        nutrients = {item["nutrient"]["id"]: item.get("amount") for item in food["foodNutrients"]}
        # Nutrient IDs 1008/1003/1005/1004 use kcal/g/g/g per 100 g.
        value = {key: nutrients[nid] for key, nid in [("energyKcal", 1008), ("proteinGrams", 1003), ("carbohydrateGrams", 1005), ("fatGrams", 1004)] if nutrients.get(nid) is not None}
        units = []
        for portion in food.get("foodPortions", [])[:8]:
            grams = portion.get("gramWeight")
            if not grams or not 0 < grams <= 100000:
                continue
            amount = portion.get("amount", 1)
            label = portion.get("modifier") or portion.get("measureUnit", {}).get("name", "portion")
            units.append({"id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"{reference}/portion/{portion['id']}")),
                          "name": f"{amount:g} {label}（USDA 份量）", "grams": grams,
                          "conversionSource": reference})
        category = food.get("foodCategory", {}).get("description", "")
        group = {
            "Cereal Grains and Pasta": "谷物与主食", "Baked Products": "谷物与主食",
            "Breakfast Cereals": "谷物与主食", "Dairy and Egg Products": "奶与蛋",
            "Fruits and Fruit Juices": "水果", "Vegetables and Vegetable Products": "蔬菜",
            "Legumes and Legume Products": "豆类与豆制品", "Nut and Seed Products": "坚果与种子",
            "Poultry Products": "肉与水产", "Finfish and Shellfish Products": "肉与水产",
            "Pork Products": "肉与水产", "Beef Products": "肉与水产", "Lamb, Veal, and Game Products": "肉与水产",
            "Fats and Oils": "油脂与调味", "Spices and Herbs": "油脂与调味", "Beverages": "饮品"
        }.get(category, "其他")
        entries.append({"id": str(uuid.uuid5(uuid.NAMESPACE_URL, reference)), "name": translations.get(fdc_id, description),
                        "aliases": [description] + localization["aliases"].get(str(fdc_id), []),
                        "category": group, "nutrients": value, "units": units, "reference": reference})
    output = root / "ios/Leanora/Resources/Catalog/foods.json"
    output.write_text(json.dumps({"version": 1, "entries": entries}, ensure_ascii=False, indent=2) + "\n")
    manifest = {"source": str(source.name), "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "url": __doc__.split("Source: ")[1].splitlines()[0], "license": "CC0-1.0",
                "records": len(entries), "translatedNames": sum(any("\u4e00" <= c <= "\u9fff" for c in e["name"]) for e in entries), "retrievedOn": "2026-10-30",
                "legacyRecordsPreserved": len(legacy), "localization": "content/food-localization.json",
                "method": "Keep all 300 legacy IDs and original nutrients/portions; add independently localized records, then category selections and fill by FDC ID to 500. No nutrient imputation. Original portion labels and grams retained. Chinese categories are navigation groups, not dietary advice."}
    (root / "docs/food-catalog-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Built {len(entries)} foods; {len(translations)} translated names")


if __name__ == "__main__":
    main()
