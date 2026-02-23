# Unused / Orphaned Files Report — Last Light Odyssey

*Generated from codebase scan — files not referenced anywhere in the project.*

---

## 1. Scripts (.gd) Not Referenced

| Path | Notes |
|------|-------|
| `scripts/management/infinite_grid_generator.gd` | Class exists but only referenced in docs; map generation uses `progressive_map_generator.gd` and `star_map_generator.gd` instead. |
| `scripts/ui/custom_tooltip_control.gd` | Implements `_make_custom_tooltip`; tooltips are built in code via `tooltip_area.gd` / `tooltip_button.gd` etc. No scene or script loads or extends it. |
| `scripts/ui/colonist_loss_scene_dialog.gd` | Only used by `colonist_loss_scene_dialog.tscn`, which is never loaded. |

**Editor / Debug Tools** (run manually, not part of gameplay):

- `scripts/tools/generate_mining_sprite.gd`
- `scripts/tools/create_mining_sprite.gd`
- `scripts/debug/verify_story_spawn.gd`
- `scripts/verify_map_spread.gd`

---

## 2. Scenes (.tscn) Not Referenced

| Path | Notes |
|------|-------|
| `scenes/ui/colonist_loss_scene_dialog.tscn` | Never `load()`'d or instanced. |
| `scenes/ui/wormhole_dialog.tscn` | Wormhole flow uses `management_hud.set_enter_wormhole_button_active()`; this dialog is never shown. |
| `scenes/ui/custom_tooltip.tscn` | Tooltips are created in code; this scene is never loaded. |
| `scenes/ui/ability_button.tscn` | `ability_panel.gd` creates buttons with `Button.new()` and never loads this scene. |
| `scenes/ui/deploy_button.tscn` | Management HUD and team select use inline `Button` nodes; this scene is never instanced. |
| `scenes/tactical/data_log.tscn` | Built for `retrieve_logs` objective, but `tactical_controller.gd` never loads or spawns it (no `DataLogScene` like SecurityTerminalScene/PowerCoreScene). |
| `scripts/verify_map_spread.tscn` | Debug scene in `scripts/` (likely misplaced). |
| `scenes/debug/verify_story_spawn.tscn` | Debug scene; never instanced. |

---

## 3. Resources (.tres) Not Referenced

| Path | Notes |
|------|-------|
| `assets/themes/style_btn_pause.tres` | Not referenced in code or base theme. |
| `assets/themes/style_btn_pause_hover.tres` | Same as above. |
| `assets/themes/style_btn_end_turn.tres` | Same as above. |
| `assets/themes/style_btn_end_turn_hover.tres` | Same as above. |
| `assets/themes/style_btn_pink.tres` | Same as above. |
| `assets/themes/style_btn_pink_hover.tres` | Same as above. |
| `assets/themes/style_btn_pink_pressed.tres` | Same as above. |

*Used theme resources:* `base_ui_theme.tres`, `style_panel_*`, `style_btn_red*`, `style_btn_green*`, `style_btn_yellow*`.

---

## 4. Assets (Images) Not Used

| Path | Notes |
|------|-------|
| `assets/sprites/ui/generated/Gemini_Generated_Image_lij8yrlij8yrlij8__1_-removebg-preview 1.png` | No references in code or scenes. |
| `scenes/ui/Gemini_Generated_Image_lij8yrlij8yrlij8__1_-removebg-preview 1.png` | Duplicate; also unused. |

---

## 5. Scripts Paired with Unused Scenes

These scripts exist but are **only** used by unused scenes above:

- `scripts/ui/wormhole_dialog.gd` — only used by `wormhole_dialog.tscn`
- `scripts/ui/deploy_button.gd` — only used by `deploy_button.tscn`
- `scripts/tactical/data_log.gd` — only used by `data_log.tscn` (part of intended `retrieve_logs` flow but never spawned)

---

## Summary Table

| Category | Orphaned Count | Notes |
|----------|---------------|-------|
| **Scripts** | 3 core + 4 tools | `infinite_grid_generator`, `custom_tooltip_control`, `colonist_loss_scene_dialog`; others are editor/debug tools. |
| **Scenes** | 8 | Including `wormhole_dialog`, `custom_tooltip`, `ability_button`, `deploy_button`, `data_log`, colonist loss, and 2 debug scenes. |
| **Resources** | 7 | Pause, end-turn, and pink button style resources. |
| **Assets** | 2 | Two copies of an unused Gemini-generated PNG. |

---

## Recommendations

1. **`data_log.tscn`** — The `retrieve_logs` objective exists in mission_objective.gd and the interaction handler in tactical_controller.gd works; what's missing is spawning. Add `DataLogScene = load("res://scenes/tactical/data_log.tscn")` and a spawning block in tactical_controller.gd (similar to SecurityTerminal and PowerCore) when `has_retrieve_logs` is true to complete the feature.

2. **`wormhole_dialog.tscn`** — Either wire it into the wormhole flow or remove it if the current management HUD implementation is final.

3. **`colonist_loss_scene_dialog`** — Either integrate for colonist loss events or delete as unused.

4. **Theme / asset cleanup** — The listed theme resources and Gemini PNGs can be safely deleted if you do not plan to use them.
