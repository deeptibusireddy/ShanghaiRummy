"""Generate the App Icon set for Shanghai Rummy.

Draws a stylized playing card (K of hearts on green felt) at 1024x1024,
then exports every size iOS + App Store require.

Run: python ci_scripts/generate_appicon.py
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Sources" / "ShanghaiRummy" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)

MASTER = 1024


def draw_master() -> Image.Image:
    img = Image.new("RGB", (MASTER, MASTER), (16, 78, 55))  # deep felt green
    d = ImageDraw.Draw(img)

    # subtle radial-ish vignette by drawing concentric darker rounded rects
    for i in range(30):
        alpha = int(4 + i * 0.6)
        d.rectangle(
            (i * 6, i * 6, MASTER - i * 6, MASTER - i * 6),
            outline=(12, 60, 42, alpha),
            width=1,
        )

    # playing card body — rotated slightly for style
    card_w, card_h = 560, 780
    card = Image.new("RGBA", (card_w + 40, card_h + 40), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    # soft shadow
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((20, 30, 20 + card_w, 30 + card_h), radius=64, fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    card = Image.alpha_composite(card, shadow)
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((20, 20, 20 + card_w, 20 + card_h), radius=64, fill=(252, 250, 244))
    cd.rounded_rectangle(
        (20, 20, 20 + card_w, 20 + card_h),
        radius=64,
        outline=(210, 195, 170),
        width=6,
    )

    # heart shape and letter
    def load_font(size: int) -> ImageFont.ImageFont:
        for name in ("arialbd.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"):
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
        return ImageFont.load_default()

    letter_font = load_font(300)
    heart_font = load_font(220)
    red = (196, 30, 58)

    # Corner K and small heart top-left
    cd.text((60, 40), "K", font=load_font(180), fill=red)
    cd.text((78, 210), "\u2665", font=load_font(120), fill=red)

    # Big centered K
    tw = cd.textlength("K", font=letter_font)
    cd.text(((card.width - tw) / 2, 240), "K", font=letter_font, fill=red)

    # Big heart under the K
    hw = cd.textlength("\u2665", font=heart_font)
    cd.text(((card.width - hw) / 2, 520), "\u2665", font=heart_font, fill=red)

    # bottom-right mirrored corner
    small_letter = load_font(180)
    small_heart = load_font(120)
    lw = cd.textlength("K", font=small_letter)
    hw2 = cd.textlength("\u2665", font=small_heart)
    corner_layer = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ccd = ImageDraw.Draw(corner_layer)
    ccd.text((60, 40), "K", font=small_letter, fill=red)
    ccd.text((78, 210), "\u2665", font=small_heart, fill=red)
    corner_layer = corner_layer.rotate(180, resample=Image.BICUBIC)
    card = Image.alpha_composite(card, corner_layer)

    # rotate the whole card slightly and paste centered
    card = card.rotate(-8, resample=Image.BICUBIC, expand=True)
    px = (MASTER - card.width) // 2
    py = (MASTER - card.height) // 2 + 20
    img.paste(card, (px, py), card)

    return img


# iOS AppIcon required sizes (post-Xcode 14 unified: single 1024 works,
# but including legacy sizes for maximum device compatibility).
SIZES = [
    ("Icon-1024.png", 1024, "ios-marketing", "1x", 1024),
    ("Icon-App-60@3x.png", 180, "iphone", "3x", 60),
    ("Icon-App-60@2x.png", 120, "iphone", "2x", 60),
    ("Icon-App-40@3x.png", 120, "iphone", "3x", 40),
    ("Icon-App-40@2x.png", 80, "iphone", "2x", 40),
    ("Icon-App-29@3x.png", 87, "iphone", "3x", 29),
    ("Icon-App-29@2x.png", 58, "iphone", "2x", 29),
    ("Icon-App-20@3x.png", 60, "iphone", "3x", 20),
    ("Icon-App-20@2x.png", 40, "iphone", "2x", 20),
    ("Icon-App-83.5@2x.png", 167, "ipad", "2x", 83.5),
    ("Icon-App-76@2x.png", 152, "ipad", "2x", 76),
    ("Icon-App-76.png", 76, "ipad", "1x", 76),
    ("Icon-App-40@2x-ipad.png", 80, "ipad", "2x", 40),
    ("Icon-App-40-ipad.png", 40, "ipad", "1x", 40),
    ("Icon-App-29@2x-ipad.png", 58, "ipad", "2x", 29),
    ("Icon-App-29-ipad.png", 29, "ipad", "1x", 29),
    ("Icon-App-20@2x-ipad.png", 40, "ipad", "2x", 20),
    ("Icon-App-20-ipad.png", 20, "ipad", "1x", 20),
]


def main() -> None:
    master = draw_master()
    contents_images = []
    written = set()
    for filename, px, idiom, scale, base in SIZES:
        if filename not in written:
            resized = master.resize((px, px), Image.LANCZOS)
            resized.save(OUT / filename)
            written.add(filename)
        size_str = f"{base:g}x{base:g}"
        contents_images.append(
            {"filename": filename, "idiom": idiom, "scale": scale, "size": size_str}
        )
    contents = {"images": contents_images, "info": {"author": "xcode", "version": 1}}
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2))
    print(f"wrote {len(written)} icons to {OUT}")


if __name__ == "__main__":
    main()
