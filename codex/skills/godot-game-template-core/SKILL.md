---
name: godot-game-template-core
description: Use for implementing gameplay/features in this Maaack Godot Game Template project (menus, levels, state, loading flow). Includes a practical workflow for wiring new game loops into level signals, AppConfig scene paths, and template-compatible validation.
metadata:
  short-description: Godot template feature implementation
---

# Godot Game Template Core

Use this skill when editing gameplay or flow in this repository.

## Goals

- Keep changes compatible with Maaack template flow (`Opening -> Main Menu -> Game UI -> LevelManager -> Win/Lose`)
- Implement features in project `scenes/` and `scripts/` (not only in `addons/.../examples`)
- Preserve level signal contract: `level_lost`, `level_won(next_level_path)`

## Workflow

1. Preflight checks
- Confirm active scene paths are project-local in `addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn`.
- Confirm `SceneLoader` and `LevelManager` still point to valid loading screen and level paths.
- Inspect `project.godot` `[autoload]` and avoid unnecessary singleton renames.

2. Implement gameplay
- Prefer a reusable gameplay script for all levels and set difficulty via exported fields in `level_1/2/3.tscn`.
- Keep root level scene as `Control` unless there is a strong reason not to.
- Emit `level_won` / `level_lost` from level script instead of calling scene loads directly.

3. Integrate with template UI
- Update menu scene to expose level select if progression is desired.
- Keep pause/credits/options scenes functional by not changing base signal names.

4. Validate
- Run Godot once and inspect debug output.
- If parser errors are from unresolved `class_name` symbols in headless/clean environments, prefer explicit `preload` references in touched scripts rather than broad architecture rewrites.
- Verify there are no broken scene/script paths after edits.

## Common pitfalls (feedback-driven)

- `AppConfig` may still target `addons/.../examples` even after project scenes exist.
- New gameplay may be implemented in project scenes but never loaded because of old AppConfig paths.
- In some environments, relying only on `class_name` discovery can fail during first-run parsing; explicit `preload` usage in key scripts improves robustness.

## Editing scope guidelines

- Primary edit targets:
- `scenes/game_scene/levels/*`
- `scenes/game_scene/game_ui.tscn`
- `scenes/menus/main_menu/*`
- `scripts/game_state.gd`
- `addons/maaacks_game_template/base/nodes/autoloads/app_config/*` (only when flow/paths require it)

- Avoid broad modifications under `addons/maaacks_game_template/examples` unless project flow explicitly uses those files.
