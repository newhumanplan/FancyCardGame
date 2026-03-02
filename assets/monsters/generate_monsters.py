#!/usr/bin/env python3
"""
生成怪物图标 - 256x256 PNG
风格参考：《炉石传说》、《杀戮尖塔》
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/monsters/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# 怪物配置
MONSTERS = [
    {
        "name": "slime",
        "prompt": "fantasy game monster, slime creature, cute, blob shape, green color, round, simple design, transparent background, card game art style, 256x256, white background, clean illustration, cartoon style",
        "negative": "low quality, blurry, complex background, text, watermark, scary, horror, dark"
    },
    {
        "name": "goblin",
        "prompt": "fantasy game monster, goblin, green skin, cunning expression, crude weapon, evil, sneaky, transparent background, card game art style, 256x256, white background, detailed illustration",
        "negative": "low quality, blurry, complex background, text, watermark, cute, friendly"
    },
    {
        "name": "skeleton",
        "prompt": "fantasy game monster, skeleton warrior, holding bone shield, old armor, spooky, undead, transparent background, card game art style, 256x256, white background, detailed illustration",
        "negative": "low quality, blurry, complex background, text, watermark, colorful, cute"
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
    print("=" * 50)
    print("生成怪物图标")
    print("=" * 50)
    
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
    
    # 生成每个怪物
    for monster in MONSTERS:
        print(f"\n{'=' * 30}")
        print(f"生成 {monster['name'].upper()}...")
        print(f"{'=' * 30}")
        
        # 生成图像 (生成更大尺寸再缩小)
        image = pipe(
            prompt=monster["prompt"],
            negative_prompt=monster["negative"],
            num_inference_steps=25,
            guidance_scale=7.5,
            width=512,
            height=512
        ).images[0]
        
        # 缩小到 256x256
        image = image.resize((256, 256), Image.LANCZOS)
        
        # 去除背景
        image = make_transparent(image)
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{monster['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(MONSTERS)} 个怪物图标")
    print("=" * 50)

if __name__ == "__main__":
    main()
