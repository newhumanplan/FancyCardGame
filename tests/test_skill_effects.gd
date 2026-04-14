extends Node

## skill_effects 测试 — 技能效果应用器

func _ready():
	var SkillData = load("res://scripts/data/skill_data.gd")
	var SkillEffects = load("res://scripts/data/skill_effects.gd")
	var HeroData = load("res://scripts/data/hero_data.gd")
	var passed = 0
	var total = 5

	# Test 1: apply_passive_skills — crit 加成
	var hero = HeroData.new()
	hero.crit_chance = 0.05
	hero.max_hp = 100
	var skill1 = SkillData.new()
	skill1.skill_id = "crit_boost"
	skill1.effect_type = SkillData.EffectType.CRIT
	skill1.effect_values = [10.0, 15.0, 20.0, 25.0]
	skill1.quality = SkillData.Quality.BRONZE
	var mods = SkillEffects.apply_passive_skills([skill1], hero)
	var t1 = abs(hero.crit_chance - 0.15) < 0.01  # 0.05 + 10/100
	print("test_crit_boost: %s (crit=%.2f)" % ["PASS" if t1 else "FAIL", hero.crit_chance])
	if t1: passed += 1

	# Test 2: apply_passive_skills — health 加成
	var hero2 = HeroData.new()
	hero2.max_hp = 100
	hero2.crit_chance = 0.05
	var skill2 = SkillData.new()
	skill2.skill_id = "hp_boost"
	skill2.effect_type = SkillData.EffectType.HEALTH
	skill2.effect_values = [50.0, 100.0, 150.0, 200.0]
	skill2.quality = SkillData.Quality.BRONZE
	SkillEffects.apply_passive_skills([skill2], hero2)
	var t2 = hero2.max_hp == 150  # 100 + 50
	print("test_health_boost: %s (hp=%d)" % ["PASS" if t2 else "FAIL", hero2.max_hp])
	if t2: passed += 1

	# Test 3: apply_passive_skills — shield 加成
	var hero3 = HeroData.new()
	var skill3 = SkillData.new()
	skill3.skill_id = "shield_boost"
	skill3.effect_type = SkillData.EffectType.SHIELD
	skill3.effect_values = [20.0, 30.0, 40.0, 50.0]
	skill3.quality = SkillData.Quality.BRONZE
	var mods3 = SkillEffects.apply_passive_skills([skill3], hero3)
	var t3 = abs(float(mods3["shield_bonus"]) - 20.0) < 0.01
	print("test_shield_boost: %s (bonus=%.1f)" % ["PASS" if t3 else "FAIL", mods3["shield_bonus"]])
	if t3: passed += 1

	# Test 4: apply_passive_skills — 多技能叠加
	var hero4 = HeroData.new()
	hero4.max_hp = 100
	hero4.crit_chance = 0.0
	var s4a = SkillData.new()
	s4a.skill_id = "hp1"
	s4a.effect_type = SkillData.EffectType.HEALTH
	s4a.effect_values = [30.0, 60.0, 90.0, 120.0]
	s4a.quality = SkillData.Quality.BRONZE
	var s4b = SkillData.new()
	s4b.skill_id = "hp2"
	s4b.effect_type = SkillData.EffectType.HEALTH
	s4b.effect_values = [20.0, 40.0, 60.0, 80.0]
	s4b.quality = SkillData.Quality.BRONZE
	SkillEffects.apply_passive_skills([s4a, s4b], hero4)
	var t4 = hero4.max_hp == 150  # 100 + 30 + 20
	print("test_multi_stack: %s (hp=%d)" % ["PASS" if t4 else "FAIL", hero4.max_hp])
	if t4: passed += 1

	# Test 5: get_effects_summary
	var s5 = SkillData.new()
	s5.skill_id = "burn1"
	s5.skill_name = "Fiery"
	s5.effect_type = SkillData.EffectType.BURN
	s5.effect_values = [3.0, 6.0, 9.0, 12.0]
	s5.quality = SkillData.Quality.BRONZE
	var summary = SkillEffects.get_effects_summary([s5])
	var t5 = "燃烧" in summary and "+3.0" in summary
	print("test_summary: %s" % ["PASS" if t5 else "FAIL"])
	if t5: passed += 1

	# Test 6: 空技能列表
	var summary_empty = SkillEffects.get_effects_summary([])
	var t6 = "无技能效果" in summary_empty
	print("test_empty_summary: %s" % ["PASS" if t6 else "FAIL"])
	if t6: passed += 1

	print("\nSkillEffects Tests: %d/%d passed" % [passed, total + 1])
