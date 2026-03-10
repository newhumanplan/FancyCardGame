extends Node

func _ready():
    await get_tree().process_frame
    print("========== 中文修复验收 ==========\n")
    
    # 1. 检查字体配置
    print("1. 检查中文字体配置:")
    var project_settings = ProjectSettings
    var font_path = project_settings.get_setting("gui/theme/custom_font")
    print("   字体路径: %s" % font_path)
    print("   字体存在: %s" % ("✅ 是" if ResourceLoader.exists(font_path) else "❌ 否"))
    
    # 2. 检查中文文本
    print("\n2. 检查中文UI文本:")
    var main_scene = load("res://scenes/main.tscn")
    var instance = main_scene.instantiate()
    get_tree().root.add_child(instance)
    await get_tree().process_frame
    
    # 检查关键节点的中文文本
    var checks = [
        ["TopBar/DayLabel", "Day 1"],
        ["TopBar/PhaseLabel", "采购"],
        ["StatsPanel/HPBarLabel", "HP: 100/100"],
        ["StatsPanel/GoldLabel", "金币: 100"],
        ["HeroSelectPanel/TitleLabel", "选择你的英雄"],
    ]
    
    for check in checks:
        var node = instance.get_node(check[0])
        var text = node.text if node else "N/A"
        var passed = text == check[1]
        print("   %s: %s (期望: %s) %s" % [check[0], text, check[1], "✅" if passed else "❌"])
    
    # 3. 检查物品修复
    print("\n3. 检查物品修复:")
    var wood_shield = load("res://resources/items/wood_shield.tres")
    print("   木盾 size=%s (期望: SMALL=0) %s" % [wood_shield.size, "✅" if wood_shield.size == 0 else "❌"])
    print("   木盾 cooldown=%.1f (期望: 5.0) %s" % [wood_shield.cooldown, "✅" if wood_shield.cooldown == 5.0 else "❌"])
    
    var small_potion = load("res://resources/items/small_health_potion.tres")
    print("   小血瓶 heal=%d (期望: 25) %s" % [small_potion.heal, "✅" if small_potion.heal == 25 else "❌"])
    
    # 4. 检查 GameManager
    print("\n4. 检查 GameManager:")
    var gm = get_node("/root/GameManager")
    print("   gold=%d (期望: 100)" % gm.gold)
    print("   prestige=%d (期望: 10)" % gm.prestige)
    print("   current_day=%d (期望: 1)" % gm.current_day)
    print("   current_hour=%d (期望: 0)" % gm.current_hour)
    
    instance.queue_free()
    print("\n========== 验收完成 ==========")
    get_tree().quit()
