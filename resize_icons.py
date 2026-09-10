import os
from PIL import Image

base_dir = r"c:\Users\DELL\Downloads\Trading Robots details\mobile_app"
src_logo = os.path.join(base_dir, "assets", "images", "logo.png")

if not os.path.exists(src_logo):
    src_logo = r"C:\Users\DELL\.gemini\antigravity-ide\brain\232544a3-f6b7-4a4c-abd2-8d384864ddf5\deriv_bot_logo_1789000096081.jpg"

img = Image.open(src_logo)

# Android mipmap targets
android_res = {
    "mipmap-mdpi": (48, 48),
    "mipmap-hdpi": (72, 72),
    "mipmap-xhdpi": (96, 96),
    "mipmap-xxhdpi": (144, 144),
    "mipmap-xxxhdpi": (192, 192),
}

android_dir = os.path.join(base_dir, "android", "app", "src", "main", "res")
for folder, size in android_res.items():
    target_folder = os.path.join(android_dir, folder)
    os.makedirs(target_folder, exist_ok=True)
    target_path = os.path.join(target_folder, "ic_launcher.png")
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(target_path, "PNG")
    print(f"Generated Android icon: {target_path} ({size[0]}x{size[1]})")

# Web targets
web_res = {
    os.path.join(base_dir, "web", "favicon.png"): (48, 48),
    os.path.join(base_dir, "web", "icons", "Icon-192.png"): (192, 192),
    os.path.join(base_dir, "web", "icons", "Icon-512.png"): (512, 512),
    os.path.join(base_dir, "web", "icons", "Icon-maskable-192.png"): (192, 192),
    os.path.join(base_dir, "web", "icons", "Icon-maskable-512.png"): (512, 512),
}

for path, size in web_res.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(path, "PNG")
    print(f"Generated Web icon: {path} ({size[0]}x{size[1]})")

print("All app icons successfully replaced with custom logo!")
