# Ability System - Quick Reference Card

**All 18 Abilities at a Glance** *(revised roster)*

---

## CAPTAIN (Yellow - #FFC700)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Execute** | Active | 1 AP | 2 | Guaranteed kill on enemy <50% HP within 4 tiles |
| **Lead by Example** | Passive | — | — | Squad gains +1 AP when Captain kills |
| **Coordinate Fire** | Active | 1 AP | — | Mark enemy: allies +20% acc/crit vs target for 1 turn |
| **Warlord** | Passive | — | — | Execute has no cooldown |
| **No One Left Behind** | Passive | — | — | Ally near death survives with 1 HP + 1-turn immunity |
| **Inspire** | Active | 1 AP | 3 | Grant one ally within 5 tiles +1 AP immediately |

---

## SCOUT (Green - #20FF80)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Overwatch** | Active | 1 AP | 2 | React shot on first enemy movement in LOS |
| **Hit & Run** | Passive | 0 AP | 1 | Dash up to 3 tiles to reposition as a free action |
| **Deep Scanner** | Active | 0 AP | 3 | Reveal all enemies within 15 tiles through walls |
| **Explosive Ambush** | Active | 0 AP | 0 | Plant a trap: 100 damage + pinned to first enemy to walk over it |
| **Phantom** | Active | 1 AP | 2 | Invisible 2 turns (+100% dmg on first hit from stealth) |
| **Untouchable** | Passive | — | — | Kill an enemy → next attack against Scout guaranteed miss |

---

## TECH (Cyan - #64E9FF)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Turret** | Active | 1 AP | 2 | Deploy sentry (3 turns) |
| **Combat Engineer** | Passive | — | — | Turrets gain +20 HP shield, 5-turn duration |
| **Field Repair** | Active | 0 AP | 3 | Restore 25 HP and +1 turn to nearest turret |
| **Overcharge** | Active | 1 AP | 3 | Turrets deal 2x dmg for 2 turns; allows 2 turrets |
| **Remote Detonation** | Active | 0 AP | 0 | Destroy nearest turret — 30 AoE damage within 2 tiles |
| **System Reboot** | Active | 1 AP | ∞ | Reset all cooldowns & grant all allies +1 AP (once/mission) |

---

## MEDIC (Magenta - #FF80CC)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Patch** | Active | 1 AP | 2 | Heal ally within 3 tiles for 62.5% HP |
| **Adrenaline Patch** | Passive | — | — | Patch also grants +2 movement, +15% accuracy for 2 turns |
| **Field Surgeon** | Passive | — | — | Auto-stabilize allies within 4 tiles from death |
| **Miracle Worker** | Active | 2 AP | ∞ | Heal all squad members 50% HP (once per mission) |
| **Toxicologist** | Passive | — | — | Attacks apply poison (5 DMG/turn, -20% aim, 3 turns) |
| **Stim Injector** | Active | 1 AP | 3 | Inject ally: +2 AP and -50% damage taken for 1 turn |

---

## HEAVY (Orange-Red - #FF6633)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Charge** | Active | 1 AP | 2 | Rush enemy — instant kill basic, 2x damage heavy |
| **Bulldozer** | Passive | — | — | Charge destroys cover and grants +20 armor |
| **Suppression Fire** | Active | 1 AP | 3 | Deal 12 damage + Pin Down (no movement 3 turns) |
| **Juggernaut** | Passive | — | — | Crit immune; regen 15% HP if Heavy didn't attack this turn |
| **Rocket Salvo** | Active | 2 AP | 3 | 40 damage to all enemies in a 3×3 area |
| **War Machine** | Passive | — | — | Each kill this mission: permanently +5 base damage |

---

## SNIPER (Purple - #9888B3)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Precision Shot** | Active | 1 AP | 2 | Guaranteed hit on any visible enemy, 1.5x damage |
| **Last Stand** | Active | 1 AP | 2 | Next shot is guaranteed hit and ignores cover |
| **Snap Shot** | Passive | — | — | Precision Shot has no cooldown |
| **Serial** | Passive | — | — | Killing an enemy refunds all AP (chain kills) |
| **Apex Predator** | Passive | — | — | Deal +100% damage vs full-health enemies |
| **Double Tap** | Active | 1 AP | 2 | Fire twice at same target (-15% acc on 2nd shot) |

---

## Status Effects

```
PHANTOM        → 50% dmg reduction, invisible (2 turns); first hit = +100% dmg
IMMUNE         → No damage taken (1 turn)
STIM           → 50% dmg reduction, +2 AP (1 turn)
ADRENALINE     → +2 movement, +15% accuracy (2 turns)
POISON         → 5 DMG/turn, -20% accuracy (3 turns) — ticks on enemy turn end
MARKED         → Allies +20% acc/crit vs target (1 turn)
BULLDOZER_ARMOR→ +20 damage reduction after a charge
UNTOUCHABLE    → Next attack against Scout guaranteed miss (1 turn)
PIN_DOWN       → No movement (3 turns) — applied by Suppression Fire or Explosive Ambush
```

---

## Key State Tracking (per officer turn)

| Variable | Reset | Used By |
|----------|-------|---------|
| `moved_this_turn` | Start of turn | Hit & Run |
| `attacked_this_turn` | Start of turn | Juggernaut regen check |
| `war_machine_bonus_damage` | Never (mission) | War Machine kill stacking |
| `emergency_protocol_triggered` | Never (mission) | System Reboot one-time |

---

## Implementation Status

✅ All 18 abilities implemented
✅ Kill hooks: Lead by Example, Serial, Untouchable, War Machine
✅ Attack hooks: Hit & Run, Toxicologist, Phantom reveal
✅ Death prevention: No One Left Behind, Field Surgeon
✅ Passive upgrades: Adrenaline Patch, Combat Engineer, Overcharge
✅ Crit system: Juggernaut immunity
✅ Active abilities: all 10 actives have targeting modes or no-target activation
✅ Turret upgrades: Field Repair, Remote Detonation, System Reboot
