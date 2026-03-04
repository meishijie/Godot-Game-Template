# Godot-Game-Template AI 开发指南

本文件面向后续 AI coding 代理，目标是让代理在当前项目中快速、安全地做增量开发。

## 1. 项目定位

- 引擎版本：Godot 4.6（模板宣称 4.3+ 兼容）。
- 项目本质：基于 `maaacks_game_template` 的菜单/加载/设置框架 + 当前仓库内的业务定制场景与脚本。
- 主入口：`res://scenes/opening/opening.tscn`（见 `project.godot`）。

## 2. 架构分层（必须遵守）

### A. 框架层（尽量不改）

- 路径：`addons/maaacks_game_template/base`、`addons/maaacks_game_template/extras`
- 职责：通用菜单、加载器、配置系统、窗口系统、关卡管理工具。
- 原则：除非明确要修框架 bug，否则优先“继承 + 覆盖”，不要直接改框架源码。

### B. 项目定制层（优先改这里）

- 路径：`scenes/`、`scripts/`、`resources/`、`assets/`
- 职责：游戏流程、状态定义、UI 定制、关卡内容、文案与资源。

### C. 配置入口层

- `project.godot`：主场景、autoload、输入映射、渲染配置。
- `override.cfg`：输入覆盖（尤其手柄相关）。

## 3. 启动与运行链路

1. `opening.tscn`（开场图序列）
2. `MainMenu`（新游戏/继续/选项/制作人员）
3. `game_ui.tscn`（Pause、LevelLoader、LevelManager、SubViewport、计时）
4. `levels/level_1..3.tscn`（发出 `level_won/level_lost` 信号）
5. 胜负窗口或结束场景（End Credits）

关键文件：

- `scenes/opening/opening.tscn`
- `scenes/menus/main_menu/main_menu*.tscn`
- `scenes/game_scene/game_ui.tscn`
- `scenes/game_scene/levels/level.gd`
- `scenes/end_credits/end_credits.tscn`

## 4. 全局单例（Autoload）职责

在 `project.godot` 中注册：

- `AppConfig`：场景路径配置 + 启动时加载配置。
- `SceneLoader`：异步加载/切场景/加载屏。
- `ProjectMusicController`：跨场景背景音乐接管与淡入淡出。
- `ProjectUISoundController`：UI 控件音效自动挂接。

说明：这些 autoload 本体在 `addons/maaacks_game_template/base/nodes/autoloads/*`。

## 5. 状态与持久化模型

### 配置持久化

- `PlayerConfig` -> `user://player_config.cfg`
- `AppSettings` 负责把配置应用到 Input/Audio/Video

### 游戏状态持久化

- `GlobalState` -> `user://global_state.tres`
- `GameState`（项目脚本）保存：
  - `level_states`（每关状态字典）
  - `current_level_path`
  - `checkpoint_level_path`
  - `play_time` / `total_time`
- `LevelState`（项目脚本）保存每关字段（如颜色、tutorial_read）

## 6. 常见开发任务与改动落点

### 新增/修改关卡

- 新增场景到 `scenes/game_scene/levels/`
- 在 `scenes/game_scene/game_ui.tscn` 的 `LevelManager/SceneLister.files` 中登记顺序
- 如需串关，设置各关 `next_level_path`

### 修改主菜单流程

- 首选改 `scenes/menus/main_menu/main_menu.gd`
- 若涉及动画流程，改 `main_menu_with_animations.gd/.tscn`
- 新窗口优先复用 `scenes/windows/*` + `OverlaidWindow` 体系

### 修改暂停菜单

- `scenes/windows/pause_menu*.tscn/.gd`
- 由 `PauseMenuController` 在 `game_ui.tscn` 内触发

### 新增可保存的游戏字段

1. 在 `scripts/game_state.gd` 或 `scripts/level_state.gd` 增加 `@export` 字段  
2. 在读写路径中接入 `GlobalState.save()`  
3. 注意兼容旧存档（默认值安全）

### 修改选项菜单

- 聚合页：`scenes/menus/options_menu/master_options_menu_with_tabs.tscn`
- 游戏页：`scenes/menus/options_menu/game/*`
- 重置逻辑：`reset_game_control.gd` + `GameState.reset()`

## 7. 已知关键坑（高优先级）

1. `AppConfig` 默认仍可能指向 `addons/.../examples/scenes/*` 路径。  
   若你要运行/发布项目自有 `scenes/`，务必核对：
   - `addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn`
   - `addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.tscn`

2. 不要直接把业务逻辑塞进 `addons` 基础脚本。  
   推荐在 `scenes/` + `scripts/` 继承扩展，降低升级冲突。

3. 菜单/弹窗流程依赖信号链。  
   改按钮行为时先确认信号连接未断（`.tscn` 内 `[connection]`）。

## 8. AI 代码改动约束

- 优先最小改动，不做无关重构。
- 不随意重命名 scene/node/script 路径（Godot 资源引用强依赖路径）。
- 新增文件后，确保 `.tscn` 的 `ext_resource` 路径有效。
- 变更输入动作时同步检查 `project.godot` 与 `override.cfg`。
- 若改动加载流程，至少手动验证：
  - opening -> main menu
  - new game -> level load
  - pause/resume
  - win/lose 分支
  - options 修改后重启仍生效

## 9. 推荐开发流程（给代理）

1. 先读 `project.godot` + 目标场景 `.tscn` + 相关 `.gd`
2. 标注改动边界（框架层 or 项目层）
3. 实施最小 patch
4. 自查引用路径、信号、autoload 调用
5. 输出变更说明 + 待人工验证清单

## 10. 快速索引

- 项目状态脚本：`scripts/game_state.gd`、`scripts/level_state.gd`
- 关卡状态管理桥接：`scripts/level_and_state_manager.gd`
- 运行主游戏场景：`scenes/game_scene/game_ui.tscn`
- 主菜单：`scenes/menus/main_menu/main_menu.tscn`
- 暂停菜单：`scenes/windows/pause_menu_layer.tscn`
- 加载屏：`scenes/loading_screen/level_loading_screen.tscn`

