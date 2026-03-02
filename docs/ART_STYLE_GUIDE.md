# FancyCardGame 美术风格规范

*版本：1.0*
*创建时间：2026-03-03*
*美术设计师：AI Assistant*

---

## 1. 整体风格定位

### 1.1 风格参考
- **参考游戏**：《炉石传说》、《杀戮尖塔》、《暗黑地牢》
- **风格关键词**：卡牌游戏、幻想风格、中世纪奇幻
- **受众年龄**：12+

### 1.2 视觉特征
- **色彩风格**：鲜艳饱和，高对比度
- **画面风格**：半写实 + 卡通渲染
- **氛围**：神秘、冒险、史诗感

---

## 2. 英雄立绘规范

### 2.1 技术规格
| 项目 | 规格 |
|------|------|
| 尺寸 | 512 x 512 px（推荐）/ 1024 x 1024 px（高清） |
| 格式 | PNG（透明背景） |
| 色深 | 32-bit (RGBA) |

### 2.2 构图要求
- **人物位置**：居中偏下，保留头部空间
- **身体比例**：半身像或 3/4 全身像
- **朝向**：向右 30-45 度（战斗姿态）
- **背景**：透明或简单渐变

### 2.3 角色设计要点

#### 战士 (Warrior)
- **色调**：暖色调（红、金、棕）
- **特征**：重型盔甲、大剑、肌肉发达
- **气质**：勇猛、坚毅、可靠
- **参考元素**：中世纪骑士、北欧战士

#### 法师 (Mage)
- **色调**：冷色调（蓝、紫、银）
- **特征**：长袍、法杖、魔法光环
- **气质**：神秘、智慧、优雅
- **参考元素**：奇幻法师、魔法学院

### 2.4 SD Prompt 模板（英雄）

```
正面示例（战士）：
[正向] fantasy game character art, warrior class, heavy armor, holding sword, heroic pose, battle stance, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512

[负向] low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime

正面示例（法师）：
[正向] fantasy game character art, mage class, wizard robes, holding magic staff, magic aura, casting spell, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512

[负向] low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime
```

---

## 3. 物品图标规范

### 3.1 技术规格
| 项目 | 规格 |
|------|------|
| 尺寸 | 128 x 128 px（基础）/ 256 x 256 px（高清） |
| 格式 | PNG（透明背景） |
| 色深 | 32-bit (RGBA) |

### 3.2 构图要求
- **物品位置**：居中，留有边距
- **角度**：45 度俯视或正面
- **光照**：左上光源，轻微阴影
- **背景**：透明

### 3.3 品质颜色编码

| 品质 | 颜色代码 | RGB | 用途 |
|------|----------|-----|------|
| 普通 | #9D9D9D | (157, 157, 157) | 边框、文字 |
| 稀有 | #0070DD | (0, 112, 221) | 边框、文字、光效 |
| 史诗 | #A335EE | (163, 53, 238) | 边框、文字、光效 |
| 传说 | #FF8000 | (255, 128, 0) | 边框、文字、光效 |

### 3.4 物品类型设计要点

#### 武器 (Weapons)
- **特征**：锋利、有光泽、材质明确
- **细节**：符文雕刻、魔法光效（高品质）
- **示例**：剑、法杖、弓

#### 护甲 (Armor)
- **特征**：坚固、层次感、金属质感
- **细节**：纹饰、磨损效果（普通品质）
- **示例**：盾牌、盔甲

#### 饰品 (Accessories)
- **特征**：小巧精致、魔法光芒
- **细节**：宝石、符文
- **示例**：戒指、项链、徽章

### 3.5 SD Prompt 模板（物品）

```
正面示例（铁剑 - 普通）：
[正向] game item icon, iron sword, simple design, metallic texture, fantasy style, transparent background, 128x128, clean lines, item icon art, top-down view, simple lighting

[负向] low quality, blurry, complex background, text, watermark, 3D render

正面示例（火之法杖 - 史诗）：
[正向] game item icon, fire staff, epic quality, magic glowing, fire elemental, ornate design, purple glow border, fantasy style, transparent background, 128x128, clean lines, item icon art, top-down view

[负向] low quality, blurry, complex background, text, watermark, 3D render
```

---

## 4. 怪物立绘规范

### 4.1 技术规格
| 项目 | 规格 |
|------|------|
| 尺寸 | 256 x 256 px（基础）/ 512 x 512 px（高清） |
| 格式 | PNG（透明背景） |
| 色深 | 32-bit (RGBA) |

### 4.2 构图要求
- **怪物位置**：居中，保留周围空间
- **角度**：正面或 3/4 角度
- **姿态**：攻击或威胁姿态
- **背景**：透明

### 4.3 怪物类型设计要点

#### 史莱姆 (Slime)
- **色调**：绿色或蓝色
- **特征**：圆滚滚、半透明、可爱
- **气质**：弱小、无害

