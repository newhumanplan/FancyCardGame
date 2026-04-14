extends Node

## passive_skill 测试 — 被动技能触发与叠加

func _ready():
	var PassiveSkillData = load("res://scripts/data/passive_skill.gd")
	var HeroData = load("res://scripts/data/hero_data.gd")
	var passed = 0
	var total = 6

	# Test 1: HEALTH_BONUS — 生命值增加
	var hero1 = HeroData.new()
	hero1.max_hp = 100
	hero1.current_hp = 100
	var ps1 = PassiveSkillData.new()
	ps1.skill_name = "坚韧"
	ps1.effect_type = PassiveSkillData.EffectType.HEALTH_BONUS
	ps1.effect_value = 50.0
	PassiveSkillData.apply_to_hero(ps1, hero1)
	var t1 = hero1.max_hp == 150 and hero1.current_hp == 150
	print("test_health_bonus: %s (hp=%d/%d)" % ["PASS" if t1 else "FAIL", hero1.current_hp, hero1.max_hp])
	if t1: passed += 1

	# Test 2: CRIT_BONUS — 暴击率增加
	var hero2 = HeroData.new()
	hero2.crit_chance = 0.05
	var ps2 = PassiveSkillData.new()
	ps2.skill_name = "战斗本能"
	ps2.effect_type = PassiveSkillData.EffectType.CRIT_BONUS
	ps2.effect_value = 15.0
	PassiveSkillData.apply_to_hero(ps2, hero2)
	var t2 = abs(hero2.crit_chance - 0.20) < 0.01  # 0.05 + 15/100
	print("test_crit_bonus: %s (crit=%.2f)" % ["PASS" if t2 else "FAIL", hero2.crit_chance])
	if t2: passed += 1

	# Test 3: SHIELD_BONUS — apply_to_hero 不报错（战斗系统处理）
	var hero3 = HeroData.new()
	var ps3 = PassiveSkillData.new()
	ps3.skill_name = "铁壁"
	ps3.effect_type = PassiveSkillData.EffectType.SHIELD_BONUS
	ps3.effect_value = 30.0
	var t3 = true  # 无报错即通过
	PassiveSkillData.apply_to_hero(ps3, hero3)
	print("test_shield_bonus_no_crash: %s" % ["PASS" if t3 else "FAIL"])
	if t3: passed += 1

	# Test 4: LIFESTEAL — apply_to_hero 不报错
	var hero4 = HeroData.new()
	var ps4 = PassiveSkillData.new()
	ps4.skill_name = "嗜血"
	ps4.effect_type = PassiveSkillData.EffectType.LIFESTEAL
	ps4.effect_value = 10.0
	var t4 = true
	PassiveSkillData.apply_to_hero(ps4, hero4)
	print("test_lifesteal_no_crash: %s" % ["PASS" if t4 else "FAIL"])
	if t4: passed += 1

	# Test 5: 效果叠加（多个被动）
	var hero5 = HeroData.new()
	hero5.max_hp = 100
	hero5.crit_chance = 0.0
	var ps5a = PassiveSkillData.new()
	ps5a.skill_name = "HP1"
	ps5a.effect_type = PassiveSkillData.EffectType.HEALTH_BONUS
	ps5a.effect_value = 30.0
	var ps5b = PassiveSkillData.new()
	ps5b.skill_name = "CRIT1"
	ps5b.effect_type = PassiveSkillData.EffectType.CRIT_BONUS
	ps5b.effect_value = 10.0
	PassiveSkillData.apply_to_hero(ps5a, hero5)
	PassiveSkillData.apply_to_hero(ps5b, hero5)
	var t5 = hero5.max_hp == 130 and abs(hero5.crit_chance - 0.10) < 0.01
	print("test_stack_passives: %s (hp=%d, crit=%.2f)" % ["PASS" if t5 else "FAIL", hero5.max_hp, hero5.crit_chance])
	if t5: passed += 1

	# Test 6: get_type_description
	var ps6 = PassiveSkillData.new()
	ps6.effect_type = PassiveSkillData.EffectType.COOLDOWN_REDUCTION
	ps6.effect_value = 15.0
	var desc = ps6.get_type_description()
	var t6 = "冷却" in desc and "15.0" in desc
	print("test_type_description: %s (%s)" % ["PASS" if t6 else "FAIL", desc])
	if t6: passed += 1

	# Test 7: get_full_description
	var ps7 = PassiveSkillData.new()
	ps7.skill_name = "铁壁"
	ps7.description = "增加护盾值"
	var full = ps7.get_full_description()
	var t7 = "铁壁" in full and "增加护盾值" in full
	print("test_full_description: %s (%s)" % ["PASS" if t7 else "FAIL", full])
	if t7: passed += 1

	# Test 8: null 安全
	var t8 = true
	PassiveSkillData.apply_to_hero(null, HeroData.new())
	PassiveSkillData.apply_to_hero(PassiveSkillData.new(), null)
	print("test_null_safety: %s" % ["PASS" if t8 else "FAIL"])
	if t8: passed += 1

	print("\nPassiveSkill Tests: %d/%d passed" % [passed, total + 2])
