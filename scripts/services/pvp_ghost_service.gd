class_name PvpGhostService
extends RefCounted

const BattleSnapshotClass = preload("res://scripts/data/battle_snapshot.gd")
const GhostSnapshotClass = preload("res://scripts/data/ghost_snapshot.gd")
const BazaarContentClass = preload("res://scripts/data/bazaar_content.gd")
const EnchantmentCatalogClass = preload("res://scripts/data/enchantment_catalog.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const ItemDataClass = preload("res://scripts/data/item_data.gd")
const LinearInventoryClass = preload("res://scripts/data/linear_inventory.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const MonsterAIClass = preload("res://scripts/data/monster_ai.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

const DEFAULT_CURATED_PATH: String = "res://data/pvp_ghost/curated_archetypes.json"
const DEFAULT_LOCAL_PLAYTEST_DIR: String = "user://ghost_pool/playtest"
const DEFAULT_EDITOR_VERSION: String = "curated-editor-v1"
const DEFAULT_LOCAL_GENERATOR_VERSION: String = "local-playtest-v1"
const DEFAULT_REPLAY_VERSION: String = "pvp-replay-summary-v1"
const FILE_SCHEMA_VERSION: int = 1
const DEFAULT_POWER_BUCKET: String = "P10"
const LOCAL_SOURCE: String = "local_playtest"
const DEFAULT_REPLAY_DIR: String = "user://ghost_pool/replays"
const LOCAL_MATCH_BAND_SCORE: int = 220

const TIER_BRONZE: String = "bronze"
const TIER_SILVER: String = "silver"
const TIER_GOLD: String = "gold"
const TIER_DIAMOND: String = "diamond"

const VALID_TIERS: Array[String] = [
	TIER_BRONZE,
	TIER_SILVER,
	TIER_GOLD,
	TIER_DIAMOND,
]

const HERO_ID_TO_TYPE := {
	"warrior": HeroDataClass.HeroType.WARRIOR,
	"mage": HeroDataClass.HeroType.MAGE,
	"vanessa": HeroDataClass.HeroType.VANESSA,
	"pygmalien": HeroDataClass.HeroType.PYGMALIEN,
	"dooley": HeroDataClass.HeroType.DOOLEY,
	"mak": HeroDataClass.HeroType.MAK,
	"stelle": HeroDataClass.HeroType.STELLE,
	"jules": HeroDataClass.HeroType.JULES,
	"karnok": HeroDataClass.HeroType.KARNOK,
}

const HERO_ID_TO_NAME := {
	"warrior": "战士",
	"mage": "法师",
	"vanessa": "Vanessa",
	"pygmalien": "Pygmalien",
	"dooley": "Dooley",
	"mak": "Mak",
	"stelle": "Stelle",
	"jules": "Jules",
	"karnok": "Karnok",
}

const TIER_TO_RARITY := {
	TIER_BRONZE: BazaarContentClass.RARITY_BRONZE,
	TIER_SILVER: BazaarContentClass.RARITY_SILVER,
	TIER_GOLD: BazaarContentClass.RARITY_GOLD,
	TIER_DIAMOND: BazaarContentClass.RARITY_DIAMOND,
}

const RARITY_TO_TIER := {
	BazaarContentClass.RARITY_BRONZE: TIER_BRONZE,
	BazaarContentClass.RARITY_SILVER: TIER_SILVER,
	BazaarContentClass.RARITY_GOLD: TIER_GOLD,
	BazaarContentClass.RARITY_DIAMOND: TIER_DIAMOND,
}

static func get_known_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	for hero_id in HERO_ID_TO_TYPE.keys():
		ids.append(str(hero_id))
	ids.sort()
	return ids

static func get_tier_options() -> Array[String]:
	return VALID_TIERS.duplicate()

static func get_enchantment_options() -> Array[String]:
	return EnchantmentCatalogClass.get_known_ids()

static func get_enchantment_label(enchantment: String) -> String:
	return EnchantmentCatalogClass.get_label(enchantment)

static func get_default_archetype() -> Dictionary:
	return {
		"id": "ghost_day01_new",
		"name": "New Ghost",
		"day": 1,
		"level": 1,
		"slot_capacity": 6,
		"hero_id": "mak",
		"prestige": 20,
		"max_health": 100,
		"health": 100,
		"regeneration": 0.0,
		"skills": [],
		"items": [],
		"notes": "",
		"created_at": "",
	}

static func load_curated_file(path: String = DEFAULT_CURATED_PATH) -> Dictionary:
	var result: Dictionary = {
		"success": true,
		"path": path,
		"schema_version": FILE_SCHEMA_VERSION,
		"archetypes": [],
		"errors": [],
	}
	if not FileAccess.file_exists(path):
		return result

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["success"] = false
		result["errors"] = ["open_failed:%s" % path]
		return result

	var json := JSON.new()
	var parse_error: int = json.parse(file.get_as_text())
	if parse_error != OK:
		result["success"] = false
		result["errors"] = [
			"parse_failed:%s:%s" % [path, json.get_error_message()],
		]
		return result

	var data: Variant = json.get_data()
	if not data is Dictionary:
		result["success"] = false
		result["errors"] = ["invalid_root_type:%s" % path]
		return result

	var payload: Dictionary = data as Dictionary
	result["schema_version"] = int(payload.get("schema_version", FILE_SCHEMA_VERSION))
	result["archetypes"] = _normalize_archetype_array(payload.get("archetypes", []))
	return result

static func save_curated_archetype(path: String, archetype_data: Dictionary) -> Dictionary:
	var existing: Dictionary = load_curated_file(path)
	if not bool(existing.get("success", false)):
		return existing

	var validation: Dictionary = validate_curated_archetype(archetype_data)
	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"saved": false,
			"errors": validation.get("errors", []),
			"warnings": validation.get("warnings", []),
			"path": path,
		}

	var normalized: Dictionary = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	var archetypes: Array[Dictionary] = _normalize_archetype_array(existing.get("archetypes", []))
	var target_id: String = str(normalized.get("id", "")).to_lower()
	var replaced: bool = false
	for index in range(archetypes.size()):
		if str(archetypes[index].get("id", "")).to_lower() == target_id:
			archetypes[index] = normalized
			replaced = true
			break
	if not replaced:
		archetypes.append(normalized)

	var payload: Dictionary = {
		"schema_version": FILE_SCHEMA_VERSION,
		"archetypes": archetypes,
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"saved": false,
			"errors": ["write_open_failed:%s" % path],
			"path": path,
		}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	var snapshot: GhostSnapshotClass = curated_archetype_to_snapshot(normalized)
	return {
		"success": true,
		"saved": true,
		"path": path,
		"archetype": normalized,
		"snapshot": snapshot.to_dictionary(),
		"warnings": validation.get("warnings", []),
	}

static func validate_curated_archetype(archetype_data: Dictionary) -> Dictionary:
	var normalized: Dictionary = get_default_archetype()
	for key in archetype_data.keys():
		normalized[key] = archetype_data[key]

	normalized["id"] = str(normalized.get("id", "")).strip_edges().to_lower()
	normalized["name"] = str(normalized.get("name", "")).strip_edges()
	normalized["hero_id"] = str(normalized.get("hero_id", "")).strip_edges().to_lower()
	normalized["day"] = int(normalized.get("day", 1))
	normalized["level"] = int(normalized.get("level", 1))
	normalized["slot_capacity"] = int(normalized.get("slot_capacity", 10))
	normalized["prestige"] = int(normalized.get("prestige", 20))
	normalized["max_health"] = int(normalized.get("max_health", 100))
	normalized["health"] = int(normalized.get("health", normalized["max_health"]))
	normalized["regeneration"] = float(normalized.get("regeneration", 0.0))
	normalized["notes"] = str(normalized.get("notes", ""))
	normalized["created_at"] = str(normalized.get("created_at", ""))

	var errors: Array[String] = []
	var warnings: Array[String] = []

	if str(normalized["id"]).is_empty():
		errors.append("missing_id")
	if str(normalized["name"]).is_empty():
		normalized["name"] = str(normalized["id"]).capitalize()
	if not HERO_ID_TO_TYPE.has(normalized["hero_id"]):
		errors.append("unknown_hero:%s" % normalized["hero_id"])
	if normalized["day"] < 1 or normalized["day"] > 20:
		errors.append("invalid_day:%d" % normalized["day"])
	if normalized["level"] < 1 or normalized["level"] > 20:
		errors.append("invalid_level:%d" % normalized["level"])
	if normalized["slot_capacity"] < 1 or normalized["slot_capacity"] > LinearInventoryClass.TOTAL_SLOTS:
		errors.append("invalid_slot_capacity:%d" % normalized["slot_capacity"])
	if normalized["max_health"] <= 0:
		errors.append("invalid_max_health:%d" % normalized["max_health"])
	if normalized["health"] <= 0 or normalized["health"] > normalized["max_health"]:
		errors.append(
			"invalid_health:%d:max=%d" % [normalized["health"], normalized["max_health"]]
		)
	if normalized["prestige"] < 0 or normalized["prestige"] > 20:
		errors.append("invalid_prestige:%d" % normalized["prestige"])
	if normalized["regeneration"] < 0.0:
		errors.append("invalid_regeneration:%.2f" % normalized["regeneration"])

	var normalized_skills: Array[Dictionary] = []
	var raw_skills: Variant = normalized.get("skills", [])
	if raw_skills is Array:
		for skill_entry in raw_skills:
			var skill_result: Dictionary = _normalize_skill_entry(skill_entry)
			var skill_errors: Array[String] = _variant_to_string_array(skill_result.get("errors", []))
			errors.append_array(skill_errors)
			if skill_result.has("warning"):
				warnings.append(str(skill_result.get("warning", "")))
			if skill_result.has("entry"):
				normalized_skills.append((skill_result.get("entry", {}) as Dictionary).duplicate(true))
	else:
		errors.append("invalid_skills_array")
	normalized["skills"] = normalized_skills

	var normalized_items: Array[Dictionary] = []
	var occupied_slots: Dictionary = {}
	var used_slots: int = 0
	var raw_items: Variant = normalized.get("items", [])
	if raw_items is Array:
		for item_entry in raw_items:
			var item_result: Dictionary = _normalize_item_entry(item_entry)
			errors.append_array(_variant_to_string_array(item_result.get("errors", [])))
			warnings.append_array(_variant_to_string_array(item_result.get("warnings", [])))
			if not item_result.has("entry"):
				continue
			var normalized_item: Dictionary = (item_result.get("entry", {}) as Dictionary).duplicate(true)
			var item_slot: int = int(normalized_item.get("slot_index", -1))
			var slot_count: int = int(normalized_item.get("size", 1))
			if item_slot < 0:
				errors.append("invalid_item_slot:%s" % normalized_item.get("item_id", ""))
				continue
			if item_slot + slot_count > normalized["slot_capacity"]:
				errors.append(
					"slot_capacity_exceeded:%s:start=%d:size=%d:capacity=%d"
					% [
						str(normalized_item.get("item_id", "")),
						item_slot,
						slot_count,
						int(normalized["slot_capacity"]),
					]
				)
			for slot_offset in range(slot_count):
				var occupied_slot: int = item_slot + slot_offset
				if occupied_slots.has(occupied_slot):
					errors.append(
						"overlapping_item_slots:%d:%s:%s"
						% [
							occupied_slot,
							str(occupied_slots[occupied_slot]),
							str(normalized_item.get("item_id", "")),
						]
					)
				else:
					occupied_slots[occupied_slot] = str(normalized_item.get("item_id", ""))
			used_slots += slot_count
			normalized_items.append(normalized_item)
	else:
		errors.append("invalid_items_array")

	if used_slots > int(normalized["slot_capacity"]):
		errors.append(
			"slot_capacity_exceeded_total:used=%d:capacity=%d"
			% [used_slots, int(normalized["slot_capacity"])]
		)

	normalized_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)
	normalized["items"] = normalized_items

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": _compact_strings(warnings),
		"normalized": normalized,
	}

