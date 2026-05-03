class_name GhostSnapshot
extends "res://scripts/data/battle_snapshot.gd"

const BattleSnapshotClass = preload("res://scripts/data/battle_snapshot.gd")

const DEFAULT_SOURCE: String = "curated"
const DEFAULT_RULES_VERSION: String = "fcg-ghost-v1"
const DEFAULT_GENERATOR_VERSION: String = "curated-editor-v1"

var source: String = DEFAULT_SOURCE
var power_score: int = 0
var power_bucket: String = "P10"
var created_at: String = ""
var rules_version: String = DEFAULT_RULES_VERSION
var generator_version: String = DEFAULT_GENERATOR_VERSION

func to_dictionary() -> Dictionary:
	var base: Dictionary = super.to_dictionary()
	base["source"] = source
	base["power_score"] = power_score
	base["power_bucket"] = power_bucket
	base["created_at"] = created_at
	base["rules_version"] = rules_version
	base["generator_version"] = generator_version
	return base

func duplicate_snapshot():
	return from_dictionary(to_dictionary())

static func from_dictionary(data: Dictionary):
	var base = BattleSnapshotClass.from_dictionary(data)
	var snapshot = new()
	snapshot.schema_version = base.schema_version
	snapshot.snapshot_id = base.snapshot_id
	snapshot.day = base.day
	snapshot.hour = base.hour
	snapshot.hero_id = base.hero_id
	snapshot.hero_name = base.hero_name
	snapshot.level = base.level
	snapshot.slot_capacity = base.slot_capacity
	snapshot.prestige = base.prestige
	snapshot.pvp_wins = base.pvp_wins
	snapshot.max_health = base.max_health
	snapshot.health = base.health
	snapshot.regeneration = base.regeneration
	snapshot.skills = BattleSnapshotClass._normalize_skill_array(base.skills)
	snapshot.items = BattleSnapshotClass._normalize_item_array(base.items)
	snapshot.stash_items = BattleSnapshotClass._normalize_item_array(base.stash_items)
	snapshot.tags = BattleSnapshotClass._normalize_string_array(base.tags)
	snapshot.source_run_id = base.source_run_id
	snapshot.notes = base.notes
	snapshot.source = str(data.get("source", DEFAULT_SOURCE))
	snapshot.power_score = int(data.get("power_score", 0))
	snapshot.power_bucket = str(data.get("power_bucket", "P10"))
	snapshot.created_at = str(data.get("created_at", ""))
	snapshot.rules_version = str(data.get("rules_version", DEFAULT_RULES_VERSION))
	snapshot.generator_version = str(data.get("generator_version", DEFAULT_GENERATOR_VERSION))
	return snapshot
