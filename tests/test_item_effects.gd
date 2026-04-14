extends Node

## item_effects 测试 — 物品效果应用逻辑

func _ready():
	var ItemData = load("res://scripts/data/item_data.gd")
	var ItemEffects = load("res://scripts/data/item_effects.gd")
	var passed = 0
	var total = 7

	# Test 1: calculate_damage — 普通物品
	var item1 = ItemData.new()
	item1.damage = 20
	item1.rarity = 1
	var dmg1 = ItemEffects.calculate_damage(item1, false)
	var t1 = dmg1 == 20  # 普通 1.0x
	print("test_damage_normal: %s (dmg=%d)" % ["PASS" if t1 else "FAIL", dmg1])
	if t1: passed += 1

	# Test 2: calculate_damage — 暴击
	var dmg2 = ItemEffects.calculate_damage(item1, true)
	var t2 = dmg2 == 40  # 20 * 2.0
	print("test_damage_crit: %s (dmg=%d)" % ["PASS" if t2 else "FAIL", dmg2])
	if t2: passed += 1

	# Test 3: calculate_damage — 稀有度加成
	var item3 = ItemData.new()
	item3.damage = 20
	item3.rarity = 3  # 史诗 1.6x
	var dmg3 = ItemEffects.calculate_damage(item3, false)
	var t3 = dmg3 == 32  # 20 * 1.6
	print("test_damage_epic: %s (dmg=%d)" % ["PASS" if t3 else "FAIL", dmg3])
	if t3: passed += 1

	# Test 4: calculate_heal
	var item4 = ItemData.new()
	item4.heal = 15
	item4.rarity = 2  # 稀有 1.3x
	var heal4 = ItemEffects.calculate_heal(item4)
	var t4 = heal4 == int(15 * 1.3)  # 19
	print("test_heal_rare: %s (heal=%d)" % ["PASS" if t4 else "FAIL", heal4])
	if t4: passed += 1

	# Test 5: calculate_shield
	var item5 = ItemData.new()
	item5.shield = 25
	item5.rarity = 4  # 传说 2.0x
	var shield5 = ItemEffects.calculate_shield(item5)
	var t5 = shield5 == 50  # 25 * 2.0
	print("test_shield_legendary: %s (shield=%d)" % ["PASS" if t5 else "FAIL", shield5])
	if t5: passed += 1

	# Test 6: build_active_effects — 中毒
	var item6 = ItemData.new()
	item6.poison_damage = 5.0
	item6.rarity = 1  # 普通 1.0x
	item6.item_name = "毒匕首"
	var effects6 = ItemEffects.build_active_effects(item6, false)
	var t6 = effects6.size() >= 1 and effects6[0]["type"] == "poison" and abs(effects6[0]["value"] - 5.0) < 0.01
	print("test_poison_effect: %s (count=%d)" % ["PASS" if t6 else "FAIL", effects6.size()])
	if t6: passed += 1

	# Test 7: build_active_effects — 燃烧+暴击
	var item7 = ItemData.new()
	item7.burn_damage = 8.0
	item7.item_name = "火焰剑"
	var effects7 = ItemEffects.build_active_effects(item7, true)
	var has_burn = false
	var burn_doubled = false
	for eff in effects7:
		if eff["type"] == "burn":
			has_burn = true
			burn_doubled = eff["value"] == 16.0  # 暴击 2x
	var t7 = has_burn and burn_doubled
	print("test_burn_crit: %s (has_burn=%s, doubled=%s)" % ["PASS" if t7 else "FAIL", has_burn, burn_doubled])
	if t7: passed += 1

	# Test 8: build_active_effects — 再生
	var item8 = ItemData.new()
	item8.regeneration = 3.0
	item8.item_name = "生命戒指"
	var effects8 = ItemEffects.build_active_effects(item8, false)
	var has_regen = false
	for eff in effects8:
		if eff["type"] == "regeneration":
			has_regen = true
	var t8 = has_regen
	print("test_regen_effect: %s" % ["PASS" if t8 else "FAIL"])
	if t8: passed += 1

	# Test 9: build_active_effects — 无特殊效果
	var item9 = ItemData.new()
	item9.damage = 10
	item9.item_name = "普通剑"
	var effects9 = ItemEffects.build_active_effects(item9, false)
	var t9 = effects9.is_empty()
	print("test_no_effects: %s" % ["PASS" if t9 else "FAIL"])
	if t9: passed += 1

	# Test 10: null 安全
	var t10 = ItemEffects.calculate_damage(null, false) == 0
	var t10b = ItemEffects.calculate_heal(null) == 0
	var t10c = ItemEffects.calculate_shield(null) == 0
	var t10_all = t10 and t10b and t10c
	print("test_null_safety: %s" % ["PASS" if t10_all else "FAIL"])
	if t10_all: passed += 1

	print("\nItemEffects Tests: %d/%d passed" % [passed, total + 3])
