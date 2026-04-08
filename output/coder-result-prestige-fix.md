# Bug 修复：游戏失败/声望规则修正

## 日期：2026-04-08

## 问题
Allen 确认的正确规则与当前代码不符：
1. 声望归零第一次 → 黄金升级 + 恢复到1（当前代码无归零计数）
2. 声望归零第二次 → 游戏结束（当前代码缺失）
3. HP 归零不应触发 game_over（当前代码错误触发）
4. 怪物战斗失败也应扣 Prestige（当前代码不扣）

## 修改文件
- `scripts/game_manager.gd`

## 修改内容

### 1. 新增 prestige_zero_count 变量
- 追踪声望归零次数

### 2. 重写 remove_prestige() 逻辑
- 第一次归零：prestige_zero_count=1 → 触发 _gold_upgrade()
  - 获得 100 金币
  - 声望恢复到 1
- 第二次归零：prestige_zero_count>=2 → game_over(false)

### 3. take_damage() 移除 game_over 触发
- HP 归零不再触发游戏结束
- 游戏结束仅由 Prestige 第二次归零触发

### 4. on_battle_lose() 增加 Prestige 扣除
- 怪物战斗失败也扣 Prestige（max(1, day/2)）
- 与 on_pvp_lose() 保持一致的惩罚机制

### 5. reset_stats() / full_reset() 重置计数
- 两个重置方法都加入 prestige_zero_count = 0

## 验证
- ✅ Godot headless 检查通过（无 ERROR/Parse/Invalid）
- ✅ 逻辑审查通过
- ✅ 无需修改 battle_system.gd
- ✅ 无需修改 main.gd
