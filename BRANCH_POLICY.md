# FancyCardGame 分支规范

## 分支策略：GitHub Flow（轻量级）

主分支 `main` 始终保持可发布状态，所有开发在功能分支上进行，通过 PR 合并。

---

## 分支命名规范

| 类型 | 前缀 | 示例 | 说明 |
|------|------|------|------|
| 功能 | `feat/` | `feat/shop-system` | 新功能开发 |
| 修复 | `fix/` | `fix/backpack-drag` | Bug 修复 |
| 优化 | `refactor/` | `refactor/battle-system` | 代码重构/优化 |
| 测试 | `test/` | `test/endgame-flow` | 测试相关 |
| 紧急 | `hotfix/` | `hotfix/crash-on-start` | 线上紧急修复 |
| Agent | `agent/` | `agent/coder/shop-enhance` | AI Agent 专用分支 |

### 命名格式
```
<前缀>/<简要描述>
```

- 使用英文小写
- 用连字符 `-` 分隔单词
- 描述不超过 3 个词，简洁明了

---

## Agent 分支约定

由于本项目由多个 AI Agent 协作开发，各 Agent 创建分支时必须带 agent 前缀：

| Agent | 分支示例 |
|-------|---------|
| Main | `feat/setup-branch-policy` |
| Planner | `agent/planner/event-system-fill` |
| Coder(OC) | `agent/coder/battle-enhance` |
| Codex | `agent/codex/backpack-optimization` |
| Artist | `agent/artist/battle-visual` |

---

## 工作流

### 1. 创建功能分支
```bash
git checkout main
git pull origin main
git checkout -b feat/your-feature
```

### 2. 开发完成后提交
```bash
git add .
git commit -m "feat: 简要描述更改"
```

### 3. 推送并创建 PR
```bash
git push origin feat/your-feature
# 然后在 GitHub 上创建 Pull Request
```

### 4. Code Review 后合并到 main
- 至少 1 个 reviewer 批准
- CI 通过（如有）
- 合并后删除功能分支

---

## Commit Message 规范

格式：`<类型>: <简要描述>`

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `refactor` | 重构（不改变行为） |
| `perf` | 性能优化 |
| `style` | 代码格式（不影响逻辑） |
| `docs` | 文档更新 |
| `test` | 测试相关 |
| `chore` | 构建/工具/杂项 |
| `ai` | AI Agent 生成/修改的代码 |

示例：
```
feat: add shop buy/sell functionality
fix: resolve backpack drag-and-drop crash
ai: implement battle visual effects (agent/coder)
```

---

## 禁止事项

- ❌ 禁止直接向 `main` 分支 push（使用 PR）
- ❌ 禁止在功能分支上 rebase main（使用 merge）
- ❌ 禁止分支命名使用中文或空格
- ❌ 禁止一个 PR 包含多个不相关的功能

---

*最后更新：2026-04-07*
