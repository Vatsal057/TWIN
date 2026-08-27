#!/usr/bin/env python3
"""Builds every launcher and web icon from assets/icon/source.png.

    python3 tools/make_icons.py              # write all icons
    python3 tools/make_icons.py --preview    # /tmp/icon_preview*.png only

Design decisions worth knowing before changing anything here.

*Why the face alone.* The source is a two-element gag: a face and a reaching
hand, captioned. Rendered at the size a launcher actually draws, 48-72px, the
pair becomes two unreadable yellow blobs, whereas the face alone keeps its
eyebrow, side-eye and grin legible. The hand belongs to the caption's joke, not
to the mark. Set INCLUDE_HAND to restore it.

*Why matte by distance from the backdrop.* The backdrop is a single flat colour
with sub-1 spread, and its drop shadow stays within ~24 of it, while the face's
dark features sit near 52 and the teeth at 163+. So a ramp across 26..48
separates subject from shadow. A colour threshold on the yellow cannot work: the
eyebrows, eyes and mouth are dark, and the grin opens at the silhouette edge, so
filling interior holes drops the whole mouth and leaves a black void.

*Why un-premultiply.* The source was already composited over its backdrop.
Recovering fg = (px - (1-a)*bg) / a removes the last trace of the old colour,
which otherwise survives as a blue-grey rim once the art sits on ink.
"""

import argparse
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw
from scipy import ndimage

# --- palette, mirroring lib/ui/app_theme.dart -------------------------------
INK = (0x14, 0x12, 0x0F)

# --- matte ------------------------------------------------------------------
# Distance-from-backdrop band over which a pixel ramps from background to
# subject. Below SHADOW_MAX is the source's own drop shadow, which is discarded:
# it was drawn against a lighter backdrop and would read as a grey smear on ink.
SHADOW_MAX = 26.0
SUBJECT_MIN = 48.0
FEATHER = 1.0

# --- composition ------------------------------------------------------------
INCLUDE_HAND = False
MASTER = 2048
FACE_WIDTH = 900
FACE_CENTRE = (1024, 1024)  # centred, since the face is the whole mark
HAND_CENTRE = (1400, 660)  # only consulted when INCLUDE_HAND
HAND_ROTATION = 18
# With the hand in play the face has to give up room and move off centre.
FACE_CENTRE_WITH_HAND = (800, 1220)

# --- output geometry --------------------------------------------------------
# Fraction of each canvas the mark occupies.
FULL_BLEED = 0.84
# Adaptive layers are 108dp but only the middle 72dp (0.667) survives every
# launcher mask, and maskable web icons are cropped to a circle of about 80%.
SAFE_ZONE = 0.58
# Legacy launchers do not mask the icon, so it rounds its own corners.
LEGACY_CORNER = 0.22

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(REPO, "assets/icon/source.png")


def matted():
    """The source as clean RGBA, with backdrop and its drop shadow removed."""
    arr = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float32)

    k = 40
    corners = np.concatenate(
        [
            arr[:k, :k].reshape(-1, 3),
            arr[:k, -k:].reshape(-1, 3),
            arr[-k:, :k].reshape(-1, 3),
            arr[-k:, -k:].reshape(-1, 3),
        ]
    )
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((arr - bg) ** 2).sum(2))

    t = np.clip((dist - SHADOW_MAX) / (SUBJECT_MIN - SHADOW_MAX), 0, 1)
    alpha = ndimage.gaussian_filter(t * t * (3 - 2 * t), FEATHER)

    a = alpha[..., None]
    fg = np.where(a > 4e-3, (arr - (1 - a) * bg) / np.maximum(a, 4e-3), arr)
    stacked = np.dstack([np.clip(fg, 0, 255), np.clip(alpha, 0, 1) * 255])
    return Image.fromarray(stacked.astype(np.uint8), "RGBA")


def elements(img):
    """The face and the hand, tightly cropped.

    The caption is white and so survives the matte. Keeping only the two largest
    connected blobs discards it, since every glyph is its own small component.
    """
    solid = np.asarray(img)[..., 3] > 24
    labels, count = ndimage.label(solid)
    areas = ndimage.sum(solid, labels, range(1, count + 1))
    keep = np.argsort(areas)[-2:] + 1
    solid = np.isin(labels, keep)

    cleaned = np.asarray(img).copy()
    cleaned[..., 3] = np.where(solid, cleaned[..., 3], 0)
    img = Image.fromarray(cleaned, "RGBA")

    # Split at the widest empty column between the two blobs.
    cols = solid.sum(0)
    xs = np.where(cols > 0)[0]
    empty = np.where(cols == 0)[0]
    inner = empty[(empty > xs.min()) & (empty < xs.max())]
    runs, start = [], inner[0]
    for i in range(1, len(inner)):
        if inner[i] != inner[i - 1] + 1:
            runs.append((start, inner[i - 1]))
            start = inner[i]
    runs.append((start, inner[-1]))
    widest = max(runs, key=lambda r: r[1] - r[0])
    split = (widest[0] + widest[1]) // 2

    def crop(x0, x1):
        band = solid[:, x0:x1]
        ys, bx = np.where(band)
        return img.crop(
            (int(bx.min()) + x0, int(ys.min()), int(bx.max()) + x0 + 1, int(ys.max()) + 1)
        )

    return crop(0, split), crop(split, solid.shape[1])


