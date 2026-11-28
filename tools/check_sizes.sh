#!/usr/bin/env bash
# Garde-fou de taille : aucun script GDScript ne dépasse MAX lignes (400 par défaut).
# Un fichier qui grossit se découpe en modules (voir scripts/level/ et scripts/player/).
set -euo pipefail
MAX="${MAX:-400}"
cd "$(dirname "$0")/.."
bad=0
while IFS= read -r f; do
  n=$(wc -l < "$f")
  if [ "$n" -gt "$MAX" ]; then
    echo "TROP LONG : $f ($n lignes > $MAX)"
    bad=1
  fi
done < <(find . -name '*.gd' -not -path './.godot/*' -not -path './addons/*' | sort)
echo "Plus gros scripts :"
find . -name '*.gd' -not -path './.godot/*' -not -path './addons/*' -exec wc -l {} + | sort -rn | sed -n '2,6p'
exit $bad
