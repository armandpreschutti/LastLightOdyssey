# Unit Ability System Implementation Guide

**Last Light Odyssey - Ability System**
*Complete implementation of 18 unit abilities with tactical integration*

---

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Ability Definitions](#ability-definitions)
4. [Usage](#usage)
5. [Implementation Details](#implementation-details)
6. [Extending the System](#extending-the-system)
7. [Status Effects](#status-effects)

---

## System Overview

The ability system provides **6 classes × 3 tiers = 18 total abilities** that officers can unlock and use during tactical missions.

### Key Features
- ✅ **Data-Driven** - All abilities defined in `GameState.ABILITY_DEFS`
- ✅ **AP-Based** - Each ability has an AP cost
- ✅ **Cooldown Management** - Automatic cooldown tracking
- ✅ **Status Effects** - Buffs/debuffs with visual feedback
- ✅ **Passive & Active** - Both types supported
- ✅ **Damage Modifiers** - Abilities affect combat stats
- ✅ **HUD Integration** - AbilityPanel shows available abilities

---

## Architecture

### File Structure

```
scripts/
├── autoload/
│   └── game_state.gd              # ABILITY_DEFS + helper functions
├── tactical/
│   ├── officer_unit.gd             # Ability implementations + status effects
│   └── tactical_controller.gd       # Ability usage handler
└── ui/
    ├── ability_panel.gd            # Ability panel controller
    └── tactical_hud.gd             # HUD integration

scenes/ui/
├── ability_panel.tscn              # Ability panel UI
└── ability_button.tscn             # Button template

docs/
└── ABILITY_SYSTEM_GUIDE.md         # This file
```

### Component Flow

```
AbilityPanel (UI)
    ↓ (ability_selected signal)
TacticalHUD (signal relay)
    ↓ (ability_used signal)
TacticalController (_on_ability_used)
    ↓
_use_upgraded_ability()
    ↓
OfficerUnit (apply_* methods)
    ↓
GameState (ABILITY_DEFS lookup)
```

---

## Ability Definitions

All 18 abilities are defined in `GameState.ABILITY_DEFS` as a Dictionary.

### Structure

```gdscript
"ability_id": {
    "name": "Display Name",
    "desc": "Full description for tooltips",
    "level": 1,              # 1 = base, 2 = level 2, 3 = level 3
    "slot": "base|a|b|c",    # Unlock slot
    "type": "active|passive",
    "cost": 1,               # AP cost (0 for free, passive N/A)
    "cooldown": 2,           # Turn cooldown (default 2)
    # Optional modifiers
    "cooldown_override": 0,  # Override cooldown
    "damage_multiplier": 2.0,
    "modifies": "base_ability",
    "aura_range": 4,
    # ... more as needed
}
```

### Example Definitions

#### Base Ability (Execute)
```gdscript
"execute": {
    "name": "Execute",
    "desc": "Guaranteed kill on enemy below 50% HP. 2-turn cooldown.",
    "level": 1,
    "slot": "base",
    "type": "active",
    "cost": 1
}
```

#### Passive Upgrade (Warlord)
```gdscript
"warlord": {
    "name": "Warlord",
    "desc": "Execute has no cooldown. Chain multiple executions.",
    "level": 3,
    "slot": "a",
    "type": "passive",
    "cooldown_override": 0,
    "modifies": "execute"
}
```

#### Active Ability with Duration (Phantom)
```gdscript
"phantom": {
    "name": "Phantom",
    "desc": "Become invisible for 2 turns.",
    "level": 3,
    "slot": "b",
    "type": "active",
    "cost": 1,
    "duration": 2
}
```

---

## Usage

### For Players

1. **During Tactical Mission:**
   - Select an officer
   - Click **"ABILITIES"** button on the HUD
   - AbilityPanel shows all unlocked abilities
   - Click an ability to use it
   - Panel closes, ability activates

2. **Ability Requirements:**
   - Must have enough AP (shown in brackets)
   - Cannot be on cooldown
   - Passive abilities are always active

### For Designers

#### Add a New Ability

1. **Define in GameState.gd:**
```gdscript
const ABILITY_DEFS: Dictionary = {
    # ... existing abilities
    "my_new_ability": {
        "name": "My New Ability",
        "desc": "Does something cool",
        "level": 2,
        "slot": "a",
        "type": "active",
        "cost": 1,
        "cooldown": 3
    }
}
```

2. **Implement in OfficerUnit.gd:**
```gdscript
## My Custom Ability
func apply_my_new_ability(target: Node2D) -> bool:
    if not use_ap(1):
        return false
    if is_ability_on_cooldown():
        return false

    var od = GameState.get_officer(officer_key)
    if not od or not od.has_ability("my_new_ability"):
        return false

    # Apply effect logic here
    target.take_damage(50)
    target.add_status_effect("stunned", 1)

    _start_cooldown(3)
    return true
```

3. **Add to Officer's Ability List:**
```gdscript
const OFFICER_ABILITIES: Dictionary = {
    "captain": ["execute", "lead_by_example", ..., "my_new_ability"],
    # ... etc
}
```

---

## Implementation Details

### Helper Functions in GameState

```gdscript
# Get ability definition
get_ability_def(ability_id: String) -> Dictionary

# Get ability properties
get_ability_cost(ability_id: String) -> int
get_ability_type(ability_id: String) -> String
get_ability_cooldown(ability_id: String) -> int
get_ability_cooldown_override(ability_id: String) -> int
get_ability_damage_multiplier(ability_id: String) -> float
```

### Methods in OfficerUnit

#### Ability Management
```gdscript
use_ability_by_id(ability_id: String) -> bool
get_effective_ability_cooldown(ability_id: String) -> int
get_ability_damage_multiplier(ability_id: String) -> float
has_ability_unlocked(ability_id: String) -> bool
```

#### Status Effects
```gdscript
add_status_effect(effect_name: String, duration: int) -> void
remove_status_effect(effect_name: String) -> void
has_status_effect(effect_name: String) -> bool
tick_status_effects() -> void
```

#### Combat Modifiers
```gdscript
calculate_damage_received(base_damage: int) -> int
get_accuracy_modifier_from_effects() -> float
get_critical_chance_modifier() -> float
```

#### Helper Actions
```gdscript
gain_bonus_ap(amount: int) -> void
gain_bonus_movement(amount: int) -> void
```

---

## Extending the System

### Adding a New Status Effect

1. **Add to _apply_status_visual_feedback():**
```gdscript
func _apply_status_visual_feedback(effect_name: String) -> void:
    match effect_name:
        # ... existing effects
        "my_effect":
            var tween = create_tween()
            tween.tween_property(sprite, "modulate", Color(1.0, 0.5, 1.0), 0.2)
            tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.2)
```

2. **Apply in ability logic:**
```gdscript
target.add_status_effect("my_effect", 3)  # 3-turn duration
```

3. **Check in combat:**
```gdscript
if has_status_effect("my_effect"):
    # Apply effect logic
    actual_damage = int(actual_damage * 0.75)
```

### Adding Ability-Specific Targeting

Some abilities need special targeting UI. To add this:

1. **Create targeting mode in TacticalController:**
```gdscript
var my_ability_mode: bool = false

func _on_ability_used(ability_id: String) -> void:
    if ability_id == "my_targeting_ability":
        my_ability_mode = true
        tactical_hud.show_combat_message("SELECT TARGET", Color.WHITE)
```

2. **Handle tile clicks:**
```gdscript
func _on_tile_clicked(grid_pos: Vector2i) -> void:
    if my_ability_mode:
        _apply_my_targeting_ability(grid_pos)
        my_ability_mode = false
```

### Ability Modifiers

Some abilities modify existing abilities. Handle with:

```gdscript
# In ability property getters
func get_execute_cooldown_with_warlord() -> int:
    var od = GameState.get_officer(officer_key)
    if od and od.has_ability("warlord"):
        return 0
    return 2
```

---

## Status Effects

### Built-In Effects

| Effect | Duration | Effect | Source |
|--------|----------|--------|--------|
| `phantom` | 2 turns | 50% damage reduction, invisibility | Phantom |
| `immune` | 1 turn | No damage taken | No One Left Behind |
| `stim` | 1 turn | 50% damage reduction, +2 AP | Stim Injector |
| `adrenaline` | 2 turns | +2 movement, +15% accuracy | Adrenaline Patch |
| `poison` | 3 turns | 5 DMG/turn, -20% accuracy | Toxicologist |
| `marked` | 1 turn | Visual indicator | Coordinate Fire |
| `bulldozer_armor` | 2 turns | +20 damage reduction | Bulldozer |
| `untouchable` | 1 turn | Next attack misses | Untouchable |
| `juggernaut` | Passive | Crit immunity, regen | Juggernaut |

### Adding Custom Effects

1. **Add visual feedback:**
```gdscript
match effect_name:
    "custom_effect":
        var tween = create_tween()
        # ... animation
```

2. **Apply in combat:**
```gdscript
if has_status_effect("custom_effect"):
    # Modify damage, accuracy, movement, etc.
```

3. **Tick during end-of-turn:**
Status effects automatically decrement via `tick_status_effects()` called by tactical controller.

---

## Testing Abilities

### Quick Test Checklist

- [ ] Ability shows in AbilityPanel when unlocked
- [ ] AP cost is enforced
- [ ] Cooldown works
- [ ] Visual feedback appears (colors, tweens)
- [ ] Combat modifiers apply correctly
- [ ] Status effects tick down
- [ ] Ability works with different unit types

### Debug Commands (if using dev mode)

```gdscript
# Force unlock all abilities for testing
var od = GameState.get_officer("captain")
od.unlock_ability("warlord")

# Check status effects
print(unit.status_effects)

# Check unlocked abilities
print(od.unlocked_abilities)
```

---

## Performance Notes

- **Status effects are lightweight** - Dictionary lookups only
- **No spawned objects** - Effects are pure stat modifiers
- **Tick once per turn** - No per-frame updates needed
- **Lazy visual feedback** - Tweens only on apply

---

## Common Issues & Solutions

### Ability Not Appearing
- Check `OfficerData.unlock_ability()` was called
- Verify ability type is `active` (passives don't show)
- Check AP cost isn't exceeding max_ap

### Status Effect Not Applying
- Ensure `add_status_effect()` is called, not just stored
- Check duration is > 0
- Verify effect name matches checks

### Cooldown Not Working
- Ensure `_start_cooldown()` is called
- Check `tick_status_effects()` is called at turn end
- Verify effect name is tracked correctly

### Visual Feedback Missing
- Add to `_apply_status_visual_feedback()` match statement
- Ensure sprite is valid (`if not sprite: return`)
- Use simple tweens for performance

---

## Future Enhancement Ideas

1. **Ability Combinations** - Special effects when using abilities in sequence
2. **Range Indicators** - Visual preview of ability effects
3. **Ability Animations** - Unique vfx for powerful abilities
4. **Sound Effects** - Audio cues for ability usage
5. **Cooldown Display** - Show remaining cooldown on UI
6. **Ability Preview** - Hover to see exact effect before using

---

**Happy ability designing! The system is fully extensible and ready for new content.**
