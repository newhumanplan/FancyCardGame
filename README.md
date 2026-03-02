# FancyCardGame

《大巴扎》风格的自走棋卡牌游戏，使用 Godot 4.x 开发。

## 项目状态

**当前进度**: 50%

### 已完成
- ✅ 核心系统架构 (Unit/Hero/Item/Combat/Inventory)
- ✅ 策划文档全部完成
- ✅ 战斗 UI 系统 (可运行 Demo)
- ✅ 美术资产
  - 4 个英雄立绘
  - 8 个物品图标
  - 1 个怪物图标

### 进行中
- ⏳ 补充怪物图标
- ⏳ 背包 UI 开发

## 快速开始

### 前置要求
- Godot 4.x (建议 4.2+)
- Git

### 运行战斗 Demo

1. 克隆项目
```bash
cd ~/Projects
git clone https://github.com/newhumanplan/FancyCardGame
cd FancyCardGame
```

2. 用 Godot 打开项目
```bash
open project.godot
# 或在 Godot 中: Project → Open → 选择 FancyCardGame 目录
```

3. 运行 Demo
- 按 F5 或点击 ▶️ 运行按钮
- 点击 **"开始战斗"** 按钮
- 观看回合制战斗演示（战士 vs 史莱姆）

## 项目结构

```
FancyCardGame/
├── docs/            # 策划文档
│   ├── progress.md          # 进度追踪
│   ├── NEXT_ITERATION.md    # 下一迭代计划
│   ├── TASKS.md             # 任务清单
│   └── *.md                 # 系统策划案
├── assets/          # 美术资源
│   ├── heroes/      # 英雄立绘
│   ├── items/       # 物品图标
│   └── monsters/    # 怪物图标
├── scripts/         # 游戏脚本
│   ├── combat.gd    # 战斗系统
│   ├── inventory.gd # 背包系统
│   ├── combat_ui.gd # 战斗 UI
│   └── main.gd      # 主场景
├── scenes/          # 游戏场景
│   ├── main.tscn    # 主场景
│   └── combat.tscn  # 战斗场景
└── resources/       # 资源定义
    ├── unit.gd      # 单位基类
    ├── hero.gd      # 英雄类
    └── item.gd      # 物品类
```

## 核心功能

### 已实现
- **战斗系统**: 回合制自动战斗，伤害计算，暴击机制
- **英雄系统**: 4 个职业（战士/法师/盗贼/牧师），职业加成
- **物品系统**: 武器/护甲/消耗品，5 级稀有度
- **背包系统**: 8x6 网格管理

### 计划中
- 背包 UI 与物品拖拽
- 商店系统
- 多关卡流程

## 开发团队

- **Product** - 产品规划
- **Coder** - 核心开发
- **Artist** - 美术制作

## 文档导航

- [项目进度](docs/progress.md)
- [下一迭代计划](docs/NEXT_ITERATION.md)
- [任务清单](docs/TASKS.md)
- [美术资产清单](docs/art-list.md)
- [技术架构](docs/technical-architecture.md)
- [美术风格指南](docs/ART_STYLE_GUIDE.md)

## 技术栈

- 游戏引擎: Godot 4.x
- 美术工具: Stable Diffusion
- 版本控制: Git

---
*更新时间: 2026-03-03 02:35*
