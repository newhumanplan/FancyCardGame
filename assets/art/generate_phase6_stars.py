#!/usr/bin/env python3
"""
生成关卡完成星星图标 - 64x64 PNG
Phase 6: 关卡完成评价
"""
from PIL import Image, ImageDraw
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/art/ui/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# 星星配置
STARS = [
    {
        "name": "star_gold",
        "color": "#FFD700",  # 金色
        "prompt": "game ui icon, gold star, shiny, 3d effect, glowing, achievement star, 64x64, simple design, clean, transparent background, white background",
        "negative": "low quality, blurry, complex, text, watermark, multiple stars, dark"
    },
    {
        "name": "star_silver",
        "color": "#C0C0C0",  # 银色
        "prompt": "game ui icon, silver star, metallic, shiny, 3d effect, achievement star, 64x64, simple design, clean, transparent background, white background",
        "negative": "low quality, blurry, complex, text, watermark, multiple stars, gold, dark"
    },
    {
        "name": "star_bronze",
        "color": "#CD7F32",  # 铜色
        "prompt": "game ui icon, bronze star, metallic, shiny, 3d effect, achievement star, 64x64, simple design, clean, transparent background, white background",
        "negative": "low quality, blurry, complex, text, watermark, multiple stars, gold, silver, dark"
    }
]

def make_transparent(img, bg_color=(255, 255, 255), tolerance=30):
    """将白色背景转为透明"""
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    for item in datas:
        if abs(item[0] - bg_color[0]) <= tolerance and \
           abs(item[1] - bg_color[1]) <= tolerance and \
           abs(item[2] - bg_color[2]) <= tolerance:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

def create_simple_star(color_hex, size=64):
    """创建简单的程序化星星作为备用"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 解析颜色
    color_hex = color_hex.lstrip('#')
    r, g, b = tuple(int(color_hex[i:i+2], 16) for i in (0, 2, 4))
    
    # 绘制五角星
    center = size // 2
    outer_r = size // 2 - 4
    inner_r = outer_r // 2
    
    # 计算星星的5个外点和5个内点
    points = []
    for i in range(10):
        angle = i * 36 - 90  # 从顶部开始
        import math
        rad = math.radians(angle)
        if i % 2 == 0:
            # 外点
            x = center + outer_r * math.cos(rad)
            y = center + outer_r * math.sin(rad)
        else:
            # 内点
            x = center + inner_r * math.cos(rad)
            y = center + inner_r * math.sin(rad)
        points.append((x, y))
    
    # 绘制填充星星
    draw.polygon(points, fill=(r, g, b, 255))
    
    # 添加高光效果
    highlight_points = []
    for i in range(10):
        angle = i * 36 - 90
        import math
        rad = math.radians(angle)
        if i % 2 == 0:
            x = center + (outer_r * 0.7) * math.cos(rad)
            y = center + (outer_r * 0.7) * math.sin(rad)
        else:
            x = center + (inner_r * 0.7) * math.cos(rad)
            y = center + (inner_r * 0.7) * math.sin(rad)
        highlight_points.append((x, y))
    
    # 绘制半透明高光
    highlight_color = (min(255, r + 60), min(255, g + 60), min(255, b + 60), 150)
    draw.polygon(highlight_points, fill=highlight_color)
    
    return img

def main():
    print("=" * 50)
    print("生成关卡完成星星图标")
    print("=" * 50)
    
    # 使用程序化生成（更快，不需要 Stable Diffusion）
    use_sd = False  # 星星图标较简单，使用程序化生成更快

    if use_sd:
        # 延迟导入，只在需要时才导入
        import torch
        from diffusers import StableDiffusionPipeline
        
        print("\n加载 Stable Diffusion 模型...")
        pipe = StableDiffusionPipeline.from_pretrained(
            MODEL_ID,
            torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32
        )
        
        if torch.backends.mps.is_available():
            pipe = pipe.to("mps")
            print("使用 MPS 加速")
        else:
            print("使用 CPU")
        
        # 生成每个星星
        for star in STARS:
            print(f"\n{'=' * 30}")
            print(f"生成 {star['name'].upper()}...")
            print(f"{'=' * 30}")
            
            # 生成图像
            image = pipe(
                prompt=star["prompt"],
                negative_prompt=star["negative"],
                num_inference_steps=25,
                guidance_scale=7.5,
                width=256,
                height=256
            ).images[0]
            
            # 缩小到 64x64
            image = image.resize((64, 64), Image.LANCZOS)
            
            # 去除背景
            image = make_transparent(image)
            
            # 保存
            output_path = os.path.join(OUTPUT_DIR, f"{star['name']}.png")
            image.save(output_path)
            print(f"✓ 已保存: {output_path}")
    else:
        # 使用程序化生成（更快）
        print("\n使用程序化生成星星图标...")
        
        for star in STARS:
            print(f"\n生成 {star['name']}...")
            
            # 创建星星
            image = create_simple_star(star['color'], 64)
            
            # 保存
            output_path = os.path.join(OUTPUT_DIR, f"{star['name']}.png")
            image.save(output_path)
            print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(STARS)} 个星星图标")
    print("=" * 50)

if __name__ == "__main__":
    main()
