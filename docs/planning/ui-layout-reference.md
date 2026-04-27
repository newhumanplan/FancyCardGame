# UI Layout Reference - Bazaar Screen Shell

更新时间：2026-04-25

本文是 FancyCardGame 主流程 UI 的权威布局规范。目标不是复刻 The Bazaar 的具体商业美术资源，
而是复刻截图中的功能区位置、层级关系和状态切换方式。后续 ACP/Codex UI 任务必须先读本文。

## 结论

主流程界面必须使用一个常驻的 `BazaarShell`，不要为事件、商人、战斗分别制作互相覆盖的
全屏弹窗。三张参考截图共用同一套骨架：

- 左侧常驻时间轮盘。
- 底部常驻英雄 HUD、血条、头像、技能/被动、宝箱/仓库、金币/收入。
- 中下常驻玩家 Board。
- 中上根据状态替换为事件选择、商人货架、敌方 Board 或怪物 Board。
- 顶部中心根据状态显示敌方头像、商人头像或事件选择节点。
- 右侧只放当前状态需要的操作按钮，不承担主信息展示。

如果代码实现与本文冲突，以本文为准；如果旧文档仍使用 `EventPanel`、`ShopPanel`、`手牌`、
`牌河`、`商店横排` 等旧术语，只能作为历史参考。

## 基准坐标

坐标以 1920x1080、16:9 横屏为基准。Godot 实现应使用 anchors + responsive scale，
但视觉比例必须按下表保持。

| 区域 | 推荐归一化范围 | 用途 | 常驻性 |
| --- | --- | --- | --- |
| `BackgroundLayer` | x 0.00-1.00, y 0.00-1.00 | 全屏场景美术、棋盘底图、边框装饰 | 常驻 |
| `LeftClockPanel` | x 0.06-0.18, y 0.36-0.66 | Day/Hour 轮盘、进度、Prestige 提示入口 | 常驻 |
| `TopContextPanel` | x 0.24-0.80, y 0.05-0.28 | 敌方/商人头像，或时间选择节点 | 状态替换 |
| `UpperBoardPanel` | x 0.20-0.82, y 0.29-0.52 | 敌方 Board、商人货架、事件节点承载区 | 状态替换 |
| `PlayerBoardPanel` | x 0.20-0.82, y 0.53-0.76 | 玩家当前 Board items | 常驻 |
| `BottomHudPanel` | x 0.18-0.84, y 0.76-0.97 | 玩家血条、头像、技能、仓库、金币/收入 | 常驻 |
| `StashButtonArea` | x 0.19-0.31, y 0.78-0.96 | 宝箱/仓库入口 | 常驻 |
| `HeroPortraitArea` | x 0.42-0.58, y 0.79-0.98 | 玩家头像、等级、核心状态 | 常驻 |
| `WalletArea` | x 0.69-0.82, y 0.78-0.95 | gold、income、购买相关资源 | 常驻 |
| `RightActionArea` | x 0.70-0.81, y 0.08-0.28 | 继续、跳过、搜索、设置等状态按钮 | 按需显示 |

窄屏或非 16:9 适配时，优先保持 `PlayerBoardPanel`、`BottomHudPanel` 和 `LeftClockPanel`
的相对位置；装饰背景可以裁切，功能区不能重叠。

## 层级结构

建议场景结构：

```text
RunScreen
  BazaarShell
    BackgroundLayer
    LeftClockPanel
    TopContextPanel
    UpperBoardPanel
    PlayerBoardPanel
    BottomHudPanel
      StashButtonArea
      PassiveSkillArea
      HeroPortraitArea
      WalletArea
    RightActionArea
    OverlayLayer
```

职责边界：

