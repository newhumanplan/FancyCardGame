#!/usr/bin/env python3
"""
生成英雄立绘 - 512x512 PNG
风格参考：《炉石传说》、《杀戮尖塔》
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/heroes/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# 英雄配置
HEROES = [
    {
        "name": "warrior",
        "prompt": "fantasy game character art, warrior class, heavy silver armor, holding giant sword, red cape, muscular, heroic pose, battle stance, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512, white background",
        "negative": "low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime, dark background"
    },
    {
        "name": "mage",
        "prompt": "fantasy game character art, mage class, blue wizard robes, holding glowing magic staff, magic aura, casting spell, mysterious, wise, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512, white background",
        "negative": "low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime, dark background"
    },
    {
        "name": "rogue",
        "prompt": "fantasy game character art, rogue class, black leather armor, holding daggers, purple cloak, agile, sneaky, shadow aura, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512, white background",
        "negative": "low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime, dark background"
    },
    {
        "name": "cleric",
        "prompt": "fantasy game character art, cleric class, white priest robes, holding holy light, golden halo, divine, benevolent, light aura, detailed digital illustration, semi-realistic style, card game art style, dynamic lighting, epic atmosphere, 512x512, white background",
        "negative": "low quality, blurry, deformed, bad anatomy, extra limbs, text, watermark, cartoon, anime, dark background"
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
    print("生成英雄立绘")
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
    
    # 生成每个英雄
    for hero in HEROES:
        print(f"\n{'=' * 30}")
        print(f"生成 {hero['name'].upper()}...")
        print(f"{'=' * 30}")
        
        # 生成图像
        image = pipe(
            prompt=hero["prompt"],
            negative_prompt=hero["negative"],
            num_inference_steps=30,  # 英雄用更多步骤
            guidance_scale=8.0,
            width=512,
            height=512
        ).images[0]
        
        # 去除背景
        image = make_transparent(image)
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{hero['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(HEROES)} 个英雄立绘")
    print("=" * 50)

if __name__ == "__main__":
    main()
