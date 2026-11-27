#!/usr/bin/env python3
"""Vérifie les licences de toutes les dépendances Dart verrouillées.

Lit un ou plusieurs fichiers pubspec.lock, interroge pub.dev pour chaque
paquet hébergé et échoue si une licence n'est pas dans la liste autorisée,
compatible avec la GPL-3.0-or-later du projet.

Pourquoi ce script : la revue des dépendances de GitHub ne sait pas valider
les licences des paquets Dart. Elle conserve le contrôle des vulnérabilités ;
les licences sont vérifiées ici, à la source.

Limite connue : pub.dev publie la licence détectée sur la dernière version
d'un paquet, pas sur chaque version. Un changement de licence entre la
version verrouillée et la dernière ne serait donc pas vu ; ce cas est rare et
la revue manuelle des mises à jour Dependabot le couvre.

Usage : check_licenses.py <pubspec.lock> [<pubspec.lock> ...]
"""
import concurrent.futures
import json
import sys
import time
import urllib.error
import urllib.request

# Identifiants SPDX (en minuscules, comme pub.dev) compatibles avec la
# GPL-3.0-or-later.
ALLOWED = {
    "mit",
    "bsd-2-clause",
    "bsd-3-clause",
    "apache-2.0",
    "isc",
    "zlib",
    "mpl-2.0",
    "unicode-3.0",
    "unicode-dfs-2016",
    "gpl-3.0",
    "gpl-3.0-only",
    "gpl-3.0-or-later",
    "lgpl-3.0",
    "lgpl-3.0-or-later",
}

# Étiquettes de pub.dev qui qualifient une licence sans la nommer.
META_TAGS = {"osi-approved", "fsf-libre"}


def locked_packages(path: str) -> dict[str, str]:
    """Paquets hébergés sur pub.dev d'un pubspec.lock : nom → version."""
    packages: dict[str, str] = {}
    name = source = version = None
    in_packages = False

    def flush() -> None:
        if name and source == "hosted" and version:
            packages[name] = version

    with open(path, encoding="utf-8") as lock:
        for raw in lock:
            line = raw.rstrip("\n")
            if not line.strip():
                continue
            indent = len(line) - len(line.lstrip(" "))
            text = line.strip()
            if indent == 0:
                if in_packages:
                    flush()
                    name = source = version = None
                in_packages = text == "packages:"
                continue
            if not in_packages:
                continue
            if indent == 2 and text.endswith(":"):
                flush()
                name, source, version = text[:-1].strip('"'), None, None
            elif indent == 4 and text.startswith("source:"):
                source = text.split(":", 1)[1].strip()
            elif indent == 4 and text.startswith("version:"):
                version = text.split(":", 1)[1].strip().strip('"')
    if in_packages:
        flush()
    return packages


def licenses_of(package: str) -> set[str]:
    """Licences SPDX détectées par pub.dev pour un paquet."""
    url = f"https://pub.dev/api/packages/{package}/score"
    for attempt in range(4):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "safelink-license-check"}
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                tags = json.load(response).get("tags", [])
            return {
                tag.split(":", 1)[1]
                for tag in tags
                if tag.startswith("license:")
                and tag.split(":", 1)[1] not in META_TAGS
            }
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return set()
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))
        except (urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(2 * (attempt + 1))
    return set()


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    packages: dict[str, set[str]] = {}
    for path in sys.argv[1:]:
        for name, version in locked_packages(path).items():
            packages.setdefault(name, set()).add(f"{version} ({path})")
    if not packages:
        print("Aucun paquet hébergé trouvé.")
        return 1

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = dict(zip(packages, pool.map(licenses_of, packages)))

    failures = 0
    for name in sorted(results):
        found = results[name]
        ok = bool(found) and found <= ALLOWED
        label = ", ".join(sorted(found)) or "non détectée"
        if not ok:
            failures += 1
            where = "; ".join(sorted(packages[name]))
            print(f"REFUSÉE  {name} : {label} — {where}")
    print(
        f"{len(results)} paquets vérifiés, "
        f"{len(results) - failures} conformes, {failures} refusé(s)."
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