- `BazaarShell` 只管理布局槽位、显示/隐藏状态、动画过渡。
- `BattleStateView` 只填充 battle 相关槽位。
- `TimeSelectView` 只填充事件/商人/怪物选择节点。
- `MerchantStateView` 只填充商人头像、货架、刷新/锁定/购买输入。
- `PlayerBoardPanel` 和 `BottomHudPanel` 由统一控制器渲染，不能被战斗或商店子界面重建。
- 业务结算仍归 service/system，UI 通过 signal 提交意图。

## Stash / Board 整理

参考仓库截图。Stash 是 `BazaarShell.OverlayLayer` 上的半透明上方叠层，不是全屏背包页：

- 点击 `BottomHudPanel/StashButtonArea` 的宝箱打开或关闭。
- 顶部中间显示宝箱图标；中上方保留较大的仓库装饰面板；10 个 Stash 槽位放在仓库面板下半部。
- 打开 Stash 时，`PlayerBoardPanel`、`BottomHudPanel`、`LeftClockPanel` 仍可见；玩家可以在 Board 与 Stash 之间拖动物品。
- Board 与 Stash 都必须使用同一套线性物品栏移动规则：直接放下、右推顺延、整组互换、失败回滚。
- Stash 默认 10 格。不要做二维 RPG 背包，也不要让 Stash 覆盖玩家 Board。

## 战斗界面

参考截图一。战斗状态不是弹窗，也不是独立 battle page，而是 `BazaarShell` 的一种填充状态。

必备布局：

- `TopContextPanel`：敌方或怪物头像居中，左右为装饰面板；PvP 可显示对手基础信息。
- `UpperBoardPanel`：敌方/怪物 Board 横排，物品正面可见，战斗中不可拖拽购买。
- `PlayerBoardPanel`：玩家 Board 横排，位于敌方 Board 下方。
- `BottomHudPanel`：玩家血条横跨底部中部，头像居中下沉，技能/被动围绕头像。
- `LeftClockPanel`：显示当前 Day/Hour 轮盘。
- `RightActionArea`：战斗结束后显示 `Continue`；战斗中可以显示加速/日志/查看按钮。

禁止项：

- 不要出现 EndTurn。
- 不要出现 PvP 商店、手牌、牌河或战斗内购买区。
- 不要用大块文字日志面板占据主棋盘。
- 不要把敌方 Board 渲染成背面卡牌。

## 时间选择界面

参考截图二。时间选择是上方浮动节点，而不是按钮列表弹窗。

必备布局：

- `TopContextPanel` + `UpperBoardPanel`：展示 3 个可选节点，横向分布在上中部。
- 每个选项使用图片/头像/场景缩略图作为主体，下面可以挂小徽章表示类型或风险。
- 选项之间保留足够空隙，背后有柔和光效或地图纹理，但不能放入普通矩形菜单面板。
- `PlayerBoardPanel` 和 `BottomHudPanel` 仍然可见，玩家可以在做选择前确认当前 build。
- `LeftClockPanel` 常驻显示当前 Hour。

允许的 option 类型：

- item vendor
- skill trainer/vendor
- free reward
- special event
- service vendor
- PvE monster choice

禁止项：

- 不要使用 `选择你的事件` 标题 + 三个文字按钮作为主界面。
- 不要遮住玩家 Board 和底部 HUD。
- 不要让 option 选择页面变成独立菜单页。

## 商人界面

参考截图三。商人界面是同一个棋盘壳中的货架状态。

必备布局：

- `TopContextPanel`：商人头像居中，左右为摊位/货架背景。
- `UpperBoardPanel`：商人物品货架，通常 3-5 个商品，左右可留空展示货架宽度。
- `PlayerBoardPanel`：玩家当前 Board 位于货架下方，保持可见。
- `BottomHudPanel`：钱包、收入、头像、血条、仓库入口保持常驻。
- 刷新、锁定、离开等操作放入 `RightActionArea` 或货架角落，不要做底部弹窗按钮条。

交互要求：