static func curated_archetype_to_snapshot(archetype_data: Dictionary) -> GhostSnapshotClass:
	var validation: Dictionary = validate_curated_archetype(archetype_data)
	if not bool(validation.get("valid", false)):
		push_error(
			"PvpGhostService cannot convert invalid curated archetype: %s"
			% JSON.stringify(validation.get("errors", []))
		)
		return GhostSnapshotClass.new()

	var normalized: Dictionary = (validation.get("normalized", {}) as Dictionary).duplicate(true)
	var snapshot: GhostSnapshotClass = GhostSnapshotClass.new()
	snapshot.snapshot_id = str(normalized.get("id", ""))
	snapshot.day = int(normalized.get("day", 1))
	snapshot.hour = 5
	snapshot.hero_id = str(normalized.get("hero_id", ""))
	snapshot.hero_name = get_hero_display_name(snapshot.hero_id)
	snapshot.level = int(normalized.get("level", 1))
	snapshot.slot_capacity = int(normalized.get("slot_capacity", LinearInventoryClass.TOTAL_SLOTS))
	snapshot.prestige = int(normalized.get("prestige", 20))
	snapshot.max_health = int(normalized.get("max_health", 100))
	snapshot.health = int(normalized.get("health", snapshot.max_health))
	snapshot.regeneration = float(normalized.get("regeneration", 0.0))
	snapshot.skills = _normalize_archetype_array(normalized.get("skills", []))
	snapshot.items = _normalize_archetype_array(normalized.get("items", []))
	snapshot.tags = _collect_snapshot_tags(snapshot)
	snapshot.notes = str(normalized.get("notes", ""))
	snapshot.created_at = str(normalized.get("created_at", ""))
	snapshot.generator_version = DEFAULT_EDITOR_VERSION
	snapshot.power_score = calculate_power_score(snapshot)
	snapshot.power_bucket = calculate_power_bucket(snapshot.power_score)
	return snapshot

static func capture_player_snapshot(
	game_manager: Node,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass = null
) -> BattleSnapshotClass:
	var snapshot: BattleSnapshotClass = BattleSnapshotClass.new()
	if game_manager == null:
		return snapshot

	var hero: Object = game_manager.get("selected_hero")
	snapshot.day = int(game_manager.get("current_day"))
	snapshot.hour = int(game_manager.get("current_hour"))
	snapshot.level = int(game_manager.get("level"))
	snapshot.slot_capacity = LinearInventoryClass.TOTAL_SLOTS
	snapshot.prestige = int(game_manager.get("prestige"))
	snapshot.pvp_wins = int(game_manager.get("pvp_wins"))
	snapshot.max_health = int(game_manager.call("get_max_health"))
	snapshot.health = int(game_manager.get("player_health"))
	snapshot.regeneration = 0.0
	if hero != null:
		var hero_type: int = int(hero.get("hero_type"))
		snapshot.hero_id = get_hero_id_for_type(hero_type)
		snapshot.hero_name = str(hero.get("hero_name"))
		var hero_skills: Variant = hero.get("skills")
		if hero_skills is Array:
			for skill_entry in hero_skills:
				var skill_result: Dictionary = _normalize_skill_entry(skill_entry)
				if skill_result.has("entry"):
					snapshot.skills.append((skill_result.get("entry", {}) as Dictionary).duplicate(true))
	if inventory != null:
		snapshot.items = _capture_inventory_items(inventory)
	if stash_inventory != null:
		snapshot.stash_items = _capture_inventory_items(stash_inventory)
	snapshot.snapshot_id = "player_day%02d_hour%02d" % [snapshot.day, snapshot.hour]
	return snapshot

