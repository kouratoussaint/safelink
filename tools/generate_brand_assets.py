#!/usr/bin/env python3
"""Génère toutes les ressources graphiques de SafeLink depuis une seule source.

Produit, à partir de la géométrie définie ci-dessous :
- app/assets/brand/safelink_mark.svg et safelink_mark_on_light.svg :
  symbole bouclier + maillon pour fonds sombres et clairs ;
- docs/brand/safelink_icon.svg et safelink_mono.svg : icône complète et
  version monochrome, pour la documentation et les visuels ;
- les icônes adaptatives Android (premier plan, monochrome) en VectorDrawable ;
- les icônes PNG héritées (Android 7.x) de 48 à 192 px.

Prérequis : Python 3 et `rsvg-convert` (paquet librsvg2-bin).
Usage, depuis la racine du dépôt : python3 tools/generate_brand_assets.py
"""
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "app/android/app/src/main/res"

NAVY, TURQUOISE, LIGHT = "#081E33", "#00C2A8", "#D9FBF6"
# Turquoise assombrie du thème clair (contraste 5,3:1 sur blanc).
TURQUOISE_ON_LIGHT = "#00796B"

# Géométrie dans le repère 108 x 108 des icônes adaptatives Android.
SHIELD = (
    "M54 24.5C62.2 29.6 70.4 32.9 79.2 34.4C80.2 34.6 80.9 35.4 80.9 36.4"
    "V52.2C80.9 67.4 70.4 78 54 84.6C37.6 78 27.1 67.4 27.1 52.2V36.4"
    "C27.1 35.4 27.8 34.6 28.8 34.4C37.6 32.9 45.8 29.6 54 24.5Z"
)
SHIELD_STROKE = 5.2
CHAIN_STROKE = 4.2
# Le maillon est dessiné à l'horizontale puis tourné de -45° autour de
# (54, 55).
ROTATION = (-45, 54, 55)


def stadium(cx: float, cy: float, w: float, h: float) -> str:
    """Rectangle aux extrémités arrondies, en données de chemin SVG."""
    r = h / 2
    return (
        f"M{cx - w / 2 + r:.2f} {cy - h / 2:.2f}H{cx + w / 2 - r:.2f}"
        f"A{r:.2f} {r:.2f} 0 0 1 {cx + w / 2 - r:.2f} {cy + h / 2:.2f}"
        f"H{cx - w / 2 + r:.2f}"
        f"A{r:.2f} {r:.2f} 0 0 1 {cx - w / 2 + r:.2f} {cy - h / 2:.2f}Z"
    )


LINKS = [stadium(46.5, 55, 21, 11), stadium(61.5, 55, 21, 11)]
AXES = ["M29.5 55H36", "M72 55H80.5"]

SVG_HEADER = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" '
    'width="108" height="108">'
)
GENERATED = "<!-- Fichier généré par tools/generate_brand_assets.py. -->"


def svg_mark(shield: str, chain: str) -> str:
    angle, px, py = ROTATION
    axes = "".join(
        f'<path d="{d}" stroke="{shield}" stroke-width="{CHAIN_STROKE}"/>'
        for d in AXES
    )
    links = "".join(
        f'<path d="{d}" stroke="{chain}" stroke-width="{CHAIN_STROKE}"/>'
        for d in LINKS
    )
    return (
        '<g fill="none" stroke-linecap="round" stroke-linejoin="round">'
        f'<path d="{SHIELD}" stroke="{shield}" '
        f'stroke-width="{SHIELD_STROKE}"/>'
        f'<g transform="rotate({angle} {px} {py})">{axes}{links}</g></g>'
    )


def vector_drawable(shield: str, chain: str, scale: float) -> str:
    """VectorDrawable Android équivalent au symbole SVG."""
    angle, px, py = ROTATION

    def path(d: str, color: str, width: float, indent: str) -> str:
        return (
            f'{indent}<path android:pathData="{d}"\n'
            f'{indent}    android:strokeColor="{color}"\n'
            f'{indent}    android:strokeWidth="{width}"\n'
            f'{indent}    android:strokeLineCap="round"\n'
            f'{indent}    android:strokeLineJoin="round" />\n'
        )

    deep = " " * 12
    inner = "".join(path(d, shield, CHAIN_STROKE, deep) for d in AXES)
    inner += "".join(path(d, chain, CHAIN_STROKE, deep) for d in LINKS)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f"{GENERATED}\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n'
        '    android:height="108dp"\n'
        '    android:viewportWidth="108"\n'
        '    android:viewportHeight="108">\n'
        f'    <group android:scaleX="{scale}" android:scaleY="{scale}"\n'
        '        android:pivotX="54" android:pivotY="54">\n'
        + path(SHIELD, shield, SHIELD_STROKE, " " * 8)
        + f'        <group android:rotation="{angle}"\n'
        f'            android:pivotX="{px}" android:pivotY="{py}">\n'
        + inner
        + "        </group>\n"
        "    </group>\n"
        "</vector>\n"
    )


def write(path: pathlib.Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"écrit : {path.relative_to(ROOT)}")


def main() -> int:
    if shutil.which("rsvg-convert") is None:
        print("rsvg-convert introuvable (installer librsvg2-bin).")
        return 1

    mark = svg_mark(TURQUOISE, LIGHT)
    write(
        ROOT / "app/assets/brand/safelink_mark.svg",
        f"{SVG_HEADER}\n{GENERATED}\n<title>SafeLink</title>\n{mark}\n</svg>\n",
    )
    # Variante pour fond clair : le maillon passe en bleu nuit pour rester
    # visible sur blanc ; le bouclier garde la turquoise foncée du thème.
    write(
        ROOT / "app/assets/brand/safelink_mark_on_light.svg",
        f"{SVG_HEADER}\n{GENERATED}\n<title>SafeLink</title>\n"
        f"{svg_mark(TURQUOISE_ON_LIGHT, NAVY)}\n</svg>\n",
    )
    icon = (
        f"{SVG_HEADER}\n{GENERATED}\n<title>SafeLink</title>\n"
        f'<rect width="108" height="108" rx="24" fill="{NAVY}"/>\n'
        '<g transform="translate(54 54) scale(1.32) translate(-54 -54.5)">'
        f"{mark}</g>\n</svg>\n"
    )
    icon_path = ROOT / "docs/brand/safelink_icon.svg"
    write(icon_path, icon)
    write(
        ROOT / "docs/brand/safelink_mono.svg",
        f"{SVG_HEADER}\n{GENERATED}\n{svg_mark('#000000', '#000000')}\n</svg>\n",
    )

    # Le symbole est réduit à 92 % pour rester dans la zone sûre de 66 dp
    # des icônes adaptatives, quel que soit le masque du fabricant.
    write(
        RES / "drawable/ic_launcher_foreground.xml",
        vector_drawable(TURQUOISE, LIGHT, 0.92),
    )
    write(
        RES / "drawable/ic_launcher_monochrome.xml",
        vector_drawable("#FFFFFFFF", "#FFFFFFFF", 0.92),
    )

    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        out = RES / f"mipmap-{density}/ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["rsvg-convert", "-w", str(size), "-h", str(size),
             str(icon_path), "-o", str(out)],
            check=True,
        )
        print(f"écrit : {out.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