#### 哥布林 (Goblin)
- **色调**：绿色皮肤、棕色装备
- **特征**：矮小、狡猾、粗制武器
- **气质**：贪婪、狡诈

#### 骷髅兵 (Skeleton)
- **色调**：灰白、黑色装备
- **特征**：骨骼清晰、破旧盔甲
- **气质**：恐怖、不死

#### 狼 (Wolf)
- **色调**：灰色或黑色毛发
- **特征**：锋利牙齿、凶狠眼神
- **气质**：野性、危险

#### Boss（哥布林首领）
- **色调**：金色装备、红色披风
- **特征**：大型、华丽装备、威严
- **气质**：强大、领袖气质

### 4.4 SD Prompt 模板（怪物）

```
正面示例（史莱姆）：
[正向] fantasy game monster, slime creature, cute, blob shape, green color, simple design, transparent background, card game art style, 256x256, clean illustration

[负向] low quality, blurry, complex background, text, watermark, scary, horror

正面示例（哥布林首领 - Boss）：
[正向] fantasy game boss, goblin chieftain, golden armor, red cape, large size, menacing, epic boss design, transparent background, card game art style, 256x256, detailed illustration

[负向] low quality, blurry, complex background, text, watermark
```

---

## 5. UI元素规范

### 5.1 技术规格
| 项目 | 规格 |
|------|------|
| 尺寸 | 可缩放（推荐 9-slice 或 SVG） |
| 格式 | PNG（位图）/ SVG（矢量） |
| 色深 | 32-bit (RGBA) |

### 5.2 UI 风格
- **风格**：中世纪奇幻风格
- **材质**：羊皮纸、金属、木板
- **边框**：装饰性边框，金色或棕色
- **字体**：衬线字体，如 Cinzel、Crimson Text

### 5.3 UI 色彩方案

| 元素 | 主色 | 辅色 | 说明 |
|------|------|------|------|
| 背景 | #2C1810 | #1A0F0A | 深棕色，羊皮纸质感 |
| 边框 | #8B7355 | #D4AF37 | 棕色 + 金色 |
| 按钮（正常） | #4A3728 | #8B7355 | 棕色系 |
| 按钮（悬停） | #6B5344 | #D4AF37 | 亮棕色 + 金色高亮 |
| 文字 | #F4E4BC | #8B7355 | 米黄色 + 棕色阴影 |

---

## 6. 资产命名规范

### 6.1 文件命名格式
```
[类别]_[子类]_[名称]_[品质].[扩展名]
```

### 6.2 示例
```
hero_warrior_full.png
hero_mage_avatar.png
item_weapon_iron_sword_common.png
item_armor_wood_shield_common.png
item_accessory_power_ring_common.png
monster_slime.png
boss_goblin_chieftain.png
ui_button_normal.png
ui_card_frame_epic.png
```

---

## 7. SD 生成流程

### 7.1 准备工作
1. 确认 SD 服务可用
2. 准备 Prompt 模板
3. 设置生成参数

### 7.2 推荐参数
| 参数 | 推荐值 | 说明 |
|------|--------|------|
| Steps | 30-50 | 高质量生成 |
| CFG Scale | 7-9 | 文本引导强度 |
| Sampler | DPM++ 2M Karras | 推荐采样器 |
| Size | 根据类型选择 | 英雄 512x512，物品 128x128 |
| Seed | -1 | 随机种子 |

### 7.3 后处理
1. **检查**：确认无变形、无多余元素
2. **裁剪**：移除多余空白
3. **优化**：压缩文件大小
4. **命名**：按规范命名文件
5. **存储**：放入对应目录

---

## 8. 质量检查清单

### 8.1 英雄立绘
- [ ] 尺寸正确（512x512 或更高）
- [ ] 透明背景
- [ ] 人物清晰，无变形
- [ ] 色彩饱和，对比度合适
- [ ] 文件命名规范

### 8.2 物品图标
- [ ] 尺寸正确（128x128 或 256x256）
- [ ] 透明背景
- [ ] 物品居中，清晰可辨
- [ ] 品质颜色正确
- [ ] 文件命名规范

### 8.3 怪物立绘
- [ ] 尺寸正确（256x256 或 512x512）
- [ ] 透明背景
- [ ] 怪物清晰，特征明显
- [ ] Boss 尺寸更大、更华丽
- [ ] 文件命名规范

---

## 9. 参考资源

### 9.1 风格参考
- 《炉石传说》卡牌艺术
- 《杀戮尖塔》角色设计
- 《暗黑地牢》怪物设计
- ArtStation: Card Game Art

### 9.2 工具推荐
- SD WebUI: Automatic1111
- Photoshop / GIMP（后处理）
- TinyPNG（压缩优化）

---

*文档维护：美术团队*
*更新频率：每迭代更新*