def build_mark():
    """The composed mark: transparent, tightly cropped."""
    face, hand = elements(matted())

    scale = FACE_WIDTH / face.width
    resize = lambda im: im.resize(
        (round(im.width * scale), round(im.height * scale)), Image.LANCZOS
    )
    face = resize(face)

    canvas = Image.new("RGBA", (MASTER, MASTER), (0, 0, 0, 0))
    if INCLUDE_HAND:
        hand = resize(hand)
        if HAND_ROTATION:
            hand = hand.rotate(HAND_ROTATION, resample=Image.BICUBIC, expand=True)
        canvas.alpha_composite(
            hand, (round(HAND_CENTRE[0] - hand.width / 2), round(HAND_CENTRE[1] - hand.height / 2))
        )
        centre = FACE_CENTRE_WITH_HAND
    else:
        centre = FACE_CENTRE

    canvas.alpha_composite(
        face, (round(centre[0] - face.width / 2), round(centre[1] - face.height / 2))
    )
    return canvas.crop(canvas.getbbox())


def monochrome(mark):
    """Flat silhouette for Android 13 themed icons.

    The system discards colour and tints by alpha, so a plain silhouette would
    be a featureless blob. Scaling alpha by luminance instead punches the dark
    eyebrows, eyes and mouth out as holes, which keeps the expression readable.
    """
    arr = np.asarray(mark).astype(np.float32)
    rgb, alpha = arr[..., :3], arr[..., 3] / 255.0
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    keep = np.clip((lum - 45.0) / 80.0, 0, 1)
    out = np.dstack(
        [np.full_like(lum, 255), np.full_like(lum, 255), np.full_like(lum, 255), alpha * keep * 255]
    )
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def place(mark, size, art_scale, background=None, corner=0.0):
    canvas = Image.new(
        "RGBA", (size, size), (*background, 255) if background else (0, 0, 0, 0)
    )
    budget = art_scale * size
    factor = min(budget / mark.width, budget / mark.height)
    w, h = max(1, round(mark.width * factor)), max(1, round(mark.height * factor))
    canvas.alpha_composite(
        mark.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2)
    )

    if corner:
        rounded = Image.new("L", (size, size), 0)
        ImageDraw.Draw(rounded).rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=corner * size, fill=255
        )
        canvas.putalpha(ImageChops.darker(canvas.getchannel("A"), rounded))
    return canvas


def write(img, *parts):
    path = os.path.join(REPO, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  {os.path.relpath(path, REPO)}  {img.width}x{img.height}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()

    mark = build_mark()
    mono = monochrome(mark)
    print(f"mark {mark.width}x{mark.height}  aspect {mark.width / mark.height:.3f}")

    if args.preview:
        place(mark, 512, FULL_BLEED, INK, LEGACY_CORNER).save("/tmp/icon_preview.png")
        place(mono, 512, SAFE_ZONE, (60, 60, 66)).save("/tmp/icon_preview_mono.png")
        print("  /tmp/icon_preview.png\n  /tmp/icon_preview_mono.png")
        return

    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    res = "android/app/src/main/res"

    print("Android legacy (48dp, self-rounded, pre-API-26)")
    for bucket, f in densities.items():
        write(
            place(mark, int(48 * f), FULL_BLEED, INK, LEGACY_CORNER),
            res, f"mipmap-{bucket}", "ic_launcher.png",
        )

    print("Android adaptive foreground (108dp)")
    for bucket, f in densities.items():
        write(
            place(mark, int(108 * f), SAFE_ZONE),
            res, f"mipmap-{bucket}", "ic_launcher_foreground.png",
        )

    print("Android monochrome (108dp, themed icons)")
    for bucket, f in densities.items():
        write(
            place(mono, int(108 * f), SAFE_ZONE),
            res, f"mipmap-{bucket}", "ic_launcher_monochrome.png",
        )

    print("Web")
    for px in (192, 512):
        write(place(mark, px, FULL_BLEED, INK), "web/icons", f"Icon-{px}.png")
    for px in (192, 512):
        write(place(mark, px, SAFE_ZONE, INK), "web/icons", f"Icon-maskable-{px}.png")
    write(place(mark, 32, 0.92, INK), "web", "favicon.png")

    print("Master (store listings, future resizing)")
    write(place(mark, 1024, FULL_BLEED, INK), "assets/icon", "icon-1024.png")


if __name__ == "__main__":
    main()
