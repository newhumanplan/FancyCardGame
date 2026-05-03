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
const FILE_SCHEMA_VERSION: int = 1
const DEFAULT_POWER_BUCKET: String = "P10"
const LOCAL_SOURCE: String = "local_playtest"

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
	exclude_snapshot_id: String = ""
) -> GhostSnapshotClass:
	var local_match: GhostSnapshotClass = pick_local_snapshot_for_day(
		day,
		target_power_score,
		local_store_dir,
		exclude_snapshot_id
	)
	if local_match != null and not local_match.snapshot_id.is_empty():
		return local_match

	var snapshots: Array[GhostSnapshotClass] = load_seed_snapshots(path)
	if snapshots.is_empty():
		return GhostSnapshotClass.new()

	var same_day: Array[GhostSnapshotClass] = []
	for snapshot in snapshots:
		if snapshot.day == day:
			same_day.append(snapshot)
	if not same_day.is_empty():
		return same_day[int(same_day.size() / 2)].duplicate_snapshot()

	var closest: GhostSnapshotClass = snapshots[0]
	var closest_distance: int = abs(day - closest.day)
	for snapshot in snapshots:
		var distance: int = abs(day - snapshot.day)
		if distance < closest_distance:
			closest = snapshot
			closest_distance = distance
	return closest.duplicate_snapshot()

static func pick_local_snapshot_for_day(
	day: int,
	target_power_score: int = -1,
	store_dir: String = DEFAULT_LOCAL_PLAYTEST_DIR,
	exclude_snapshot_id: String = ""
) -> GhostSnapshotClass:
	var snapshots: Array[GhostSnapshotClass] = load_local_snapshots(store_dir)
	var target_bucket: String = calculate_power_bucket(target_power_score) if target_power_score >= 0 else ""
	var candidates: Array[GhostSnapshotClass] = []
	for snapshot in snapshots:
		if int(snapshot.day) != day:
			continue
		if not exclude_snapshot_id.is_empty() and snapshot.snapshot_id == exclude_snapshot_id:
			continue
		if not target_bucket.is_empty() and snapshot.power_bucket != target_bucket:
			continue
		candidates.append(snapshot)
	if candidates.is_empty() and not target_bucket.is_empty():
		for snapshot in snapshots:
			if int(snapshot.day) != day:
				continue
			if not exclude_snapshot_id.is_empty() and snapshot.snapshot_id == exclude_snapshot_id:
				continue
			candidates.append(snapshot)
	if candidates.is_empty():
		return GhostSnapshotClass.new()

	var target_score: int = target_power_score
	if target_score < 0:
		target_score = int(candidates[int(candidates.size() / 2)].power_score)
	var best: GhostSnapshotClass = candidates[0]
	var best_distance: int = abs(int(best.power_score) - target_score)
	for snapshot in candidates:
		var distance: int = abs(int(snapshot.power_score) - target_score)
		if distance < best_distance:
			best = snapshot
			best_distance = distance
	return best.duplicate_snapshot()

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

	var score: float = 0.0
	score += float(snapshot.day) * 110.0
	score += float(snapshot.level) * 75.0
	score += float(snapshot.max_health) * 1.6
	score += float(snapshot.health) * 0.35
	score += float(snapshot.prestige) * 8.0
	score += snapshot.regeneration * 28.0

	for skill_entry in snapshot.skills:
		score += _skill_power_value(skill_entry)
	for item_entry in snapshot.items:
		score += _item_power_value(item_entry)

	var used_slots: int = 0
	for item_entry in snapshot.items:
		used_slots += int(item_entry.get("size", 1))
	if snapshot.slot_capacity > 0:
		score += clampf(float(used_slots) / float(snapshot.slot_capacity), 0.0, 1.0) * 70.0

	return int(round(score))

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
		entries.append({
			"snapshot_id": snapshot.snapshot_id,
			"day": snapshot.day,
			"hour": snapshot.hour,
			"source": snapshot.source,
			"power_score": snapshot.power_score,
			"power_bucket": snapshot.power_bucket,
			"hero_id": snapshot.hero_id,
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
