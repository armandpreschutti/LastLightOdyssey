# Ability System - Quick Reference Card

**All 18 Abilities at a Glance**

---

## CAPTAIN (Yellow - #FFC700)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Execute** | Active | 1 AP | 2 | Guaranteed kill on enemy <50% HP |
| **Lead by Example** | Passive | — | — | Squad gains +1 AP when you kill |
| **Coordinate Fire** | Active | 1 AP | 2 | Mark target +20% acc/crit to allies |
| **Warlord** | Passive | — | — | Execute has no cooldown |
| **No One Left Behind** | Passive | — | — | Save ally from death with 1 HP |
| **Command Presence** | Passive | — | — | Aura: allies +10% acc/crit |

---

## SCOUT (Green - #20FF80)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Overwatch** | Active | 1 AP | 2 | React shot on enemy movement |
| **Hit & Run** | Passive | — | — | +3 movement after shooting |
| **Deep Scanner** | Active | 0 AP | 3 | Reveal enemies through walls |
| **Killzone** | Passive | — | — | Overwatch triggers on ALL enemies |
| **Phantom** | Active | 1 AP | 2 | Invisible 2 turns (+100% dmg on first hit) |
| **Untouchable** | Passive | — | — | Next attack after kill = miss |

---

## TECH (Cyan - #64E9FF)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Turret** | Active | 1 AP | 2 | Deploy sentry (3 turns, 15 DMG) |
| **Combat Engineer** | Passive | — | — | Turrets +20 HP shield, 5 turn duration |
| **Sapper** | Active | 1 AP | 2 | EMP stuns robots, disables weapons |
| **Twin-Link** | Passive | — | — | Deploy 2 turrets simultaneously |
| **Overclock** | Active | 0 AP | 2 | Turret fires 3x then explodes (area dmg) |
| **Haywire Protocol** | Active | 1 AP | 4 | Control enemy robot 2 turns |

---

## MEDIC (Magenta - #FF80CC)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Patch** | Active | 1 AP | 2 | Heal 62.5% HP within 3 tiles |
| **Adrenaline Patch** | Passive | — | — | Patch grants +movement/accuracy |
| **Field Surgeon** | Passive | — | — | Auto-stabilize allies within 4 tiles |
| **Miracle Worker** | Active | 2 AP | ∞ | Global heal 50% HP all squad |
| **Toxicologist** | Passive | — | — | Attacks apply poison (5 DMG/turn, -20% aim) |
| **Stim Injector** | Active | 1 AP | 3 | +2 AP and -50% damage 1 turn |

---

## HEAVY (Orange-Red - #FF6633)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Charge** | Active | 1 AP | 2 | Rush enemy (instant kill basic, 2x dmg heavy) |
| **Bulldozer** | Passive | — | — | Charge destroys cover, gain +20 armor |
| **Suppression Fire** | Active | 2 AP | 2 | Cone attack pins enemies |
| **Juggernaut** | Passive | — | — | Crit immune, regen 15% HP if idle |
| **Rocket Salvo** | Active | 2 AP | 3 | Area damage 3x3, destroys cover |
| **Intimidate** | Passive | — | — | Aura debuffs enemies -20% accuracy |

---

## SNIPER (Purple - #9888B3)

| Ability | Type | Cost | Cooldown | Effect |
|---------|------|------|----------|--------|
| **Precision Shot** | Active | 1 AP | 2 | Guaranteed hit, 2x damage |
| **Damn Good Ground** | Passive | — | — | Stationary +15% crit, +2 sight range |
| **Snap Shot** | Passive | — | — | Precision Shot has no cooldown |
| **Serial** | Passive | — | — | Refund AP on kills (chain kills) |
| **Apex Predator** | Passive | — | — | 2x damage vs full-health enemies |
| **Double Tap** | Active | 1 AP | 2 | Fire twice (-15% accuracy on 2nd) |

---

## Status Effects Applied

```
PHANTOM       → 50% damage reduction, invisibility (2 turns)
IMMUNE        → No damage taken (1 turn)
STIM          → 50% damage reduction, +2 AP (1 turn)
ADRENALINE    → +2 movement, +15% accuracy (2 turns)
POISON        → 5 DMG/turn, -20% accuracy (3 turns)
MARKED        → Visual indicator (1 turn)
BULLDOZER_ARM → +20 damage reduction (2 turns)
UNTOUCHABLE   → Next attack misses (1 turn)
JUGGERNAUT    → Crit immunity, HP regen (passive)
```

---

## How to Use in Missions

### Player Flow
1. Select officer
2. Click **ABILITIES** button
3. See list of unlocked abilities
4. Click ability to use
5. Ability applies immediately

### Developer Flow
1. **Define** in `GameState.ABILITY_DEFS`
2. **Implement** in `OfficerUnit` (apply_* methods)
3. **Test** with unlock via `OfficerData.unlock_ability()`

---

## Key Files

| File | Purpose |
|------|---------|
| `GameState.gd` | ABILITY_DEFS + lookup helpers |
| `OfficerUnit.gd` | All ability implementations |
| `TacticalController.gd` | Ability usage handler |
| `AbilityPanel.gd` | HUD panel controller |
| `ability_panel.tscn` | UI scene |
| `ABILITY_SYSTEM_GUIDE.md` | Full documentation |

---

## Common Commands

```gdscript
# Unlock ability for an officer
var od = GameState.get_officer("captain")
od.unlock_ability("warlord")

# Check if unlocked
if od.has_ability("warlord"):
    print("Warlord unlocked!")

# Apply status effect
unit.add_status_effect("stim", 1)

# Check status
if unit.has_status_effect("phantom"):
    print("Unit is invisible!")

# Get ability info
var def = GameState.get_ability_def("phantom")
print(def.get("desc"))
```

---

## AP Cost Summary

| Cost | Abilities |
|------|-----------|
| 0 AP | Deep Scanner, Overclock |
| 1 AP | Most abilities (majority) |
| 2 AP | Miracle Worker, Suppression Fire, Rocket Salvo |

---

## Cooldown Summary

| Cooldown | Abilities |
|----------|-----------|
| 0 | Warlord (Execute), Snap Shot (Precision Shot) |
| 2 | Most base abilities & upgrades |
| 3 | Deep Scanner, Stim Injector, Rocket Salvo |
| 4 | Haywire Protocol |
| ∞ | Miracle Worker (once per mission) |

---

## Ready to Test!

✅ All 18 abilities implemented
✅ Status effects system ready
✅ HUD integration complete
✅ Damage modifiers working
✅ Cooldown tracking enabled

**Start a tactical mission and unlock abilities via the Barracks to test!**

---

*For detailed implementation info, see ABILITY_SYSTEM_GUIDE.md*
