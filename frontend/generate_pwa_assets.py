import os
from PIL import Image, ImageDraw

def create_health_icon(size):
    # Base image with transparent background for icons or filled for solid icons
    img = Image.new("RGBA", (size, size), (15, 23, 42, 255)) # #0F172A background
    draw = ImageDraw.Draw(img)
    
    # Draw a stylized heart-beat / health symbol in the center
    # Let's draw a nice rounded cross or heart shape
    padding = size * 0.2
    
    # We will draw a heart and a heartbeat line
    # For a heartbeat cross:
    # Vertical bar
    draw.rounded_rectangle(
        [size * 0.42, padding, size * 0.58, size - padding],
        radius=size * 0.05,
        fill=(20, 184, 166, 255) # Teal #14B8A6
    )
    # Horizontal bar
    draw.rounded_rectangle(
        [padding, size * 0.42, size - padding, size * 0.58],
        radius=size * 0.05,
        fill=(20, 184, 166, 255)
    )
    
    # Draw a little white heart/cross overlay
    draw.rounded_rectangle(
        [size * 0.47, size * 0.35, size * 0.53, size * 0.65],
        radius=size * 0.02,
        fill=(255, 255, 255, 255)
    )
    draw.rounded_rectangle(
        [size * 0.35, size * 0.47, size * 0.65, size * 0.53],
        radius=size * 0.02,
        fill=(255, 255, 255, 255)
    )
    
    return img

def create_splash_screen(width, height):
    # Solid background
    img = Image.new("RGBA", (width, height), (15, 23, 42, 255))
    draw = ImageDraw.Draw(img)
    
    # Draw logo in the center
    logo_size = min(width, height) // 4
    logo = create_health_icon(logo_size)
    
    # Paste logo in center
    x = (width - logo_size) // 2
    y = (height - logo_size) // 2
    img.paste(logo, (x, y), logo)
    
    return img

def main():
    public_dir = os.path.join(os.path.dirname(__file__), "public")
    os.makedirs(public_dir, exist_ok=True)
    
    print("Generating PWA assets in:", public_dir)
    
    # Generate favicon.ico (standard sizes)
    fav = create_health_icon(32)
    fav.save(os.path.join(public_dir, "favicon.ico"), format="ICO")
    print("Saved favicon.ico")
    
    # Generate PWA PNG icons
    sizes = {
        "pwa-192x192.png": 192,
        "pwa-512x512.png": 512,
        "logo192.png": 192,
        "logo512.png": 512,
        "apple-touch-icon.png": 180
    }
    
    for filename, size in sizes.items():
        img = create_health_icon(size)
        img.save(os.path.join(public_dir, filename), format="PNG")
        print(f"Saved {filename} ({size}x{size})")
        
    # Generate Splash Screen
    splash = create_splash_screen(2048, 2732)
    splash.save(os.path.join(public_dir, "splash-screen.png"), format="PNG")
    print("Saved splash-screen.png (2048x2732)")
    
    # Copy favicon.svg to masked-icon.svg if favicon.svg exists
    fav_svg = os.path.join(public_dir, "favicon.svg")
    masked_svg = os.path.join(public_dir, "masked-icon.svg")
    if os.path.exists(fav_svg):
        with open(fav_svg, 'r') as f:
            svg_content = f.read()
        with open(masked_svg, 'w') as f:
            f.write(svg_content)
        print("Copied favicon.svg to masked-icon.svg")
        
    print("All PWA assets generated successfully!")

if __name__ == "__main__":
    main()