static func capture_player_ghost_snapshot(
	game_manager: Node,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass = null
) -> GhostSnapshotClass:
	var base: BattleSnapshotClass = capture_player_snapshot(game_manager, inventory, stash_inventory)
	var snapshot: GhostSnapshotClass = GhostSnapshotClass.from_dictionary(base.to_dictionary())
	snapshot.source = LOCAL_SOURCE
	snapshot.rules_version = GhostSnapshotClass.DEFAULT_RULES_VERSION
	snapshot.generator_version = DEFAULT_LOCAL_GENERATOR_VERSION
	snapshot.created_at = Time.get_datetime_string_from_system(false, true)
	snapshot.power_score = calculate_power_score(snapshot)
	snapshot.power_bucket = calculate_power_bucket(snapshot.power_score)
	snapshot.tags = _collect_snapshot_tags(snapshot)
	snapshot.snapshot_id = _build_local_snapshot_id(snapshot)
	return snapshot

static func save_player_snapshot(
	game_manager: Node,
	inventory: LinearInventoryClass,
	stash_inventory: LinearInventoryClass = null,
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR
) -> Dictionary:
	var snapshot: GhostSnapshotClass = capture_player_ghost_snapshot(
		game_manager,
		inventory,
		stash_inventory
	)
	return save_local_snapshot(snapshot, store_dir)

static func save_local_snapshot(
	snapshot: GhostSnapshotClass,
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR
) -> Dictionary:
	if snapshot == null:
		return {"success": false, "saved": false, "errors": ["missing_snapshot"], "path": ""}

	var validation: Dictionary = validate_ghost_snapshot(snapshot.to_dictionary())
	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"saved": false,
			"errors": validation.get("errors", []),
			"path": "",
		}

	var normalized: GhostSnapshotClass = GhostSnapshotClass.from_dictionary(
		(validation.get("normalized", {}) as Dictionary).duplicate(true)
	)
	normalized.source = LOCAL_SOURCE
	if normalized.created_at.is_empty():
		normalized.created_at = Time.get_datetime_string_from_system(false, true)
	normalized.generator_version = DEFAULT_LOCAL_GENERATOR_VERSION
	normalized.rules_version = GhostSnapshotClass.DEFAULT_RULES_VERSION
	normalized.power_score = calculate_power_score(normalized)
	normalized.power_bucket = calculate_power_bucket(normalized.power_score)
	if normalized.snapshot_id.is_empty():
		normalized.snapshot_id = _build_local_snapshot_id(normalized)

	var directory_path: String = "%s/day%02d" % [store_dir, int(normalized.day)]
	var ensure_result: Dictionary = _ensure_user_directory(directory_path)
	if not bool(ensure_result.get("success", false)):
		return ensure_result

	var file_path: String = "%s/%s.json" % [directory_path, _sanitize_file_token(normalized.snapshot_id)]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"saved": false,
			"errors": ["write_open_failed:%s" % file_path],
			"path": file_path,
		}
	file.store_string(normalized.to_json_string("\t"))
	file.close()

	_rebuild_local_snapshot_index(store_dir)
	return {
		"success": true,
		"saved": true,
		"path": file_path,
		"snapshot": normalized.to_dictionary(),
	}

static func validate_ghost_snapshot(snapshot_data: Dictionary) -> Dictionary:
	var snapshot: GhostSnapshotClass = GhostSnapshotClass.from_dictionary(snapshot_data)
	var errors: Array[String] = []

	if int(snapshot.schema_version) != BattleSnapshotClass.SCHEMA_VERSION:
		errors.append("invalid_schema_version:%d" % int(snapshot.schema_version))
	if str(snapshot.snapshot_id).strip_edges().is_empty():
		errors.append("missing_snapshot_id")
	if snapshot.day < 1 or snapshot.day > 20:
		errors.append("invalid_day:%d" % snapshot.day)
	if snapshot.hour < 0 or snapshot.hour >= 6:
		errors.append("invalid_hour:%d" % snapshot.hour)
	if not HERO_ID_TO_TYPE.has(snapshot.hero_id):
		errors.append("unknown_hero:%s" % snapshot.hero_id)
	if snapshot.level < 1 or snapshot.level > 20:
		errors.append("invalid_level:%d" % snapshot.level)
	if snapshot.slot_capacity < 1 or snapshot.slot_capacity > LinearInventoryClass.TOTAL_SLOTS:
		errors.append("invalid_slot_capacity:%d" % snapshot.slot_capacity)
	if snapshot.max_health <= 0:
		errors.append("invalid_max_health:%d" % snapshot.max_health)
	if snapshot.health <= 0 or snapshot.health > snapshot.max_health:
		errors.append("invalid_health:%d:max=%d" % [snapshot.health, snapshot.max_health])
	if snapshot.prestige < 0 or snapshot.prestige > 20:
		errors.append("invalid_prestige:%d" % snapshot.prestige)
	if snapshot.power_score < 0:
		errors.append("invalid_power_score:%d" % snapshot.power_score)
	if snapshot.power_bucket.is_empty():
		errors.append("missing_power_bucket")

	var normalized_skills: Array[Dictionary] = []
	for skill_entry in snapshot.skills:
		var skill_result: Dictionary = _normalize_skill_entry(skill_entry)
		errors.append_array(_variant_to_string_array(skill_result.get("errors", [])))
		if skill_result.has("entry"):
			normalized_skills.append((skill_result.get("entry", {}) as Dictionary).duplicate(true))
	snapshot.skills = normalized_skills

	var normalized_items: Array[Dictionary] = []
	var occupied_slots: Dictionary = {}
	var used_slots: int = 0
	for item_entry in snapshot.items:
		var item_result: Dictionary = _normalize_item_entry(item_entry)
		errors.append_array(_variant_to_string_array(item_result.get("errors", [])))
		if not item_result.has("entry"):
			continue
		var normalized_item: Dictionary = (item_result.get("entry", {}) as Dictionary).duplicate(true)
		var item_slot: int = int(normalized_item.get("slot_index", -1))
		var slot_count: int = int(normalized_item.get("size", 1))
		if item_slot + slot_count > snapshot.slot_capacity:
			errors.append(
				"slot_capacity_exceeded:%s:start=%d:size=%d:capacity=%d"
				% [str(normalized_item.get("item_id", "")), item_slot, slot_count, snapshot.slot_capacity]
			)
		for slot_offset in range(slot_count):
			var occupied_slot: int = item_slot + slot_offset
			if occupied_slots.has(occupied_slot):
				errors.append(
					"overlapping_item_slots:%d:%s:%s"
					% [occupied_slot, str(occupied_slots[occupied_slot]), str(normalized_item.get("item_id", ""))]
				)
			else:
				occupied_slots[occupied_slot] = str(normalized_item.get("item_id", ""))
		used_slots += slot_count
		normalized_items.append(normalized_item)
	if used_slots > snapshot.slot_capacity:
		errors.append("slot_capacity_exceeded_total:used=%d:capacity=%d" % [used_slots, snapshot.slot_capacity])
	normalized_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)
	snapshot.items = normalized_items

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"normalized": snapshot.to_dictionary(),
	}

