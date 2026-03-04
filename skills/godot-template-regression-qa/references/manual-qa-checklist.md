# Manual QA Checklist

## 1. Startup And Scene Flow

1. Launch project and confirm `scenes/opening/opening.tscn` appears.
2. Confirm opening sequence transitions to main menu.
3. From main menu, start a new game and confirm game scene loads.
4. Trigger end flow (or simulate win chain) and confirm end credits/menu path works.

## 2. Gameplay And Pause Flow

1. In game scene, open pause menu with `ui_cancel`.
2. Resume and confirm gameplay input restores correctly.
3. Open pause options and return without focus/input lock.
4. Trigger win and lose windows; verify buttons route correctly (continue/restart/menu/exit).

## 3. Level Management

1. Confirm first level loads from `LevelManager` checkpoint/start path.
2. Confirm win advances to next level when configured.
3. Confirm lose behavior reloads level or opens lose window as intended.
4. Confirm level-specific state (for example color) persists across scene reload.

## 4. Settings And Input

1. Change at least one audio option and reopen scene/project to verify persistence.
2. Change at least one video option and verify applied value on reopen.
3. If input rebinding was touched, verify changed binding works and survives restart.

## 5. Save And Reset Behavior

1. Confirm `GameState` progress path updates during play.
2. Use reset action (if present) and verify progress and checkpoint clear as expected.
3. Confirm post-reset new game starts from intended entry state.

## 6. Platform-Sensitive Checks

1. Native build behavior:
   - Exit buttons should be visible and functional.
2. Web behavior:
   - Exit buttons should be hidden where designed.
   - No hard quit assumption for web-only paths.

