# FancyCardGame 技术架构文档

## 项目概述

FancyCardGame 是一款使用 Godot 4.x 开发的卡牌游戏。

## 技术栈

- **游戏引擎**: Godot 4.2
- **渲染方式**: GL Compatibility (兼容模式)
- **脚本语言**: GDScript

## 项目结构

```
FancyCardGame/
├── assets/          # 静态资源 (图片、音频等)
├── docs/            # 项目文档
├── resources/       # Godot 资源文件
├── scenes/          # 场景文件 (.tscn)
├── scripts/         # 脚本文件 (.gd)
├── project.godot    # 项目配置文件
└── README.md        # 项目说明
```

## 核心模块

### 1. 场景架构

- **main.tscn**: 主入口场景
- **game.tscn**: 游戏核心场景
- **ui.tscn**: UI 层场景 (CanvasLayer)

### 2. 脚本结构

| 脚本 | 功能 |
|------|------|
| main.gd | 主场景逻辑 |
| game.gd | 游戏核心逻辑 |
| ui.gd | UI 管理逻辑 |

## 后续规划

- [ ] 卡牌数据模型设计
- [ ] 游戏循环实现
- [ ] UI 系统完善
- [ ] 资源导入与整理