static func load_local_snapshots(
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR
) -> Array[GhostSnapshotClass]:
	var snapshots: Array[GhostSnapshotClass] = []
	for day_dir in _list_subdirectories(store_dir):
		for file_path in _list_json_files(day_dir):
			var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				continue
			var json := JSON.new()
			var parse_error: int = json.parse(file.get_as_text())
			if parse_error != OK:
				continue
			var data: Variant = json.get_data()
			if not data is Dictionary:
				continue
			var source_data: Dictionary = data as Dictionary
			var validation: Dictionary = validate_ghost_snapshot(source_data)
			if not bool(validation.get("valid", false)):
				continue
			var snapshot: GhostSnapshotClass = GhostSnapshotClass.from_dictionary(
				(validation.get("normalized", {}) as Dictionary).duplicate(true)
			)
			snapshot.source = str(source_data.get("source", snapshot.source))
			snapshot.created_at = str(source_data.get("created_at", snapshot.created_at))
			snapshot.generator_version = str(source_data.get("generator_version", snapshot.generator_version))
			snapshot.rules_version = str(source_data.get("rules_version", snapshot.rules_version))
			snapshots.append(snapshot)
	snapshots.sort_custom(func(a: GhostSnapshotClass, b: GhostSnapshotClass) -> bool:
		if a.day == b.day:
			return a.power_score < b.power_score
		return a.day < b.day
	)
	return snapshots

static func load_seed_snapshots(path: String = DEFAULT_CURATED_PATH) -> Array[GhostSnapshotClass]:
	var loaded: Dictionary = load_curated_file(path)
	var snapshots: Array[GhostSnapshotClass] = []
	if not bool(loaded.get("success", false)):
		return snapshots
	for archetype in loaded.get("archetypes", []):
		var snapshot: GhostSnapshotClass = curated_archetype_to_snapshot(archetype)
		if snapshot.snapshot_id.is_empty():
			continue
		snapshots.append(snapshot)
	snapshots.sort_custom(func(a: GhostSnapshotClass, b: GhostSnapshotClass) -> bool:
		if a.day == b.day:
			return a.power_score < b.power_score
		return a.day < b.day
	)
	return snapshots

static func pick_snapshot_for_day(
	day: int,
	path: String = DEFAULT_CURATED_PATH,
	target_power_score: int = -1,
	local_store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = "",
	selection_seed: int = -1
) -> GhostSnapshotClass:
	var report: Dictionary = pick_snapshot_for_day_report(
		day,
		path,
		target_power_score,
		local_store_dir,
		exclude_snapshot_id,
		selection_seed
	)
	return report.get("snapshot", GhostSnapshotClass.new()) as GhostSnapshotClass

static func pick_snapshot_for_day_report(
	day: int,
	path: String = DEFAULT_CURATED_PATH,
	target_power_score: int = -1,
	local_store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = "",
	selection_seed: int = -1,
	target_snapshot: GhostSnapshotClass = null
) -> Dictionary:
	var target_profile: Dictionary = _build_target_match_profile(day, target_power_score, target_snapshot)
	var local_report: Dictionary = pick_local_snapshot_for_day_report(
		day,
		target_power_score,
		local_store_dir,
		exclude_snapshot_id,
		selection_seed,
		target_profile
	)
	var local_snapshot: GhostSnapshotClass = local_report.get("snapshot", GhostSnapshotClass.new()) as GhostSnapshotClass
	if local_snapshot != null and not local_snapshot.snapshot_id.is_empty():
		local_report["source"] = LOCAL_SOURCE
		return local_report

	var curated_report: Dictionary = _pick_curated_snapshot_report(day, path, selection_seed, target_profile)
	curated_report["local_fallback_reason"] = str(local_report.get("fallback_reason", "no_local_candidates"))
	return curated_report

static func pick_snapshot_for_opponent(
	player_snapshot: GhostSnapshotClass,
	path: String = DEFAULT_CURATED_PATH,
	local_store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = "",
	selection_seed: int = -1
) -> Dictionary:
	if player_snapshot == null:
		return pick_snapshot_for_day_report(1, path, -1, local_store_dir, exclude_snapshot_id, selection_seed)
	var excluded_id: String = exclude_snapshot_id
	if excluded_id.is_empty():
		excluded_id = player_snapshot.snapshot_id
	return pick_snapshot_for_day_report(
		player_snapshot.day,
		path,
		player_snapshot.power_score,
		local_store_dir,
		excluded_id,
		selection_seed,
		player_snapshot
	)

static func pick_local_snapshot_for_day(
	day: int,
	target_power_score: int = -1,
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = "",
	selection_seed: int = -1
) -> GhostSnapshotClass:
	var report: Dictionary = pick_local_snapshot_for_day_report(
		day,
		target_power_score,
		store_dir,
		exclude_snapshot_id,
		selection_seed
	)
	return report.get("snapshot", GhostSnapshotClass.new()) as GhostSnapshotClass

static func pick_local_snapshot_for_day_report(
	day: int,
	target_power_score: int = -1,
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = "",
	selection_seed: int = -1,
	target_profile: Dictionary = {}
) -> Dictionary:
	var snapshots: Array[GhostSnapshotClass] = load_local_snapshots(store_dir)
	var profile: Dictionary = target_profile.duplicate(true)
	if profile.is_empty():
		profile = _build_target_match_profile(day, target_power_score, null)
	var target_bucket: String = str(profile.get("power_bucket", ""))
	var same_day_candidates: Array[GhostSnapshotClass] = []
	var scored: Array[Dictionary] = []
	for snapshot in snapshots:
		if int(snapshot.day) != day:
			continue
		if not exclude_snapshot_id.is_empty() and snapshot.snapshot_id == exclude_snapshot_id:
			continue
		same_day_candidates.append(snapshot)
		var candidate_profile: Dictionary = build_power_profile(snapshot)
		var match_score: int = _calculate_match_score(candidate_profile, profile)
		scored.append({
			"snapshot": snapshot,
			"score": match_score,
			"profile": candidate_profile,
			"bucket_match": target_bucket.is_empty() or str(candidate_profile.get("power_bucket", "")) == target_bucket,
		})
	if scored.is_empty():
		return {
			"snapshot": GhostSnapshotClass.new(),
			"source": LOCAL_SOURCE,
			"fallback_reason": "no_local_candidates_for_day:%d" % day,
			"target_profile": profile,
			"candidate_count": 0,
		}

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return str((a.get("snapshot") as GhostSnapshotClass).snapshot_id) < str((b.get("snapshot") as GhostSnapshotClass).snapshot_id)
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)
	var best_score: int = int(scored[0].get("score", 0))
	var band: Array[Dictionary] = []
	for entry in scored:
		if int(entry.get("score", 0)) - best_score <= LOCAL_MATCH_BAND_SCORE:
			band.append(entry)
	var chosen_index: int = _selection_index(band.size(), selection_seed, day, target_power_score, exclude_snapshot_id)
	var chosen: Dictionary = band[chosen_index]
	var chosen_snapshot: GhostSnapshotClass = chosen.get("snapshot") as GhostSnapshotClass
	return {
		"snapshot": chosen_snapshot.duplicate_snapshot(),
		"source": LOCAL_SOURCE,
		"fallback_reason": "",
		"target_profile": profile,
		"selected_profile": chosen.get("profile", {}),
		"match_score": int(chosen.get("score", 0)),
		"power_band_match": bool(chosen.get("bucket_match", false)),
		"candidate_count": scored.size(),
		"same_day_candidate_count": same_day_candidates.size(),
		"rotation_band_count": band.size(),
		"selection_seed": selection_seed,
	}

