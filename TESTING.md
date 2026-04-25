# TESTING.md

本文档定义 FancyCardGame 的验证策略。没有测试框架时，也要做 Godot headless
加载和关键路径自查。

## 最低验证

文档任务：

```bash
git status --short
rg -n "回合制|EndTurn|最终Boss|5 个 Hour|5个Hour|固定扣 2|初始 10" docs AGENTS.md
```

代码任务：

```bash
godot --headless --path /Users/Allenz/Projects/FancyCardGame --quit
godot --headless --path /Users/Allenz/Projects/FancyCardGame --editor --quit
```

如果本机 Godot 命令不是 `godot`，先用：

```bash
which godot
which godot4
```

无法运行 Godot 时，把命令、错误和原因写进 `.codex-status/{task_id}/godot_verify.json`。

## 推荐测试分层

### Unit

适合测试：

- PhaseService：Hour 0-5 对应阶段，Hour 5 后进下一 Day。
- RunState：Prestige 扣除、last chance、10 wins。
- EconomyService：price、sell value、refresh cost、income。
- EffectSystem：trigger、condition、target、chain guard。
- LinearInventory：Small/Medium/Large 连续槽位、移动、删除。

### Integration

适合测试：

- 完整 Day 0-5 推进。
- PvE 选择怪物 -> 战斗 -> 奖励 -> 下一 Hour。
- PvP 失败扣 Prestige，第一次归零触发 Last Chance。
- XP 满 8 后弹出 level-up 奖励。
- 商店购买后 board/stash 和 gold 同步。

### Manual QA

每个可玩切片至少手动检查：

- 新开 run 后 gold/income/prestige/hour 显示正确。
- Hour 2 必定进入怪物三选一。
- Hour 5 必定进入自动 PvP。
- 战斗中没有 EndTurn、手牌、PvP 商店等误导性交互。
- 物品 cooldown、护盾、治疗、持续伤害可见且不重叠。
- 战斗结束等待玩家确认，不自动跳走。

## ACP 结果文件

代码任务应写：

```text
.codex-status/{task_id}/
├── summary.md
├── changed_files.md
├── test_results.json
├── cr_signoff.json
└── godot_verify.json
```

`test_results.json`:

```json
{
  "tests": [
    {"name": "godot_headless_load", "result": "pass", "detail": ""}
  ],
  "total": 1,
  "passed": 1,
  "failed": 0
}
```

`godot_verify.json`:

```json
{
  "commands": [
    "godot --headless --path /Users/Allenz/Projects/FancyCardGame --quit"
  ],
  "exit_code": 0,
  "errors": [],
  "warnings": [],
  "timestamp": "2026-04-25T00:00:00+08:00"
}
```

`cr_signoff.json`:

```json
{
  "approved": true,
  "issues": [],
  "checks": {
    "rules_aligned": true,
    "state_owner_respected": true,
    "gdscript_style": true,
    "tests_run": true
  }
}
```

## 不合格条件

出现以下任一项，不应交付为完成：

- 新代码继续写 5 Hour 循环。
- 新增回合制 PvP、EndTurn、PvP 商店或战斗内手牌操作。
- 直接在 UI 中扣 Prestige、发奖励或推进 Hour。
- 新增状态字段但没有说明权威归属。
- Godot 无法加载且没有记录阻塞原因。
