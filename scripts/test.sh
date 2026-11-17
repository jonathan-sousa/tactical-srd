#!/usr/bin/env bash
# Lance toute la suite gdUnit4 en mode headless.
#
# Usage : GODOT_BIN=/chemin/vers/godot scripts/test.sh [options gdUnit4]
# Sans option, exécute tout le dossier res://tests.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -z "${GODOT_BIN:-}" ]; then
	echo "Définir GODOT_BIN avec le chemin de l'exécutable Godot 4.7." >&2
	exit 1
fi

# Importe les ressources et enregistre les class_name : indispensable sur un
# clone neuf, où le dossier .godot/ n'existe pas encore.
"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1 || true

args=("$@")
if [ ${#args[@]} -eq 0 ]; then
	args=(-a res://tests)
fi

exec addons/gdUnit4/runtest.sh --godot_binary "$GODOT_BIN" --headless --ignoreHeadlessMode -c "${args[@]}"
