# UI重构-大巴扎风格策划细案

> **文件编号**：FCG_UI_Rework_001 | **版本**：v1.1.0 | **日期**：2026-04-25

本文只描述主流程 UI 重构方向。玩法流程以根目录 `GAME_RULES.md` 为准，截图级布局以
`docs/planning/ui-layout-reference.md` 为准。

## 设计目的

将当前文字面板和临时商店弹窗重构为 The Bazaar-like 的全屏棋盘式界面。核心目标是让
战斗、时间选择、商人三个高频状态共用同一个主界面骨架，玩家可以始终看到自己的 build、
生命、金币和当前 Hour。

## 权威布局

后续 UI 开发必须遵循 `ui-layout-reference.md` 中定义的 `BazaarShell`：

- `LeftClockPanel`：左侧常驻 Day/Hour 轮盘。
- `TopContextPanel`：敌方、商人或事件节点的顶部上下文。
- `UpperBoardPanel`：敌方 Board、商人货架或事件选择承载区。
- `PlayerBoardPanel`：玩家 Board，所有主流程状态常驻。
- `BottomHudPanel`：玩家血条、头像、等级、技能/被动、仓库、gold/income。
- `RightActionArea`：继续、刷新、设置等状态操作按钮。

旧的“三层结构 TopZone + ItemBar + HeroBar”只能作为早期草案参考，不能覆盖
`ui-layout-reference.md` 的坐标和槽位。

## 状态填充

### 时间选择

- 上中部显示 3 个可选节点，使用头像/场景缩略图/徽章，而不是文字按钮列表。
- 玩家 Board、左侧时钟和底部 HUD 保持可见。
- 选项选择后由 flow service 进入商人、PvE、奖励或事件结算。

### 商人

- 顶部中心显示商人头像，左右是摊位背景。
- 商人物品作为货架显示在玩家 Board 上方。
- 刷新、锁定、离开等输入只发 signal，不直接在 UI 中扣钱或推进 Hour。

### 战斗

- 顶部中心显示敌方/怪物头像。
- 上方显示敌方/怪物 Board，物品正面可见但不可交互。
- 下方显示玩家 Board。
- 战斗自动进行，结束后在 `RightActionArea` 显示继续按钮。

## 术语规范

| 用途 | 推荐名 | 说明 |
| --- | --- | --- |
| 主界面骨架 | `BazaarShell` | 所有主流程状态共用 |
| 时间选择 | `TimeSelectView` | 替代旧 `EventPanel` |
| 商人货架 | `MerchantStateView` / `MerchantShelfPanel` | 替代旧 `ShopPanel` 弹窗 |
| 战斗状态 | `BattleStateView` | 填充敌方/玩家 Board |
| 玩家物品 | `PlayerBoardPanel` | 不使用“手牌” |
| 敌方物品 | `OpponentBoardPanel` | 不使用背面隐藏 |
| 底部 HUD | `BottomHudPanel` | 替代零散动态 `HeroBarLayer` |

## 当前实现差距

- `EventPanel` 仍是顶部文字按钮面板。
- `ShopUI` 仍是普通商店窗口，缺少商人头像、货架、玩家 Board 的同屏布局。
- `BattleUI` 有上下结构雏形，但未接入统一 `BazaarShell`，仍保留旧命名和不稳定区域。
- 底部 HUD 由 `main.gd` 动态创建，缺少可复用场景和明确数据绑定。

## 客户端校验与提示

| 编号 | Key | 提示文本 | 触发条件 |
| --- | --- | --- | --- |
| E_UI_001 | SHELL_SLOT_MISSING | 主界面槽位缺失 | `BazaarShell` 缺少必需子节点 |
| E_UI_002 | ITEMBAR_FULL | 道具栏已满 | 玩家 Board 无空位 |
| E_UI_003 | GOLD_INSUFFICIENT | 金币不足 | 购买/刷新时金币不够 |
| E_UI_004 | REFRESH_USED | 刷新已使用 | 当前商人已使用过刷新 |
| E_UI_005 | STATE_VIEW_LOAD_FAIL | 状态界面加载失败 | 子 view 场景不存在或初始化失败 |

## 实施顺序

按 `ui-layout-reference.md` 的推荐任务拆分执行。不要把事件、商人、战斗 UI 一次性混在
一个大任务里；每个任务必须有截图级验收标准。
