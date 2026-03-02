extends Control

## 主场景脚本
## 负责初始化游戏并管理场景切换

## 引用 Combat 系统节点
@onready var combat_system: Node = $CombatSystem
@onready var start_button: Button = $VBox/StartButton
@onready var shop_button: Button = $VBox/ShopButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var gold_label: Label = $VBox/GoldLabel
@onready var stage_label: Label = $VBox/StageLabel

## 关卡管理器 (从场景中获取)
@onready var stage_manager: StageManager = $StageManager

## 预加载场景
var combat_scene: PackedScene
var character_panel_scene: PackedScene
var shop_scene: PackedScene

## 背包和装备
var inventory: Inventory
var equipment: Equipment
var shop: Shop

## 角色面板实例
var character_panel = null
var shop_ui = null

## 波次战斗系统
var stage_enemies: Array[Unit] = []
var current_enemy_index: int = 0
var current_player: Unit = null

func _ready() -> void:
	# 加载场景
	combat_scene = load("res://scenes/combat.tscn")
	character_panel_scene = load("res://scenes/character_panel.tscn")
	shop_scene = load("res://scenes/shop.tscn")
	
	# 初始化背包和装备
	inventory = Inventory.new()
	equipment = Equipment.new()
	shop = Shop.new()
	add_child(shop)
	
	# 初始化金币（战士初始金币 100）
	GoldManager.reset()
	_update_gold_display()
	_update_stage_display()
	
	# 连接金币变化信号
	GoldManager.gold_changed.connect(_on_gold_changed)
	
	# 连接关卡信号
	stage_manager.stage_changed.connect(_on_stage_changed)
	stage_manager.game_complete.connect(_on_game_complete)
	
	# 添加初始装备（战士：铁剑 + 皮甲）
	_add_initial_items()
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	shop_button.pressed.connect(_on_shop_button_pressed)
	
	# 创建角色面板
	_create_character_panel()
	
	# 创建商店 UI（隐藏）
	_create_shop_ui()
	
	print("FancyCardGame 已就绪！")
	status_label.text = "点击上方按钮开始战斗"

## 添加初始物品
func _add_initial_items() -> void:
	# 铁剑
	var iron_sword = Weapon.new("铁剑", 10, 1)
	iron_sword.icon_path = "res://assets/items/iron_sword.png"
	iron_sword.description = "新手战士的标准武器"
	inventory.add_item(iron_sword)
	equipment.equip_item(iron_sword)
	
	# 皮甲
	var leather_armor = Armor.new("皮甲", 5, 1)
	leather_armor.icon_path = "res://assets/items/leather_armor.png"
	leather_armor.description = "提供基本防护的皮制护甲"
	inventory.add_item(leather_armor)
	equipment.equip_item(leather_armor)
	
	# 治疗药水
	var health_potion = Consumable.new("治疗药水", 30, 3, 1)
	health_potion.icon_path = "res://assets/items/health_potion.png"
	health_potion.description = "恢复 30 点生命值"
	inventory.add_item(health_potion)
	
	# 匕首
	var dagger = Weapon.new("匕首", 6, 1)
	dagger.icon_path = "res://assets/items/dagger.png"
	dagger.description = "轻便的副手武器"
	inventory.add_item(dagger)
	
	print("已添加初始物品")
	print(inventory.get_inventory_info())

## 创建角色面板
func _create_character_panel() -> void:
	character_panel = character_panel_scene.instantiate()
	add_child(character_panel)
	character_panel.set_equipment(equipment)
	character_panel.set_inventory(inventory)
	
	# 放置在右侧
	character_panel.position = Vector2(600, 100)

## 创建商店 UI
func _create_shop_ui() -> void:
	shop_ui = shop_scene.instantiate()
	add_child(shop_ui)
	shop_ui.set_data(shop, inventory, GoldManager)
	shop_ui.visible = false
	
	# 连接商店关闭信号
	if shop_ui.has_signal("shop_closed"):
		shop_ui.shop_closed.connect(_on_shop_closed)

## 开始战斗按钮回调
func _on_start_button_pressed() -> void:
	# 获取当前关卡的敌人
	stage_enemies = stage_manager.generate_enemies_for_stage()
	
	if stage_enemies.is_empty():
		status_label.text = "没有敌人配置！"
		return
	
	# 重置波次索引
	current_enemy_index = 0
	
	# 创建玩家单位：战士（应用装备加成）
	var base_atk := 15
	var base_def := 8
	current_player = Unit.new(
		"战士", 
		120, 
		base_atk + equipment.get_attack_bonus(),
		base_def + equipment.get_defense_bonus(),
		10, 0.1, 1.5
	)
	
	# 显示关卡信息
	var stage_data = stage_manager.get_current_stage_data()
	var stage_name = stage_data.get("name", "未知关卡")
	var difficulty = stage_data.get("difficulty", "easy")
	status_label.text = "第 %d 关: %s [%s]" % [stage_manager.current_stage, stage_name, difficulty]
	
	# 开始第一波战斗
	_start_next_wave()

