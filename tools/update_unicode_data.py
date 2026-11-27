#!/usr/bin/env python3
"""Met à jour les données Unicode embarquées dans le moteur SafeLink.

Génère, depuis les fichiers officiels d'Unicode :
- packages/safelink_engine/lib/src/url/confusables_data.g.dart : caractères
  qui ressemblent à des lettres ou chiffres latins (UTS #39,
  confusables.txt), réduits aux correspondances vers l'ASCII ;
- packages/safelink_engine/lib/src/url/scripts_data.g.dart : écriture
  (latin, cyrillique…) de chaque caractère (Scripts.txt).
Copie aussi la licence Unicode dans app/assets/licenses/unicode.txt.

Les données sont sous licence Unicode v3 : la notice de licence accompagne
les fichiers générés.

Usage, depuis la racine du dépôt : python3 tools/update_unicode_data.py
Option : --source-dir <dossier> contenant confusables.txt, Scripts.txt et
license.txt déjà téléchargés.
"""
import argparse
import hashlib
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENGINE = ROOT / "packages/safelink_engine"
SOURCES = {
    "confusables.txt": "https://www.unicode.org/Public/security/latest/confusables.txt",
    "Scripts.txt": "https://www.unicode.org/Public/UCD/latest/ucd/Scripts.txt",
    "license.txt": "https://www.unicode.org/license.txt",
}
USER_AGENT = "SafeLink-update-unicode (+https://github.com/kouratoussaint/safelink)"
TARGET_PATTERN = re.compile(r"^[A-Za-z0-9-]+$")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def version_of(text: str) -> str:
    for line in text.splitlines()[:12]:
        match = re.search(r"(\d+\.\d+\.\d+)", line)
        if match and ("Version" in line or line.startswith("# Scripts-")):
            return match.group(1)
    raise ValueError("Version introuvable")


def header(name: str, version: str, digest: str) -> str:
    return (
        "// Fichier généré par tools/update_unicode_data.py : ne pas modifier\n"
        "// à la main.\n"
        "//\n"
        f"// Données : Unicode {version}, {name}, https://www.unicode.org/\n"
        "// Copyright © 1991-2026 Unicode, Inc. Licence Unicode v3 :\n"
        "// https://www.unicode.org/license.txt (texte complet dans\n"
        "// app/assets/licenses/unicode.txt).\n"
        f"// SHA-256 du fichier source : {digest}\n"
        "// ignore_for_file: lines_longer_than_80_chars\n\n"
    )


def generate_confusables(raw: bytes) -> tuple[str, int]:
    text = raw.decode("utf-8-sig")
    entries = []
    for line in text.splitlines():
        data = line.split("#", 1)[0].strip()
        if not data:
            continue
        source, target, _ = (part.strip() for part in data.split(";"))
        if len(source.split()) != 1:
            continue
        prototype = "".join(chr(int(cp, 16)) for cp in target.split())
        if not TARGET_PATTERN.match(prototype):
            continue
        code_point = int(source, 16)
        lowered = prototype.lower()
        if chr(code_point) == lowered:
            continue
        entries.append(f"{code_point:X}:{lowered}")
    version = version_of(text)
    digest = hashlib.sha256(raw).hexdigest()
    body = "\n".join(entries)
    dart = (
        header("confusables.txt (UTS #39)", version, digest)
        + f"/// Version d'Unicode des correspondances.\nconst confusablesVersion = '{version}';\n\n"
        + "/// Caractère (hexadécimal) → prototype ASCII en minuscules, une\n"
        + "/// correspondance par ligne.\n"
        + "const confusablesData = '''\n" + body + "\n''';\n"
    )
    return dart, len(entries)


def generate_scripts(raw: bytes) -> tuple[str, int]:
    text = raw.decode("utf-8")
    ranges = []
    for line in text.splitlines():
        data = line.split("#", 1)[0].strip()
        if not data:
            continue
        span, script = (part.strip() for part in data.split(";"))
        start, _, end = span.partition("..")
        ranges.append((int(start, 16), int(end or start, 16), script))
    ranges.sort()
    merged = []
    for start, end, script in ranges:
        if merged and merged[-1][2] == script and merged[-1][1] + 1 == start:
            merged[-1] = (merged[-1][0], end, script)
        else:
            merged.append((start, end, script))
    names = sorted({script for *_, script in merged})
    index = {name: i for i, name in enumerate(names)}
    flat = ",".join(f"0x{s:X},0x{e:X},{index[n]}" for s, e, n in merged)
    version = version_of(text)
    digest = hashlib.sha256(raw).hexdigest()
    lines = []
    chunk = ""
    for item in flat.split(","):
        if len(chunk) + len(item) + 1 > 76:
            lines.append(chunk)
            chunk = ""
        chunk += item + ","
    lines.append(chunk)
    dart = (
        header("Scripts.txt", version, digest)
        + f"/// Version d'Unicode des écritures.\nconst scriptsVersion = '{version}';\n\n"
        + "/// Noms des écritures (propriété Script d'Unicode).\n"
        + "const scriptNames = <String>[\n"
        + "".join(f"  '{name}',\n" for name in names)
        + "];\n\n"
        + "/// Plages triées : début, fin (incluse), indice dans [scriptNames].\n"
        + "const scriptRanges = <int>[\n"
        + "".join(f"  {line}\n" for line in lines)
        + "];\n"
    )
    return dart, len(merged)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=pathlib.Path)
    args = parser.parse_args()
    raw = {}
    for name, url in SOURCES.items():
        raw[name] = (args.source_dir / name).read_bytes() if args.source_dir else fetch(url)

    confusables, count = generate_confusables(raw["confusables.txt"])
    if count < 1000:
        print("Correspondances anormalement peu nombreuses : abandon.")
        return 1
    out = ENGINE / "lib/src/url/confusables_data.g.dart"
    out.write_text(confusables, encoding="utf-8")
    print(f"{out.relative_to(ROOT)} : {count} correspondances")

    scripts, count = generate_scripts(raw["Scripts.txt"])
    out = ENGINE / "lib/src/url/scripts_data.g.dart"
    out.write_text(scripts, encoding="utf-8")
    print(f"{out.relative_to(ROOT)} : {count} plages")

    license_out = ROOT / "app/assets/licenses/unicode.txt"
    license_out.write_text(
        "Données Unicode (confusables.txt, Scripts.txt)\n"
        "https://www.unicode.org/\n\n"
        "SafeLink embarque des extraits de ces fichiers, convertis en code\n"
        "Dart, pour repérer les caractères qui imitent des lettres latines.\n\n"
        "--------------------------------------------------------------------\n\n"
        + raw["license.txt"].decode("utf-8"),
        encoding="utf-8",
    )
    print(f"{license_out.relative_to(ROOT)} : licence copiée")
    return 0


if __name__ == "__main__":
    sys.exit(main())
