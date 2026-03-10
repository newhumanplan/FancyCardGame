extends Node

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	# 获取 main 节点
	var main = get_node("/root/Main")
	if not main:
		print("错误: 找不到 Main 节点")
		get_tree().quit()
		return
	
	# 检查 inventory_ui 引用
	print("========== 背包系统验证测试 ==========")
	print("inventory_ui 变量: %s" % str(main.inventory_ui))
	print("inventory_ui 是否有效: %s" % str(main.inventory_ui != null))
	
	# 如果有效，调用 _calculate_stats
	if main.inventory_ui:
		# 调用 _calculate_stats 的内部逻辑
		var inventory = main.inventory_ui.get_inventory()
		var total_damage = 0
		var total_shield = 0
		var total_heal = 0
		
		for item in inventory.items:
			if item != null:
				total_damage += item.damage
				total_shield += item.shield
				total_heal += item.heal
		
		print("\n物品属性统计:")
		print("  攻击力加成: %d" % total_damage)
		print("  防御力加成: %d" % total_shield)
		print("  治疗加成: %d" % total_heal)
		
		print("\n测试通过!")
	else:
		print("错误: inventory_ui 为 null")
	
	get_tree().quit()
