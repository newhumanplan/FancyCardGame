# 技术翻译：规则修正（4处改动）

## 日期：2026-04-08
## 派发目标：Codex (sessions_spawn, run模式)
## 任务ID：38236929

## 改动清单

### 改动1：声望第一次归零 → Futura 事件（3选1）⚠️ 大改
- **game_manager.gd**: 新增 `signal futura_triggered()`，`_gold_upgrade()` 不再给固定100金，改为 emit futura_triggered
- **main.gd**: 连接 futura_triggered 信号，弹出3选项面板（Bounty/Crossroads/Legacy），选择后声望恢复到1
- 风险：信号断开/重连逻辑较复杂，需仔细测试

### 改动2：声望上限 100 → 20
- **game_manager.gd**: `max_prestige = 20`

### 改动3：胜利条件改为 10 场 PvP 胜利
- **game_manager.gd**: 新增 `pvp_wins` 变量，新增 `on_pvp_win()` 方法
- **battle_ui.gd**: `_on_battle_win()` 区分 PvP/PvE，PvP 调用 `on_pvp_win()`
- **main.gd**: game_over 面板显示 PvP 胜场

### 改动4：怪物战斗失败不扣 Prestige
- **game_manager.gd**: `on_battle_lose()` 移除 Prestige 扣除（回退到简单版本）

### 确认项：天数推进逻辑
- 当前 `_auto_advance_hour()` → `next_hour()` → hour 0-4 循环 → day+1 ✅ 已正确

## 修改文件
- scripts/game_manager.gd
- scripts/main.gd
- scripts/ui/battle_ui.gd

## 状态
- [x] 技术翻译完成
- [ ] Codex 执行中
- [ ] 运行验证待做