## 开始下一波战斗
func _start_next_wave() -> void:
	if current_enemy_index >= stage_enemies.size():
		# 所有敌人已击败，进入商店
		_on_all_waves_complete()
		return
	
	var enemy = stage_enemies[current_enemy_index]
	
	# 波次间恢复 20% HP（如果玩家已受伤）
	if current_player.current_hp < current_player.max_hp:
		var heal_amount = int(current_player.max_hp * 0.2)
		current_player.current_hp = min(current_player.current_hp + heal_amount, current_player.max_hp)
		print("波次间恢复 %d HP，当前 HP: %d" % [heal_amount, current_player.current_hp])
	
	# 更新状态标签显示波次信息
	status_label.text = "第 %d 波 / 共 %d 波 - %s" % [current_enemy_index + 1, stage_enemies.size(), enemy.name]
	
	# 切换到战斗场景
	_change_to_combat(current_player, enemy)

## 所有波次完成回调
func _on_all_waves_complete() -> void:
	status_label.text = "🎉 本关所有敌人已击败！"
	
	# 获得关卡奖励
	var stage_data = stage_manager.get_current_stage_data()
	var gold_reward = stage_data.get("gold_reward", 0)
	GoldManager.add_gold(gold_reward)
	print("获得金币: %d" % gold_reward)
	
	# 完成关卡
	stage_manager.complete_stage()
	
	# 检查是否通关
	if stage_manager.is_game_complete():
		await get_tree().create_timer(1.0).timeout
		stage_manager.game_complete.emit()
		status_label.text = "🎉 恭喜通关！你是真正的英雄！"
		start_button.text = "重新开始"
		start_button.pressed.disconnect(_on_start_button_pressed)
		start_button.pressed.connect(_on_restart_game_pressed)
		$VBox.visible = true
		character_panel.visible = true
	else:
		# 进入商店，然后下一关
		await get_tree().create_timer(1.0).timeout
		_open_shop()

## 商店按钮回调
func _on_shop_button_pressed() -> void:
	_open_shop()

## 打开商店
func _open_shop() -> void:
	if shop_ui:
		shop_ui.visible = true
		shop_ui.refresh()
		# 隐藏其他 UI
		$VBox.visible = false
		character_panel.visible = false

## 商店关闭回调
func _on_shop_closed() -> void:
	# 刷新商店物品（新关卡）
	shop.refresh_shop()
	
	# 显示主 UI
	$VBox.visible = true
	character_panel.visible = true
	
	# 如果不是最后一关，进入下一关
	if not stage_manager.is_game_complete():
		stage_manager.next_stage()
		status_label.text = "准备进入第 %d 关！" % stage_manager.current_stage

## 切换到战斗场景
func _change_to_combat(player: Unit, enemy: Unit) -> void:
	# 实例化战斗场景
	var combat = combat_scene.instantiate()
	
	# 添加到当前场景
	add_child(combat)
	
	# 获取 CombatUI 节点并初始化
	var combat_ui = combat.get_node("CombatUI")
	var combat_sys = combat.get_node("CombatSystem")
	
	# 先初始化 UI（连接信号）
	combat_ui.init(combat_sys, player, enemy)
	# 再初始化战斗系统（会触发信号）
	combat_sys.init_combat(player, enemy)
	
	# 隐藏主 UI
	$VBox.visible = false
	character_panel.visible = false
	
	# 连接战斗结束信号
	combat_sys.combat_ended.connect(_on_combat_ended)

## 战斗结束回调
func _on_combat_ended(victory: bool) -> void:
	# 释放战斗场景，防止内存泄漏
	var combat = get_tree().get_first_node_in_group("combat")
	if combat:
		combat.queue_free()
	
	if victory:
		status_label.text = "🎉 第 %d 波战斗胜利！" % (current_enemy_index + 1)
		
		# 增加波次索引
		current_enemy_index += 1
		
		# 检查是否还有敌人
		if current_enemy_index < stage_enemies.size():
			# 还有敌人，开始下一波（延迟一下让玩家看到胜利消息）
			await get_tree().create_timer(1.0).timeout
			_start_next_wave()
		else:
			# 所有敌人已击败，进入商店
			_on_all_waves_complete()
	else:
		# 战斗失败惩罚：扣除 10% 金币
		var penalty = int(GoldManager.get_gold() * 0.1)
		GoldManager.spend_gold(penalty)
		status_label.text = "💀 失败... 损失 %d 金币，请提升实力后再来" % penalty
		# 显示主 UI
		$VBox.visible = true
		character_panel.visible = true

## 金币变化回调
func _on_gold_changed(_amount: int) -> void:
	_update_gold_display()

## 更新金币显示
func _update_gold_display() -> void:
	gold_label.text = "金币: %d" % GoldManager.get_gold()

## 更新关卡显示
func _update_stage_display() -> void:
	stage_label.text = stage_manager.get_progress_text()

## 关卡变化回调
func _on_stage_changed(stage_num: int) -> void:
	_update_stage_display()
	status_label.text = "第 %d 关已解锁！" % stage_num

## 游戏完成回调
func _on_game_complete() -> void:
	status_label.text = "🎉 恭喜通关！你是真正的英雄！"
	start_button.text = "重新开始"
	start_button.pressed.disconnect(_on_start_button_pressed)
	start_button.pressed.connect(_on_restart_game_pressed)
	# 显示胜利特效或弹窗

## 重新开始游戏
func _on_restart_game_pressed() -> void:
	stage_manager.reset_stages()
	GoldManager.reset()
	_update_gold_display()
	_update_stage_display()
	status_label.text = "点击上方按钮开始战斗"
	start_button.text = "开始战斗"
	start_button.pressed.disconnect(_on_restart_game_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
