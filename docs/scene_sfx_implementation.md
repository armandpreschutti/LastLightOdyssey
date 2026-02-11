# Scene SFX Implementation

## Overview
Implemented a dedicated audio channel for "Event Scenes" to allow independent volume control and immediate stopping of scene-specific audio when a scene is dismissed.

## Key Changes

### 1. SFXManager
- Added `scene_player` (AudioStreamPlayer) dedicated to scene SFX.
- Added `scene_volume` (0-100) property.
- Added `play_scene_sfx(path)` which stops any currently playing scene SFX before playing the new one.
- Added `stop_scene_sfx()` to immediately cut scene audio.

### 2. Settings Menu
- Added "Scenes" volume slider (0-100%) between SFX and Music sliders.
- Connected slider to `SFXManager.set_scene_volume()`.
- Persists volume setting in `user://settings.cfg` under `[audio] scene`.

### 3. Scene Dialogs
Refactored all scene dialogs to use `SFXManager.play_scene_sfx()` instead of generic `SFXManager.play_sfx()`.
Updated `BaseSceneDialog` to automatically call `SFXManager.stop_scene_sfx()` when `_on_dismissed()` is triggered.

Affected Scenes:
- Event Scene (`event_scene_dialog.gd`)
- Mission Scene (`mission_scene_dialog.gd`)
- Colonist Loss Scene (`colonist_loss_scene_dialog.gd`)
- Objective Complete Scene (`objective_complete_scene_dialog.gd`)
- Enemy Elimination Scene (`enemy_elimination_scene_dialog.gd`)
- New Earth Scene (`new_earth_scene_dialog.gd`)
- Game Over Scene (`game_over_scene_dialog.gd`)
- Voyage Intro Scene (`voyage_intro_scene_dialog.gd`)

### 4. New SFX Implementation
Added specific SFX triggers for:
- **Beam Up/Down**: `TacticalController.gd` (triggers `beam.mp3` on animation start).
- **Extraction**: `MissionRecap.gd` (triggers `extraction_complete.mp3` or `extraction_failed.mp3`).
- **Outpost Arrival**: `Main.gd` (triggers `outpost_arrival.mp3` on arrival).
- **Voyage Failure**: `GameOverRecap.gd` (triggers `voyage_failure.mp3`).

### 5. Audio Generation
Updated `tools/generate_scene_sfx.py` to:
- Generate louder SFX (0.95 amplitude vs 0.8).
- Include new SFX: `beam.mp3`, `extraction_complete.mp3`, `extraction_failed.mp3`, `outpost_arrival.mp3`, `voyage_failure.mp3`.
- Regenerated all scene SFX files.
