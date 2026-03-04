---
name: godot-template-state-persistence
description: Safely extend or modify persistent state in this Godot template. Use when changing GameState, LevelState, GlobalState, AppSettings, or PlayerConfig data and save/load behavior.
---

# Godot Template State Persistence

## Overview

Change persistent data with backward-safe defaults and explicit save points.

## State Map

- Game progress state:
  - `scripts/game_state.gd`
  - `scripts/level_state.gd`
  - `addons/maaacks_game_template/base/nodes/state/global_state.gd`
  - `addons/maaacks_game_template/base/nodes/state/global_state_data.gd`
- Player settings state:
  - `addons/maaacks_game_template/base/nodes/config/player_config.gd`
  - `addons/maaacks_game_template/base/nodes/config/app_settings.gd`

## Add Or Change A Persistent Field

1. Add `@export` field with a safe default.
2. Update read/write call sites.
3. Call `GlobalState.save()` after state mutation where needed.
4. Ensure reset paths are consistent:
   - `GameState.reset()`
   - any UI reset action that implies state reset
5. Validate behavior with both fresh and existing save files.

## Compatibility Rules

- Never assume existing save files contain new keys.
- Prefer fallback behavior over hard failures.
- Keep missing-key behavior deterministic and user-safe.

## Review Checklist

- New field has a default value.
- All write paths save explicitly.
- Reset behavior is intentional and documented in change summary.
- No accidental coupling between config state and game progress state.