static func ghost_snapshot_to_monster(snapshot: GhostSnapshotClass) -> MonsterDataClass:
	var monster: MonsterDataClass = MonsterDataClass.new()
	if snapshot == null:
		return monster

	monster.monster_name = snapshot.hero_name if not snapshot.hero_name.is_empty() else get_hero_display_name(snapshot.hero_id)
	monster.max_hp = snapshot.max_health
	monster.current_hp = snapshot.health
	monster.current_shield = 0.0
	monster.gold_reward_min = 0
	monster.gold_reward_max = 0
	monster.xp_reward = 0
	monster.reward = {
		"is_ghost_snapshot": true,
		"source": snapshot.source,
		"snapshot_id": snapshot.snapshot_id,
		"power_score": snapshot.power_score,
		"power_bucket": snapshot.power_bucket,
	}
	monster.is_ghost_snapshot = true
	monster.source_snapshot_id = snapshot.snapshot_id
	monster.source_snapshot = snapshot.to_dictionary()
	monster.ai = MonsterAIClass.create_aggressive()
	monster.monster_skills = _build_monster_skill_entries(snapshot.skills)
	monster.monster_items = []
	for item_entry in snapshot.items:
		var item_data: ItemDataClass = BazaarContentClass.create_item(
			str(item_entry.get("item_id", "")),
			_tier_to_rarity(str(item_entry.get("tier", TIER_BRONZE))),
			str(item_entry.get("enchantment", ""))
		)
		if item_data == null:
			continue
		var monster_item: Dictionary = BazaarContentClass.item_to_monster_item(item_data)
		monster_item["slot_count"] = int(item_entry.get("size", item_data.get_slot_count()))
		monster_item["slot_index"] = int(item_entry.get("slot_index", 0))
		monster_item["tier"] = str(item_entry.get("tier", TIER_BRONZE))
		monster_item["charges"] = int(item_entry.get("charges", 0))
		if item_entry.has("cooldown") and float(item_entry.get("cooldown", -1.0)) >= 0.0:
			monster_item["cooldown"] = maxf(float(item_entry.get("cooldown", 0.0)), 0.0)
			monster_item["current_cooldown"] = maxf(float(monster_item["cooldown"]), 0.0)
		if item_entry.has("ammo") and int(item_entry.get("ammo", -1)) >= 0:
			monster_item["ammo"] = int(item_entry.get("ammo", 0))
		monster.monster_items.append(monster_item)

	monster.monster_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)
	monster.init_item_cooldowns()
	return monster

static func calculate_power_score(snapshot: GhostSnapshotClass) -> int:
	if snapshot == null:
		return 0

	var profile: Dictionary = build_power_profile(snapshot)
	var score: float = 0.0
	score += float(profile.get("day", 1)) * 110.0
	score += float(profile.get("level", 1)) * 75.0
	score += float(snapshot.max_health) * 1.6
	score += float(snapshot.health) * 0.35
	score += float(snapshot.prestige) * 8.0
	score += snapshot.regeneration * 28.0
	score += float(profile.get("skill_value", 0.0))
	score += float(profile.get("board_value", 0.0))
	if snapshot.slot_capacity > 0:
		score += clampf(float(profile.get("used_slots", 0)) / float(snapshot.slot_capacity), 0.0, 1.0) * 70.0
	score += float(profile.get("skill_count", 0)) * 12.0
	score += float(profile.get("enchantment_count", 0)) * 35.0
	return int(round(score))

static func build_power_profile(snapshot: GhostSnapshotClass) -> Dictionary:
	var profile: Dictionary = {
		"day": 1,
		"level": 1,
		"hero_id": "",
		"power_score": 0,
		"power_bucket": DEFAULT_POWER_BUCKET,
		"board_value": 0,
		"skill_value": 0,
		"skill_count": 0,
		"item_count": 0,
		"used_slots": 0,
		"slot_capacity": 0,
		"enchantment_count": 0,
		"enchantments": [],
		"match_bucket": "",
	}
	if snapshot == null:
		profile["match_bucket"] = _compose_match_bucket(profile)
		return profile
	var board_value: float = 0.0
	var used_slots: int = 0
	var enchantments: Array[String] = []
	for item_entry in snapshot.items:
		board_value += _item_power_value(item_entry)
		used_slots += int(item_entry.get("size", 1))
		var enchantment: String = str(item_entry.get("enchantment", "")).to_lower()
		if not enchantment.is_empty() and not enchantments.has(enchantment):
			enchantments.append(enchantment)
	var skill_value: float = 0.0
	for skill_entry in snapshot.skills:
		skill_value += _skill_power_value(skill_entry)
	var score: int = int(snapshot.power_score)
	if score <= 0:
		score = int(round(
			float(snapshot.day) * 110.0
			+ float(snapshot.level) * 75.0
			+ float(snapshot.max_health) * 1.6
			+ float(snapshot.health) * 0.35
			+ float(snapshot.prestige) * 8.0
			+ snapshot.regeneration * 28.0
			+ skill_value
			+ board_value
		))
	profile["day"] = snapshot.day
	profile["level"] = snapshot.level
	profile["hero_id"] = snapshot.hero_id
	profile["power_score"] = score
	profile["power_bucket"] = calculate_power_bucket(score)
	profile["board_value"] = int(round(board_value))
	profile["skill_value"] = int(round(skill_value))
	profile["skill_count"] = snapshot.skills.size()
	profile["item_count"] = snapshot.items.size()
	profile["used_slots"] = used_slots
	profile["slot_capacity"] = snapshot.slot_capacity
	profile["enchantment_count"] = enchantments.size()
	profile["enchantments"] = enchantments
	profile["match_bucket"] = _compose_match_bucket(profile)
	return profile

static func calculate_power_bucket(power_score: int) -> String:
	if power_score >= 2100:
		return "P90"
	if power_score >= 1600:
		return "P75"
	if power_score >= 1100:
		return "P50"
	if power_score >= 700:
		return "P25"
	return DEFAULT_POWER_BUCKET

static func get_hero_display_name(hero_id: String) -> String:
	return str(HERO_ID_TO_NAME.get(str(hero_id).to_lower(), hero_id.capitalize()))

static func get_hero_id_for_type(hero_type: int) -> String:
	for hero_id in HERO_ID_TO_TYPE.keys():
		if int(HERO_ID_TO_TYPE[hero_id]) == hero_type:
			return hero_id
	return "warrior"

static func _normalize_skill_entry(skill_entry: Variant) -> Dictionary:
	var result: Dictionary = {"errors": [], "warnings": []}
	var entry: Dictionary = {}
	if skill_entry is Dictionary:
		entry = (skill_entry as Dictionary).duplicate(true)
	else:
		entry = {"id": str(skill_entry)}

	var skill_id: String = str(entry.get("id", entry.get("skill_id", ""))).strip_edges().to_lower()
	var tier: String = _normalize_tier_name(entry.get("tier", TIER_BRONZE))
	if skill_id.is_empty():
		result["errors"] = ["missing_skill_id"]
		return result

	var resolved: Dictionary = PlayerSkillCatalogClass.get_skill_entry({"id": skill_id, "tier": tier})
	var support_status: String = str(resolved.get("support_status", PlayerSkillCatalogClass.SUPPORT_UNKNOWN))
	match support_status:
		PlayerSkillCatalogClass.SUPPORT_UNKNOWN:
			result["errors"] = ["unknown_skill:%s" % skill_id]
			return result
		PlayerSkillCatalogClass.SUPPORT_UNSUPPORTED:
			result["errors"] = [
				"unsupported_skill:%s:%s"
				% [skill_id, str(resolved.get("unsupported_reason", "unknown"))],
			]
			return result

	result["entry"] = {
		"id": skill_id,
		"name": str(resolved.get("name", skill_id.capitalize())),
		"tier": tier,
	}
	return result

