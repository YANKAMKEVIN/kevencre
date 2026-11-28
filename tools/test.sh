#!/usr/bin/env bash
# Vérifications headless, comme la CI : import sans erreur, taille des scripts, chargement de tous
# les scripts, tests unitaires et d'intégration, parcours (modèle contre moteur + atteignabilité).
# Usage : GODOT=/chemin/godot tools/test.sh [import|sizes|check|unit|parcours]...   (défaut : tout)
#         PARCOURS_ARGS="--niveau=2" pour un seul chapitre.
# Le robot qui joue toute la partie (plus long, avec écran virtuel) : tools/ci.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${OUT:-ci-out}"
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p "$OUT"
steps=("$@")
[ ${#steps[@]} -eq 0 ] && steps=(import sizes check unit parcours)
SCRIPT_ERRORS='SCRIPT ERROR|Parse Error|Failed to load script|Compile Error'

run_godot() {   # run_godot <journal> <arguments...> : échoue sur un code non nul ou une erreur de script
  local log="$OUT/$1"; shift
  "$GODOT" --headless --path . --fixed-fps 60 "$@" > "$log" 2>&1
  local code=$?
  grep -E '^(ECHEC|RESULTAT|CHECK)|^      ' "$log" || true
  if grep -E "$SCRIPT_ERRORS" "$log"; then echo "ÉCHEC : erreur de script ($log)"; return 1; fi
  if [ $code -ne 0 ]; then echo "ÉCHEC : code $code ($log)"; return 1; fi
}

fail=0
for s in "${steps[@]}"; do
  echo "== $s"
  case "$s" in
    import)
      "$GODOT" --headless --path . --import > "$OUT/import1.log" 2>&1 || true   # 1er import : polices pas encore prêtes
      "$GODOT" --headless --path . --import > "$OUT/import.log" 2>&1 || true
      if grep -E "$SCRIPT_ERRORS|^ERROR:" "$OUT/import.log"; then echo "ÉCHEC : erreurs à l'import"; fail=1; fi ;;
    sizes) tools/check_sizes.sh || fail=1 ;;
    check) run_godot check.log -- --check || fail=1 ;;
    unit) run_godot unit.log -- --unit || fail=1 ;;
    parcours) run_godot parcours.log -- --parcours ${PARCOURS_ARGS:-} || fail=1 ;;
    *) echo "étape inconnue : $s"; fail=1 ;;
  esac
done
[ $fail -eq 0 ] && echo "Tout est vert." || echo "ÉCHEC."
exit $fail
