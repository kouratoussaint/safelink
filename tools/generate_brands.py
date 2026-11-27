#!/usr/bin/env python3
"""Génère la liste des marques de référence du moteur SafeLink.

Lit packages/safelink_engine/data/brands.json, vérifie que chaque domaine
officiel est justifié par une source datée, puis écrit
packages/safelink_engine/lib/src/url/brands_data.g.dart.

La liste sert seulement à repérer les imitations : elle ne certifie jamais
qu'un lien est sûr.

Usage, depuis la racine du dépôt : python3 tools/generate_brands.py
Option : --check pour vérifier sans écrire (échoue si le fichier Dart n'est
pas à jour).
"""
import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENGINE = ROOT / "packages/safelink_engine"
DATA = ENGINE / "data/brands.json"
OUTPUT = ENGINE / "lib/src/url/brands_data.g.dart"

CATEGORIES = {
    "bank": "bank",
    "crypto": "crypto",
    "delivery": "delivery",
    "ecommerce": "ecommerce",
    "email": "email",
    "media": "media",
    "messaging": "messaging",
    "money_transfer": "moneyTransfer",
    "payment": "payment",
    "public_institution": "publicInstitution",
    "social": "social",
    "tech": "tech",
    "telecom": "telecom",
}
SOURCE_KINDS = {"wikidata": "wikidata", "brvm": "brvm"}
ID = re.compile(r"^[a-z][a-z0-9_]*$")
DOMAIN = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$")
WORD = re.compile(r"^[a-z0-9]+$")


def fail(message: str) -> None:
    raise SystemExit(f"brands.json invalide : {message}")


def validate(doc: dict) -> list[dict]:
    kinds = set(doc.get("source_kinds", {}))
    if kinds != set(SOURCE_KINDS):
        fail(f"types de sources attendus : {sorted(SOURCE_KINDS)}")
    seen_ids: set[str] = set()
    owner: dict[str, str] = {}
    today = datetime.date.today()
    for brand in doc["brands"]:
        bid = brand["id"]
        if not ID.match(bid) or bid in seen_ids:
            fail(f"identifiant invalide ou en double : {bid}")
        seen_ids.add(bid)
        if not brand.get("name", "").strip():
            fail(f"{bid} : nom manquant")
        if brand["category"] not in CATEGORIES:
            fail(f"{bid} : catégorie inconnue {brand['category']}")
        verified = datetime.date.fromisoformat(brand["verified_on"])
        if verified > today:
            fail(f"{bid} : date de vérification dans le futur")
        sources = brand.get("sources") or fail(f"{bid} : aucune source")
        sourced: set[str] = set()
        for source in sources:
            if source["kind"] not in kinds:
                fail(f"{bid} : type de source inconnu {source['kind']}")
            if not source["url"].startswith("https://"):
                fail(f"{bid} : source non HTTPS {source['url']}")
            if not source["domains"]:
                fail(f"{bid} : source sans domaine {source['url']}")
            sourced.update(source["domains"])
        domains = brand["domains"]
        if not domains or sorted(set(domains)) != domains:
            fail(f"{bid} : domaines absents, en double ou non triés")
        if set(domains) != sourced:
            fail(f"{bid} : chaque domaine doit venir d'une source, et seulement d'elles")
        for domain in domains:
            if not DOMAIN.match(domain):
                fail(f"{bid} : domaine invalide {domain}")
            if domain in owner:
                fail(f"{domain} appartient à {owner[domain]} et {bid}")
            owner[domain] = bid
        for word in brand["keywords"]:
            if not WORD.match(word) or len(word) < 5:
                fail(f"{bid} : mot-clé trop court ou invalide {word}")
        for word in brand["tokens"]:
            if not WORD.match(word) or len(word) < 3:
                fail(f"{bid} : mot isolé trop court ou invalide {word}")
        if not brand["keywords"] and not brand["tokens"]:
            fail(f"{bid} : aucun mot-clé")
    return doc["brands"]


def dart_list(items: list[str]) -> str:
    return "[" + ", ".join(f"'{item}'" for item in items) + "]"


def generate(brands: list[dict]) -> str:
    out = [
        "// Fichier généré par tools/generate_brands.py depuis data/brands.json :",
        "// ne pas modifier à la main.",
        "// ignore_for_file: lines_longer_than_80_chars",
        "",
        "import 'package:safelink_engine/src/url/brands.dart';",
        "",
        "/// Marques de référence embarquées. Servent seulement à repérer les",
        "/// imitations : figurer ici ne certifie jamais qu'un lien est sûr.",
        "const embeddedBrands = <Brand>[",
    ]
    for brand in brands:
        name = brand["name"].replace("'", "\\'")
        out.append("  Brand(")
        out.append(f"    id: '{brand['id']}',")
        out.append(f"    name: '{name}',")
        out.append(f"    category: BrandCategory.{CATEGORIES[brand['category']]},")
        out.append(f"    domains: {dart_list(brand['domains'])},")
        out.append(f"    keywords: {dart_list(brand['keywords'])},")
        out.append(f"    tokens: {dart_list(brand['tokens'])},")
        out.append("    sources: [")
        for source in brand["sources"]:
            out.append("      BrandSource(")
            out.append(f"        kind: BrandSourceKind.{SOURCE_KINDS[source['kind']]},")
            out.append(f"        url: '{source['url']}',")
            out.append(f"        domains: {dart_list(source['domains'])},")
            out.append("      ),")
        out.append("    ],")
        out.append(f"    verifiedOn: '{brand['verified_on']}',")
        out.append("  ),")
    out.append("];")
    return "\n".join(out) + "\n"


def formatted(dart: str) -> str:
    """Code mis en forme par `dart format`, comme le reste du dépôt."""
    with tempfile.TemporaryDirectory() as directory:
        path = pathlib.Path(directory) / "brands_data.g.dart"
        path.write_text(dart, encoding="utf-8")
        subprocess.run(["dart", "format", str(path)], check=True, capture_output=True)
        return path.read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    brands = validate(json.loads(DATA.read_text(encoding="utf-8")))
    dart = formatted(generate(brands))
    if args.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
        if current != dart:
            print("brands_data.g.dart n'est pas à jour : lancez tools/generate_brands.py")
            return 1
        print(f"{len(brands)} marques, fichier Dart à jour")
        return 0
    OUTPUT.write_text(dart, encoding="utf-8")
    print(f"{OUTPUT.relative_to(ROOT)} : {len(brands)} marques, "
          f"{sum(len(b['domains']) for b in brands)} domaines officiels")
    return 0


if __name__ == "__main__":
    sys.exit(main())