static func _normalize_item_entry(item_entry: Variant) -> Dictionary:
	var result: Dictionary = {"errors": [], "warnings": []}
	if not item_entry is Dictionary:
		result["errors"] = ["invalid_item_entry_type"]
		return result

	var entry: Dictionary = (item_entry as Dictionary).duplicate(true)
	var item_id: String = str(entry.get("item_id", entry.get("id", ""))).strip_edges().to_lower()
	var tier: String = _normalize_tier_name(entry.get("tier", TIER_BRONZE))
	var slot_size: int = int(entry.get("size", 1))
	var slot_index: int = int(entry.get("slot_index", -1))
	var enchantment: String = str(entry.get("enchantment", "")).strip_edges().to_lower()
	var cooldown: float = float(entry.get("cooldown", -1.0))
	var ammo: int = int(entry.get("ammo", -1))
	var charges: int = int(entry.get("charges", 0))

	if item_id.is_empty():
		result["errors"] = ["missing_item_id"]
		return result
	if not EnchantmentCatalogClass.is_known_enchantment(enchantment):
		result["errors"] = ["invalid_enchantment:%s:%s" % [item_id, enchantment]]
		return result
	if slot_size < 1 or slot_size > 3:
		result["errors"] = ["invalid_item_size:%s:%d" % [item_id, slot_size]]
		return result
	if slot_index < 0:
		result["errors"] = ["invalid_item_slot:%s:%d" % [item_id, slot_index]]
		return result
	if cooldown < -0.001:
		result["errors"] = ["invalid_item_cooldown:%s:%.2f" % [item_id, cooldown]]
		return result
	if ammo < -1:
		result["errors"] = ["invalid_item_ammo:%s:%d" % [item_id, ammo]]
		return result
	if charges < 0:
		result["errors"] = ["invalid_item_charges:%s:%d" % [item_id, charges]]
		return result

	var item_data: ItemDataClass = BazaarContentClass.create_item(item_id, _tier_to_rarity(tier))
	if item_data == null:
		result["errors"] = ["unknown_item:%s" % item_id]
		return result

	if slot_size != item_data.get_slot_count():
		result["warnings"] = [
			"slot_size_override:%s:base=%d:override=%d"
			% [item_id, item_data.get_slot_count(), slot_size],
		]

	var normalized: Dictionary = {
		"item_id": item_id,
		"name": item_data.item_name,
		"tier": tier,
		"size": slot_size,
		"slot_index": slot_index,
		"enchantment": enchantment,
		"cooldown": item_data.cooldown if cooldown < 0.0 else cooldown,
		"ammo": item_data.ammo if ammo < 0 else ammo,
		"charges": charges,
	}
	result["entry"] = normalized
	return result

static func _capture_inventory_items(inventory: LinearInventoryClass) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if inventory == null:
		return items
	for item in inventory.items:
		if item == null:
			continue
		items.append({
			"item_id": item.source_id,
			"name": item.item_name,
			"tier": _rarity_to_tier(item.rarity),
			"size": item.get_slot_count(),
			"slot_index": item.slot_index,
			"enchantment": item.enchantment_id,
			"cooldown": item.cooldown,
			"ammo": item.ammo,
			"charges": 0,
		})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)
	return items

static func _build_monster_skill_entries(skill_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for skill_entry in skill_entries:
		var skill_id: String = str(skill_entry.get("id", "")).to_lower()
		var resolved: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_entry)
		result.append({
			"id": skill_id,
			"name": str(resolved.get("name", skill_id.capitalize())),
			"tier": str(skill_entry.get("tier", TIER_BRONZE)),
		})
	return result

static func _collect_snapshot_tags(snapshot: GhostSnapshotClass) -> Array[String]:
	var tags: Array[String] = []
	var seen: Dictionary = {}
	for item_entry in snapshot.items:
		var item_id: String = str(item_entry.get("item_id", ""))
		var item: ItemDataClass = BazaarContentClass.create_item(
			item_id,
			_tier_to_rarity(str(item_entry.get("tier", TIER_BRONZE)))
		)
		if item == null:
			continue
		for tag in item.tags:
			var normalized_tag: String = str(tag).to_lower()
			if normalized_tag.is_empty() or seen.has(normalized_tag):
				continue
			seen[normalized_tag] = true
			tags.append(normalized_tag)
		var enchantment: String = str(item_entry.get("enchantment", "")).to_lower()
		if not enchantment.is_empty() and not seen.has(enchantment):
			seen[enchantment] = true
			tags.append(enchantment)
	return tags

static func _skill_power_value(skill_entry: Dictionary) -> float:
	var resolved: Dictionary = PlayerSkillCatalogClass.get_skill_entry(skill_entry)
	var tier: String = str(skill_entry.get("tier", TIER_BRONZE))
	var base_score: float = 42.0
	var tier_bonus: float = float(_tier_to_rarity(tier) - 1) * 18.0
	var numeric_value: float = PlayerSkillCatalogClass.get_tier_value(
		{"id": str(resolved.get("id", "")), "tier": tier},
		"values",
		0.0
	)
	if numeric_value <= 0.0:
		numeric_value = PlayerSkillCatalogClass.get_tier_value(
			{"id": str(resolved.get("id", "")), "tier": tier},
			"charge_seconds",
			0.0
		)
	base_score += numeric_value * 6.0
	return base_score + tier_bonus

static func _item_power_value(item_entry: Dictionary) -> float:
	var item_id: String = str(item_entry.get("item_id", ""))
	var tier: String = str(item_entry.get("tier", TIER_BRONZE))
	var item: ItemDataClass = BazaarContentClass.create_item(item_id, _tier_to_rarity(tier))
	if item == null:
		return 0.0

	var score: float = 0.0
	score += float(_tier_to_rarity(tier)) * 60.0
	score += float(int(item_entry.get("size", item.get_slot_count()))) * 18.0
	score += float(item.damage) * 1.4
	score += float(item.shield) * 1.1
	score += float(item.heal) * 1.1
	score += float(item.burn_damage) * 9.0
	score += float(item.poison_damage) * 9.0
	score += float(item.regeneration) * 11.0
	score += maxf(item.cooldown, 0.0) * 2.5
	score += maxf(float(item_entry.get("charges", 0)), 0.0) * 12.0
	score += maxf(float(item_entry.get("ammo", item.ammo)), 0.0) * 9.0
	score += float(EnchantmentCatalogClass.get_power_bonus(str(item_entry.get("enchantment", ""))))
	return score

static func build_battle_replay_summary(
	snapshot: GhostSnapshotClass,
	monster: MonsterDataClass,
	effect_trace: Array,
	battle_logs: Array[String],
	won: bool,
	result_reason: String,
	player_health: int,
	player_shield: float = 0.0
) -> Dictionary:
	var trace_summary: Dictionary = _summarize_effect_trace(effect_trace)
	var log_summary: Dictionary = _summarize_battle_logs(battle_logs)
	var opponent_health: int = 0
	var opponent_shield: float = 0.0
	if monster != null:
		opponent_health = int(monster.current_hp)
		opponent_shield = float(monster.get("current_shield")) if "current_shield" in monster else 0.0
	return {
		"schema_version": 1,
		"summary_version": DEFAULT_REPLAY_VERSION,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"snapshot_id": "" if snapshot == null else snapshot.snapshot_id,
		"opponent_name": "" if monster == null else monster.monster_name,
		"source": "" if snapshot == null else snapshot.source,
		"day": 0 if snapshot == null else snapshot.day,
		"hero_id": "" if snapshot == null else snapshot.hero_id,
		"power_score": 0 if snapshot == null else snapshot.power_score,
		"power_bucket": "" if snapshot == null else snapshot.power_bucket,
		"match_profile": {} if snapshot == null else build_power_profile(snapshot),
		"won": won,
		"result_reason": result_reason,
		"final_state": {
			"player_health": player_health,
			"player_shield": int(round(player_shield)),
			"opponent_health": opponent_health,
			"opponent_shield": int(round(opponent_shield)),
		},
		"key_triggers": log_summary.get("key_triggers", []),
		"source_totals": log_summary.get("source_totals", {}),
		"effect_totals": trace_summary.get("effect_totals", {}),
		"major_drivers": _build_major_drivers(log_summary, trace_summary, won, result_reason),
		"log_excerpt": _tail_strings(battle_logs, 8),
	}

