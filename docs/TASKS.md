# FancyCardGame 任务清单

> 更新时间：2026-03-03 03:00

---

## ✅ 已完成

### Phase 1: 基础架构
- [x] Godot 项目初始化
- [x] Git 仓库配置
- [x] 项目结构搭建
- [x] 核心玩法调研

### Phase 2: 核心系统
- [x] Unit 基类 (resources/unit.gd)
- [x] Hero 系统 (resources/hero.gd)
- [x] Item 系统 (resources/item.gd)
- [x] Combat 系统 (scripts/combat.gd)
- [x] Inventory 系统 (scripts/inventory.gd)

### Phase 3: UI 系统
- [x] 战斗 UI 场景 (scenes/combat.tscn)
- [x] CombatUI 脚本 (scripts/combat_ui.gd)
- [x] 主场景 (scenes/main.tscn)
- [x] 测试用例：战士 vs 史莱姆

### 策划文档
- [x] 英雄系统策划案
- [x] 物品系统策划案
- [x] 战斗系统策划案
- [x] 怪物系统策划案
- [x] 背包系统策划案
- [x] 商店系统策划案
- [x] 美术风格指南

### 美术资产
- [x] 4 个英雄立绘 (warrior, mage, rogue, cleric)
- [x] 8 个物品图标
- [x] 3 个怪物图标 (slime, goblin, skeleton)

---

## 📋 Phase 4: 背包 UI (进行中)

### Coder 任务
- [ ] 4.1 创建背包场景 scenes/backpack.tscn
- [ ] 4.2 实现 8x6 网格布局 (GridContainer)
- [ ] 4.3 创建 ItemSlot 物品格子组件
- [ ] 4.4 实现物品拖拽系统
- [ ] 4.5 实现装备槽位系统 (武器/护甲/饰品)
- [ ] 4.6 创建物品详情提示框 (Tooltip)
- [ ] 4.7 与主场景集成

### Artist 任务
- [ ] 4.8 背包格子背景 slot_bg.png (64x64)
- [ ] 4.9 格子边框/悬停效果 (64x64)
- [ ] 4.10 物品稀有度边框 (5种颜色)
- [ ] 4.11 装备槽位图标 (3个)
- [ ] 4.12 背包背景 backpack_bg.png

### 测试任务
- [ ] 测试物品拖拽移动
- [ ] 测试物品装备到正确槽位
- [ ] 测试装备/卸下属性变化

---

## 📋 Phase 5: 商店系统 (待开始)

### Coder 任务
- [ ] 5.1 创建商店场景 scenes/shop.tscn
- [ ] 5.2 创建 Shop 系统类 scripts/shop.gd
- [ ] 5.3 实现金币系统
- [ ] 5.4 实现购买逻辑
- [ ] 5.5 实现出售逻辑
- [ ] 5.6 实现商品刷新机制
- [ ] 5.7 与背包系统对接
- [ ] 5.8 战后商店入口

### Artist 任务
- [ ] 5.9 商店背景 shop_bg.png (512x512)
- [ ] 5.10 金币图标 coin_icon.png (32x32)
- [ ] 5.11 购买/出售按钮

---

## 📋 Phase 6: 多关卡流程 (待开始)

### Coder 任务
- [ ] 6.1 创建 LevelManager 管理系统
- [ ] 6.2 定义 4 个关卡配置
- [ ] 6.3 实现难度递增曲线
- [ ] 6.4 实现战利品系统
- [ ] 6.5 创建关卡选择 UI
- [ ] 6.6 创建战斗结算界面
- [ ] 6.7 实现游戏流程状态机

### Artist 任务
- [ ] 6.8 关卡选择背景 (1024x768)
- [ ] 6.9 4 个关卡图标 (256x256)
- [ ] 6.10 胜利/失败画面 (1024x768)
- [ ] 6.11 战利品箱图标

---

## 🎯 里程碑

| 里程碑 | 进度 | 状态 |
|--------|------|------|
| M1: 核心系统完成 | 35% | ✅ |
| M2: 战斗 Demo 可玩 | 50% | ✅ |
| M3: 背包 UI 完成 | 75% | 📋 |
| M4: 商店系统完成 | 85% | 📋 |
| M5: MVP 完成 | 100% | 📋 |

---

## 团队分工

### Coder
- [x] Phase 1-3 核心系统
- [ ] Phase 4 背包 UI
- [ ] Phase 5 商店系统
- [ ] Phase 6 关卡流程

### Artist
- [x] Phase 1-3 美术资产
- [ ] Phase 4 UI 元素
- [ ] Phase 5 UI 元素
- [ ] Phase 6 UI 元素

---

## 今日任务 (Phase 4)

**优先级排序**:
1. 🔴 创建背包场景和网格布局
2. 🔴 物品格子组件开发
3. 🔴 物品拖拽系统
4. 🟡 装备槽系统
5. 🟡 Tooltip 提示框
6. 🟢 集成测试

**目标**: 今天完成背包 UI 基础功能
