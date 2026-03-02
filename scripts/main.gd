extends Control

## 主场景脚本
## 负责初始化游戏并管理场景切换

## 引用 Combat 系统节点
@onready var combat_system: Node = $CombatSystem
@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel

## 预加载场景
var combat_scene: PackedScene
var character_panel_scene: PackedScene

## 背包和装备
var inventory: Inventory
var equipment: Equipment

## 角色面板实例
var character_panel = null

func _ready() -> void:
	# 加载场景
	combat_scene = load("res://scenes/combat.tscn")
	character_panel_scene = load("res://scenes/character_panel.tscn")
	
	# 初始化背包和装备
	inventory = Inventory.new()
	equipment = Equipment.new()
	
	# 添加初始装备（战士：铁剑 + 皮甲）
	_add_initial_items()
	
	# 连接按钮信号
	start_button.pressed.connect(_on_start_button_pressed)
	
	# 创建角色面板
	_create_character_panel()
	
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

## 开始战斗按钮回调
func _on_start_button_pressed() -> void:
	# 创建测试单位：战士 vs 史莱姆
	var warrior = Unit.new("战士", 120, 15, 8, 10, 0.1, 1.5)
	var slime = Unit.new("史莱姆", 80, 8, 3, 5, 0.05, 1.5)
	
	print("初始化战斗: %s vs %s" % [warrior.name, slime.name])
	status_label.text = "战斗进行中..."
	
	# 切换到战斗场景
	_change_to_combat(warrior, slime)

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
	if victory:
		status_label.text = "🎉 胜利！"
	else:
		status_label.text = "💀 失败..."
	
	# 显示主 UI
	$VBox.visible = true
	character_panel.visible = true
	
	# 延迟后重新加载场景（清除战斗状态）
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
