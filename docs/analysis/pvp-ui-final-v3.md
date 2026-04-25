# PvP UI 最终策划案 v3

> **2026-04-25 二次修订**：本文只作为早期 BattleUI 局部问题记录，不再作为主流程布局
> 权威。战斗、时间选择、商人的统一布局以 `docs/planning/ui-layout-reference.md` 为准。
> 文中的“商店横排/手牌/河流”是旧截图术语，后续开发统一改称 BoardItems /
> CenterDivider / BattleCenter。不得据此实现回合制、EndTurn、PvP 商店或战斗内购买。

> **日期**：2026-04-16 | **基于**：Allen 提供的 Bazaar 实际截图 + 当前代码审计 | **关键修正**：v2 误标为"左右对称"，实际 Bazaar 和 FCG 均为上下结构

> **结论更新**：旧 BattleUI 的上下方向可保留为战斗局部参考，但“仅需修复 3 个偏差”
> 已不成立。若目标是对齐 Allen 2026-04-25 提供的三张参考截图，必须先引入
> `BazaarShell`，再将 BattleUI 作为 `BattleStateView` 填充到统一槽位中。

---

## 一、现状审计（当前代码 vs Bazaar 实际）

### 1.1 局部可复用（不是全局无需改动）

| 维度 | FCG 现状 | Bazaar | 状态 |
|------|---------|--------|------|
| 布局方向 | 上下结构（对手顶0.18/玩家底0.78） | 上下结构 | ✅ 正确 |
| 卡牌尺寸 | 80×110 矩形 | 矩形 | ✅ 正确 |
| 左上角价格 | 蓝色圆底+白色数字 | 蓝色圆底+白色数字 | ✅ 正确 |
| 插画色块 | WEAPON红/SHIELD蓝/HEAL绿/UTILITY紫 | 幻想插画 | ✅ Phase1占位 |
| 中线分隔 | 蓝色 0.50-0.506 | 中央视觉分隔 | ✅ 正确 |
| 对手/怪物 Board 横排 | 上排蓝色边框 | 上排正面物品 | ✅ 正确 |
| 玩家 Board 横排 | 下排深色边框 | 下排正面物品 | ✅ 正确 |
| HP大数字 | 36px白色+描边+纯数字%d | 775大数字 | ✅ 正确 |
| 充能条 | 12px绿底 | 绿→红渐变 | ✅ 基本正确 |
| 护盾条 | 叠在充能条上方 | 叠在HP上方 | ✅ 正确 |
| 时钟图标 | 48×48，居中线分隔上方 | 华丽时钟 | ✅ 正确 |
| 头像框 | 64×64对手+玩家 | 矩形头像框 | ✅ 正确 |
| 角色头像 | 48×48玩家info_box内 | 角色头像 | ✅ 正确 |
| 冷却遮罩 | 丝滑覆盖 | 丝滑覆盖 | ✅ 正确 |
| PvE兼容 | is_pvp守卫 | — | ✅ 正确 |

### 1.2 需修复（3 项偏差）

| # | 维度 | FCG 现状 | Bazaar 实际 | 优先级 |
|---|------|---------|------------|--------|
| 1 | 对手物品展示 | **背面**（card_back_style, line 803） | **正面可见**（信息透明） | P0 |
| 2 | 对手技能展示 | **隐藏❓**（hidden=true, line 1677-1683） | **全部可见** | P0 |
| 3 | 胜场计数器 | 仅战斗结束提示 | **常驻显示** "7/10 Wins" + 🏆 | P1 |

---

## 二、修复方案

### Fix-1：对手物品改为正面可见（P0）

**改动文件**：`scripts/ui/battle_ui.gd`

```gdscript
# 当前（line 803）
card_panel.add_theme_stylebox_override("panel", _create_card_back_style())

# 改为：复用玩家卡牌样式
card_panel.add_theme_stylebox_override("panel", _create_card_front_style())
```

**需要同步**：
- 添加插画色块（调用 `_create_illustration_block(item.type)`）
- 添加物品名称+属性标签
- 添加冷却遮罩
- 保持 `mouse_filter = MOUSE_FILTER_IGNORE`（不可交互）

### Fix-2：对手技能改为可见（P0）

**改动文件**：`scripts/ui/battle_ui.gd`

```gdscript
# 当前（line 1677-1683）
func _update_skill_labels(skill_labels, skill_names, hidden: bool):
    for i in range(skill_labels.size()):
        if hidden:
            skill_labels[i].text = "❓"

# 对手技能更新调用改为 hidden=false
```

**数据来源**：`current_monster.monster_skills` 数组（已存在）

### Fix-3：胜场计数器（P1）

**改动文件**：`scripts/ui/battle_ui.gd`

**新增元素**：
- 位置：时钟图标旁（中线分隔上方）
- 格式：🏆 7/10 Wins
- 数据源：`game_manager.pvp_wins`
- 更新时机：`_process()` 或 `on_pvp_win` 信号

---

## 三、不修改项

| 维度 | 为什么不改 |
|------|-----------|
| 准备阶段对手 board 未生成 | 进入战斗后显示对手 snapshot，准备阶段不显示未知数据 |
| 战斗阶段对手物品可见 | 需要在战斗开始后显示对手 board，与 Fix-1 一并处理 |
| 仓库/宝箱 | P2 后续功能，当前 LinearInventory 10格已够用 |
| 物品尺寸 S/M/L | P2 后续功能 |

---

## 四、验收标准

| # | 验收项 | 通过条件 | 对应修复 |
|---|--------|---------|---------|
| 1 | 对手物品正面 | 显示名称+属性+冷却遮罩（不可交互） | Fix-1 |
| 2 | 对手技能可见 | 显示实际技能名（非❓） | Fix-2 |
| 3 | 胜场计数器 | 🏆 N/10 Wins 常驻显示 | Fix-3 |
| 4 | 对手物品不可交互 | mouse_filter=IGNORE | Fix-1 |
| 5 | PvE兼容 | is_pvp=false 使用怪物数据而非 ghost 数据 | 全部 |
| 6 | 0 ERROR | headless + GUI | 全部 |

---

## 五、实施建议

> 建议拆分为 **T-PVP-8** 单个任务，1个commit，预计 1-2天。Fix-1 + Fix-2 + Fix-3 一起做。
