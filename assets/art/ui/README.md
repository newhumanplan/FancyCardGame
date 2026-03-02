# Shop UI Assets - Phase 5

Created: 2026-03-03
Author: Artist Agent

## Assets Overview

All assets are PNG format with RGBA color and transparency support.

### Priority 🔴 High

#### 1. coin_icon.png
- **Size:** 32x32 px
- **Description:** Golden coin with shine effect
- **Style:** Simple, clean, recognizable
- **Usage:** Currency display in shop UI

#### 2. shop_bg.png  
- **Size:** 512x512 px
- **Description:** Medieval shop/tent interior
- **Style:** Warm colors (browns/golds), wooden floor, tent canopy with stripes
- **Usage:** Background for shop interface
- **Features:** 
  - Red/gold striped canopy
  - Wooden counter
  - Side curtains
  - Shelf details
  - Decorative barrel

### Priority 🟡 Medium

#### 3. btn_buy.png
- **Size:** 128x48 px
- **Description:** Green button with gold "BUY" text
- **Style:** 3D effect with highlight and shadow
- **Usage:** Purchase items in shop

#### 4. btn_sell.png
- **Size:** 128x48 px
- **Description:** Blue button with silver "SELL" text
- **Style:** 3D effect with highlight and shadow
- **Usage:** Sell items in shop

## Integration Notes for Coder Agent

### Godot Import
```
assets/art/ui/coin_icon.png
assets/art/ui/shop_bg.png
assets/art/ui/btn_buy.png
assets/art/ui/btn_sell.png
```

### Recommended Usage

```gdscript
# Coin icon
$CoinIcon.texture = load("res://assets/art/ui/coin_icon.png")

# Shop background
$ShopBackground.texture = load("res://assets/art/ui/shop_bg.png")

# Buttons
$BuyButton.texture_normal = load("res://assets/art/ui/btn_buy.png")
$SellButton.texture_normal = load("res://assets/art/ui/btn_sell.png")
```

## Design Consistency

- Color palette matches medieval/fantasy theme
- All buttons have similar 3D bevel style
- Text is centered and readable
- Transparent backgrounds for buttons and coin
- Opaque background for shop_bg

## Future Enhancements (Optional)

If needed, we can add:
- Button hover/pressed state variants
- Animated coin (spinning)
- Different shop background variants (night/day)
- Additional decorative elements

## Status

✅ All 4 assets created and saved
✅ Files in correct location: `assets/art/ui/`
⏳ Ready for Godot integration testing
