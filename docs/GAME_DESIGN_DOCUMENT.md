# Last Light Odyssey - Game Design Document
**Version 2.1 | Engine: Godot 4.6 | Last Updated: February 5, 2026**

> *"The last journey of the human race isn't a hero's quest; it's a survival marathon."*

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [The Management Layer](#2-the-management-layer-the-trail)
3. [The Tactical Layer](#3-the-tactical-layer-the-search)
4. [The Pressure Mechanic](#4-the-oregon-trail-pressure-mechanic)
5. [Win/Loss Conditions](#5-winloss-logic)
6. [Visual & Audio Direction](#6-visual--audio-direction)
7. [Implementation Status](#7-implementation-status)
8. [Next Steps & Roadmap](#8-next-steps--roadmap)

---

## 1. Project Overview

### Concept
A space-faring survival manager inspired by **The Oregon Trail**, featuring **Fallout 1/2 style** isometric tactical exploration. Players guide the last remnants of humanity across the stars, making desperate choices about when to scavenge, when to trade, and when to flee.

### Core Loop
```
Strategic Navigation → Random Event Resolution → Resource Scarcity → Tactical Scavenging → Repeat
```

### Platform Target
- **Primary**: PC (Mouse & Keyboard)
- **Resolution**: 1920x1080 (scaled to 1600x900 window)
- **Renderer**: GL Compatibility (for broad hardware support)

---

## 2. The Management Layer (The "Trail")

This layer simulates the grueling trek across the stars.

### 2.1 Primary Statistics

| Statistic | Starting Value | Description |
|-----------|----------------|-------------|
| **Colonists** | 1,000 | The player's "health" and final score. Humanity's last survivors. |
| **Fuel** | 10 | The clock. Each jump consumes fuel. At 0, ship enters "Drift Mode" (−20 colonists per jump). |
| **Ship Integrity** | 100% | Damaged by space hazards. At 0%, the ship is destroyed. Game Over. |
| **Scrap** | 0 | Currency found on tactical maps. Used for repairs and trading. |

### 2.2 The Star Map (Node System)

A procedurally generated node graph with **20 nodes** leading to New Earth.

**Structure:**
- 7 columns of nodes
- Variable nodes per column (2-4)
- Each node connects to 1-3 nodes in the next column
- Variable fuel costs per connection (1-3 fuel)

**Node Types:**

| Type | Frequency | Description |
|------|-----------|-------------|
| **Empty Space** | 40% | No tactical map, just a random event roll. |
| **Scavenge Site** | 40% | Triggers Isometric Tactical Mode for resource gathering. |
| **Trading Outpost** | 20% | Menu-based screen to trade Scrap for Fuel (10→1) or repairs (15→10%). |

### 2.3 Random Event System

Upon entering a node, the game rolls **1d10** against the Random Event Table.

**Current Events:**

| Roll | Event | Base Loss | Specialist | Mitigated Loss |
|------|-------|-----------|------------|----------------|
| 1 | Solar Flare | −50 colonists, −10% integrity | Tech | −10 colonists, 0% integrity |
| 2 | Meteor Shower | −30 colonists, −20% integrity | Scout | 0 colonists, −5% integrity |
| 3 | Disease Outbreak | −80 colonists | Medic | −20 colonists |
| 4 | System Malfunction | −20 colonists, −15% integrity | Tech | 0 colonists, −5% integrity |
| 5 | Pirate Ambush | −40 colonists, −25% integrity | Scout | −10 colonists, −10% integrity |
| 6 | Supply Cache | +2 fuel, +15 scrap | — | — |
| 7 | Distress Signal | +50 colonists, −10% integrity | Medic | +50 colonists, 0% integrity |
| 8 | Radiation Storm | −60 colonists, −5% integrity | Tech | −15 colonists |
| 9 | Cryo Pod Failure | −100 colonists | Medic | −30 colonists |
| 10 | Clear Skies | No effect | — | — |

**Resolution:** Events display narrative text. If the required specialist is alive, a "Mitigate" option becomes available.

---

## 3. The Tactical Layer (The "Search")

When the ship docks at a Scavenge Site, the game switches to isometric turn-based combat.

### 3.1 The Away Team

- Players select **3 Officers** to deploy
- **Permadeath**: Dead officers are removed permanently
- Losing a specialist disables their event mitigation options

### 3.2 Officer Archetypes

| Role | Passive Ability | Active Ability | HP | Move | Sight |
|------|-----------------|----------------|-----|------|-------|
| **Captain** | — | — | 100 | 5 | 6 |
| **Scout** | +2 sight range, extended enemy detection | **Overwatch** (1 AP): Reaction shot at first enemy that moves in LOS | 80 | 6 | 10 |
| **Tech** | Can see items through walls | **Breach** (1 AP): Destroy 1 tile of cover or wall | 70 | 4 | 5 |
| **Medic** | Can see exact enemy HP | **Patch** (2 AP): Heal adjacent ally for 50% max HP | 75 | 5 | 5 |

### 3.3 Combat System

**Turn Structure:**
- Unit-by-unit turn order (not side-based)
- Each officer acts in sequence, then all enemies act
- After all units act, a new round begins

**Action Point System:**
- Each unit has **2 AP** per round
- **Move**: 1 AP (distance up to move_range tiles)
- **Shoot**: 1 AP
- **Use Ability**: 1-2 AP (varies by ability)
- **Interact/Pickup**: Free (auto-pickup when stepping on items)

**Combat Calculations:**

```
Base Hit Chance = Class-based (varies by distance)
Adjacent (1 tile): 95%
Close (2 tiles): 90%
Medium (3-6 tiles): 50-85% (class-dependent)
Long (7+ tiles): 25-65% (class-dependent)

Defender Cover Modifier (reduces attacker's hit chance):
  - Half Cover (crates): −25% hit chance
  - Full Cover (walls): −50% hit chance

Attacker Cover Bonus (stable firing position):
  - Half Cover: +10% hit chance
  - Full Cover: +15% hit chance

Flanking Bonus:
  - Attacking from unprotected angle: +50% DAMAGE
  - Cover only protects from the direction it faces

Final Hit Chance = clamp(Base - DefenderCover + AttackerBonus, 10%, 95%)
```

**Class Accuracy Profiles:**
- **Scout**: Best at long range (65% at 8+ tiles)
- **Captain**: Balanced (50% at 8+ tiles)
- **Tech/Medic**: Support-focused, weaker at range (40% at 8+ tiles)

### 3.4 Cover & Destruction

| Cover Type | Defender Penalty | Attacker Bonus | Destructible |
|------------|------------------|----------------|--------------|
| Half Cover | −25% to hit | +10% accuracy | Yes (Breach) |
| Full Cover | −50% to hit | +15% accuracy | Yes (Tech only) |
| Walls | Blocks LOS | — | Some breachable |

When cover is destroyed, it becomes rubble (0% cover value).

**Flanking System:**
Cover only protects from the direction it faces. Attacking from an unprotected angle (flanking) bypasses cover AND deals **+50% bonus damage**. Tactical positioning is crucial!

### 3.5 Fog of War

- Map starts blacked out
- Reveals in radius around each officer (sight_range)
- Enemies are only visible when in revealed areas AND within sight range

### 3.6 Enemy AI

**Behavior Priority:**
1. If target in range + LOS + has AP → **Shoot**
2. If target visible + has AP → **Move to tactical position**
3. Otherwise → **Idle**

**Tactical Position Scoring:**
- Ideal engagement range: 4-7 tiles
- Bonus for cover positions
- Bonus for maintaining LOS to targets
- Penalty for being too close or losing LOS

**Enemy Types:**

| Type | HP | Damage | Sight | Shoot Range | Spawn Rate |
|------|-----|--------|-------|-------------|------------|
| Basic | 50 | 20 | 6 | 8 | 80% |
| Heavy | 80 | 30 | 5 | 6 | 20% |

---

## 4. The "Oregon Trail" Pressure Mechanic

To prevent players from spending unlimited turns looting, the **Cryo-Stability Timer** creates urgency.

### Stability System

| Phase | Effect |
|-------|--------|
| **100%** | Mission start |
| **100% → 0%** | Decreases by **5%** every round |
| **0% (Collapse)** | "CRYO-FAILURE" warning displays |
| **Each round at 0%** | −10 colonists immediately |

### Extraction

- Extraction zone marked on map
- Mission ends when **all surviving officers** reach extraction tiles
- Resources collected during mission are added to ship totals upon extraction

### Mission Abort

Players can pause during tactical missions and choose to **Abandon Mission**:
- Costs **20 colonists** as penalty
- All deployed officers return safely (even if surrounded)
- No resources are gained from the mission
- Useful when a mission goes badly wrong

---

## 5. Win/Loss Logic

### Win Condition
Reach the **"New Earth"** node (node 19) with **Colonists > 0**.

### Ending Tiers

| Colonists | Ending | Title |
|-----------|--------|-------|
| 1,000 | Perfect | "The Golden Age" |
| 500–999 | Good | "The Hard Foundation" |
| 1–499 | Bad | "The Endangered Species" |

### Loss Conditions

| Condition | Message |
|-----------|---------|
| Colonists = 0 | "EXTINCTION: Humanity's light has been extinguished." |
| Ship Integrity = 0% | "CATASTROPHIC FAILURE: The ship has been destroyed." |
| Captain dies | "LEADERSHIP LOST: Without leadership, the mission cannot continue." |

---

## 6. Visual & Audio Direction

### Art Style
- **Low-fidelity 2D sprites** with gritty color palette
- Dark grays, industrial oranges, neon blues
- Isometric tactical view (32×32 tile grid)

### UI Philosophy
- **Diegetic/Retro**: 1980s monochrome CRT terminal aesthetic
- Amber text on dark backgrounds
- Minimal, functional displays

### Tutorial System
First-time players receive a **9-step guided tutorial** that covers:

1. **Star Map Navigation** - How to plot course and fuel costs
2. **Resource Management** - Understanding colonists, fuel, hull, and scrap
3. **Random Events** - How events work and specialist mitigation
4. **Scavenge Missions** - Team selection and permadeath warning
5. **Tactical Movement** - Action points and movement
6. **Combat** - Attacking enemies and cover mechanics
7. **Abilities** - Specialist unique abilities (Scout, Tech, Medic)
8. **Cryo-Stability** - Time pressure and colonist loss
9. **Extraction** - Completing missions

Tutorial can be skipped at any time and reset from the Settings menu.

---

### Sprite Assets

#### Officer Characters
The player's controllable units, each with distinct visual identity matching their role.

| Captain | Scout | Tech | Medic |
|:-------:|:-----:|:----:|:-----:|
| ![Captain](../assets/sprites/characters/officer_captain.png) | ![Scout](../assets/sprites/characters/officer_scout.png) | ![Tech](../assets/sprites/characters/officer_tech.png) | ![Medic](../assets/sprites/characters/officer_medic.png) |
| Command leader | Recon specialist | Engineer | Field medic |

#### Enemy Units
Hostile forces encountered during tactical missions.

| Basic Enemy | Heavy Enemy |
|:-----------:|:-----------:|
| ![Basic](../assets/sprites/characters/enemy_basic.png) | ![Heavy](../assets/sprites/characters/enemy_heavy.png) |
| Standard threat (80% spawn) | Armored threat (20% spawn) |

#### Unit Indicators
Visual feedback elements for unit states.

| Selection Ring | Shadow |
|:--------------:|:------:|
| ![Selection](../assets/sprites/characters/selection_ring.png) | ![Shadow](../assets/sprites/characters/shadow.png) |
| Active unit indicator | Ground shadow for depth |

---

#### Interactable Objects
Items and cover objects found on tactical maps.

| Fuel Crate | Scrap Pile | Cover Crate | Destroyed Cover |
|:----------:|:----------:|:-----------:|:---------------:|
| ![Fuel](../assets/sprites/objects/crate_fuel.png) | ![Scrap](../assets/sprites/objects/scrap_pile.png) | ![Cover](../assets/sprites/objects/crate_cover.png) | ![Destroyed](../assets/sprites/objects/crate_cover_destroyed.png) |
| +1 Fuel | +5 Scrap | Half cover (−25%) | Rubble (0% cover) |

---

#### Environment Tiles

**Floor Tiles**
| Panel | Grating | Cables | Damaged | Vent |
|:-----:|:-------:|:------:|:-------:|:----:|
| ![Panel](../assets/sprites/environment/floor_panel.png) | ![Grating](../assets/sprites/environment/floor_grating.png) | ![Cables](../assets/sprites/environment/floor_cables.png) | ![Damaged](../assets/sprites/environment/floor_damaged.png) | ![Vent](../assets/sprites/environment/floor_vent.png) |

**Wall Tiles**
| Solid Wall | Reinforced | Pipes | Terminal |
|:----------:|:----------:|:-----:|:--------:|
| ![Solid](../assets/sprites/environment/wall_solid.png) | ![Reinforced](../assets/sprites/environment/wall_reinforced.png) | ![Pipes](../assets/sprites/environment/wall_pipes.png) | ![Terminal](../assets/sprites/environment/wall_terminal.png) |

**Fog of War**
| Fog (Unexplored) | Fog Edge |
|:----------------:|:--------:|
| ![Fog](../assets/sprites/environment/fog.png) | ![Fog Edge](../assets/sprites/environment/fog_edge.png) |

**Overlays & Indicators**
| Grid Overlay | Movement Range | Attack Range | Hover |
|:------------:|:--------------:|:------------:|:-----:|
| ![Grid](../assets/sprites/environment/overlay_grid.png) | ![Movement](../assets/sprites/environment/overlay_movement.png) | ![Attack](../assets/sprites/environment/overlay_attack.png) | ![Hover](../assets/sprites/environment/overlay_hover.png) |

**Special Tiles**
| Extraction Zone | Half Cover | Space Background | Tileset Atlas |
|:---------------:|:----------:|:----------------:|:-------------:|
| ![Extraction](../assets/sprites/environment/extraction.png) | ![Half Cover](../assets/sprites/environment/half_cover.png) | ![Space](../assets/sprites/environment/space_background.png) | ![Atlas](../assets/sprites/environment/tileset_atlas.png) |

---

#### Terrain Tiles (Procedural Map Generation)

Additional tile variants used for procedural tactical map generation.

**Floor Variants**
| Metal 1 | Metal 2 | Metal Rusty | Concrete 1 | Concrete 2 | Dirt | Tiles |
|:-------:|:-------:|:-----------:|:----------:|:----------:|:----:|:-----:|
| ![Metal1](../assets/sprites/terrain/floor_metal_1.png) | ![Metal2](../assets/sprites/terrain/floor_metal_2.png) | ![Rusty](../assets/sprites/terrain/floor_metal_rusty.png) | ![Concrete1](../assets/sprites/terrain/floor_concrete_1.png) | ![Concrete2](../assets/sprites/terrain/floor_concrete_2.png) | ![Dirt](../assets/sprites/terrain/floor_dirt_1.png) | ![Tiles](../assets/sprites/terrain/floor_tiles.png) |

**Wall Variants**
| Metal | Concrete | Border | Debris |
|:-----:|:--------:|:------:|:------:|
| ![WallMetal](../assets/sprites/terrain/wall_metal_1.png) | ![WallConcrete](../assets/sprites/terrain/wall_concrete_1.png) | ![Border](../assets/sprites/terrain/wall_border.png) | ![Debris](../assets/sprites/terrain/wall_debris_1.png) |

**Cover Variants**
| Crate Cover | Barrier Cover |
|:-----------:|:-------------:|
| ![CrateCover](../assets/sprites/terrain/cover_crate_1.png) | ![BarrierCover](../assets/sprites/terrain/cover_barrier_1.png) |

**Decorations & Details**
| Floor Grime | Cracks | Debris | Wires | Blood |
|:-----------:|:------:|:------:|:-----:|:-----:|
| ![Grime](../assets/sprites/terrain/floor_grime.png) | ![Cracks](../assets/sprites/terrain/decor_cracks.png) | ![Debris](../assets/sprites/terrain/decor_debris.png) | ![Wires](../assets/sprites/terrain/decor_wires.png) | ![Blood](../assets/sprites/terrain/decor_blood.png) |

**Fog of War (Terrain)**
| Fog Full | Fog Edge |
|:--------:|:--------:|
| ![FogFull](../assets/sprites/terrain/fog_full.png) | ![FogEdge](../assets/sprites/terrain/fog_edge.png) |

**Tile Highlights**
| Grid Overlay | Movement | Attack | Hover |
|:------------:|:--------:|:------:|:-----:|
| ![Grid](../assets/sprites/terrain/grid_overlay.png) | ![Move](../assets/sprites/terrain/highlight_movement.png) | ![Attack](../assets/sprites/terrain/highlight_attack.png) | ![Hover](../assets/sprites/terrain/highlight_hover.png) |

**Extraction Zone (Terrain)**
| Extraction Tile | Extraction Glow |
|:---------------:|:---------------:|
| ![Extract](../assets/sprites/terrain/extraction_1.png) | ![Glow](../assets/sprites/terrain/extraction_glow.png) |

**Ambient Effects**
| Dust Particles | Smoke | Vignette |
|:--------------:|:-----:|:--------:|
| ![Dust](../assets/sprites/terrain/ambient_dust.png) | ![Smoke](../assets/sprites/terrain/ambient_smoke.png) | ![Vignette](../assets/sprites/terrain/vignette.png) |

---

#### Star Map Navigation Icons
Visual elements for the management layer star map.

| Asteroid Field | Trading Station | Earth (Goal) | Gas Planet | Red Planet |
|:--------------:|:---------------:|:------------:|:----------:|:----------:|
| ![Asteroid](../assets/sprites/navigation/asteroid.png) | ![Station](../assets/sprites/navigation/station_trading.png) | ![Earth](../assets/sprites/navigation/planet_earth.png) | ![Gas](../assets/sprites/navigation/planet_gas.png) | ![Red](../assets/sprites/navigation/planet_red.png) |
| Empty Space node | Trading Outpost | New Earth (Win) | Scavenge Site | Scavenge Site |

---

### Sound Design (Planned)
- Low ambient hums
- Metallic clangs for movement
- Piercing alarm when Cryo-Stability hits 0%
- UI feedback sounds for selections and actions

---

## 7. Implementation Status

### ✅ Phase 1: Core Systems (COMPLETE)
- [x] Global game state management (`GameState` autoload)
- [x] Primary statistics tracking with signals
- [x] Win/loss condition checking
- [x] Officer roster with alive/deployed states
- [x] Jump logic with fuel consumption and drift mode

### ✅ Phase 2: Star Map & Events (COMPLETE)
- [x] Procedural star map generator (7 columns, 2-4 nodes each)
- [x] Node connection system with variable fuel costs
- [x] Visual node graph with clickable navigation
- [x] Node type system (Empty, Scavenge, Trading)
- [x] Random event system with 10 events
- [x] Specialist mitigation for events
- [x] Event dialog UI

### ✅ Phase 3: Tactical Framework (COMPLETE)
- [x] Grid-based tilemap system (20×20)
- [x] A* pathfinding for movement
- [x] Point-and-click movement with path visualization
- [x] Fog of war with per-unit reveal radius
- [x] Interactable objects (Fuel Crates, Scrap Piles)
- [x] Auto-pickup system
- [x] Procedural map generation

### ✅ Phase 4: Combat System (COMPLETE)
- [x] Turn-based unit-by-unit system
- [x] Action Point management
- [x] Line-of-sight calculations (Bresenham's algorithm)
- [x] Cover system with hit chance modifiers
- [x] Class-based accuracy profiles
- [x] Shooting with hit/miss resolution
- [x] Damage calculation and HP bars
- [x] Enemy AI with tactical positioning
- [x] Enemy visibility tied to fog of war
- [x] Attackable target highlighting

### ✅ Phase 5: Specialist Abilities (COMPLETE)
- [x] Scout: Overwatch (reaction shots)
- [x] Tech: Breach (destroy cover/walls)
- [x] Medic: Patch (heal allies)
- [x] Ability buttons in HUD
- [x] AP cost validation

### ✅ Phase 6: Pressure Mechanic (COMPLETE)
- [x] Cryo-Stability bar and display
- [x] Stability drain per round (5%)
- [x] Colonist loss at 0% stability
- [x] Warning messages and visual feedback
- [x] Extraction zone system

### ✅ Phase 7: Visual Polish (PARTIAL)
- [x] Character sprites for all officer types
- [x] Enemy sprites (basic, heavy)
- [x] Environment tileset
- [x] Selection indicators and HP bars
- [x] Damage popup numbers
- [x] Combat camera focus during attacks
- [x] Projectile visual effects
- [x] Idle animations for units

### ✅ Phase 8: UI & UX Polish (COMPLETE)
- [x] Tactical HUD with unit info
- [x] Management HUD with ship stats
- [x] Team selection dialog
- [x] Trading dialog with fuel purchase and hull repair
- [x] Event dialog with choices
- [x] Title menu with animated starfield, typewriter subtitle, and polish
- [x] Settings menu (display, audio sliders, tutorial reset)
- [x] Tutorial system with 9-step guided onboarding
- [x] Pause menu with abandon mission option
- [x] Confirmation dialog for destructive actions
- [x] Game over and victory screens with ending text
- [x] Restart game functionality

### ✅ Phase 9: Save/Load System (COMPLETE)
- [x] Save game state to JSON file (colonists, fuel, integrity, scrap, officers)
- [x] Save star map layout and node progress
- [x] Load game state on continue
- [x] Continue button on title menu (disabled if no save)
- [x] New game confirmation dialog when save exists
- [x] Delete save functionality
- [x] Settings persistence (display, audio, tutorial state)

### ⏳ Phase 10: Audio (NOT STARTED)
- [ ] Background ambient music
- [ ] UI sound effects
- [ ] Combat sound effects (shots, impacts)
- [ ] Alarm sounds for warnings
- [ ] Movement sounds

### ❌ Phase 11: Game Feel & Balance (NOT STARTED)
- [ ] Difficulty balancing
- [ ] Resource economy tuning
- [ ] Event frequency/impact balance
- [ ] Combat damage/accuracy tuning

---

## 8. Next Steps & Roadmap

### ✅ Recently Completed

#### Title Menu & Game Flow
- [x] Animated starfield background with 200 parallax stars
- [x] Typewriter subtitle animation ("The final journey of humanity begins")
- [x] Title glow pulsing effect
- [x] Button hover scale animations
- [x] New Game / Continue / Settings / Quit buttons
- [x] Continue button disabled when no save exists
- [x] Confirmation dialog for new game when save exists
- [x] Fade transitions between scenes
- [x] Game over screen with restart option
- [x] Victory screen with ending tier text

#### Save/Load System
- [x] Full game state persistence (colonists, fuel, integrity, scrap)
- [x] Officer status persistence (alive/deployed state)
- [x] Star map layout persistence (nodes, connections, types, fuel costs)
- [x] Node progress persistence (current node, visited nodes)
- [x] Continue game from title menu
- [x] Delete save when starting new game

#### Settings Menu
- [x] Display settings (fullscreen toggle, resolution: 720p/900p/1080p)
- [x] Audio volume sliders (Master, SFX, Music) - UI ready for Phase 10
- [x] Reset Tutorial button with visual feedback
- [x] Settings persistence to user://settings.cfg
- [x] Apply button with confirmation feedback

#### Tutorial System
- [x] TutorialManager autoload singleton
- [x] 9-step guided onboarding sequence
- [x] Tutorial overlay with animated prompts
- [x] Directional arrow indicators
- [x] Skip tutorial option
- [x] Tutorial state persistence
- [x] Reset tutorial from settings

#### Trading System Enhancement
- [x] Buy fuel: 10 scrap → 1 fuel
- [x] Repair hull: 15 scrap → 10% integrity
- [x] Status feedback on transactions
- [x] Button availability based on resources

#### Additional UI
- [x] Pause menu with abandon mission option (costs 20 colonists)
- [x] Reusable confirmation dialog component

### Immediate Priority (Week 1-2)

#### 1. Audio Foundation
- [ ] Implement background ambience for each game layer
- [ ] Add UI click/hover sounds
- [ ] Add weapon fire and impact sounds
- [ ] Add Cryo-Stability alarm sound
- [ ] Add movement footstep sounds

#### 2. Visual Effects Polish
- [ ] Screen shake on damage
- [ ] Particle effects for explosions/impacts
- [ ] Enhanced fog of war transitions
- [ ] Animated tileset elements (flickering lights, steam vents)

### Short-Term Goals (Week 3-4)

#### 3. Game Balance Pass
- [ ] Difficulty balancing (event damage, enemy stats)
- [ ] Resource economy tuning (fuel costs, scrap drops)
- [ ] Event frequency/impact balance
- [ ] Combat damage/accuracy tuning

#### 4. Quality of Life
- [ ] Auto-save after jumps and missions
- [ ] Tooltip system for UI elements
- [ ] Mission briefing before tactical deployment
- [ ] Keyboard shortcuts reference

### Medium-Term Goals (Month 2)

#### 5. Content Expansion
- [ ] Additional random events (expand to 20+)
- [ ] New enemy types (ranged, explosive, boss)
- [ ] Environmental hazards on tactical maps
- [ ] Special mission types (rescue, sabotage)

#### 6. Procedural Generation Improvements
- [ ] More map templates/themes
- [ ] Room-based generation for interior maps
- [ ] Loot distribution balancing
- [ ] Enemy placement variety

#### 7. Officer System Expansion
- [ ] Recruit new officers at trading posts
- [ ] Officer experience/leveling (optional)
- [ ] Unique officer traits/perks
- [ ] Officer equipment system

### Long-Term Goals (Month 3+)

#### 8. Advanced Features
- [ ] Multiple difficulty modes
- [ ] Endless/roguelike mode
- [ ] Achievement system
- [ ] Statistics tracking (missions completed, enemies killed, etc.)
- [ ] Controller support

#### 9. Story & Narrative
- [ ] "Captain's Log" intro sequence
- [ ] Story events tied to specific nodes
- [ ] Character interactions/dialogue
- [ ] Multiple ending variants based on decisions

---

## Development Notes

### File Structure
```
Last Light Odyssey/
├── assets/
│   ├── audio/          # Sound effects and music (TODO)
│   ├── fonts/          # Custom fonts
│   └── sprites/        # All game graphics
│       ├── characters/ # Officer and enemy sprites
│       ├── environment/# Tiles, cover, fog
│       ├── navigation/ # Star map elements
│       ├── objects/    # Interactables
│       └── terrain/    # Ground tiles
├── docs/
│   └── GAME_DESIGN_DOCUMENT.md  # This file
├── resources/
│   ├── events/         # Event data resources
│   └── officers/       # Officer data resources
├── scenes/
│   ├── management/     # Star map scenes
│   ├── tactical/       # Combat scenes
│   └── ui/             # Interface scenes
├── scripts/
│   ├── autoload/       # Global singletons
│   ├── management/     # Star map logic
│   ├── tactical/       # Combat logic
│   └── ui/             # Interface scripts
└── project.godot       # Godot project file
```

### Key Autoloads
- **GameState**: Global statistics, officer tracking, win/loss logic, save/load system
- **EventManager**: Random events, node types, event resolution
- **TutorialManager**: Tutorial state, step progression, persistence

### Design Philosophy
> *"Start with Gray Boxes."* Don't polish art until the mechanics feel fun. If the game is stressful and addictive with just squares and numbers, it will be a masterpiece once polish is added.

The core tension should come from:
1. **Resource scarcity** - Never enough fuel, always losing colonists
2. **Time pressure** - Cryo-Stability forces mission exits
3. **Meaningful choices** - Trade-offs between risk and reward
4. **Permanent consequences** - Dead officers stay dead

---

*Document maintained by the Last Light Odyssey development team.*
