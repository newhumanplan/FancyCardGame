# CODING_STANDARDS.md

本规范适用于 FancyCardGame 的 Godot 4.6.1 / GDScript 2.0 代码。它继承
`docs/program/02-code-standards.md` 的核心要求，并补充本项目的架构约束。

## 格式

- 缩进使用 Tab，不使用空格。
- 行宽尽量不超过 100 字符。
- 文件使用 UTF-8、LF、末尾保留一个空行。
- 新文件必须有 `class_name`，除非是场景私有脚本且确实不需要外部引用。

## 命名

| 类型 | 规范 | 示例 |
| --- | --- | --- |
| 文件 | snake_case | `battle_system.gd` |
| 类 | PascalCase | `class_name BattleSystem` |
| Node | PascalCase | `BattlePanel` |
| 函数 | snake_case | `calculate_damage()` |
| 变量 | snake_case | `current_cooldown` |
| 信号 | 过去式 snake_case | `battle_ended(won: bool)` |
| 常量 | UPPER_SNAKE_CASE | `MAX_BOARD_SLOTS` |
| 枚举 | PascalCase 单数 | `enum Tier` |
| 枚举值 | UPPER_SNAKE_CASE | `BRONZE` |
| 私有成员 | `_` 前缀 | `_effect_queue` |

## 类型提示

所有 public API、信号、成员变量、函数参数和返回值都应有类型。

```gdscript
var health: int = 0
var items: Array[ItemData] = []

func apply_damage(amount: int) -> int:
	return amount
```

`@onready` 必须显式类型，不要用 `:=`：

```gdscript
@onready var health_bar: ProgressBar = $UI/HealthBar
```

局部变量在类型清晰时可以使用 `:=`：

```gdscript
var offset := Vector2(8, 4)
```

## 代码顺序

每个脚本按 17 步排序：

1. `@tool`
2. `class_name`
3. `extends`
4. 类文档注释
5. `signal`
6. `enum`
7. `const`
8. `static var`
9. `@export`
10. 普通变量，public 到 private
11. `@onready`
12. `_static_init()`
13. 静态方法
14. Godot 虚函数：`_init`、`_enter_tree`、`_ready`、`_process`、`_physics_process`
15. 覆盖的自定义方法
16. 其余方法，public 到 private
17. 内部类

## 信号

- 信号参数必须有类型。
- 连接信号使用 Callable 或直接方法引用。
- UI 通过信号请求业务动作，不直接修改全局状态。

```gdscript
signal item_purchased(item: ItemData)

func _ready() -> void:
	item_purchased.connect(_on_item_purchased)
```

## 布尔表达式

使用英文布尔运算符：

```gdscript
if is_alive and not is_frozen:
	pass
```

不要使用 `&&`、`||`、`!`。

## 错误处理

- 不可变前置条件用 `assert`。
- 运行时异常路径用 `push_warning` 或 `push_error`。
- 不要静默返回 `null` 或 `false`，除非调用方已明确处理。

```gdscript
func get_item(slot: int) -> ItemData:
	if slot < 0 or slot >= MAX_BOARD_SLOTS:
		push_warning("Invalid slot: %d" % slot)
		return null
	return _items[slot]
```

## 注释

- 类和重要 public 方法使用 Godot 文档注释 `##`。
- 普通注释只解释意图、约束或非显然原因。
- 不写“把 x 赋给 y”这类重复代码的注释。

## UI 规则

- UI 控制器只管理显示、动画、输入和 signal。
- 不在 UI 中结算战斗、扣 Prestige、推进 Hour 或改 XP。
- 父子节点不要同时设置 anchor 和 offset，避免布局漂移。
- 动态创建 UI 时要设定最小尺寸、锚点和容器规则，避免不同分辨率重叠。

## 数据与状态

- 基础数据用 Resource/JSON；运行时状态用 runtime 对象。
- 不要把 cooldown、temporary modifier、trigger count 写回基础 Resource。
- Day/Hour、Prestige、XP、Income 只允许一个权威状态源。
- 需要兼容旧 API 时，旧 API 应代理到权威状态源，而不是复制字段。

## 反模式

- 在 `main.gd` 里继续堆业务逻辑。
- 在 UI 脚本里写战斗结算。
- 新增第五/第六套阶段判断。
- 用字符串散落判断 `"PvP"`、`"采购"`。
- 为单个物品写硬编码 if，而不是用 effect data。
- 为了修 bug 回滚无关用户改动。

## Git

提交格式：

```text
feat(scope): subject
fix(scope): subject
docs(scope): subject
refactor(scope): subject
test(scope): subject
chore(scope): subject
```

提交前确认 `git status --short`，只包含本任务相关文件。
