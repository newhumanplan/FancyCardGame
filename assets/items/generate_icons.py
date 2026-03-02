#!/usr/bin/env python3
"""
生成游戏物品图标 - 像素风格
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/items/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"  # 使用已缓存的模型

# 物品配置
ITEMS = [
    {
        "name": "iron_sword",
        "prompt": "pixel art game icon, iron sword, 64x64, transparent background, item icon, simple design, fantasy weapon, white background",
        "negative": "blurry, complex, 3d render, realistic, shading, shadows"
    },
    {
        "name": "staff", 
        "prompt": "pixel art game icon, magic staff, 64x64, transparent background, fantasy, glowing gem, simple design, white background",
        "negative": "blurry, complex, 3d render, realistic, shading, shadows"
    },
    {
        "name": "dagger",
        "prompt": "pixel art game icon, dagger, 64x64, transparent background, fantasy weapon, simple design, white background",
        "negative": "blurry, complex, 3d render, realistic, shading, shadows"
    }
]

def make_transparent(img, bg_color=(255, 255, 255), tolerance=30):
    """将白色背景转为透明"""
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    for item in datas:
        # 检查是否接近白色
        if abs(item[0] - bg_color[0]) <= tolerance and \
           abs(item[1] - bg_color[1]) <= tolerance and \
           abs(item[2] - bg_color[2]) <= tolerance:
            new_data.append((255, 255, 255, 0))  # 透明
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

def main():
    print("加载 Stable Diffusion 模型...")
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32
    )
    
    # 使用 MPS (Mac) 或 CPU
    if torch.backends.mps.is_available():
        pipe = pipe.to("mps")
        print("使用 MPS 加速")
    else:
        print("使用 CPU")
    
    # 生成每个图标
    for item in ITEMS:
        print(f"\n生成 {item['name']}...")
        
        # 生成图像 (生成更大尺寸再缩小，效果更好)
        image = pipe(
            prompt=item["prompt"],
            negative_prompt=item["negative"],
            num_inference_steps=20,
            guidance_scale=7.5,
            width=512,
            height=512
        ).images[0]
        
        # 缩小到 64x64 (使用最近邻插值保持像素感)
        image = image.resize((64, 64), Image.NEAREST)
        
        # 去除背景
        image = make_transparent(image)
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{item['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n完成！生成了 3 个图标")

if __name__ == "__main__":
    main()
