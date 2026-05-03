class_name EnchantmentCatalog
extends RefCounted

const ItemDataClass = preload("res://scripts/data/item_data.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")

const NO_ENCHANTMENT: String = ""

const _ENCHANTMENT_ORDER: Array[String] = [
	NO_ENCHANTMENT,
	"fiery",
	"toxic",
	"heavy",
	"restorative",
	"obsidian",
]

const _ENCHANTMENT_SPECS := {
	"fiery": {
		"label": "Fiery",
		"name_suffix": " [Fiery]",
		"power_bonus": 60,
		"bonuses": {"burn": 2.0},
	},
	"toxic": {
		"label": "Toxic",
		"name_suffix": " [Toxic]",
		"power_bonus": 60,
		"bonuses": {"poison": 2.0},
	},
	"heavy": {
		"label": "Heavy",
		"name_suffix": " [Heavy]",
		"power_bonus": 45,
		"bonuses": {"damage": 8.0},
	},
	"restorative": {
		"label": "Restorative",
		"name_suffix": " [Restorative]",
		"power_bonus": 55,
		"bonuses": {"regeneration": 3.0, "heal": 6.0},
	},
	"obsidian": {
		"label": "Obsidian",
		"name_suffix": " [Obsidian]",
		"power_bonus": 90,
		"bonuses": {"damage": 18.0},
	},
}

static func normalize_enchantment_id(enchantment: String) -> String:
	return str(enchantment).strip_edges().to_lower()

static func get_known_ids() -> Array[String]:
	return _ENCHANTMENT_ORDER.duplicate()

static func is_known_enchantment(enchantment: String) -> bool:
	return get_known_ids().has(normalize_enchantment_id(enchantment))

static func get_label(enchantment: String) -> String:
	var enchantment_id: String = normalize_enchantment_id(enchantment)
	if enchantment_id.is_empty():
		return "None"
	return str((_ENCHANTMENT_SPECS.get(enchantment_id, {}) as Dictionary).get("label", enchantment_id))

static func get_power_bonus(enchantment: String) -> int:
	var enchantment_id: String = normalize_enchantment_id(enchantment)
	if enchantment_id.is_empty():
		return 0
	return int((_ENCHANTMENT_SPECS.get(enchantment_id, {}) as Dictionary).get("power_bonus", 0))

static func apply_to_item(item: ItemDataClass, enchantment: String) -> void:
	if item == null:
		return
	var enchantment_id: String = normalize_enchantment_id(enchantment)
	item.enchantment_id = enchantment_id
	item.item_name = item.base_item_name if not item.base_item_name.is_empty() else item.item_name
	if enchantment_id.is_empty():
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
		return

	var spec: Dictionary = _ENCHANTMENT_SPECS.get(enchantment_id, {})
	if spec.is_empty():
		push_warning("Unknown enchantment id: %s" % enchantment_id)
		item.enchantment_id = ""
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
		return

	_ensure_tag(item, "Enchanted")
	_ensure_tag(item, str(spec.get("label", enchantment_id)))
	item.item_name = "%s%s" % [item.item_name, str(spec.get("name_suffix", ""))]
	var bonuses: Dictionary = spec.get("bonuses", {})
	for bonus_key in bonuses.keys():
		var amount: float = float(bonuses.get(bonus_key, 0.0))
		match str(bonus_key):
			"damage":
				item.damage += int(round(amount))
			"shield":
				item.shield += int(round(amount))
			"heal":
				item.heal += int(round(amount))
			"burn":
				item.burn_damage += amount
			"poison":
				item.poison_damage += amount
			"regeneration":
				item.regeneration += amount

	item.effects = EffectDefinitionClass.build_item_effects(item)
	item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)

static func _ensure_tag(item: ItemDataClass, tag: String) -> void:
	if item == null or tag.is_empty():
		return
	for existing_tag in item.tags:
		if str(existing_tag).to_lower() == tag.to_lower():
			return
	item.tags.append(tag)
