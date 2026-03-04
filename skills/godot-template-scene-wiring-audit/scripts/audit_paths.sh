#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-}"
if [[ -z "${PROJECT_ROOT}" ]]; then
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    PROJECT_ROOT="${git_root}"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi

cd "${PROJECT_ROOT}"

missing_count=0
warn_count=0

check_path() {
  local res_path="$1"
  local origin="$2"

  local rel="${res_path#res://}"
  if [[ ! -e "${rel}" ]]; then
    echo "[MISSING] ${origin} -> ${res_path}"
    missing_count=$((missing_count + 1))
  fi
}

echo "== Godot path audit =="
echo "Project root: ${PROJECT_ROOT}"

if [[ -f "project.godot" ]]; then
  while IFS= read -r line; do
    while [[ "${line}" =~ res://[A-Za-z0-9_./-]+ ]]; do
      res_path="${BASH_REMATCH[0]}"
      check_path "${res_path}" "project.godot"
      line="${line#*${res_path}}"
    done
  done < "project.godot"
else
  echo "[ERROR] project.godot not found"
  exit 2
fi

while IFS= read -r scene_file; do
  while IFS= read -r line; do
    while [[ "${line}" =~ path=\"(res://[^\"]+)\" ]]; do
      res_path="${BASH_REMATCH[1]}"
      check_path "${res_path}" "${scene_file}"
      line="${line#*path=\"${res_path}\"}"
    done
  done < "${scene_file}"
done < <(find . -name "*.tscn" -type f | sed 's#^\./##' | sort)

app_config="addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn"
scene_loader="addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.tscn"

if [[ -f "${app_config}" ]] && rg -q "addons/maaacks_game_template/examples/scenes" "${app_config}"; then
  echo "[WARN] AppConfig still points to addons examples scenes: ${app_config}"
  warn_count=$((warn_count + 1))
fi

if [[ -f "${scene_loader}" ]] && rg -q "addons/maaacks_game_template/examples/scenes" "${scene_loader}"; then
  echo "[WARN] SceneLoader loading screen still points to addons examples: ${scene_loader}"
  warn_count=$((warn_count + 1))
fi

echo
echo "Missing refs: ${missing_count}"
echo "Warnings: ${warn_count}"

if [[ "${missing_count}" -gt 0 ]]; then
  exit 1
fi

exit 0

