#!/usr/bin/env python3
"""Genera las imágenes del README a partir de capturas de previews con datos sintéticos.

Uso: python3 scripts/make-docs-images.py <carpeta-con-capturas>

La carpeta debe tener raw-{presupuestos,patrimonio,flujo,cuentas,widget}.png, renderizadas con
RenderPreview desde App/Views/ShowcasePreviews.swift y App/Views/WidgetPreviews.swift.
Nunca uses capturas de la app con datos reales.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = Path(sys.argv[1])
OUT = Path(__file__).resolve().parent.parent / "docs"
SCREENS = ["presupuestos", "patrimonio", "flujo", "cuentas"]
SF = "/System/Library/Fonts/SFNS.ttf"
SF_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    f.set_variation_by_name(weight)
    return f


def clean(im):
    """El lienzo de previews dibuja un círculo vacío al centro de la toolbar; se tapa fila por
    fila con el color de fondo (degradado vertical)."""
    im = im.convert("RGBA")
    px = im.load()
    for y in range(4, 51):
        ref = px[540, y]
        for x in range(548, 602):
            px[x, y] = ref
    return im


def shadowed(im, radius=40, offset=(0, 24), opacity=150):
    """Devuelve la imagen sobre un lienzo con sombra suave, y el margen agregado."""
    pad = radius * 2
    canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    alpha = im.split()[3].point(lambda a: opacity if a > 0 else 0)
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 255))
    shadow.putalpha(alpha)
    canvas.paste(shadow, (pad + offset[0], pad + offset[1]), shadow)
    canvas = canvas.filter(ImageFilter.GaussianBlur(radius))
    canvas.alpha_composite(im, (pad, pad))
    return canvas, pad


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius, fill=255)
    out = im.copy()
    out.putalpha(mask)
    return out


def background(w, h):
    bg = Image.new("RGBA", (w, h), (14, 15, 24, 255))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for (cx, cy, r, color) in [
        (0.08, 0.05, 0.22, (255, 149, 0, 70)),
        (0.92, 0.00, 0.28, (10, 132, 255, 80)),
        (0.62, 1.05, 0.26, (48, 209, 88, 55)),
    ]:
        d.ellipse((cx * w - r * w, cy * h - r * w, cx * w + r * w, cy * h + r * w), fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    bg.alpha_composite(glow)
    return bg


def rings(size, stroke):
    """Tres anillos tipo Actividad: el motivo visual de la app."""
    scale = 4
    s, st = size * scale, stroke * scale
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, (color, frac) in enumerate([((255, 69, 58), 1.12), ((255, 159, 10), 0.84), ((48, 209, 88), 0.58)]):
        inset = i * st * 1.25 + st / 2
        box = (inset, inset, s - inset, s - inset)
        d.arc(box, 0, 360, fill=color[:3] + (60,), width=int(st))
        d.arc(box, -90, -90 + 360 * min(frac, 1), fill=color, width=int(st))
        if frac > 1:
            dark = tuple(int(c * 0.7) for c in color)
            d.arc(box, -90, -90 + 360 * (frac - 1), fill=dark, width=int(st))
    return im.resize((size, size), Image.LANCZOS)


def banner(w, h, screenshot, widget, compact=False):
    im = background(w, h)
    # Texto y etiquetas en una capa aparte: en RGBA, ImageDraw reemplaza píxeles en vez de mezclar.
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x = int(w * 0.055)
    ring = rings(int(h * 0.16), int(h * 0.017))
    im.alpha_composite(ring, (x, int(h * 0.14)))
    title = font(SF, int(h * 0.105), "Bold")
    ty = int(h * 0.36)
    d.text((x, ty), "Wispr Money", font=title, fill=(255, 255, 255))
    d.text((x, ty + int(h * 0.115)), "para Mac", font=title, fill=(255, 255, 255, 150))
    sub = font(SF, int(h * 0.036), "Regular")
    sy = ty + int(h * 0.27)
    for i, line in enumerate(["Tus finanzas en vivo, nativas en macOS Tahoe.",
                              "Sin caché, sin web views, con widget de escritorio."]):
        d.text((x, sy + i * int(h * 0.052)), line, font=sub, fill=(235, 235, 245, 200))
    chip = font(SF, int(h * 0.026), "Semibold")
    cx, cy = x, sy + int(h * 0.14)
    for label in ["SwiftUI", "WidgetKit", "Liquid Glass", "MCP"]:
        tw = d.textlength(label, font=chip)
        pad_x, pad_y = int(h * 0.02), int(h * 0.011)
        box = (cx, cy, cx + tw + pad_x * 2, cy + chip.size + pad_y * 2)
        d.rounded_rectangle(box, radius=(box[3] - box[1]) // 2, fill=(255, 255, 255, 28),
                            outline=(255, 255, 255, 60), width=1)
        d.text((cx + pad_x, cy + pad_y - 2), label, font=chip, fill=(255, 255, 255, 230))
        cx = box[2] + int(h * 0.015)
    im.alpha_composite(layer)

    # Captura a la derecha, recortada por el borde; el widget encima.
    shot_w = int(w * (0.62 if not compact else 0.58))
    shot = screenshot.resize((shot_w, int(screenshot.height * shot_w / screenshot.width)), Image.LANCZOS)
    shot_s, pad = shadowed(shot, radius=int(h * 0.05))
    sx, sy2 = int(w * 0.50), int(h * 0.12)
    im.alpha_composite(shot_s, (sx - pad, sy2 - pad))
    wid_w = int(h * 0.44)
    wid = widget.resize((wid_w, int(widget.height * wid_w / widget.width)), Image.LANCZOS)
    wid_s, pad = shadowed(wid, radius=int(h * 0.04), opacity=190)
    im.alpha_composite(wid_s, (int(w * 0.455) - pad, int(h * 0.50) - pad))
    return im.convert("RGB")


def main():
    shots = {n: clean(Image.open(SRC / f"raw-{n}.png")) for n in SCREENS}
    (OUT / "screenshots").mkdir(parents=True, exist_ok=True)
    for n, im in shots.items():
        im.save(OUT / "screenshots" / f"{n}.png", optimize=True)

    gallery = Image.open(SRC / "raw-widget.png").convert("RGBA")
    # Galería del widget sin la barra de título del lienzo (32 px).
    gallery.crop((0, 32, gallery.width, gallery.height)).save(OUT / "screenshots" / "widget.png", optimize=True)
    # Widget grande: marco de 364×382 en (408, 56) dentro de la galería.
    large = rounded(gallery.crop((408, 56, 408 + 364, 56 + 382)), 24)

    banner(1280, 640, shots["patrimonio"], large).save(OUT / "social-preview.png", optimize=True)
    banner(1600, 640, shots["patrimonio"], large, compact=True).save(OUT / "banner.png", optimize=True)
    print("Listo:", sorted(p.name for p in OUT.rglob("*.png")))


if __name__ == "__main__":
    main()
