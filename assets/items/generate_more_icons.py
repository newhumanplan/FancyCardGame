#!/usr/bin/env python3
"""
生成更多游戏物品图标 - 像素风格
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/items/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# 新物品配置
ITEMS = [
    # 护甲类
    {
        "name": "cloth_armor",
        "prompt": "pixel art game icon, cloth armor, robe, 64x64, transparent background, fantasy armor, simple design, light blue cloth, white background",
        "negative": "blurry, complex, 3d render, realistic, heavy armor, metal"
    },
    {
        "name": "leather_armor",
        "prompt": "pixel art game icon, leather armor vest, 64x64, transparent background, fantasy armor, brown leather, simple design, white background",
        "negative": "blurry, complex, 3d render, realistic, metal armor, shiny"
    },
    # 饰品类
    {
        "name": "ring",
        "prompt": "pixel art game icon, golden ring with gem, 64x64, transparent background, fantasy jewelry, simple design, magic ring, white background",
        "negative": "blurry, complex, 3d render, realistic, detailed, shading"
    },
    {
        "name": "amulet",
        "prompt": "pixel art game icon, magic amulet necklace, 64x64, transparent background, fantasy jewelry, glowing pendant, simple design, white background",
        "negative": "blurry, complex, 3d render, realistic, detailed, chain"
    },
    # 消耗品类
    {
        "name": "health_potion",
        "prompt": "pixel art game icon, red health potion bottle, 64x64, transparent background, fantasy item, healing potion, simple design, white background",
        "negative": "blurry, complex, 3d render, realistic, detailed, glass"
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

def main():
    print("加载 Stable Diffusion 模型...")
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32
    )
    
    if torch.backends.mps.is_available():
        pipe = pipe.to("mps")
        print("使用 MPS 加速")
    else:
        print("使用 CPU")
    
    for item in ITEMS:
        print(f"\n生成 {item['name']}...")
        
        image = pipe(
            prompt=item["prompt"],
            negative_prompt=item["negative"],
            num_inference_steps=20,
            guidance_scale=7.5,
            width=512,
            height=512
        ).images[0]
        
        image = image.resize((64, 64), Image.NEAREST)
        image = make_transparent(image)
        
        output_path = os.path.join(OUTPUT_DIR, f"{item['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n完成！生成了 5 个新图标")

if __name__ == "__main__":
    main()
