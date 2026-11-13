import io
import os
import cairosvg
from PIL import Image

RES_DIR = os.path.join("android", "app", "src", "main", "res")

FOREGROUND_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="coverGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#2A2C36"/>
      <stop offset="55%" stop-color="#111217"/>
      <stop offset="100%" stop-color="#060608"/>
    </linearGradient>
    <linearGradient id="rimGrad" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.95"/>
      <stop offset="50%" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.72"/>
    </linearGradient>
    <linearGradient id="pageEdge" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="100%" stop-color="#CBD0DC"/>
    </linearGradient>
    <linearGradient id="coilGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="50%" stop-color="#9CA2B0"/>
      <stop offset="100%" stop-color="#1E2028"/>
    </linearGradient>
    <linearGradient id="penBlack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#4B4E5C"/>
      <stop offset="50%" stop-color="#111217"/>
      <stop offset="100%" stop-color="#050507"/>
    </linearGradient>
    <linearGradient id="penWhite" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF"/>
      <stop offset="60%" stop-color="#E1E4ED"/>
      <stop offset="100%" stop-color="#AEB4C2"/>
    </linearGradient>
    <filter id="drop" x="-25%" y="-25%" width="150%" height="150%">
      <feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#000000" flood-opacity="0.72"/>
    </filter>
    <filter id="penShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="4" dy="12" stdDeviation="10" flood-color="#000000" flood-opacity="0.68"/>
    </filter>
  </defs>

  <g filter="url(#drop)">
    <!-- 3D Page Stack & Back Cover -->
    <rect x="334" y="256" width="388" height="532" rx="44" fill="#050507" stroke="#FFFFFF" stroke-opacity="0.22" stroke-width="4"/>
    <rect x="326" y="248" width="388" height="532" rx="42" fill="url(#pageEdge)"/>

    <!-- Main Obsidian Notebook Cover -->
    <rect x="316" y="240" width="386" height="530" rx="42" fill="url(#coverGrad)" stroke="url(#rimGrad)" stroke-width="7"/>

    <!-- White Emblem Plate on Cover -->
    <rect x="404" y="346" width="218" height="114" rx="20" fill="#FFFFFF" fill-opacity="0.95"/>
    <line x1="438" y1="388" x2="588" y2="388" stroke="#0B0B0E" stroke-width="14" stroke-linecap="round"/>
    <line x1="438" y1="422" x2="534" y2="422" stroke="#0B0B0E" stroke-opacity="0.45" stroke-width="11" stroke-linecap="round"/>
  </g>

  <!-- Metallic Spiral Binding (7 Coils) -->
  <g>
    <circle cx="344" cy="306" r="11" fill="#08080B"/><path d="M 300 314 C 272 306, 272 288, 344 298" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="372" r="11" fill="#08080B"/><path d="M 300 380 C 272 372, 272 354, 344 364" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="438" r="11" fill="#08080B"/><path d="M 300 446 C 272 438, 272 420, 344 430" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="504" r="11" fill="#08080B"/><path d="M 300 512 C 272 504, 272 486, 344 496" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="570" r="11" fill="#08080B"/><path d="M 300 578 C 272 570, 272 552, 344 562" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="636" r="11" fill="#08080B"/><path d="M 300 644 C 272 636, 272 618, 344 628" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
    <circle cx="344" cy="702" r="11" fill="#08080B"/><path d="M 300 710 C 272 702, 272 684, 344 694" fill="none" stroke="url(#coilGrad)" stroke-width="13" stroke-linecap="round"/>
  </g>

  <!-- Sleek Black & White 3D Pen Resting Diagonally on Cover -->
  <g transform="translate(396, 650) rotate(-42)" filter="url(#penShadow)">
    <!-- Silver Tip -->
    <polygon points="0,0 56,-22 56,22" fill="url(#penWhite)"/>
    <circle cx="5" cy="0" r="4.5" fill="#050507"/>
    <!-- Pearl White Lower Barrel -->
    <rect x="56" y="-23" width="96" height="46" fill="url(#penWhite)"/>
    <!-- Obsidian Upper Barrel -->
    <path d="M 152 -23 L 368 -23 A 23 23 0 0 1 368 23 L 152 23 Z" fill="url(#penBlack)" stroke="#FFFFFF" stroke-opacity="0.32" stroke-width="3"/>
    <!-- Metallic Divider Ring & Clip -->
    <rect x="148" y="-25" width="14" height="50" rx="4" fill="#FFFFFF"/>
    <rect x="218" y="-36" width="128" height="12" rx="6" fill="#FFFFFF"/>
    <!-- Specular Top Highlight -->
    <line x1="62" y1="-11" x2="360" y2="-11" stroke="#FFFFFF" stroke-opacity="0.65" stroke-width="5" stroke-linecap="round"/>
  </g>
</svg>
"""

FULL_BG_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="35%" cy="28%" r="82%">
      <stop offset="0%" stop-color="#22242D"/>
      <stop offset="60%" stop-color="#0C0D11"/>
      <stop offset="100%" stop-color="#050507"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
</svg>
"""

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

BACKGROUND_DRAWABLE_XML = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient
        android:type="radial"
        android:gradientRadius="120%"
        android:centerX="35%"
        android:centerY="28%"
        android:startColor="#242630"
        android:centerColor="#0E0F14"
        android:endColor="#050507"/>
</shape>
"""

DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def render_png(svg_str: str, size: int) -> Image.Image:
    png_bytes = cairosvg.svg2png(
        bytestring=svg_str.encode("utf-8"),
        output_width=size,
        output_height=size,
    )
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA")


def main():
    fg_master = render_png(FOREGROUND_SVG, 1024)
    bg_master = render_png(FULL_BG_SVG, 1024)
    combined_master = Image.alpha_composite(bg_master, fg_master)

    for density, (legacy_px, fg_px) in DENSITIES.items():
        mip_dir = os.path.join(RES_DIR, f"mipmap-{density}")
        os.makedirs(mip_dir, exist_ok=True)

        legacy = combined_master.resize((legacy_px, legacy_px), Image.LANCZOS)
        legacy.save(os.path.join(mip_dir, "ic_launcher.png"))
        legacy.save(os.path.join(mip_dir, "ic_launcher_round.png"))

        fg = fg_master.resize((fg_px, fg_px), Image.LANCZOS)
        fg.save(os.path.join(mip_dir, "ic_launcher_foreground.png"))

    anydpi_dir = os.path.join(RES_DIR, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(ADAPTIVE_XML)
    with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
        f.write(ADAPTIVE_XML)

    drawable_dir = os.path.join(RES_DIR, "drawable")
    os.makedirs(drawable_dir, exist_ok=True)
    with open(os.path.join(drawable_dir, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write(BACKGROUND_DRAWABLE_XML)

    print("Generated all luxury black & white app icons successfully!")


if __name__ == "__main__":
    main()
