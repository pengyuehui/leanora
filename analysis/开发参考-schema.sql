-- 独立开发参考模型，2026-10-20。
-- 这是本次分析提出的 SQLite 设计，不是训记或薄荷的原始数据库。
-- 用于训练记录 + 饮食记录 + 身体趋势的核心版本；账号权限与同步协议仍需业务实现。
-- 时间戳使用 UTC ISO-8601；local_date 和 timezone 保留记录发生地的归日语义。
PRAGMA foreign_keys = ON;

CREATE TABLE app_user (
  id TEXT PRIMARY KEY,
  timezone TEXT NOT NULL DEFAULT 'Asia/Shanghai'
);

CREATE TABLE exercise (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('strength','reps','timed','cardio')),
  muscles_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(muscles_json))
);

CREATE TABLE workout_template (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_user(id),
  name TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1 CHECK(version > 0),
  updated_at TEXT NOT NULL
);

CREATE TABLE template_item (
  id TEXT PRIMARY KEY,
  template_id TEXT NOT NULL REFERENCES workout_template(id),
  exercise_id TEXT NOT NULL REFERENCES exercise(id),
  position INTEGER NOT NULL CHECK(position >= 0),
  planned_sets_json TEXT NOT NULL DEFAULT '[]' CHECK(json_valid(planned_sets_json)),
  -- planned_sets 的应用层合同：组类型、目标次数范围、负重、休息秒数；不保存实际完成值。
  UNIQUE(template_id, position)
);

CREATE TABLE workout_session (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_user(id),
  template_id TEXT REFERENCES workout_template(id),
  template_version INTEGER,
  local_date TEXT NOT NULL,
  timezone TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  state TEXT NOT NULL CHECK(state IN ('draft','active','completed','abandoned')),
  note TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK(version > 0),
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  CHECK(state != 'completed' OR ended_at IS NOT NULL)
);
CREATE INDEX workout_session_user_date ON workout_session(user_id, local_date);

CREATE TABLE session_exercise (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES workout_session(id),
  exercise_id TEXT NOT NULL REFERENCES exercise(id),
  exercise_name_snapshot TEXT NOT NULL,
  kind_snapshot TEXT NOT NULL CHECK(kind_snapshot IN ('strength','reps','timed','cardio')),
  position INTEGER NOT NULL CHECK(position >= 0),
  superset_key TEXT,
  note TEXT,
  UNIQUE(session_id, position)
);

CREATE TABLE workout_set (
  id TEXT PRIMARY KEY,
  session_exercise_id TEXT NOT NULL REFERENCES session_exercise(id),
  position INTEGER NOT NULL CHECK(position >= 0),
  set_kind TEXT NOT NULL DEFAULT 'working' CHECK(set_kind IN ('warmup','working','drop','failure')),
  reps INTEGER CHECK(reps >= 0),
  weight_kg REAL CHECK(weight_kg >= 0),
  assistance_kg REAL CHECK(assistance_kg >= 0),
  duration_sec INTEGER CHECK(duration_sec >= 0),
  distance_m REAL CHECK(distance_m >= 0),
  rpe REAL CHECK(rpe BETWEEN 0 AND 10),
  rest_sec INTEGER CHECK(rest_sec >= 0),
  completed_at TEXT,
  CHECK(completed_at IS NULL OR reps IS NOT NULL OR duration_sec IS NOT NULL OR distance_m IS NOT NULL),
  UNIQUE(session_exercise_id, position)
);

CREATE TABLE food (
  id TEXT PRIMARY KEY,
  owner_id TEXT REFERENCES app_user(id),
  name TEXT NOT NULL,
  source TEXT NOT NULL,
  source_revision TEXT,
  -- 统一以 100g 可食部为基准；NULL 表示未知，不能按 0 统计。
  kcal_per_100g REAL CHECK(kcal_per_100g >= 0),
  protein_g_per_100g REAL CHECK(protein_g_per_100g >= 0),
  fat_g_per_100g REAL CHECK(fat_g_per_100g >= 0),
  carb_g_per_100g REAL CHECK(carb_g_per_100g >= 0),
  fiber_g_per_100g REAL CHECK(fiber_g_per_100g >= 0),
  sodium_mg_per_100g REAL CHECK(sodium_mg_per_100g >= 0)
);

CREATE TABLE food_unit (
  id TEXT PRIMARY KEY,
  food_id TEXT NOT NULL REFERENCES food(id),
  label TEXT NOT NULL,
  edible_grams_per_unit REAL NOT NULL CHECK(edible_grams_per_unit > 0),
  UNIQUE(food_id, label)
);

CREATE TABLE nutrition_goal (
  user_id TEXT NOT NULL REFERENCES app_user(id),
  effective_from TEXT NOT NULL,
  kcal REAL NOT NULL CHECK(kcal > 0),
  protein_g REAL CHECK(protein_g >= 0),
  fat_g REAL CHECK(fat_g >= 0),
  carb_g REAL CHECK(carb_g >= 0),
  -- 改目标新增版本；旧日期的展示读取当时适用的版本。
  PRIMARY KEY(user_id, effective_from)
);

CREATE TABLE diet_entry (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_user(id),
  food_id TEXT REFERENCES food(id),
  food_name_snapshot TEXT,
  food_revision_snapshot TEXT,
  local_date TEXT NOT NULL,
  timezone TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  meal_type TEXT NOT NULL CHECK(meal_type IN ('breakfast','morning_snack','lunch','afternoon_snack','dinner','evening_snack','other')),
  source TEXT NOT NULL CHECK(source IN ('search','manual','photo','barcode','copy')),
  quantity REAL CHECK(quantity > 0),
  unit_snapshot TEXT,
  edible_grams REAL CHECK(edible_grams > 0),
  -- 保存当次营养快照，避免食物资料更新后历史数据跟着变化。
  kcal REAL NOT NULL CHECK(kcal >= 0),
  protein_g REAL CHECK(protein_g >= 0),
  fat_g REAL CHECK(fat_g >= 0),
  carb_g REAL CHECK(carb_g >= 0),
  photo_uri TEXT,
  version INTEGER NOT NULL DEFAULT 1 CHECK(version > 0),
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);
CREATE INDEX diet_entry_user_date ON diet_entry(user_id, local_date, meal_type);

CREATE TABLE body_measurement (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_user(id),
  metric TEXT NOT NULL CHECK(metric IN ('weight','body_fat','waist')),
  value REAL NOT NULL CHECK(value > 0),
  unit TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  local_date TEXT NOT NULL,
  timezone TEXT NOT NULL,
  source TEXT NOT NULL,
  source_record_id TEXT,
  CHECK((metric='weight' AND unit='kg') OR (metric='body_fat' AND unit='percent' AND value<=100) OR (metric='waist' AND unit='cm')),
  UNIQUE(user_id, source, source_record_id)
);
CREATE INDEX body_measurement_user_metric_time ON body_measurement(user_id, metric, recorded_at);

CREATE TABLE sport_entry (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES app_user(id),
  -- 相同运动只能指定一个统计来源，避免训练记录和设备导入双算。
  workout_session_id TEXT REFERENCES workout_session(id),
  name TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  local_date TEXT NOT NULL,
  timezone TEXT NOT NULL,
  duration_sec INTEGER CHECK(duration_sec >= 0),
  kcal REAL CHECK(kcal >= 0),
  source TEXT NOT NULL,
  source_record_id TEXT,
  UNIQUE(user_id, source, source_record_id)
);
