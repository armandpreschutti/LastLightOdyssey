# Ability System - Quick Reference Card

**All 18 Abilities at a Glance** *(revised roster)*

---

## CAPTAIN (Yellow - #FFC700)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Execute** | Active | 1 AP | 2 | Guaranteed kill on enemy <50% HP within 4 tiles |
| **Lead by Example** | Passive | — | — | Squad gains +1 AP when Captain kills |
| **Coordinate Fire** | Active | 1 AP | 2 | Mark enemy: allies +20% acc/crit vs target for 1 turn |
| **Warlord** | Passive | — | — | Execute has no cooldown |
| **No One Left Behind** | Passive | — | — | Ally near death survives with 1 HP + 1-turn immunity |
| **Inspire** | Active | 1 AP | 3 | Grant one ally within 5 tiles +1 AP immediately |

---

## SCOUT (Green - #20FF80)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Overwatch** | Active | 1 AP | 2 | React shot on first enemy movement in LOS |
| **Hit & Run** | Passive | — | — | +3 movement after shooting if also moved this turn |
| **Deep Scanner** | Active | 0 AP | 3 | Reveal all enemies within 15 tiles through walls |
| **Ambush** | Passive | — | — | First shot each turn is auto-crit if Scout hasn't moved |
| **Phantom** | Active | 1 AP | 2 | Invisible 2 turns (+100% dmg on first hit from stealth) |
| **Untouchable** | Passive | — | — | Kill an enemy → next attack against Scout guaranteed miss |

---

## TECH (Cyan - #64E9FF)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Turret** | Active | 1 AP | 2 | Deploy sentry (3 turns, 45 DMG) |
| **Combat Engineer** | Passive | — | — | Turrets gain +20 HP shield, 5-turn duration |
| **Field Repair** | Active | 0 AP | 3 | Restore 25 HP and +1 turn to nearest turret |
| **Twin-Link** | Passive | — | — | Deploy up to 2 turrets simultaneously |
| **Remote Detonation** | Active | 0 AP | 0 | Destroy nearest turret — 30 AoE damage within 2 tiles |
| **Emergency Protocol** | Passive | — | — | First time HP <25%: gain +2 AP + reset Turret cooldown |

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
| **Bulldozer** | Passive | — | — | Charge grants +20 armor for 2 turns |
| **Suppression Fire** | Active | 2 AP | 2 | All visible enemies get -25% accuracy for 1 turn |
| **Juggernaut** | Passive | — | — | Crit immune; regen 15% HP if Heavy didn't attack this turn |
| **Rocket Salvo** | Active | 2 AP | 3 | 40 damage to all enemies in a 3×3 area |
| **War Machine** | Passive | — | — | Each kill this mission: permanently +5 base damage |

---

## SNIPER (Purple - #9888B3)

| Ability | Type | Cost | CD | Effect |
|---------|------|------|----|--------|
| **Precision Shot** | Active | 1 AP | 2 | Guaranteed hit on any visible enemy, 2x damage |
| **Damn Good Ground** | Passive | — | — | If stationary this turn: +15% critical chance |
| **Snap Shot** | Passive | — | — | Precision Shot has no cooldown |
| **Serial** | Passive | — | — | Killing an enemy refunds all AP (chain kills) |
| **Apex Predator** | Passive | — | — | 2x damage vs full-health enemies |
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
BULLDOZER_ARMOR→ +20 damage reduction (2 turns)
UNTOUCHABLE    → Next attack against Scout guaranteed miss (1 turn)
PIN_DOWN       → -25% accuracy (1 turn) — applied by Suppression Fire
```

---

## Key State Tracking (per officer turn)

| Variable | Reset | Used By |
|----------|-------|---------|
| `moved_this_turn` | Start of turn | Ambush, Damn Good Ground, Hit & Run |
| `attacked_this_turn` | Start of turn | Juggernaut regen check |
| `shots_fired_this_turn` | Start of turn | Ambush (first-shot only) |
| `war_machine_bonus_damage` | Never (mission) | War Machine kill stacking |
| `emergency_protocol_triggered` | Never (mission) | Emergency Protocol one-time |

---

## Implementation Status

✅ All 18 abilities implemented
✅ Kill hooks: Lead by Example, Serial, Untouchable, War Machine
✅ Attack hooks: Hit & Run, Toxicologist, Ambush, Phantom reveal
✅ Death prevention: No One Left Behind, Field Surgeon
✅ Passive upgrades: Adrenaline Patch, Combat Engineer, Twin-Link
✅ Crit system: Ambush (auto), Damn Good Ground (+15%), Juggernaut immunity
✅ Active abilities: all 10 actives have targeting modes or no-target activation
✅ Turret upgrades: Field Repair, Remote Detonation, Emergency Protocol
