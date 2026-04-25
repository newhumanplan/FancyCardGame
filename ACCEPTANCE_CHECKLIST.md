# ACCEPTANCE_CHECKLIST.md

ACP/Codex 任务完成前必须自查本清单。

## 任务开始

- [ ] 已阅读与任务相关的根目录文档。
- [ ] 已确认任务是否涉及 Day/Hour、Prestige、XP、Income、Battle、Item、Skill、Monster。
- [ ] 已检查当前 worktree，未计划回滚无关改动。
- [ ] 已识别权威状态源，不会新增重复状态。
- [ ] 如任务涉及主流程 UI，已阅读 `docs/planning/ui-layout-reference.md`。

## 方案

- [ ] 方案符合 `GAME_RULES.md`。
- [ ] 效果/触发改动符合 `EFFECT_SYSTEM.md`。
- [ ] 数据字段改动符合 `DATA_MODEL.md`。
- [ ] 架构边界符合 `ARCHITECTURE.md`。
- [ ] UI 布局符合 `docs/planning/ui-layout-reference.md`。
- [ ] 没有引入反目标：回合制 PvP、EndTurn、PvP 商店、最终 Boss、5 Hour。

## 实现

- [ ] GDScript 类型提示完整。
- [ ] `@onready` 显式类型。
- [ ] 代码顺序符合 17 步规则。
- [ ] UI 只做展示和输入，不做业务结算。
- [ ] 主流程 UI 没有新增全屏弹窗式 `EventPanel` / `ShopUI` 变体。
- [ ] 时间选择、商人、战斗共用同一套底部 HUD 和玩家 Board 位置。
- [ ] 商人商品位于玩家 Board 上方；时间选择为上中部 3 个节点；战斗为上敌方/下玩家 Board。
- [ ] 没有散落新的 magic number；核心常量集中定义。
- [ ] 新数据没有写入 battle runtime 临时字段。
- [ ] 错误路径有 `push_warning` / `push_error` 或明确返回处理。

## 验证

- [ ] 运行了相关 unit/integration 测试，或说明没有测试框架。
- [ ] 运行了 Godot headless 加载，或记录无法运行原因。
- [ ] 手动检查了关键 UI/流程。
- [ ] 如涉及主流程 UI，已手动截图检查 1920x1080 和至少一个窄屏尺寸。
- [ ] 用 `rg` 搜索确认没有新增旧规则关键词。

## 交付

- [ ] 总结说明包含改了什么、为什么、如何验证。
- [ ] 如有 `task_id`，已写 `.codex-status/{task_id}/`。
- [ ] 如任务要求 commit，commit 信息符合规范。
- [ ] 未提交时已说明当前文件状态。

## 常用搜索

```bash
rg -n "current_hour|% 5|>= 5|== 4|Hour 5|5 个 Hour|5个Hour" scripts docs
rg -n "回合制|EndTurn|最终Boss|PvP商店|手牌|牌河" scripts docs
rg -n "prestige|Prestige|pvp_wins|last_chance|futura" scripts docs
rg -n "xp|level|income|gold" scripts docs
rg -n "EventPanel|ShopPanel|ShopPopup|HeroBarLayer|PlayerHand|CombatHand|ShopRow|River" scripts scenes docs
```
