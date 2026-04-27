# 商店系统策划案

更新时间：2026-04-25

根目录 `GAME_RULES.md`、`DATA_MODEL.md`、`ARCHITECTURE.md` 是商店和经济的权威规则。

## 经济基准

- 起始 gold：15。
- 起始 income：7。
- 每个 Day/Hour 的金币奖励、售价和刷新成本都应围绕这个量级设计。
- 不使用 100-500 gold 的大数值经济，除非明确切换到另一个 demo 经济比例。

## Hour 中的选项

Hour 0/1/3/4 不一定总是同一个商店，应从以下 option 中生成：

- item vendor
- skill trainer/vendor
- free reward
- special event
- service vendor：upgrade、enchant、heal、income 等

玩家选择 1 个 option 后进入对应 UI 或直接结算奖励。

当前 demo 先实现最小真实子集：

- 每个构筑 Hour 生成 1 个 item vendor 和 2 个真实 Day 1 event。
- 不再使用 `treasure` / `camp` 这类泛用占位事件；奖励、休息、服务商人必须以真实事件或真实 vendor 数据进入池子。
- 真实事件池见 `docs/planning/07-day1-real-content.md`。

## Item Vendor

- 展示 3-5 个物品。
- 物品来自 hero pool、tag pool、tier pool。
- 支持刷新。
- 支持锁定。
- 支持查看详情。
- 支持购买后放入 stash 或 board。
- 购买得到的道具先进入 Board 的第一个可用连续槽位；玩家可通过拖拽在 Board / Stash 间整理。
- UI 必须使用 `docs/planning/ui-layout-reference.md` 的商人布局：商人头像在顶部中心，
  商品货架位于玩家 Board 上方，底部 HUD 和钱包常驻。

## Skill Trainer

- 展示 2-3 个 skill。
- 可以按 tier、tag、hero_id 筛选。
- 购买后加入玩家 skill 集合，默认生效。
- 不进入固定技能槽。

## Free Reward

用于稳定节奏，避免玩家在烂商店中完全空过：

- +gold
- +XP
- +Max Health
- +Income
- random small item
- reroll token

## 价格与出售

P0 建议：

| Tier | Small | Medium | Large |
| --- | --- | --- | --- |
| Bronze | 3-5 | 5-7 | 7-9 |
| Silver | 6-8 | 8-10 | 10-12 |
| Gold | 9-12 | 12-15 | 15-18 |
| Diamond | 14-18 | 18-22 | 22-26 |

- 出售基于 item value，而不是原价硬砍。
- 普通物品可按 50% 左右出售。
- 特殊经济物品可以有独立 sell effect。

## 刷新和锁定

- Bronze vendor 早期刷新成本应低。
- 每个商店可以有 1 次免费刷新，视设计而定。
- 锁定物品不随刷新消失。
- 进入新 Hour 后，未锁定商品刷新。

## 当前实现差距

当前商店已有购买、刷新、锁定等雏形，但经济数值和 skill trainer / free option /
income 体系还需要统一。后续任务应让商店由 EventOption 驱动，而不是每个 Hour
硬跳同一个 UI。

当前 `ShopUI` 仍偏普通弹窗式商店。后续应迁移为 `MerchantStateView`，不要继续扩展
全屏 `ShopPanel`。
