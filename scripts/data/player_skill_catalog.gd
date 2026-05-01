class_name PlayerSkillCatalog
extends RefCounted

const SkillDataClass = preload("res://scripts/data/skill_data.gd")
const WikiMonsterCatalogClass = preload("res://scripts/data/wiki_monster_catalog.gd")

const _TIER_INDEX := {
	"bronze": 0,
	"silver": 1,
	"gold": 2,
	"diamond": 3,
}

const _NUMERIC_SKILL_RULES := {
	"fiery": {
		"effect_type": SkillDataClass.EffectType.BURN,
		"values": [1.0, 2.0, 3.0, 4.0],
		"starting_tier": "bronze",
	},
	"improved_toxins": {
		"effect_type": SkillDataClass.EffectType.POISON,
		"values": [1.0, 2.0, 3.0, 4.0],
		"starting_tier": "bronze",
	},
	"keen_eye": {
		"effect_type": SkillDataClass.EffectType.CRIT,
		"values": [4.0, 8.0, 12.0, 16.0],
		"starting_tier": "bronze",
	},
	"quick_defenses": {
		"effect_type": SkillDataClass.EffectType.COOLDOWN,
		"values": [5.0, 7.0, 10.0, 15.0],
		"starting_tier": "bronze",
	},
	"toughness": {
		"effect_type": SkillDataClass.EffectType.SHIELD,
		"values": [10.0, 15.0, 20.0, 25.0],
		"starting_tier": "bronze",
	},
	"large_appetites": {
		"effect_type": SkillDataClass.EffectType.HEALTH,
		"values": [500.0, 1000.0, 1500.0, 2000.0],
		"starting_tier": "bronze",
	},
}

const _TRIGGER_SKILL_RULES := {
	"heated_shells": {
		"values": [2.0, 3.0, 4.0],
		"starting_tier": "silver",
	},
	"paralytic_poison": {
		"values": [2.0, 3.0, 4.0],
		"starting_tier": "silver",
	},
	"slow_burn": {
		"limits": [5.0, 10.0],
		"charge_seconds": [1.0, 1.0],
		"starting_tier": "gold",
	},
}

static func resolve_skill_refs(skill_refs: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for skill_ref in skill_refs:
		var entry: Dictionary = normalize_skill_ref(skill_ref)
		if not entry.is_empty():
			resolved.append(entry)
	return resolved

static func normalize_skill_ref(skill_ref: Variant) -> Dictionary:
	if skill_ref == null:
		return {}
	if skill_ref is SkillDataClass:
		var data: SkillDataClass = skill_ref as SkillDataClass
		if data == null or data.id.is_empty():
			return {}
		return {
			"id": data.id.to_lower(),
			"name": data.skill_name,
			"description": data.description,
			"tier_index": int(data.rarity),
			"starting_tier_index": int(data.rarity),
			"tags": [],
			"numeric_rule": {},
			"trigger_rule": {},
		}

	var skill_id: String = ""
	var raw_tier: Variant = null
	if skill_ref is Dictionary:
		var entry: Dictionary = skill_ref as Dictionary
		skill_id = str(entry.get("id", entry.get("skill_id", ""))).strip_edges().to_lower()
		raw_tier = entry.get("tier", entry.get("rarity", null))
	elif skill_ref is String:
		skill_id = str(skill_ref).strip_edges().to_lower()
	else:
		return {}

	if skill_id.is_empty():
		return {}

	var wiki_spec: Dictionary = WikiMonsterCatalogClass.find_skill_spec(skill_id)
	var numeric_rule: Dictionary = _NUMERIC_SKILL_RULES.get(skill_id, {})
	var trigger_rule: Dictionary = _TRIGGER_SKILL_RULES.get(skill_id, {})
	var default_tier_index: int = _tier_index(
		numeric_rule.get("starting_tier", trigger_rule.get("starting_tier", wiki_spec.get("starting_tier", "bronze")))
	)
	return {
		"id": skill_id,
		"name": str(wiki_spec.get("name", _titleize_skill_id(skill_id))),
		"description": str(wiki_spec.get("effect", "")),
		"tier_index": _resolve_tier_index(raw_tier, default_tier_index),
		"starting_tier_index": default_tier_index,
		"tags": wiki_spec.get("tags", []),
		"numeric_rule": numeric_rule,
		"trigger_rule": trigger_rule,
	}

static func build_skill_data(skill_ref: Variant) -> SkillDataClass:
	var resolved: Dictionary = skill_ref if skill_ref is Dictionary else normalize_skill_ref(skill_ref)
	if resolved.is_empty():
		return null
	var numeric_rule: Dictionary = resolved.get("numeric_rule", {})
	if numeric_rule.is_empty():
		return null

	var values: Array = numeric_rule.get("values", [])
	if values.is_empty():
		return null

	var skill: SkillDataClass = SkillDataClass.new()
	skill.id = str(resolved.get("id", ""))
	skill.skill_name = str(resolved.get("name", skill.id))
	skill.description = str(resolved.get("description", ""))
	skill.rarity = clampi(int(resolved.get("tier_index", 0)), 0, 3)
	skill.effect_type = int(numeric_rule.get("effect_type", SkillDataClass.EffectType.CRIT))
	skill.effect_values = _expand_values(values, int(resolved.get("starting_tier_index", 0)))
	return skill

static func get_skill_display_name(skill_ref: Variant) -> String:
	var resolved: Dictionary = normalize_skill_ref(skill_ref)
	return "" if resolved.is_empty() else str(resolved.get("name", ""))

static func get_tier_value(skill_ref: Variant, field: String = "values", fallback: float = 0.0) -> float:
	var resolved: Dictionary = skill_ref if skill_ref is Dictionary else normalize_skill_ref(skill_ref)
	if resolved.is_empty():
		return fallback

	var source_rule: Dictionary = resolved.get("trigger_rule", {})
	if source_rule.is_empty() or not source_rule.has(field):
		source_rule = resolved.get("numeric_rule", {})
	if source_rule.is_empty():
		return fallback

	var values: Array = source_rule.get(field, [])
	if values.is_empty():
		return fallback

	var start_tier: int = clampi(int(resolved.get("starting_tier_index", 0)), 0, 3)
	var tier_index: int = clampi(int(resolved.get("tier_index", start_tier)), 0, 3)
	if tier_index < start_tier:
		return fallback
	var offset: int = clampi(tier_index - start_tier, 0, values.size() - 1)
	return float(values[offset])

static func _expand_values(values: Array, start_tier_index: int) -> Array[float]:
	var expanded: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var safe_start: int = clampi(start_tier_index, 0, 3)
	for offset in range(values.size()):
		var tier_index: int = safe_start + offset
		if tier_index < 0 or tier_index >= expanded.size():
			break
		expanded[tier_index] = float(values[offset])
	return expanded

static func _tier_index(raw_tier: Variant) -> int:
	if raw_tier is int:
		var int_value: int = int(raw_tier)
		if int_value >= 1 and int_value <= 4:
			return int_value - 1
		return clampi(int_value, 0, 3)
	var tier_name: String = str(raw_tier).strip_edges().to_lower()
	return int(_TIER_INDEX.get(tier_name, 0))

static func _resolve_tier_index(raw_tier: Variant, default_index: int) -> int:
	if raw_tier == null:
		return clampi(default_index, 0, 3)
	return _tier_index(raw_tier)

static func _titleize_skill_id(skill_id: String) -> String:
	var words: PackedStringArray = skill_id.split("_", false)
	for index in range(words.size()):
		words[index] = words[index].capitalize()
	return " ".join(words)
