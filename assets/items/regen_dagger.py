#!/usr/bin/env python3
"""
重新生成 dagger 图标 - 禁用 safety checker
"""
import torch
from diffusers import StableDiffusionPipeline
from PIL import Image
import os

OUTPUT_DIR = os.path.expanduser("~/Projects/FancyCardGame/assets/items/")
MODEL_ID = "runwayml/stable-diffusion-v1-5"

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
    print("加载 Stable Diffusion 模型（禁用 safety checker）...")
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL_ID,
        torch_dtype=torch.float16 if torch.backends.mps.is_available() else torch.float32,
        safety_checker=None,  # 禁用 safety checker
        requires_safety_checker=False
    )
    
    if torch.backends.mps.is_available():
        pipe = pipe.to("mps")
    
    prompt = "pixel art game icon, small dagger knife, 64x64, white background, fantasy weapon, simple design, item icon"
    negative = "blurry, complex, 3d render, realistic, blood, violence, nsfw"
    
    print("生成 dagger...")
    image = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=20,
        guidance_scale=7.5,
        width=512,
        height=512
    ).images[0]
    
    image = image.resize((64, 64), Image.NEAREST)
    image = make_transparent(image)
    
    output_path = os.path.join(OUTPUT_DIR, "dagger.png")
    image.save(output_path)
    print(f"✓ 已保存: {output_path}")

if __name__ == "__main__":
    main()
