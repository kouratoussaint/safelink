#!/usr/bin/env python3
"""Vérifie qu'un APK est compatible avec les pages mémoire de 16 Ko.

Google Play refuse les mises à jour dont les bibliothèques natives 64 bits
ne sont pas alignées sur 16 Ko. Pour chaque fichier lib/<abi>/*.so des ABI
arm64-v8a et x86_64, le script contrôle :
- l'alignement des segments ELF chargeables (PT_LOAD) : au moins 16 384 ;
- le décalage du fichier dans l'archive : multiple de 16 384 lorsqu'il est
  stocké sans compression.

Usage : check_16kb_alignment.py <fichier.apk>
"""
import struct
import sys
import zipfile

PAGE = 16 * 1024
ABIS_64_BITS = ("arm64-v8a", "x86_64")
PT_LOAD = 1


def min_load_alignment(elf: bytes) -> int:
    """Plus petit alignement des segments PT_LOAD d'un ELF 64 bits."""
    if elf[:4] != b"\x7fELF" or elf[4] != 2:
        raise ValueError("ELF 64 bits attendu")
    endian = "<" if elf[5] == 1 else ">"
    phoff = struct.unpack_from(endian + "Q", elf, 0x20)[0]
    phentsize, phnum = struct.unpack_from(endian + "HH", elf, 0x36)
    alignments = []
    for i in range(phnum):
        base = phoff + i * phentsize
        if struct.unpack_from(endian + "I", elf, base)[0] == PT_LOAD:
            alignments.append(struct.unpack_from(endian + "Q", elf, base + 0x30)[0])
    if not alignments:
        raise ValueError("aucun segment PT_LOAD")
    return min(alignments)


def data_offset(apk: zipfile.ZipFile, info: zipfile.ZipInfo) -> int:
    """Position des données d'une entrée dans l'archive."""
    apk.fp.seek(info.header_offset)
    header = apk.fp.read(30)
    name_len, extra_len = struct.unpack_from("<HH", header, 26)
    return info.header_offset + 30 + name_len + extra_len


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    failures = 0
    checked = 0
    with zipfile.ZipFile(sys.argv[1]) as apk:
        for info in apk.infolist():
            parts = info.filename.split("/")
            if len(parts) != 3 or parts[0] != "lib" or parts[1] not in ABIS_64_BITS:
                continue
            if not parts[2].endswith(".so"):
                continue
            checked += 1
            alignment = min_load_alignment(apk.read(info))
            problems = []
            if alignment < PAGE:
                problems.append(f"segments alignés sur {alignment} octets")
            if info.compress_type == zipfile.ZIP_STORED:
                offset = data_offset(apk, info)
                if offset % PAGE:
                    problems.append(f"décalage {offset} non multiple de 16 Ko")
            status = "INCOMPATIBLE" if problems else "ok"
            detail = f" ({'; '.join(problems)})" if problems else ""
            print(f"{status:12} {info.filename}{detail}")
            failures += bool(problems)
    if checked == 0:
        print("Aucune bibliothèque native 64 bits trouvée.")
        return 1
    if failures:
        print(f"Échec : {failures} bibliothèque(s) incompatible(s) avec 16 Ko.")
        return 1
    print(f"{checked} bibliothèque(s) compatible(s) avec les pages de 16 Ko.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
