#!/usr/bin/env python3
"""
背包增强功能测试脚本
测试拖拽系统、物品详情面板、协同效果
"""

import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.expanduser("~/Projects/FancyCardGame"))

print("=" * 60)
print("背包增强功能测试")
print("=" * 60)

# 测试 1: 检查文件是否存在
print("\n[测试 1] 检查文件是否存在...")
files_to_check = [
    "scripts/ui/inventory_ui.gd",
    "scripts/ui/item_detail_panel.gd",
    "scenes/ui/item_detail_panel.tscn",
    "scripts/data/linear_inventory.gd",
    "scripts/data/item_data.gd"
]

all_exist = True
for f in files_to_check:
    path = os.path.expanduser(f"~/Projects/FancyCardGame/{f}")
    exists = os.path.exists(path)
    status = "✓" if exists else "✗"
    print(f"  {status} {f}")
    if not exists:
        all_exist = False

if not all_exist:
    print("\n[失败] 缺少必要文件")
    sys.exit(1)

print("\n[通过] 所有文件存在")

# 测试 2: 检查 inventory_ui.gd 关键功能
print("\n[测试 2] 检查 inventory_ui.gd 关键功能...")
inventory_ui_path = os.path.expanduser("~/Projects/FancyCardGame/scripts/ui/inventory_ui.gd")
with open(inventory_ui_path, 'r') as f:
    content = f.read()

features = {
    "拖拽高亮": "_update_drag_overlays" in content,
    "有效位置绿色": "Color(0.2, 0.8, 0.2" in content,
    "无效位置红色": "Color(0.8, 0.2, 0.2" in content,
    "物品详情面板": "_show_item_detail" in content,
    "协同高亮": "_update_synergy_highlights" in content,
    "背景点击关闭": "_on_background_input" in content,
}

for feature, exists in features.items():
    status = "✓" if exists else "✗"
    print(f"  {status} {feature}")

# 测试 3: 检查 item_detail_panel.gd
print("\n[测试 3] 检查 item_detail_panel.gd...")
detail_panel_path = os.path.expanduser("~/Projects/FancyCardGame/scripts/ui/item_detail_panel.gd")
with open(detail_panel_path, 'r') as f:
    content = f.read()

detail_features = {
    "显示攻击属性": "attack" in content.lower() or "damage" in content.lower(),
    "显示防御属性": "shield" in content.lower() or "defense" in content.lower(),
    "显示治疗属性": "heal" in content.lower(),
    "显示稀有度": "rarity" in content.lower(),
    "显示尺寸": "size" in content.lower(),
    "显示特殊效果": "special_effect" in content.lower() or "poison" in content.lower(),
    "显示协同加成": "synergy" in content.lower(),
}

for feature, exists in detail_features.items():
    status = "✓" if exists else "✗"
    print(f"  {status} {feature}")

# 测试 4: 检查协同效果系统
print("\n[测试 4] 检查协同效果系统...")
linear_inventory_path = os.path.expanduser("~/Projects/FancyCardGame/scripts/data/linear_inventory.gd")
with open(linear_inventory_path, 'r') as f:
    content = f.read()

synergy_features = {
    "get_item_synergy_bonus": "get_item_synergy_bonus" in content,
    "get_adjacent_items": "get_adjacent_items" in content,
    "武器协同": "WEAPON" in content,
    "护盾协同": "SHIELD" in content,
    "治疗协同": "HEAL" in content,
}

for feature, exists in synergy_features.items():
    status = "✓" if exists else "✗"
    print(f"  {status} {feature}")

print("\n" + "=" * 60)
print("测试完成!")
print("=" * 60)
print("\n验收标准检查:")
print("  [ ] 拖拽物品 → 移动到新位置 (需在 Godot 中测试)")
print("  [ ] 无法放置 → 显示红色 (需在 Godot 中测试)")
print("  [ ] 点击物品 → 显示详情面板 (需在 Godot 中测试)")
print("  [ ] 相邻同类物品 → 高亮显示 (需在 Godot 中测试)")
print("\n在 Godot 中打开 scenes/main.tscn 运行游戏进行手动测试")
