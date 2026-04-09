# 技术翻译：技能系统实现（T1）

## 日期：2026-04-09
## 派发目标：Codex (sessions_spawn, run模式)
## 任务ID：0221fb3c

## 策划文档分析

### 核心理解
- **技能全是被动技能**（策划原文："技能是英雄的被动能力"）
- **无主动释放，不需要 MP**
- 效果分类：Crit/Shield/Burn/Poison/Freeze/Haste/Charge/Health/Cooldown（9种）
- 四级品质：Bronze/Silver/Gold/Diamond，效果值按品质递增
- 技能通过 JSON 配置，支持 from_dict 加载
- 多同类技能效果可叠加
- 技能来源：升级时从技能商人处选择、事件奖励

### 策划细节
- 文档来源：`fcg-sheet-技能系统.json`
- Alpha 目标：技能可选择并生效
- 技能数据：ID/名称/品质/类型标签/效果数值(4级)/所属英雄

## 改动清单

### 1. 重构 `scripts/data/skill_data.gd`
- 移除旧枚举（ATTACK/BUFF/DEBUFF/HEAL）
- 新增 Quality 枚举（BRONZE/SILVER/GOLD/DIAMOND）
- 新增 EffectType 枚举（9种效果类型）
- 新增 effect_values 数组（按品质递增）
- 新增 from_dict() 静态方法（JSON 加载）
- 新增 get_effect_value()（按当前品质取值）

### 2. 新建 `scripts/data/skill_manager.gd`
- extends RefCounted（纯逻辑，无节点）
- 装备/卸下技能
- get_total_effect() 按类型汇总效果值
- 按类型查询技能

### 3. 新建 `scripts/data/skill_effects.gd`
- 纯静态方法（工具类）
- apply_passive_skills() 将技能效果应用到英雄
- get_effects_summary() 生成效果摘要文本

### 4. 新建 `scripts/data/skills_config.json`
- 8个示例技能配置（Deadly Eye, Keen Eye, Toughness, Large Appetites, Quick Defenses, Fiery, Improved Toxins, Initial Chill）

## ⚠️ 重要设计决策
- PM 说"支持主动技能和被动技能"，但策划文档明确说"技能是英雄的被动能力"，**按策划文档为准**，只做被动
- 暂不修改 hero_data.gd（已有 `skills: Array[SkillData]` 字段，兼容）
- 暂不修改 battle_system.gd（后续集成任务）

## 修改文件
- scripts/data/skill_data.gd（完全替换）
- scripts/data/skill_manager.gd（新建）
- scripts/data/skill_effects.gd（新建）
- scripts/data/skills_config.json（新建）

## 状态
- [x] 技术翻译完成
- [ ] Codex 执行中
- [ ] 运行验证待做
