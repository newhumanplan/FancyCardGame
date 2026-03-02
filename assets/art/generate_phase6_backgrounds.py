#!/usr/bin/env python3
"""
生成关卡背景 - 1024x768 PNG
Phase 6: 多关卡流程
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

# 配置
OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/art/backgrounds/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

# 关卡背景配置
BACKGROUNDS = [
    {
        "name": "stage_1_bg",
        "prompt": "fantasy game background, forest entrance, sunlight through trees, peaceful meadow, path into woods, mystical forest, card game art style, 1024x768, no characters, landscape, detailed digital illustration, semi-realistic style, warm colors",
        "negative": "characters, people, text, watermark, low quality, blurry, dark, horror"
    },
    {
        "name": "stage_2_bg",
        "prompt": "fantasy game background, deep forest, dense trees, shadows, mysterious atmosphere, ancient trees, fireflies, card game art style, 1024x768, no characters, landscape, detailed digital illustration, semi-realistic style, cool colors",
        "negative": "characters, people, text, watermark, low quality, blurry, bright, cheerful"
    },
    {
        "name": "stage_3_bg",
        "prompt": "fantasy game background, abandoned village, ruined houses, overgrown streets, eerie atmosphere, fog, broken fences, card game art style, 1024x768, no characters, landscape, detailed digital illustration, semi-realistic style, muted colors",
        "negative": "characters, people, text, watermark, low quality, blurry, modern, bright"
    },
    {
        "name": "stage_4_bg",
        "prompt": "fantasy game background, dungeon entrance, stone archway, torches, dark stairs descending, ominous, gothic architecture, card game art style, 1024x768, no characters, landscape, detailed digital illustration, semi-realistic style, dark colors",
        "negative": "characters, people, text, watermark, low quality, blurry, bright, colorful"
    },
    {
        "name": "stage_5_bg",
        "prompt": "fantasy game background, boss room, grand throne room, pillars, treasure piles, dragon lair, epic atmosphere, card game art style, 1024x768, no characters, landscape, detailed digital illustration, semi-realistic style, dramatic lighting",
        "negative": "characters, people, text, watermark, low quality, blurry, simple, plain"
    }
]

def main():
    print("=" * 50)
    print("生成关卡背景")
    print("=" * 50)
    
    print("\n加载 Stable Diffusion 模型...")
    # 使用 CPU 避免内存问题
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float32
    )
    
    pipe = pipe.to("cpu")
    print("使用 CPU")
    
    # 生成每个背景
    for bg in BACKGROUNDS:
        print(f"\n{'=' * 30}")
        print(f"生成 {bg['name'].upper()}...")
        print(f"{'=' * 30}")
        
        # 生成图像 (使用更小尺寸以避免内存问题)
        image = pipe(
            prompt=bg["prompt"],
            negative_prompt=bg["negative"],
            num_inference_steps=20,  # 减少步骤
            guidance_scale=7.5,
            width=384,
            height=256
        ).images[0]
        
        # 保存
        output_path = os.path.join(OUTPUT_DIR, f"{bg['name']}.png")
        image.save(output_path, quality=90)
        print(f"✓ 已保存: {output_path}")
    
    print("\n" + "=" * 50)
    print(f"完成！生成了 {len(BACKGROUNDS)} 个关卡背景")
    print("=" * 50)

if __name__ == "__main__":
    main()
