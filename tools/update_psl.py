#!/usr/bin/env python3
"""Met à jour la Public Suffix List embarquée dans le moteur SafeLink.

Télécharge la liste depuis publicsuffix.org (seule source autorisée par ses
mainteneurs), convertit les règles internationales en punycode et génère :
- packages/safelink_engine/lib/src/url/psl_data.g.dart (règles ICANN et
  privées, date, empreinte SHA-256 du fichier source) ;
- packages/safelink_engine/test/data/psl_tests.txt (tests officiels,
  domaine public) depuis le dépôt publicsuffix/list.

La liste est sous licence MPL-2.0 : l'en-tête de licence est conservé dans
le fichier généré.

Usage, depuis la racine du dépôt : python3 tools/update_psl.py
Option : --source <fichier> pour utiliser un fichier déjà téléchargé.
"""
import argparse
import datetime
import hashlib
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENGINE = ROOT / "packages/safelink_engine"
LIST_URL = "https://publicsuffix.org/list/public_suffix_list.dat"
TESTS_URL = "https://raw.githubusercontent.com/publicsuffix/list/main/tests/tests.txt"
USER_AGENT = "SafeLink-update-psl (+https://github.com/kouratoussaint/safelink)"


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def to_ascii(rule: str) -> str:
    """Convertit une règle en ASCII, label par label (punycode)."""
    labels = []
    for label in rule.lower().split("."):
        if label.isascii():
            labels.append(label)
        else:
            labels.append("xn--" + label.encode("punycode").decode("ascii"))
    return ".".join(labels)


def parse(text: str) -> tuple[list[str], list[str]]:
    icann: list[str] = []
    private: list[str] = []
    section = None
    for raw in text.splitlines():
        line = raw.strip()
        if "===BEGIN ICANN DOMAINS===" in line:
            section = icann
            continue
        if "===BEGIN PRIVATE DOMAINS===" in line:
            section = private
            continue
        if "===END" in line:
            section = None
            continue
        if not line or line.startswith("//") or section is None:
            continue
        # Une règle s'arrête au premier espace (convention de la liste).
        rule = line.split()[0]
        prefix = ""
        if rule.startswith("!"):
            prefix, rule = "!", rule[1:]
        section.append(prefix + to_ascii(rule))
    return icann, private


def dart_string(rules: list[str]) -> str:
    body = "\n".join(rules)
    if "'''" in body or "\\" in body or "$" in body:
        raise ValueError("Caractère inattendu dans une règle")
    return "'''\n" + body + "\n'''"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path)
    args = parser.parse_args()

    raw = args.source.read_bytes() if args.source else fetch(LIST_URL)
    digest = hashlib.sha256(raw).hexdigest()
    text = raw.decode("utf-8")
    icann, private = parse(text)
    if len(icann) < 5000 or len(private) < 1000:
        print("Liste anormalement courte : abandon.")
        return 1
    license_header = "\n".join(
        "// " + line[2:].strip() if line.startswith("//") else line
        for line in text.splitlines()[:3]
    )
    today = datetime.date.today().isoformat()
    out = ENGINE / "lib/src/url/psl_data.g.dart"
    out.write_text(
        "// Fichier généré par tools/update_psl.py : ne pas modifier à la main.\n"
        "//\n"
        "// Données : Public Suffix List, https://publicsuffix.org/list/\n"
        f"{license_header}\n"
        "// ignore_for_file: lines_longer_than_80_chars\n\n"
        "/// Date de téléchargement de la Public Suffix List embarquée.\n"
        f"const pslRetrievedOn = '{today}';\n\n"
        "/// Empreinte SHA-256 du fichier source téléchargé.\n"
        f"const pslSha256 = '{digest}';\n\n"
        "/// Règles de la section ICANN, une par ligne, en ASCII (punycode).\n"
        f"const pslIcannRules = {dart_string(icann)};\n\n"
        "/// Règles de la section privée (hébergeurs, plateformes), une par\n"
        "/// ligne, en ASCII (punycode).\n"
        f"const pslPrivateRules = {dart_string(private)};\n",
        encoding="utf-8",
    )
    print(f"{out.relative_to(ROOT)} : {len(icann)} règles ICANN, "
          f"{len(private)} règles privées, sha256 {digest[:12]}…")

    tests = ENGINE / "test/data/psl_tests.txt"
    tests.parent.mkdir(parents=True, exist_ok=True)
    tests.write_bytes(fetch(TESTS_URL))
    print(f"{tests.relative_to(ROOT)} : tests officiels mis à jour")
    return 0


if __name__ == "__main__":
    sys.exit(main())
