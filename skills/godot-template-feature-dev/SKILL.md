---
name: godot-template-feature-dev
description: Implement gameplay or UI features in this Godot Game Template with minimal-risk changes. Use when adding or modifying menus, windows, levels, tutorials, or flow logic under scenes/ and scripts/, while preserving addon boundaries and signal wiring.
---

# Godot Template Feature Dev

## Overview

Implement feature changes in project-owned files first, and keep framework (`addons/`) edits as opt-in only.

## Follow This Workflow

1. Read entry and flow context first.
2. Read only affected scene/script pairs.
3. Patch the smallest safe surface.
4. Verify signal wiring and scene references.
5. Provide a concise manual test list.

## Read These Files First

- `project.godot`
- `scenes/opening/opening.tscn`
- `scenes/menus/main_menu/main_menu.tscn`
- `scenes/game_scene/game_ui.tscn`

Then load target files for the requested feature.

## Change Boundaries

- Prefer editing:
  - `scenes/**`
  - `scripts/**`
  - `resources/**`
- Avoid editing by default:
  - `addons/maaacks_game_template/**`
- Edit addon files only if the user explicitly asks or the bug is proven to be inside addon base logic.

## Implementation Rules

- Keep `NodePath`, signal names, and scene paths stable unless required by the task.
- Avoid broad refactors during feature work.
- Preserve existing pause/load/menu flow behavior unless explicitly changing it.
- If adding a new scene, ensure all referencing `.tscn` files use valid `ext_resource path`.

## Done Criteria

- New behavior works in intended entry point.
- Existing flow still works:
  - opening -> main menu
  - main menu -> game scene
  - pause -> resume
- No broken scene resource path references.

