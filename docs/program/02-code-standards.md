# 代码规范

更新时间：2026-04-25

根目录 `CODING_STANDARDS.md` 是当前权威规范。本文保留旧路径兼容，并摘录关键规则。

## GDScript

- Tab 缩进。
- 类型提示完整。
- `@onready` 必须显式类型。
- 信号参数必须有类型。
- 使用 `and` / `or` / `not`，不用 `&&` / `||` / `!`。
- 常量使用 `UPPER_SNAKE_CASE`。
- class_name 使用 PascalCase。

## 代码顺序

1. `@tool`
2. `class_name`
3. `extends`
4. 类文档注释
5. `signal`
6. `enum`
7. `const`
8. `static var`
9. `@export`
10. 普通变量
11. `@onready`
12. `_static_init()`
13. 静态方法
14. Godot 虚函数
15. 覆盖的自定义方法
16. 其余方法
17. 内部类

## 项目特有约束

- 不要新增 5 Hour 逻辑。
- 不要新增回合制 PvP、EndTurn、PvP 商店、最终 Boss。
- UI 不直接扣 Prestige、推进 Hour、结算战斗奖励。
- 新 item/skill 优先使用 effect model。
- 修改 Day/Hour 前必须搜索 `current_hour`、`% 5`、`>= 5`、`== 4`。

完整规范见根目录 `CODING_STANDARDS.md`。
