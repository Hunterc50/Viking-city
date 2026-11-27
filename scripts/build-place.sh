#!/usr/bin/env bash
# Rebuilds the ready-to-open place file from the code in src/.
# Run this after every code change so VikingCity.rbxlx stays up to date.
set -euo pipefail
cd "$(dirname "$0")/.."
rojo build default.project.json -o VikingCity.rbxlx
echo "Built VikingCity.rbxlx"