static func save_battle_replay_summary(
	summary: Dictionary,
	store_dir: String = DEFAULT_REPLAY_DIR
) -> Dictionary:
	if summary.is_empty():
		return {"success": false, "saved": false, "errors": ["missing_summary"], "path": ""}
	var day: int = maxi(int(summary.get("day", 1)), 1)
	var directory_path: String = "%s/day%02d" % [store_dir, day]
	var ensure_result: Dictionary = _ensure_user_directory(directory_path)
	if not bool(ensure_result.get("success", false)):
		return ensure_result
	var snapshot_id: String = _sanitize_file_token(str(summary.get("snapshot_id", "pvp_replay")))
	if snapshot_id.is_empty():
		snapshot_id = "pvp_replay"
	var timestamp: String = _sanitize_file_token(Time.get_datetime_string_from_system(false, true))
	var file_path: String = "%s/%s_%s.json" % [directory_path, snapshot_id, timestamp]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "saved": false, "errors": ["write_open_failed:%s" % file_path], "path": file_path}
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	return {"success": true, "saved": true, "path": file_path, "summary": summary}

static func _pick_curated_snapshot_report(
	day: int,
	path: String,
	selection_seed: int,
	target_profile: Dictionary
) -> Dictionary:
	var snapshots: Array[GhostSnapshotClass] = load_seed_snapshots(path)
	if snapshots.is_empty():
		return {
			"snapshot": GhostSnapshotClass.new(),
			"source": GhostSnapshotClass.DEFAULT_SOURCE,
			"fallback_reason": "curated_pool_empty",
			"target_profile": target_profile,
			"candidate_count": 0,
		}
	var same_day: Array[GhostSnapshotClass] = []
	for snapshot in snapshots:
		if snapshot.day == day:
			same_day.append(snapshot)
	var pool: Array[GhostSnapshotClass] = same_day if not same_day.is_empty() else snapshots
	var scored: Array[Dictionary] = []
	for snapshot in pool:
		var profile: Dictionary = build_power_profile(snapshot)
		scored.append({"snapshot": snapshot, "profile": profile, "score": _calculate_match_score(profile, target_profile)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) == int(b.get("score", 0)):
			return int((a.get("snapshot") as GhostSnapshotClass).day) < int((b.get("snapshot") as GhostSnapshotClass).day)
		return int(a.get("score", 0)) < int(b.get("score", 0))
	)
	var chosen_index: int = _selection_index(mini(scored.size(), 3), selection_seed, day, int(target_profile.get("power_score", -1)), "curated")
	var chosen: Dictionary = scored[chosen_index]
	var chosen_snapshot: GhostSnapshotClass = chosen.get("snapshot") as GhostSnapshotClass
	return {
		"snapshot": chosen_snapshot.duplicate_snapshot(),
		"source": GhostSnapshotClass.DEFAULT_SOURCE,
		"fallback_reason": "no_local_power_match_curated_fallback" if not same_day.is_empty() else "no_same_day_curated_using_closest_day",
		"target_profile": target_profile,
		"selected_profile": chosen.get("profile", {}),
		"match_score": int(chosen.get("score", 0)),
		"power_band_match": str((chosen.get("profile", {}) as Dictionary).get("power_bucket", "")) == str(target_profile.get("power_bucket", "")),
		"candidate_count": pool.size(),
		"selection_seed": selection_seed,
	}

static func _build_target_match_profile(day: int, target_power_score: int, target_snapshot: GhostSnapshotClass) -> Dictionary:
	if target_snapshot != null:
		return build_power_profile(target_snapshot)
	var score: int = target_power_score if target_power_score >= 0 else 0
	var profile: Dictionary = {
		"day": day,
		"level": day,
		"hero_id": "",
		"power_score": score,
		"power_bucket": calculate_power_bucket(score) if score > 0 else "",
		"board_value": 0,
		"skill_value": 0,
		"skill_count": 0,
		"item_count": 0,
		"used_slots": 0,
		"slot_capacity": LinearInventoryClass.TOTAL_SLOTS,
		"enchantment_count": 0,
		"enchantments": [],
	}
	profile["match_bucket"] = _compose_match_bucket(profile)
	return profile

static func _calculate_match_score(candidate_profile: Dictionary, target_profile: Dictionary) -> int:
	var score: int = 0
	score += abs(int(candidate_profile.get("power_score", 0)) - int(target_profile.get("power_score", 0)))
	score += abs(int(candidate_profile.get("day", 1)) - int(target_profile.get("day", 1))) * 500
	score += abs(int(candidate_profile.get("level", 1)) - int(target_profile.get("level", 1))) * 90
	score += abs(int(candidate_profile.get("board_value", 0)) - int(target_profile.get("board_value", 0))) / 3
	score += abs(int(candidate_profile.get("skill_count", 0)) - int(target_profile.get("skill_count", 0))) * 45
	score += abs(int(candidate_profile.get("enchantment_count", 0)) - int(target_profile.get("enchantment_count", 0))) * 55
	if not str(target_profile.get("hero_id", "")).is_empty() and str(candidate_profile.get("hero_id", "")) != str(target_profile.get("hero_id", "")):
		score += 70
	if not str(target_profile.get("power_bucket", "")).is_empty() and str(candidate_profile.get("power_bucket", "")) != str(target_profile.get("power_bucket", "")):
		score += 300
	return score

static func _selection_index(count: int, selection_seed: int, day: int, target_power_score: int, token: String) -> int:
	if count <= 1:
		return 0
	var seed: int = selection_seed
	if seed < 0:
		seed = Time.get_ticks_msec()
	seed += day * 97 + target_power_score * 13 + _stable_string_hash(token)
	return abs(seed) % count

static func _compose_match_bucket(profile: Dictionary) -> String:
	return "D%02d-L%02d-%s-%s-B%03d-S%02d-E%02d" % [
		int(profile.get("day", 1)),
		int(profile.get("level", 1)),
		str(profile.get("hero_id", "any")),
		str(profile.get("power_bucket", DEFAULT_POWER_BUCKET)),
		int(profile.get("board_value", 0)) / 100,
		int(profile.get("skill_count", 0)),
		int(profile.get("enchantment_count", 0)),
	]

static func _summarize_effect_trace(effect_trace: Array) -> Dictionary:
	var totals: Dictionary = {}
	for entry in effect_trace:
		if not entry is Dictionary:
			continue
		var trace: Dictionary = entry as Dictionary
		var effect_type: String = str(trace.get("effect_type", ""))
		if effect_type.is_empty():
			continue
		totals[effect_type] = float(totals.get(effect_type, 0.0)) + float(trace.get("amount", 0.0)) * maxf(float(trace.get("target_count", 1)), 1.0)
	return {"effect_totals": totals}

static func _summarize_battle_logs(battle_logs: Array[String]) -> Dictionary:
	var source_totals: Dictionary = {"damage": {}, "heal": {}, "shield": {}, "status": {}}
	var key_triggers: Array[Dictionary] = []
	for line in battle_logs:
		var source_name: String = _extract_between(line, "[", "]")
		if source_name.is_empty():
			source_name = "battle"
		var damage: int = _extract_number_before(line, "伤害")
		var heal: int = _extract_number_before(line, "生命")
		var shield: int = _extract_number_before(line, "护盾")
		var poison: int = _extract_number_before(line, "中毒")
		var burn: int = _extract_number_before(line, "燃烧")
		if damage > 0:
			_add_source_total(source_totals["damage"], source_name, damage)
		if heal > 0:
			_add_source_total(source_totals["heal"], source_name, heal)
		if shield > 0:
			_add_source_total(source_totals["shield"], source_name, shield)
		if poison > 0:
			_add_source_total(source_totals["status"], "%s:poison" % source_name, poison)
		if burn > 0:
			_add_source_total(source_totals["status"], "%s:burn" % source_name, burn)
		if damage > 0 or heal > 0 or shield > 0 or poison > 0 or burn > 0:
			key_triggers.append({
				"source": source_name,
				"damage": damage,
				"heal": heal,
				"shield": shield,
				"poison": poison,
				"burn": burn,
				"line": line,
			})
	return {"source_totals": source_totals, "key_triggers": _top_trigger_entries(key_triggers, 8)}

