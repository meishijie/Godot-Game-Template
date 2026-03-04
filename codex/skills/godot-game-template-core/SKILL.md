---
name: godot-game-template-core
description: Use for gameplay/features and scene-flow wiring in this Maaack Godot Game Template project. Covers project-first edits (`scenes/`, `scripts/`), level signal contracts, AppConfig path checks, and robust validation in clean environments.
metadata:
  short-description: Godot template feature implementation
---

# Godot Game Template Core

Use this skill when editing gameplay or flow in this repository.

## Trigger cues

- User asks for gameplay implementation, game loop changes, or level logic.
- User asks for scene wiring, menu/level transitions, load screen flow, or AppConfig path fixes.
- User reports level win/lose flow regressions after gameplay edits.

## Goals

- Keep changes compatible with Maaack template flow (`Opening -> Main Menu -> Game UI -> LevelManager -> Win/Lose`)
- Implement features in project `scenes/` and `scripts/` (not only in `addons/.../examples`)
- Preserve level signal contract: `level_lost`, `level_won(next_level_path)`

## Workflow

1. Preflight checks
- Confirm active scene paths are project-local in `addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn`.
- Confirm `SceneLoader` and `LevelManager` still point to valid loading screen and level paths.
- Inspect `project.godot` `[autoload]` and avoid unnecessary singleton renames.
- If your change adds or touches custom script dependencies, map dependency direction first:
  project `scenes/scripts` -> addon base scripts is fine; avoid requiring addon/example scripts to discover project classes at parse time.

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
- After each fix batch, restart and re-run once to avoid acting on stale buffered errors.
- Separate `ERROR`/`SCRIPT ERROR` (must fix) from `WARNING` (can be deferred, but record).

Validation command examples (choose what exists in environment):

- `godot4 --headless --path . --quit`
- `godot --headless --path . --quit`

5. Dependency robustness pattern (important)
- For cross-script calls, prefer explicit constants:
  - `const SOME_SCRIPT := preload("res://path/to/some_script.gd")`
  - call `SOME_SCRIPT.static_fn()` instead of relying on global `class_name` lookup.
- For inheritance across modules, prefer explicit script paths in `extends` when parse order is uncertain.
- Avoid typed exports/annotations that require global custom classes to be registered first (for example custom types in `@export_node_path` or variable type hints). Use `Node`/`Resource` and validate methods at runtime when needed.
- Keep this pattern scoped to changed files; do not rewrite the whole project unless there is repeated breakage.

6. Asset and import resilience
- Startup-critical scenes should not hard-fail on optional textures/icons. Prefer safe defaults (empty arrays / null textures) and feature fallback.
- If imported texture cache is unavailable in a clean environment, avoid introducing new hard dependencies on `.godot/imported/*` artifacts.
- Treat UI icon assets as optional unless gameplay depends on them.

## Minimal completion checklist

- Gameplay changes are in project files (`scenes/` / `scripts/`) and not only addon examples.
- Level scripts still emit `level_won(next_level_path)` and `level_lost`.
- AppConfig and menu flow still open the intended project scenes.
- At least one runtime/headless validation pass was performed and checked.

7. UID hygiene
- If many resources were moved/renamed or you see broad `invalid UID` warnings, run project UID refresh (`update_project_uids`) as a cleanup step.
- Do not block gameplay fixes on UID cleanup if runtime is otherwise healthy; schedule UID cleanup as a focused follow-up.

## Common pitfalls (feedback-driven)

- `AppConfig` may still target `addons/.../examples` even after project scenes exist.
- New gameplay may be implemented in project scenes but never loaded because of old AppConfig paths.
- In some environments, relying only on `class_name` discovery can fail during first-run parsing; explicit `preload` usage in key scripts improves robustness.
- Custom class names inside export/type annotations can break scene loading before gameplay code runs.
- Fixing one parser error often reveals the next dependency edge; iterate in small cycles (`edit -> rerun -> narrow next error`).

## Editing scope guidelines

- Primary edit targets:
- `scenes/game_scene/levels/*`
- `scenes/game_scene/game_ui.tscn`
- `scenes/menus/main_menu/*`
- `scripts/game_state.gd`
- `addons/maaacks_game_template/base/nodes/autoloads/app_config/*` (only when flow/paths require it)

- Avoid broad modifications under `addons/maaacks_game_template/examples` unless project flow explicitly uses those files.
