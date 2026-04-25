# ACP_TASK_TEMPLATE.md

把任务派给 Codex ACP 时，建议使用下面模板。目标是让 Codex 先对齐规则和架构，再动手
实现，减少“看到了旧代码就继续错下去”的情况。

## 模板

```text
你在 /Users/Allenz/Projects/FancyCardGame 工作。
这是 Godot 4.6.1 + GDScript 2.0 项目。

task_id: <TASK-ID>
任务目标:
<用 3-8 行描述玩家可见目标和代码目标>

必须先读:
- AGENTS.md
- GAME_RULES.md
- EFFECT_SYSTEM.md
- DATA_MODEL.md
- ARCHITECTURE.md
- CODING_STANDARDS.md
- TESTING.md
- ACCEPTANCE_CHECKLIST.md
- docs/planning/ui-layout-reference.md（仅 UI/布局/商人/时间选择/战斗界面任务必读）
- docs/planning/ui-refactor-task-plan.md（UI 重构拆分任务必读）

本任务涉及的模块:
- <scripts/services/...>
- <scripts/data/...>
- <scripts/ui/...>

硬性约束:
- 不要转发给其他 agent。
- 不要新增回合制 PvP、EndTurn、PvP 商店、最终 Boss 或 5 Hour 逻辑。
- UI 任务必须遵循 BazaarShell 布局，不要新增全屏弹窗式 EventPanel/ShopUI。
- 如果发现旧文档/旧代码冲突，以根目录文档为准。
- 不要回滚无关 dirty files。

执行流程:
1. 先输出 5-10 行实现方案，列出会改哪些文件。
2. 检查方案是否违反 GAME_RULES/ARCHITECTURE。
3. 实现代码和必要文档更新。
4. 运行 TESTING.md 中相关验证。
5. 写 .codex-status/<TASK-ID>/summary.md、changed_files.md、
   test_results.json、cr_signoff.json、godot_verify.json。
6. 如果本任务明确要求 commit，再提交 commit。

验收标准:
- <可观察结果 1>
- <可观察结果 2>
- <测试/验证标准>
```

## 好任务示例

```text
task_id: T-RUN-6HOUR
任务目标:
把 Day/Hour 从旧 5 阶段迁移为 6 Hour。
Hour 0/1/3/4 是 Vendor/Event/Free，Hour 2 是 PvE，Hour 5 是 PvP。
所有判断必须通过 PhaseService，不允许继续散落 %5、>=5、==4。

涉及模块:
- scripts/services/phase_service.gd
- scripts/services/run_state.gd
- scripts/game_manager.gd
- scripts/main.gd
- 相关 UI label

验收标准:
- 新 run 显示 Day 1 Hour 0。
- 走完 0,1,2,3,4,5 后进入 Day 2 Hour 0。
- Hour 2 进入怪物选择，Hour 5 进入 PvP。
- rg 搜索没有新增 % 5 或 current_hour == 4。
```

```text
task_id: T-UI-TIME-SELECT
任务目标:
把当前 EventPanel 替换为 BazaarShell 中的 TimeSelectView。
时间选择应在上中部显示 3 个图片/头像节点，左侧时钟、玩家 Board、底部 HUD 保持可见。
不要使用“选择你的事件”标题加三个文字按钮的弹窗布局。

涉及模块:
- docs/planning/ui-layout-reference.md
- scenes/main.tscn
- scripts/main.gd
- scripts/ui/bazaar_shell.gd
- scripts/ui/time_select_view.gd

验收标准:
- 进入 Hour option 选择时，屏幕中上部显示 3 个横向选择节点。
- 玩家 Board 和底部 HUD 没有被遮挡。
- 左侧时间轮盘位置与战斗/商人状态一致。
- UI 只发出 option selected signal，不直接结算奖励或推进 Hour。
- Godot headless 0 ERROR，GUI 手动截图检查 1920x1080。
```

```text
task_id: T-UI-MERCHANT-SHELF
任务目标:
把当前 ShopUI 弹窗迁移为 BazaarShell 的 MerchantStateView。
商人头像位于顶部中心，商品货架位于玩家 Board 上方，底部 HUD 和钱包区域常驻。

涉及模块:
- docs/planning/ui-layout-reference.md
- scenes/shop_panel.tscn
- scripts/ui/shop_ui.gd
- scripts/ui/merchant_state_view.gd
- scripts/services/economy_service.gd

验收标准:
- 商人界面没有全屏普通面板标题“商人商店”。
- 商品显示在上方货架区，玩家 Board 显示在下方。
- 刷新/购买/锁定通过 service API 或 signal，不在 UI 内直接改 gold。
- Godot headless 0 ERROR，GUI 手动截图检查 1920x1080。
```

## 坏任务示例

```text
做一下大巴扎的战斗，顺便优化 UI。
```

问题：

- 没有 task_id。
- 没有模块范围。
- 没有验收标准。
- “战斗”和“UI”同时太大，容易牵出不受控改动。