- 商品点击打开详情或购买确认，不直接在 UI 中扣钱。
- 锁定状态必须在商品卡上直接可见。
- 购买失败要通过轻量提示反馈，不弹出遮挡棋盘的大对话框。
- 离开商人后回到 Hour 流程，由 flow service 推进。

禁止项：

- 不要使用全屏 `ShopUI` 面板盖住主棋盘。
- 不要只显示商品而隐藏玩家 Board。
- 不要把商店做成普通列表、网格背包或 RPG 商店窗口。

## 组件命名

新代码应使用以下命名，避免旧卡牌对战术语继续扩散。

| 目标概念 | 推荐名称 | 禁止/旧名称 |
| --- | --- | --- |
| 主流程棋盘壳 | `BazaarShell` | `GamePanel`, `MainPanel` |
| 顶部上下文 | `TopContextPanel` | `TopZone` 单独承担所有内容 |
| 上方动态区域 | `UpperBoardPanel` | `ShopRow`, `Hand`, `River` |
| 玩家物品区 | `PlayerBoardPanel` | `CombatHand`, `PlayerHand` |
| 敌方/怪物物品区 | `OpponentBoardPanel` | `HiddenCards`, `CardBackRow` |
| 商人货架 | `MerchantShelfPanel` | `ShopPanel`, `ShopPopup` |
| 时间选择 | `TimeSelectView` | `EventPanel` |
| 底部 HUD | `BottomHudPanel` | `HeroBarLayer` 零散动态节点 |

## 当前实现差距

当前工程中的这些实现不符合本文目标，后续 UI 重构应逐步替换：

- `scenes/main.tscn` 中的 `EventPanel` 是顶部按钮面板，不符合时间选择截图。
- `scenes/shop_panel.tscn` 和 `scripts/ui/shop_ui.gd` 是普通商店面板，不符合商人货架截图。
- `scripts/ui/battle_ui.gd` 已有上下 Board 雏形，但缺少统一 `BazaarShell`，且仍保留旧名称和部分旧布局。
- `scripts/main.gd` 动态创建 `HeroBarLayer`，导致底部 HUD 难以成为所有状态共享的稳定布局。

## 验收标准

UI 重构任务必须至少通过以下人工验收：

- 战斗、时间选择、商人三种状态的 `LeftClockPanel` 和 `BottomHudPanel` 位置一致。
- 时间选择和商人状态下，玩家 Board 与底部 HUD 不被弹窗遮挡。
- 商人状态中，商人头像在顶部中心，商品在玩家 Board 上方。
- 战斗状态中，敌方/怪物 Board 在上，玩家 Board 在下，敌方物品正面可见。
- 屏幕中不得出现主流程级普通矩形弹窗：`选择你的事件`、`商人商店`、底部关闭按钮条等。
- Headless 加载 0 error；GUI 手动截图检查 1920x1080 和至少一个窄屏尺寸。

## 推荐任务拆分

不要把 UI 一次性派成“优化 UI”。推荐按以下顺序派发：

1. `T-UI-SHELL-DESIGN`：只做技术设计，输出 `BazaarShell` 节点树、槽位 API 和迁移方案。
2. `T-UI-SHELL-FOUNDATION`：实现 `BazaarShell`、`BottomHudPanel`、`PlayerBoardPanel`、`LeftClockPanel` 的空壳与数据绑定。
3. `T-UI-TIME-SELECT`：把当前 `EventPanel` 迁移为 `TimeSelectView`，三节点布局，保持底部 HUD 可见。
4. `T-UI-MERCHANT-SHELF`：把当前 `ShopUI` 迁移为 `MerchantStateView`，商品货架在玩家 Board 上方。
5. `T-UI-BATTLE-SHELL`：让 `BattleUI` 填充 `BazaarShell`，清理旧 `hand/river/shop` 命名。
6. `T-UI-SCREENSHOT-QA`：建立截图验收清单，检查三种状态的区域位置和遮挡问题。
