#!/usr/bin/env bash
# Vérifie qu'un APK ne déclare que les permissions Android autorisées.
#
# Usage : tools/check_apk_permissions.sh <fichier.apk> [permission ...]
#
# Les permissions passées en arguments sont autorisées en plus de la
# permission interne <paquet>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION,
# ajoutée par AndroidX, protégée par signature et invisible des autres
# applications. Toute autre permission fait échouer le script (code 1).
#
# Exemple (lot E) :
#   tools/check_apk_permissions.sh app-release.apk android.permission.CAMERA
set -euo pipefail

apk="${1:?Usage : check_apk_permissions.sh <fichier.apk> [permission ...]}"
shift
allowed=("$@")

if command -v aapt2 >/dev/null 2>&1; then
  aapt2="$(command -v aapt2)"
else
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  aapt2="$(ls -d "$sdk"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1)"
fi
if [[ -z "${aapt2:-}" || ! -x "$aapt2" ]]; then
  echo "aapt2 introuvable : définir ANDROID_HOME ou l'ajouter au PATH." >&2
  exit 2
fi

package="$("$aapt2" dump packagename "$apk")"
allowed+=("${package}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION")

mapfile -t declared < <(
  "$aapt2" dump permissions "$apk" |
    sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort -u
)

echo "Paquet : $package"
echo "Permissions déclarées (${#declared[@]}) :"
status=0
for permission in "${declared[@]}"; do
  ok=0
  for candidate in "${allowed[@]}"; do
    [[ "$permission" == "$candidate" ]] && ok=1 && break
  done
  if [[ $ok -eq 1 ]]; then
    echo "  autorisée : $permission"
  else
    echo "  INTERDITE : $permission" >&2
    status=1
  fi
done
if [[ $status -ne 0 ]]; then
  echo "Échec : l'APK déclare une permission hors de la liste autorisée." >&2
fi
exit $status
