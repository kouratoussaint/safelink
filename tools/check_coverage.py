#!/usr/bin/env python3
"""Vérifie qu'un rapport lcov atteint un taux minimal de couverture de lignes.

Usage : check_coverage.py <lcov.info> <taux_minimal_en_pourcent> [préfixe]

Seuls les fichiers dont le chemin contient le préfixe (par défaut « lib/ »)
sont comptés. Le script échoue (code 1) si le taux est inférieur au seuil.
"""
import sys


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    path, minimum = sys.argv[1], float(sys.argv[2])
    prefix = sys.argv[3] if len(sys.argv) > 3 else "lib/"
    found = hit = 0
    current = None
    per_file = {}
    with open(path, encoding="utf-8") as report:
        for line in report:
            line = line.strip()
            if line.startswith("SF:"):
                current = line[3:]
            elif line.startswith("DA:") and current and prefix in current:
                _, count = line[3:].split(",")[:2]
                found += 1
                covered = int(count) > 0
                hit += covered
                f, h = per_file.get(current, (0, 0))
                per_file[current] = (f + 1, h + covered)
    if found == 0:
        print(f"Aucune ligne trouvée pour le préfixe « {prefix} ».")
        return 1
    rate = 100.0 * hit / found
    for name, (f, h) in sorted(per_file.items()):
        print(f"{100.0 * h / f:6.1f} %  {name}")
    print(f"Couverture totale : {rate:.1f} % ({hit}/{found} lignes), seuil {minimum:.0f} %")
    return 0 if rate >= minimum else 1


if __name__ == "__main__":
    sys.exit(main())
