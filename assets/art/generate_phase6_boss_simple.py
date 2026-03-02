#!/usr/bin/env python3
"""
生成简单 Boss 图标 - 程序化生成
作为占位符使用
"""
from PIL import Image, ImageDraw
import os
import math

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/art/enemies/")

def create_dragon_icon(size=256):
    """创建简单的龙图标"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    # 红色身体
    body_color = (180, 30, 30, 255)
    
    # 画一个大圆作为身体
    r = size // 3
    draw.ellipse([center-r, center-r*0.8, center+r, center+r*0.8], fill=body_color)
    
    # 画眼睛
    eye_color = (255, 255, 0, 255)
    eye_r = size // 20
    draw.ellipse([center-r*0.5-eye_r, center-r*0.3-eye_r, center-r*0.5+eye_r, center-r*0.3+eye_r], fill=eye_color)
    draw.ellipse([center+r*0.5-eye_r, center-r*0.3-eye_r, center+r*0.5+eye_r, center-r*0.3+eye_r], fill=eye_color)
    
    # 画翅膀
    wing_color = (150, 25, 25, 255)
    # 左翅膀
    wing_points = [
        (center - r, center),
        (center - r*1.5, center - r*0.5),
        (center - r*1.3, center + r*0.2),
        (center - r*0.8, center + r*0.3)
    ]
    draw.polygon(wing_points, fill=wing_color)
    # 右翅膀
    wing_points = [
        (center + r, center),
        (center + r*1.5, center - r*0.5),
        (center + r*1.3, center + r*0.2),
        (center + r*0.8, center + r*0.3)
    ]
    draw.polygon(wing_points, fill=wing_color)
    
    # 画火焰
    fire_color = (255, 150, 0, 200)
    for i in range(5):
        x = center + (i - 2) * (size // 10)
        h = size // 6 + (i % 2) * (size // 12)
        draw.polygon([
            (x, center + r*0.5),
            (x - size//20, center + r*0.5 + h),
            (x, center + r*0.5 + h - size//10),
            (x + size//20, center + r*0.5 + h)
        ], fill=fire_color)
    
    return img

def main():
    print("=" * 50)
    print("生成 Boss 图标")
    print("=" * 50)
    
    # 确保输出目录存在
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # 创建龙图标
    print(f"\n生成 boss_dragon...")
    icon = create_dragon_icon(256)
    
    # 保存
    output_path = os.path.join(OUTPUT_DIR, "boss_dragon.png")
    icon.save(output_path)
    print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print("完成！")
    print("=" * 50)

if __name__ == "__main__":
    main()
