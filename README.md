# FancyCardGame

《大巴扎》风格的自走棋游戏

## 核心玩法

- **6x6 背包网格** - 在有限空间内放置物品
- **物品尺寸系统** - 物品占 1-4 格（1x1, 1x2, 2x2, 2x3）
- **空间策略** - 合理摆放物品最大化战斗力
- **回合制战斗** - 准备好后自动战斗

## 开发状态

🚧 重构中 - 修复核心玩法

## 技术栈

- Godot 4.x
- GDScript

## 如何运行

1. 用 Godot 4.x 打开项目
2. 运行主场景

## 目录结构

```
scripts/
  - game_manager.gd    # 全局游戏管理
  - backpack_grid.gd   # 背包网格数据
  - backpack_ui.gd     # 背包 UI 显示
  - main.gd            # 主场景逻辑

resources/
  - item.gd            # 物品数据类

scenes/
  - main.tscn          # 主场景
  - backpack.tscn      # 背包场景
```

## 历史版本

- `archive/old-version` 分支 - 旧版代码（已废弃）
