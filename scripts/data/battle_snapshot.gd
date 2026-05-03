class_name BattleSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1

var schema_version: int = SCHEMA_VERSION
var snapshot_id: String = ""
var day: int = 1
var hour: int = 5
var hero_id: String = ""
var hero_name: String = ""
var level: int = 1
var slot_capacity: int = 10
var prestige: int = 20
var pvp_wins: int = 0
var max_health: int = 100
var health: int = 100
var regeneration: float = 0.0
var skills: Array[Dictionary] = []
var items: Array[Dictionary] = []
var stash_items: Array[Dictionary] = []
var tags: Array[String] = []
var source_run_id: String = ""
var notes: String = ""

func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"snapshot_id": snapshot_id,
		"day": day,
		"hour": hour,
		"hero_id": hero_id,
		"hero_name": hero_name,
		"level": level,
		"slot_capacity": slot_capacity,
		"prestige": prestige,
		"pvp_wins": pvp_wins,
		"max_health": max_health,
		"health": health,
		"regeneration": regeneration,
		"skills": _duplicate_array(skills),
		"items": _duplicate_array(items),
		"stash_items": _duplicate_array(stash_items),
		"tags": tags.duplicate(),
		"source_run_id": source_run_id,
		"notes": notes,
	}

func to_json_string(indent: String = "\t") -> String:
	return JSON.stringify(to_dictionary(), indent)

func duplicate_snapshot():
	return from_dictionary(to_dictionary())

static func from_dictionary(data: Dictionary):
	var snapshot = new()
	snapshot.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	snapshot.snapshot_id = str(data.get("snapshot_id", ""))
	snapshot.day = int(data.get("day", 1))
	snapshot.hour = int(data.get("hour", 5))
	snapshot.hero_id = str(data.get("hero_id", ""))
	snapshot.hero_name = str(data.get("hero_name", ""))
	snapshot.level = int(data.get("level", 1))
	snapshot.slot_capacity = int(data.get("slot_capacity", 10))
	snapshot.prestige = int(data.get("prestige", 20))
	snapshot.pvp_wins = int(data.get("pvp_wins", 0))
	snapshot.max_health = int(data.get("max_health", 100))
	snapshot.health = int(data.get("health", snapshot.max_health))
	snapshot.regeneration = float(data.get("regeneration", 0.0))
	snapshot.skills = _normalize_skill_array(data.get("skills", []))
	snapshot.items = _normalize_item_array(data.get("items", []))
	snapshot.stash_items = _normalize_item_array(data.get("stash_items", []))
	snapshot.tags = _normalize_string_array(data.get("tags", []))
	snapshot.source_run_id = str(data.get("source_run_id", ""))
	snapshot.notes = str(data.get("notes", ""))
	return snapshot

static func _duplicate_array(entries: Array[Dictionary]) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for entry in entries:
		copies.append(entry.duplicate(true))
	return copies

static func _normalize_dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for entry in value:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result

static func _normalize_skill_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _normalize_dictionary_array(value):
		var normalized: Dictionary = entry.duplicate(true)
		normalized["id"] = str(normalized.get("id", normalized.get("skill_id", "")))
		if normalized.has("name"):
			normalized["name"] = str(normalized.get("name", ""))
		if normalized.has("tier"):
			normalized["tier"] = str(normalized.get("tier", ""))
		result.append(normalized)
	return result

static func _normalize_item_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _normalize_dictionary_array(value):
		var normalized: Dictionary = entry.duplicate(true)
		normalized["item_id"] = str(normalized.get("item_id", normalized.get("id", "")))
		if normalized.has("name"):
			normalized["name"] = str(normalized.get("name", ""))
		if normalized.has("tier"):
			normalized["tier"] = str(normalized.get("tier", ""))
		if normalized.has("enchantment"):
			normalized["enchantment"] = str(normalized.get("enchantment", ""))
		if normalized.has("size"):
			normalized["size"] = int(normalized.get("size", 1))
		if normalized.has("slot_index"):
			normalized["slot_index"] = int(normalized.get("slot_index", 0))
		if normalized.has("ammo"):
			normalized["ammo"] = int(normalized.get("ammo", 0))
		if normalized.has("charges"):
			normalized["charges"] = int(normalized.get("charges", 0))
		if normalized.has("cooldown"):
			normalized["cooldown"] = float(normalized.get("cooldown", 0.0))
		result.append(normalized)
	return result

static func _normalize_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for entry in value:
		result.append(str(entry))
	return result
