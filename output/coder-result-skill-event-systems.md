# 技术翻译：技能系统(T1) + 事件系统补全(T2)

## 日期：2026-04-09
## 执行方式：直接修改（Codex 不可用）

---

## T1：技能系统实现

### 策划分析
- 策划文档明确："技能是英雄的被动能力"
- 只有被动技能，无主动释放，不需要 MP
- 9种效果类型 × 4级品质 = 灵活配置
- 技能通过 JSON 配置，支持 from_dict 加载

### 产出文件
| 文件 | 操作 | 说明 |
|------|------|------|
| scripts/data/skill_data.gd | 重构 | Quality/EffectType 枚举 + effect_values + from_dict |
| scripts/data/skill_manager.gd | 新建 | 装备/卸下/效果汇总 |
| scripts/data/skill_effects.gd | 新建 | 静态方法：apply_passive_skills/get_effects_summary |
| scripts/data/skills_config.json | 新建 | 8个示例技能配置 |

## T2：事件系统补全

### 现状分析
- 所有事件逻辑硬编码在 main.gd（~400行）
- 12个随机事件 match-case 散落各处
- 无独立模块，难以维护和扩展

### 改动方案
- 提取事件逻辑到 EventManager（extends RefCounted）
- main.gd 通过 EventManager 生成选项和执行效果
- 事件定义数据化（ID/名称/图标/权重）

### 产出文件
| 文件 | 操作 | 说明 |
|------|------|------|
| scripts/data/event_manager.gd | 新建 | 事件选项生成 + 12个随机事件效果执行 |
| scripts/data/game_event.gd | 新建 | GameEvent 数据类（未来扩展用） |
| scripts/main.gd | 修改 | 用 EventManager 替换硬编码，减少~100行 |

## 状态
- [x] T1 技能系统 ✅
- [x] T2 事件系统补全 ✅
- [x] Godot headless 验证通过 ✅
- [ ] 待 commit
