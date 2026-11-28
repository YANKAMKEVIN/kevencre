#!/usr/bin/env bash
# Télécharge Godot 4.3 (Linux), vérifie son empreinte et l'installe dans $1 (défaut : ./.godot-bin).
# Affiche le chemin de l'exécutable.
set -euo pipefail
DEST="${1:-.godot-bin}"
BIN="$DEST/Godot_v4.3-stable_linux.x86_64"
SHA="7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DEST"
  curl --fail --location --retry 3 --silent --show-error --output "$DEST/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
  echo "$SHA  $DEST/godot.zip" | sha256sum --check --quiet
  unzip -q -o "$DEST/godot.zip" -d "$DEST"
  rm "$DEST/godot.zip"
  chmod +x "$BIN"
fi
echo "$(cd "$DEST" && pwd)/Godot_v4.3-stable_linux.x86_64"
