import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
MOBILE_APP = os.path.dirname(ROOT)
LOGO_PATH = os.path.join(MOBILE_APP, "assets", "icons", "SAHAI_Logo_Transparent.png")

if not os.path.exists(LOGO_PATH):
    raise FileNotFoundError(f"Logo not found at {LOGO_PATH}")

logo = Image.open(LOGO_PATH).convert("RGBA")
print(f"Loaded logo: {logo.size}")

# 1. Android Mipmaps
RES_DIR = os.path.join(MOBILE_APP, "android", "app", "src", "main", "res")

MIPMAP_SIZES = {
    "mipmap-mdpi": (48, 108, 96),       # (legacy_icon, adaptive_fg, launch_img)
    "mipmap-hdpi": (72, 162, 144),
    "mipmap-xhdpi": (96, 216, 192),
    "mipmap-xxhdpi": (144, 324, 288),
    "mipmap-xxxhdpi": (192, 432, 384),
}

def create_legacy_icon(size, is_round=False):
    """Creates a crisp icon on white background (rounded rect or circle)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw white background
    if is_round:
        draw.ellipse([0, 0, size - 1, size - 1], fill=(255, 255, 255, 255))
    else:
        radius = int(size * 0.22)
        draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=(255, 255, 255, 255))
    
    # Scale logo into 70% of the plate
    inner_size = int(size * 0.70)
    resized_logo = logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
    offset = (size - inner_size) // 2
    img.alpha_composite(resized_logo, (offset, offset))
    return img

def create_adaptive_foreground(size):
    """Creates transparent foreground with logo centered in 62% safe zone."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner_size = int(size * 0.62)
    resized_logo = logo.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
    offset = (size - inner_size) // 2
    img.alpha_composite(resized_logo, (offset, offset))
    return img

def create_launch_image(size):
    """Creates transparent launch image."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    resized_logo = logo.resize((size, size), Image.Resampling.LANCZOS)
    img.alpha_composite(resized_logo, (0, 0))
    return img

# Generate Android Icons
for folder, (ic_size, fg_size, launch_size) in MIPMAP_SIZES.items():
    folder_path = os.path.join(RES_DIR, folder)
    os.makedirs(folder_path, exist_ok=True)
    
    # Legacy Square / Rounded Rect Icon
    legacy = create_legacy_icon(ic_size, is_round=False)
    legacy.save(os.path.join(folder_path, "ic_launcher.png"), "PNG")
    
    # Round Icon
    round_icon = create_legacy_icon(ic_size, is_round=True)
    round_icon.save(os.path.join(folder_path, "ic_launcher_round.png"), "PNG")
    
    # Adaptive Foreground
    fg = create_adaptive_foreground(fg_size)
    fg.save(os.path.join(folder_path, "ic_launcher_foreground.png"), "PNG")

    # Drawable launch images
    drawable_folder = folder.replace("mipmap-", "drawable-")
    drawable_folder_path = os.path.join(RES_DIR, drawable_folder)
    os.makedirs(drawable_folder_path, exist_ok=True)
    launch_img = create_launch_image(launch_size)
    launch_img.save(os.path.join(drawable_folder_path, "launch_image.png"), "PNG")

# Default drawable launch_image
drawable_default = os.path.join(RES_DIR, "drawable")
os.makedirs(drawable_default, exist_ok=True)
launch_default = create_launch_image(288)
launch_default.save(os.path.join(drawable_default, "launch_image.png"), "PNG")

print("Android icons & launch images generated successfully.")

# 2. iOS AppIcon
IOS_APPICON_DIR = os.path.join(MOBILE_APP, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
if os.path.exists(IOS_APPICON_DIR):
    IOS_SIZES = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, px in IOS_SIZES.items():
        # iOS AppStore requires non-transparent background
        ios_icon = Image.new("RGBA", (px, px), (255, 255, 255, 255))
        inner_px = int(px * 0.76)
        resized_logo = logo.resize((inner_px, inner_px), Image.Resampling.LANCZOS)
        offset = (px - inner_px) // 2
        ios_icon.alpha_composite(resized_logo, (offset, offset))
        # Convert to RGB (no alpha channel for iOS AppIcon per Apple guidelines)
        ios_icon_rgb = ios_icon.convert("RGB")
        ios_icon_rgb.save(os.path.join(IOS_APPICON_DIR, filename), "PNG")
    print("iOS AppIcon set generated successfully.")

# iOS LaunchImages
IOS_LAUNCH_DIR = os.path.join(MOBILE_APP, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
if os.path.exists(IOS_LAUNCH_DIR):
    for filename, px in [("LaunchImage.png", 140), ("LaunchImage@2x.png", 280), ("LaunchImage@3x.png", 420)]:
        li = create_launch_image(px)
        li.save(os.path.join(IOS_LAUNCH_DIR, filename), "PNG")
    print("iOS LaunchImages generated successfully.")

# 3. Web Icons
WEB_DIR = os.path.join(MOBILE_APP, "web")
if os.path.exists(WEB_DIR):
    favicon = create_legacy_icon(32, is_round=True)
    favicon.save(os.path.join(WEB_DIR, "favicon.png"), "PNG")
    
    web_icons_dir = os.path.join(WEB_DIR, "icons")
    os.makedirs(web_icons_dir, exist_ok=True)
    for px in [192, 512]:
        std_icon = create_legacy_icon(px, is_round=True)
        std_icon.save(os.path.join(web_icons_dir, f"Icon-{px}.png"), "PNG")
        maskable = create_adaptive_foreground(px)
        maskable.save(os.path.join(web_icons_dir, f"Icon-maskable-{px}.png"), "PNG")
    print("Web icons generated successfully.")
