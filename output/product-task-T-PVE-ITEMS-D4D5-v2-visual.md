# T-PVE-ITEMS-D4D5-v2 视觉验收任务

## 基本信息
- **task_id**: T-PVE-ITEMS-D4D5-v2
- **commit**: 551ab49
- **skill**: fancycardgame-visual-acceptance
- **验收方式**: 必须使用 fancycardgame-visual-acceptance skill，通过 Godot MCP 截图 + Minimax 视觉识别验证
- **不接受**: 纯代码审查/grep 验证

## 验收标准

### C1: P0-1 旧UI节点已移除
- **要求**: main.tscn 中无 StatsPanel/PrestigeContainer 节点
- **验证**: Godot MCP 截图，scene tree 检查 + HeroBar 层截图无重叠 HP 条
- **screenshot_required**: true

### C2: P0-2 商店横排5卡 + 关闭按钮可见
- **要求**: 打开商店，5张卡牌横排显示，关闭按钮在可见区域
- **验证**: Godot MCP 截图商店界面
- **screenshot_required**: true

### C3: P1 HeroBar 包含头像 + 3被动技能图标
- **要求**: HeroBar 层有 HeroAvatar TextureRect + 3个 Passive 图标
- **验证**: Godot MCP 截图 HeroBar 层
- **screenshot_required**: true

### C4: 三层布局结构正确
- **要求**: TopZone Y:0-45%, ItemBar Y:45-80%, HeroBar Y:80-100%
- **验证**: 任意场景截图确认三层分区
- **screenshot_required**: true

## 输出要求

1. **截图保存到**: `~/Projects/FancyCardGame/screenshots/acceptance/T-PVE-ITEMS-D4D5-v2/`
2. **验收报告**: 写入 `.codex-status/T-PVE-ITEMS_acceptance.json`
3. **每个 criterion 必须有 screenshot 路径（非 null）**
4. **verdict**: pass / fail

## 流程

1. 使用 fancycardgame-visual-acceptance skill
2. 启动 Godot MCP 截图
3. 用 Minimax 分析每张截图
4. 每项 criterion 记录 pass/fail + screenshot 路径
5. 更新 `.codex-status/T-PVE-ITEMS_acceptance.json`
