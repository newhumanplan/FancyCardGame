#!/usr/bin/env python3
"""
生成 Boss 图标 - 512x512 PNG
Phase 6: 最终 Boss
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/art/enemies/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# Boss 配置
BOSSES = [
    {
        "name": "boss_dragon",
        "prompt": "fantasy game boss, giant red dragon, majestic, powerful, breathing fire, epic boss design, transparent background, card game art style, 512x512, white background, detailed illustration, fierce, intimidating, scales, wings spread",
        "negative": "low quality, blurry, complex background, text, watermark, cute, small, multiple dragons"
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
    print("生成 Boss 图标")
    print("=" * 50)
    
    print("\n加载 Stable Diffusion 模型...")
    # 使用 CPU 避免内存问题
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float32
    )
    
    pipe = pipe.to("cpu")
    print("使用 CPU")
    
    # 生成每个 Boss
    for boss in BOSSES:
        print(f"\n{'=' * 30}")
        print(f"生成 {boss['name'].upper()}...")
        print(f"{'=' * 30}")
        
        # 生成图像 (使用较小尺寸以避免内存问题)
        image = pipe(
            prompt=boss["prompt"],
            negative_prompt=boss["negative"],
            num_inference_steps=30,
            guidance_scale=8.0,
            width=512,
            height=512
        ).images[0]
        
        # 去除背景
        image = make_transparent(image)
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{boss['name']}.png")
        image.save(output_path)
        print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(BOSSES)} 个 Boss 图标")
    print("=" * 50)

if __name__ == "__main__":
    main()
