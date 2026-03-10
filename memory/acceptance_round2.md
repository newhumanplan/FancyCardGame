# MCP 验收标准文档 - Round 2

## 项目：FancyCardGame（大巴扎）
## 验收时间：2026-03-11
## 验收人：MCP Agent

---

## 验收清单

### P0 功能修复验收

| # | 验收项 | 状态 | 备注 |
|---|--------|------|------|
| 1 | 英雄选择界面不显示商店/战斗按钮 | 🔲 待验证 | 检查 HeroSelectPanel 可见时 ButtonBox 隐藏 |
| 2 | 选择英雄后显示事件选择面板 | 🔲 待验证 | EventPanel 在 _on_game_started() 中显示 |
| 3 | 点击事件选项后自动进入下一 Hour | 🔲 待验证 | _auto_advance_hour() 被事件处理函数调用 |
| 4 | Hour 2 显示战斗按钮 | 🔲 待验证 | _update_button_visibility() 中 hour==2 显示战斗 |
| 5 | Hour 5 显示 PvP | 🔲 待验证 | hour==5 固定显示 "⚔️ PvP 对战" |
| 6 | "下一小时"按钮不再出现 | 🔲 待验证 | next_hour_button.visible = false |

---

## 验收方法

1. 启动游戏 (Godot 4.6.1)
2. 进入英雄选择界面，验证商店/战斗按钮隐藏
3. 选择英雄（战士/法师）
4. 验证事件选择面板出现
5. 点击任意事件选项
6. 验证自动进入下一 Hour
7. 验证 Hour 2 显示战斗
8. 验证 Hour 5 显示 PvP
9. 验证"下一小时"按钮始终隐藏

---

## 代码审查结果

### 1. 英雄选择界面隐藏按钮 ✅
- `_show_hero_selection()` 调用 `_hide_game_buttons()`
- `_hide_game_buttons()` 设置 shop_button, battle_button, next_hour_button 为不可见

### 2. 事件选择系统 ✅
- `_show_event_panel()` 和 `_hide_event_panel()` 已实现
- `_generate_event_options()` 生成随机事件
- Hour 5 固定为 PvP

### 3. 自动流转 ✅
- `_auto_advance_hour()` 在所有事件处理后调用
- `await get_tree().create_timer(1.0).timeout` 延迟显示
- `GameManager.next_hour()` 进入下一小时
- `_generate_event_options()` 重新生成事件

### 4. Hour 2 战斗 ✅
- `_update_button_visibility()` 中 `elif hour == 2: battle_button.visible = true`

### 5. Hour 5 PvP ✅
- `_generate_event_options()` 中 `if hour == 5: ... current_event_type = "pvp"`

### 6. 下一小时按钮隐藏 ✅
- `_update_button_visibility()` 中 `next_hour_button.visible = false`

---

## 结论

代码逻辑审查通过，需要实际运行游戏验证。
