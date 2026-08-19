"""Generate the App Icon set for Shanghai Rummy Nights.

Draws an original midnight Shanghai skyline and a three-card heart run, then
exports every size iOS and the App Store require.

Run: python ci_scripts/generate_appicon.py
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Sources" / "ShanghaiRummy" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
OUT.mkdir(parents=True, exist_ok=True)

MASTER = 1024

MIDNIGHT = (10, 13, 35)
PLUM = (42, 19, 52)
CREAM = (255, 246, 225)
GOLD = (247, 174, 75)
ROSE = (242, 56, 103)
SHADOW = (3, 5, 18)


def load_font(size: int) -> ImageFont.ImageFont:
    for name in (
        "arialbd.ttf",
        "Arial Bold.ttf",
        "DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def lerp_color(
    start: tuple[int, int, int],
    end: tuple[int, int, int],
    amount: float,
) -> tuple[int, int, int]:
    return tuple(
        round(start[index] + (end[index] - start[index]) * amount)
        for index in range(3)
    )


def add_glow(
    image: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    opacity: int,
    blur: int,
) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x, y = center
    draw.ellipse(
        (x - radius, y - radius, x + radius, y + radius),
        fill=(*color, opacity),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    image.alpha_composite(layer)


def draw_skyline(image: Image.Image) -> None:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    buildings = [
        (24, 610, 118, 220),
        (128, 520, 118, 310),
        (236, 575, 92, 255),
        (316, 465, 122, 365),
        (428, 555, 86, 275),
        (610, 510, 110, 320),
        (708, 570, 104, 260),
        (802, 475, 116, 355),
        (905, 590, 92, 240),
    ]
    for index, (x, y, width, height) in enumerate(buildings):
        bottom = min(MASTER, y + height)
        fill = (20 + index % 3 * 3, 22, 48 + index % 2 * 7, 245)
        draw.rounded_rectangle(
            (x, y, x + width, bottom),
            radius=7,
            fill=fill,
            outline=(100, 78, 128, 105),
            width=3,
        )
        if index in (1, 3, 7):
            draw.polygon(
                (
                    (x + width * 0.35, y),
                    (x + width * 0.5, y - 35),
                    (x + width * 0.65, y),
                ),
                fill=(31, 25, 58, 245),
            )
        for window_y in range(y + 38, bottom - 20, 52):
            for window_x in range(x + 22, x + width - 14, 34):
                if (window_x + window_y + index) % 4:
                    draw.rounded_rectangle(
                        (
                            window_x,
                            window_y,
                            window_x + 12,
                            window_y + 6,
                        ),
                        radius=3,
                        fill=(*GOLD, 150),
                    )

    # The twin-sphere tower makes the city identifiable without tiny text.
    tower_x = MASTER // 2
    draw.line(
        (tower_x, 122, tower_x, 638),
        fill=(*GOLD, 235),
        width=14,
    )
    draw.line(
        (tower_x, 148, tower_x, 638),
        fill=(*ROSE, 245),
        width=6,
    )
    draw.polygon(
        (
            (tower_x - 18, 122),
            (tower_x, 54),
            (tower_x + 18, 122),
        ),
        fill=(*GOLD, 245),
    )
    for y, radius in ((268, 54), (424, 78)):
        draw.ellipse(
            (
                tower_x - radius,
                y - radius,
                tower_x + radius,
                y + radius,
            ),
            fill=(*ROSE, 245),
            outline=(*GOLD, 255),
            width=12,
        )
        draw.ellipse(
            (
                tower_x - radius * 0.34,
                y - radius * 0.45,
                tower_x - radius * 0.02,
                y - radius * 0.13,
            ),
            fill=(*CREAM, 155),
        )
    draw.line(
        (tower_x - 64, 486, tower_x - 112, 650),
        fill=(*GOLD, 210),
        width=12,
    )
    draw.line(
        (tower_x + 64, 486, tower_x + 112, 650),
        fill=(*GOLD, 210),
        width=12,
    )

    image.alpha_composite(layer)


def make_card(
    rank: str,
    angle: float,
    prominent: bool,
    corner: str = "left",
) -> Image.Image:
    width, height = (330, 454) if prominent else (300, 420)
    margin = 42
    canvas = Image.new(
        "RGBA",
        (width + margin * 2, height + margin * 2),
        (0, 0, 0, 0),
    )

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            margin + 10,
            margin + 22,
            margin + width + 10,
            margin + height + 22,
        ),
        radius=46,
        fill=(*SHADOW, 190),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas = Image.alpha_composite(canvas, shadow)

    draw = ImageDraw.Draw(canvas)
    card_bounds = (
        margin,
        margin,
        margin + width,
        margin + height,
    )
    draw.rounded_rectangle(
        card_bounds,
        radius=46,
        fill=(*CREAM, 255),
        outline=(*GOLD, 255),
        width=7,
    )

    corner_font = load_font(74 if prominent else 66)
    heart_font = load_font(56 if prominent else 48)
    center_rank_font = load_font(164 if prominent else 138)
    center_heart_font = load_font(118 if prominent else 96)
    rank_box = draw.textbbox((0, 0), rank, font=corner_font)
    heart_box = draw.textbbox((0, 0), "\u2665", font=heart_font)
    if corner == "right":
        x = margin + width - 30 - (rank_box[2] - rank_box[0])
        heart_x = margin + width - 26 - (heart_box[2] - heart_box[0])
    else:
        x = margin + 30
        heart_x = x + 4
    draw.text((x, margin + 18), rank, font=corner_font, fill=ROSE)
    draw.text((heart_x, margin + 89), "\u2665", font=heart_font, fill=ROSE)

    rank_box = draw.textbbox((0, 0), rank, font=center_rank_font)
    rank_width = rank_box[2] - rank_box[0]
    rank_height = rank_box[3] - rank_box[1]
    rank_y = margin + height * 0.34 - rank_height / 2
    draw.text(
        (margin + (width - rank_width) / 2, rank_y),
        rank,
        font=center_rank_font,
        fill=ROSE,
    )
    center_heart_box = draw.textbbox((0, 0), "\u2665", font=center_heart_font)
    heart_width = center_heart_box[2] - center_heart_box[0]
    draw.text(
        (
            margin + (width - heart_width) / 2,
            margin + height * 0.58,
        ),
        "\u2665",
        font=center_heart_font,
        fill=ROSE,
    )

    return canvas.rotate(
        angle,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )


def paste_centered(
    destination: Image.Image,
    source: Image.Image,
    center: tuple[int, int],
) -> None:
    destination.alpha_composite(
        source,
        (
            round(center[0] - source.width / 2),
            round(center[1] - source.height / 2),
        ),
    )


def draw_master() -> Image.Image:
    background = Image.new("RGB", (MASTER, MASTER), MIDNIGHT)
    draw = ImageDraw.Draw(background)
    for y in range(MASTER):
        amount = math.pow(y / (MASTER - 1), 1.32)
        draw.line(
            (0, y, MASTER, y),
            fill=lerp_color(MIDNIGHT, PLUM, amount),
        )
    image = background.convert("RGBA")

    add_glow(image, (512, 330), 180, GOLD, 105, 86)
    add_glow(image, (700, 700), 290, ROSE, 70, 135)

    star_layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    stars = (
        (92, 145, 3),
        (172, 264, 2),
        (262, 112, 2),
        (350, 208, 3),
        (690, 132, 2),
        (772, 250, 3),
        (904, 164, 2),
        (844, 350, 2),
        (128, 396, 2),
        (932, 432, 3),
    )
    star_draw = ImageDraw.Draw(star_layer)
    for x, y, radius in stars:
        star_draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=(255, 222, 151, 180),
        )
    image.alpha_composite(star_layer)

    draw_skyline(image)

    river = Image.new("RGBA", image.size, (0, 0, 0, 0))
    river_draw = ImageDraw.Draw(river)
    river_draw.rectangle((0, 650, MASTER, MASTER), fill=(5, 8, 25, 205))
    for index, y in enumerate(range(680, 1010, 48)):
        inset = 34 + index * 11
        color = GOLD if index % 2 == 0 else ROSE
        river_draw.rounded_rectangle(
            (inset, y, MASTER - inset, y + 5),
            radius=3,
            fill=(*color, 76),
        )
    image.alpha_composite(river)

    paste_centered(image, make_card("3", -17, False), (350, 775))
    paste_centered(image, make_card("5", 17, False, corner="right"), (674, 775))
    paste_centered(image, make_card("4", 0, True), (512, 732))

    frame = Image.new("RGBA", image.size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        (24, 24, MASTER - 24, MASTER - 24),
        radius=128,
        outline=(*GOLD, 215),
        width=6,
    )
    image.alpha_composite(frame)
    return image.convert("RGB")


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
