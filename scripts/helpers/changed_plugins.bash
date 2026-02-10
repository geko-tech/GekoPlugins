#!/usr/bin/env bash
set -euo pipefail

PLUGINS_FILE="plugins.json"

changed_files=$(git --no-pager diff --name-only --merge-base FETCH_HEAD)

if [[ -z "$changed_files" ]]; then
  exit 0
fi

plugins=$(jq -r '.plugins[].name' "$PLUGINS_FILE")

changed_plugins=()

for plugin in $plugins; do
  if echo "$changed_files" | grep -q "^${plugin}/"; then
    changed_plugins+=("$plugin")
  fi
done

jq -nc '$ARGS.positional' --args "${changed_plugins[@]}"
