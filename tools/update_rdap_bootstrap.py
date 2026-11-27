#!/usr/bin/env python3
"""Met à jour la table des serveurs RDAP embarquée dans l'application.

Télécharge le registre d'amorçage RDAP de l'IANA (RFC 9224), qui indique,
pour chaque extension (com, org, xyz…), le serveur du registre qui publie
les données d'enregistrement des domaines. L'application l'utilise pour
connaître la date de création d'un domaine sans passer par un
intermédiaire.

Génère app/lib/features/online/rdap_bootstrap.g.dart : une entrée par
extension, seulement des adresses https, avec la date de publication de
l'IANA et l'empreinte SHA-256 du fichier source.

Usage, depuis la racine du dépôt : python3 tools/update_rdap_bootstrap.py
Option : --source <fichier> pour utiliser un fichier déjà téléchargé.
"""
import argparse
import hashlib
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "app/lib/features/online/rdap_bootstrap.g.dart"
SOURCE_URL = "https://data.iana.org/rdap/dns.json"
USER_AGENT = "SafeLink-update-rdap (+https://github.com/kouratoussaint/safelink)"


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def servers(document: dict) -> dict[str, str]:
    table: dict[str, str] = {}
    for tlds, urls in document["services"]:
        https = [u for u in urls if u.startswith("https://")]
        if not https:
            continue
        base = https[0] if https[0].endswith("/") else https[0] + "/"
        for tld in tlds:
            table[tld.lower()] = base
    if len(table) < 500:
        sys.exit(f"Registre suspect : seulement {len(table)} extensions.")
    return dict(sorted(table.items()))


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path)
    args = parser.parse_args()
    raw = args.source.read_bytes() if args.source else fetch(SOURCE_URL)
    document = json.loads(raw)
    table = servers(document)
    published = document.get("publication", "")[:10]
    digest = hashlib.sha256(raw).hexdigest()
    lines = [
        "// Fichier généré par tools/update_rdap_bootstrap.py : ne pas modifier.",
        "// Source : registre d'amorçage RDAP de l'IANA (RFC 9224),",
        f"// {SOURCE_URL}",
        "",
        "/// Date de publication du registre d'amorçage par l'IANA.",
        f"const rdapBootstrapPublished = {dart_string(published)};",
        "",
        "/// Empreinte SHA-256 du fichier source.",
        f"const rdapBootstrapSha256 = {dart_string(digest)};",
        "",
        "/// Serveur RDAP (https) de chaque extension.",
        "const rdapServers = <String, String>{",
    ]
    for tld, base in table.items():
        lines.append(f"  {dart_string(tld)}: {dart_string(base)},")
    lines.append("};")
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{len(table)} extensions, publication {published} -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
