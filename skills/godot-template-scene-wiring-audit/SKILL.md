---
name: godot-template-scene-wiring-audit
description: Audit scene/resource wiring integrity for this Godot template. Use when troubleshooting scene load failures, broken ext_resource paths, autoload path mismatches, or suspicious menu/level wiring regressions.
---

# Godot Template Scene Wiring Audit

## Overview

Check path wiring early before debugging runtime behavior.

## Quick Start

Run:

```bash
skills/godot-template-scene-wiring-audit/scripts/audit_paths.sh
```

Optionally pass a project root:

```bash
skills/godot-template-scene-wiring-audit/scripts/audit_paths.sh /abs/path/to/project
```

## What The Script Checks

- `project.godot` `res://` references
- `.tscn` `ext_resource path="res://..."`
- existence of referenced files
- warning if `AppConfig` still points to `addons/.../examples/scenes`
- warning if `SceneLoader` still points to `addons/.../examples/scenes`

## Manual Follow-Up

After script output, inspect:

- `scenes/game_scene/game_ui.tscn`
- `scenes/menus/main_menu/main_menu*.tscn`
- `addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn`
- `addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.tscn`

## Fix Strategy

1. Fix hard missing file references first.
2. Re-run audit script.
3. Then validate runtime flow in editor.

