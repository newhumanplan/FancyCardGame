#!/usr/bin/env python3
"""
生成简单关卡背景 - 程序化生成
作为占位符使用
"""
from PIL import Image, ImageDraw
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/art/backgrounds/")

# 背景配置
BACKGROUNDS = [
    {
        "name": "stage_1_bg",
        "title": "Forest Entrance",
        "colors": ["#1a472a", "#2d5a3f", "#3a7d52"]  # 深绿到浅绿
    },
    {
        "name": "stage_2_bg",
        "title": "Deep Forest", 
        "colors": ["#0d2818", "#1a4d2e", "#266e42"]  # 更深的绿色
    },
    {
        "name": "stage_3_bg",
        "title": "Abandoned Village",
        "colors": ["#3d3d3d", "#5a5a5a", "#6b6b6b"]  # 灰色调
    },
    {
        "name": "stage_4_bg",
        "title": "Dungeon Entrance",
        "colors": ["#1a1a2e", "#2d2d4a", "#3d3d5c"]  # 深蓝紫色
    },
    {
        "name": "stage_5_bg",
        "title": "Boss Room",
        "colors": ["#4a1a1a", "#6e2d2d", "#8c3d3d"]  # 深红色
    }
]

def create_gradient_background(colors, width=512, height=384):
    """创建渐变背景"""
    img = Image.new('RGB', (width, height), colors[0])
    draw = ImageDraw.Draw(img)
    
    # 绘制简单的渐变效果
    num_strips = 20
    strip_height = height // num_strips
    
    for i in range(num_strips):
        # 计算渐变颜色
        ratio = i / num_strips
        c1 = tuple(int(colors[0][j:j+2], 16) for j in (1, 3, 5))
        c2 = tuple(int(colors[1][j:j+2], 16) for j in (1, 3, 5))
        c3 = tuple(int(colors[2][j:j+2], 16) for j in (1, 3, 5))
        
        # 混合颜色
        if i < num_strips // 2:
            r = int(c1[0] + (c2[0] - c1[0]) * (i / (num_strips // 2)))
            g = int(c1[1] + (c2[1] - c1[1]) * (i / (num_strips // 2)))
            b = int(c1[2] + (c2[2] - c1[2]) * (i / (num_strips // 2)))
        else:
            r = int(c2[0] + (c3[0] - c2[0]) * ((i - num_strips // 2) / (num_strips // 2)))
            g = int(c2[1] + (c3[1] - c2[1]) * ((i - num_strips // 2) / (num_strips // 2)))
            b = int(c2[2] + (c3[2] - c2[2]) * ((i - num_strips // 2) / (num_strips // 2)))
        
        color = (r, g, b)
        
        # 绘制横条
        y1 = i * strip_height
        y2 = min((i + 1) * strip_height, height)
        draw.rectangle([0, y1, width, y2], fill=color)
    
    return img

def main():
    print("=" * 50)
    print("生成简单关卡背景（程序化）")
    print("=" * 50)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for bg in BACKGROUNDS:
        print(f"\n生成 {bg['name']}...")
        
        # 创建背景
        image = create_gradient_background(bg['colors'])
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{bg['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(BACKGROUNDS)} 个关卡背景")
    print("=" * 50)

if __name__ == "__main__":
    main()