static func _build_major_drivers(log_summary: Dictionary, trace_summary: Dictionary, won: bool, result_reason: String) -> Array[String]:
	var drivers: Array[String] = []
	drivers.append("result:%s" % result_reason)
	var source_totals: Dictionary = log_summary.get("source_totals", {}) as Dictionary
	for category in ["damage", "heal", "shield", "status"]:
		var totals: Dictionary = source_totals.get(category, {}) as Dictionary
		var top: String = _top_total_key(totals)
		if not top.is_empty():
			drivers.append("%s:%s=%s" % [category, top, str(totals[top])])
	var effect_totals: Dictionary = trace_summary.get("effect_totals", {}) as Dictionary
	var top_effect: String = _top_total_key(effect_totals)
	if not top_effect.is_empty():
		drivers.append("effect:%s=%s" % [top_effect, str(effect_totals[top_effect])])
	if drivers.size() == 1:
		drivers.append("outcome:%s" % ("player_survived" if won else "player_defeated"))
	return drivers

static func _add_source_total(totals: Dictionary, source_name: String, amount: int) -> void:
	if source_name.is_empty() or amount <= 0:
		return
	totals[source_name] = int(totals.get(source_name, 0)) + amount

static func _top_trigger_entries(entries: Array[Dictionary], limit: int) -> Array[Dictionary]:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_total: int = int(a.get("damage", 0)) + int(a.get("heal", 0)) + int(a.get("shield", 0)) + int(a.get("poison", 0)) + int(a.get("burn", 0))
		var b_total: int = int(b.get("damage", 0)) + int(b.get("heal", 0)) + int(b.get("shield", 0)) + int(b.get("poison", 0)) + int(b.get("burn", 0))
		return a_total > b_total
	)
	var result: Array[Dictionary] = []
	for index in range(mini(entries.size(), limit)):
		result.append(entries[index].duplicate(true))
	return result

static func _top_total_key(totals: Dictionary) -> String:
	var best_key: String = ""
	var best_value: float = -1.0
	for key in totals.keys():
		var value: float = float(totals[key])
		if value > best_value:
			best_key = str(key)
			best_value = value
	return best_key

static func _tail_strings(values: Array[String], limit: int) -> Array[String]:
	var result: Array[String] = []
	var start_index: int = maxi(values.size() - limit, 0)
	for index in range(start_index, values.size()):
		result.append(values[index])
	return result

static func _extract_between(text: String, left: String, right: String) -> String:
	var start: int = text.find(left)
	if start < 0:
		return ""
	var end: int = text.find(right, start + left.length())
	if end < 0:
		return ""
	return text.substr(start + left.length(), end - start - left.length())

static func _extract_number_before(text: String, marker: String) -> int:
	var marker_index: int = text.find(marker)
	if marker_index < 0:
		return 0
	var index: int = marker_index - 1
	while index >= 0 and text[index] == " ":
		index -= 1
	var end_index: int = index
	while index >= 0 and text[index] >= "0" and text[index] <= "9":
		index -= 1
	if end_index < index + 1:
		return 0
	return int(text.substr(index + 1, end_index - index))

static func _stable_string_hash(value: String) -> int:
	var hash_value: int = 0
	for index in range(value.length()):
		hash_value = int((hash_value * 31 + value.unicode_at(index)) & 0x7fffffff)
	return hash_value

static func _tier_to_rarity(tier_name: String) -> int:
	return int(TIER_TO_RARITY.get(_normalize_tier_name(tier_name), BazaarContentClass.RARITY_BRONZE))

static func _rarity_to_tier(rarity: int) -> String:
	return str(RARITY_TO_TIER.get(clampi(rarity, 1, 4), TIER_BRONZE))

static func _normalize_tier_name(raw_tier: Variant) -> String:
	var tier_name: String = str(raw_tier).strip_edges().to_lower()
	if tier_name.is_empty():
		return TIER_BRONZE
	if VALID_TIERS.has(tier_name):
		return tier_name
	if raw_tier is int:
		return _rarity_to_tier(int(raw_tier))
	return TIER_BRONZE

static func _normalize_archetype_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

static func _compact_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for value in values:
		var normalized: String = str(value).strip_edges()
		if normalized.is_empty() or seen.has(normalized):
			continue
		seen[normalized] = true
		result.append(normalized)
	return result

static func _build_local_snapshot_id(snapshot: GhostSnapshotClass) -> String:
	var timestamp: String = snapshot.created_at
	if timestamp.is_empty():
		timestamp = Time.get_datetime_string_from_system(false, true)
	return _sanitize_file_token(
		"player_day%02d_hour%02d_%s_%s"
		% [snapshot.day, snapshot.hour, snapshot.power_bucket, timestamp]
	)

static func _sanitize_file_token(value: String) -> String:
	var token: String = str(value).strip_edges().to_lower()
	var result: String = ""
	for index in range(token.length()):
		var character: String = token.substr(index, 1)
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			result += character
		elif character == "_" or character == "-":
			result += character
		else:
			result += "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	if result.is_empty():
		return "snapshot"
	return result

static func _ensure_user_directory(path: String) -> Dictionary:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var error: int = DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK:
		return {
			"success": false,
			"saved": false,
			"errors": ["mkdir_failed:%s:%d" % [path, error]],
			"path": path,
		}
	return {"success": true, "path": path}

static func _list_subdirectories(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if dir.current_is_dir() and not entry_name.begins_with("."):
			result.append("%s/%s" % [path, entry_name])
		entry_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func _list_json_files(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not dir.current_is_dir() and entry_name.ends_with(".json") and entry_name != "index.json":
			result.append("%s/%s" % [path, entry_name])
		entry_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func _rebuild_local_snapshot_index(store_dir: String) -> void:
	var snapshots: Array[GhostSnapshotClass] = load_local_snapshots(store_dir)
	var entries: Array[Dictionary] = []
	for snapshot in snapshots:
		var profile: Dictionary = build_power_profile(snapshot)
		entries.append({
			"snapshot_id": snapshot.snapshot_id,
			"day": snapshot.day,
			"hour": snapshot.hour,
			"source": snapshot.source,
			"power_score": snapshot.power_score,
			"power_bucket": snapshot.power_bucket,
			"match_bucket": str(profile.get("match_bucket", "")),
			"match_profile": profile,
			"hero_id": snapshot.hero_id,
			"level": snapshot.level,
			"board_value": int(profile.get("board_value", 0)),
			"skill_count": int(profile.get("skill_count", 0)),
			"enchantment_count": int(profile.get("enchantment_count", 0)),
			"created_at": snapshot.created_at,
		})
	var ensure_result: Dictionary = _ensure_user_directory(store_dir)
	if not bool(ensure_result.get("success", false)):
		return
	var file: FileAccess = FileAccess.open("%s/index.json" % store_dir, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": FILE_SCHEMA_VERSION,
		"snapshot_schema": GhostSnapshotClass.DEFAULT_RULES_VERSION,
		"store": "ghost_pool/playtest",
		"snapshots": entries,
	}, "\t"))
	file.close()

static func _variant_to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry in value:
		result.append(str(entry))
	return result
