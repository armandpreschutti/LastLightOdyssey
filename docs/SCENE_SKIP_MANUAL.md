# Reversing Scene Skipping Changes

This document provides instructions on how to restore the cinematic scenes that were skipped for development/testing purposes in `scripts/main.gd`.

## Summary of Changes
To skip scenes, the `.show_scene()` calls were commented out, and their respective completion handlers (e.g., `_on_event_scene_dismissed()`) were called directly. 

## How to Reverse

Open `scripts/main.gd` and search for the following sections to revert:

### 1. Random Events
**Location:** `_trigger_random_event()`
**Revert:**
```gdscript
# Change this:
# event_scene_dialog.show_scene(current_event)
_on_event_scene_dismissed()

# To this:
event_scene_dialog.show_scene(current_event)
# _on_event_scene_dismissed() # Remove this call
```

### 2. Scavenge Missions (Transition)
**Location:** `_process_node_after_jump()` (inside `match pending_node_type:`)
**Revert:**
```gdscript
# Change this:
# mission_scene_dialog.show_scene(pending_biome_type)
_on_mission_scene_dismissed()

# To this:
mission_scene_dialog.show_scene(pending_biome_type)
# _on_mission_scene_dismissed() # Remove this call
```

### 3. Voyage Introduction
**Location:** `_show_voyage_intro()`
**Revert:**
```gdscript
# Change this:
# voyage_intro_scene_dialog.show_scene()
_on_voyage_intro_scene_dismissed()

# To this:
voyage_intro_scene_dialog.show_scene()
# _on_voyage_intro_scene_dismissed() # Remove this call
```

### 4. Game Over Scene
**Location:** `_on_game_over()`
**Revert:**
```gdscript
# Change this:
# game_over_scene_dialog.show_scene(reason)
_on_game_over_scene_dismissed()

# To this:
game_over_scene_dialog.show_scene(reason)
# _on_game_over_scene_dismissed() # Remove this call
```

### 5. Game Won (New Earth Arrival)
**Location:** `_on_game_won()`
**Revert:**
```gdscript
# Change this:
# new_earth_scene.show_scene(ending_type)
_on_new_earth_scene_dismissed()

# To this:
new_earth_scene.show_scene(ending_type)
# _on_new_earth_scene_dismissed() # Remove this call
```

---
*Note: Ensure you remove the forced dismissal calls when restoring the `.show_scene()` calls, otherwise the menus will appear instantly over the starting scenes.*
