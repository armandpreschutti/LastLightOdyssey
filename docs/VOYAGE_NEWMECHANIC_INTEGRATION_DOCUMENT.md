# Voyage 2.0 Technical Implementation Plan

**Target Engine:** Godot 4.6
**Scope:** Management Layer, Economy, Progression, Map Generation

## Current Phase Snapshot (February 2026)

- **Current Phase:** **Phase 5 (Loop Closer) is now in active implementation**.
- **Confirmed complete in code:** Officer progression model, Barracks + Ability Tree UI, injury tracking/recovery, mission-end XP/rewards, and story-node chapter chain scaffolding.
- **Primary remaining work:** Narrative content polish, chapter-specific mission variants, and tuning of story pacing/reward cadence.

## 1. Global Architecture & Economy (GameState.gd) [COMPLETED]

### 1.1 Deprecated Systems
The following variables and logic must be stripped out of the GameState singleton:
* **colonists**: REMOVED. Game Over is no longer tied to a population count.
* **cryo_stability**: REMOVED from the Management Layer. (It remains strictly as a turn-timer within the TacticalManager).

### 1.2 New Economy Model
Implement the following persistent variables in GameState.gd to support the new loop.


## 1. Global Architecture & Economy (GameState.gd) [COMPLETED]

### 1.1 Deprecated Systems
The following variables and logic must be stripped out of the GameState singleton:
* **colonists**: REMOVED. Game Over is no longer tied to a population count.
* **cryo_stability**: REMOVED from the Management Layer. (It remains strictly as a turn-timer within the TacticalManager).

### 1.2 New Economy Model
Implement the following persistent variables in GameState.gd to support the new loop.

| Variable | Type | Initial | Description |
| :--- | :--- | :--- | :--- |
| **fuel** | int | 10 | Ship Stamina. Consumed per jump (1-3 based on distance). at 0, applies Hull Damage. |
| **scrap** | int | 25 | Maintenance. Used only for: 1) Hull Repairs, 2) Event Mitigation. |
| **hull_integrity** | float | 100.0 | Health. At 0.0, trigger Game Over (Ship Destruction). |
| **cash** | int | 100 | Liquid Assets. New currency. Used in the MarketMenu to buy Fuel/Scrap. |
| **intel** | int | 0 | Story Progress. Gained from tactical missions. Threshold 3 spawns a Story Node (1 in dev mode). |
| **data_logs** | int | 0 | [REFACTORED] Now tracked per-officer in OfficerData. Earned via Level Up. |

### 1.3 The Market System (MarketMenu.tscn)
Create a new UI scene accessible from the Management HUD. It serves as the primary "bailout" mechanism.
Transactions: Implement functions that directly modify GameState.
* **buy_fuel():** Check cash >= 10. If true: cash -= 10, fuel += 5.
* **buy_scrap():** Check cash >= 10. If true: cash -= 10, scrap += 10.
* **repair_hull():** Check cash >= 50. If true: cash -= 50, hull_integrity += 10.0 (Clamp at 100.0).

## 2. The Infinite Map System (VoyageManager.gd) [COMPLETED]

### 2.1 Coordinate-Based Generation
The map uses a free-floating world-space system with progressive generation, not a grid.
* **Coordinate System:** Track player position using NodeData.position (Vector2 world space).
* **Data Structure:** `var nodes: Dictionary = {}` (String UUID → NodeData).
* **Generation:** ProgressiveMapGenerator spawns 2-3 new child nodes 300-500 world units away from arrival node, within 60° spread cone.

**Algorithm:**
When the player jumps to a new node:
1. ProgressiveMapGenerator creates 2-3 new NodeData objects at randomized angles/distances.
2. New nodes are bidirectionally connected to the arrival node (explicit parent-child link).
3. `_apply_proximity_connections()` auto-connects any two nodes within 450 world units (PROXIMITY_CONNECT_DISTANCE).
4. New nodes are stored in the `nodes` dictionary and rendered on the star map.

### 2.2 Node States & Backtracking
NodeData tracks the following states:
* **UNVISITED (0):** Default. Clickable. Enters Tactical Mode or Event.
* **CLEARED (1):** Set after mission success. Node is traversable but interacts as a "Dead Zone" (Costs fuel, no reward).
* **VISITED (2):** Traveled to previously. Backtracking along amber pathlines is free (no fuel cost).
* **LOCKED (3):** Inaccessible (may be used for blocked content).
* **STORY (4):** Special story mission node. Overrides standard behavior.
* **TRADING (5):** Trading post node (reserved for future content).

### 2.3 Story Node Spawning Logic
**Trigger:** Monitor GameState.intel in VoyageManager._try_spawn_story_node().
**Logic (Current Implementation):**
1. When intel >= threshold (3 normally, 1 in dev mode):
2. Search for reachable UNVISITED neighbors of the current node.
3. If a suitable candidate exists within direct connections, convert it to STORY state.
4. Otherwise, generate new candidate nodes and search again (up to 1200 world units away).
5. Keep **one active story node** at a time.
6. Spend intel on **story chapter completion** (not on spawn).

**Planned Enhancement (Upcoming):**
Story signals will spawn at a distance (~800 world units) away from the player, requiring multiple jumps to reach. The pathline will auto-form when the player explores within 450 units proximity.

**UI Feedback:** Visual map display updates; "Signal detected" message emitted.

## 3. Roster & Progression (OfficerData.gd) [MOSTLY COMPLETE]

### 3.1 Data Structure Expansion
Refactor the simple roster dictionary into a robust OfficerData class.

```gdscript
class_name OfficerData
extends Resource

# Identity
var id: String          # "captain", "scout", "tech", "medic", "heavy", "sniper"
var alive: bool = true  # Permadeath flag

# Progression
var level: int = 1      # Current Level (Max 3)
var xp: int = 0         # Current XP accumulator
var unlocked_abilities: Array[String] = ["base"] # List of Ability IDs (e.g. "execute", "warlord")

# Health & Status
var max_hp: int         # Base HP
var current_hp: int     # Tracks persistent damage across jumps
var data_logs: int      # Unit-specific tech currency earned on level up
var injury_jumps: int   # 0 = Ready. >0 = Unavailable for selection.
```

### 3.2 The Injury System
**Trigger:** In TacticalManager.end_mission():
* If officer.current_hp < (officer.max_hp * 0.5) AND officer.alive == true:
    * Set officer.injury_jumps = 2.

**UI:** Display "Injured (2 Jumps)" in the Roster view.

**Recovery (Refined):** In VoyageManager.process_jump():
* Iterate through all officers.
* **Logic:** decrement `injury_jumps` ONLY if the jump is to a new (unvisited) node. Jumps along **Amber Pathlines** (backtracking) do not count towards recovery.
* **Healing:** When `injury_jumps` reaches 0, the officer's `current_hp` is restored to `max_hp`.
* **Travel Maintenance:** All living units (injured or not) heal a small percentage of HP on every jump to represent shipboard medical care.


### 3.3 XP & Leveling Logic
**XP Sources (TacticalManager):**
* **Kills:** +30 XP (to killer).
* **Survival:** +60 XP (to all living squad members).
* **Objective:** +45% Multiplier to total XP (if successful).

**Tech Tree Implementation (BarracksMenu.gd):**
Create a UI for unlocking skills.
**Requirements:**
* **Level 2 Unlock:** Requires Level 2 + 1 Data Log (Unit-specific).
* **Level 3 Unlock:** Requires Level 3 + 1 Data Log (Unit-specific).

**Progression Mechanics:**
* **Auto-Leveling:** Units automatically advance in level when XP thresholds are met.
* **Reward:** Each level up awards +1 Data Log to that specific unit.
* **UI Feedback:** The Mission Recap screen features an animated XP progression bar for each unit.


**Action:** On confirm, append the selected Ability ID to unlocked_abilities and deduct Data Logs from the officer's `data_logs` count.

### 3.4 Implementation Status (Code Check)
- [x] `OfficerData` class is implemented with `level`, `xp`, `unlocked_abilities`, `current_hp`, and `injury_jumps`.
- [x] Barracks/Ability Tree UI is implemented and supports level-gated, data-log-cost unlocks.
- [x] Tier selection behavior is implemented (one pick in level 2 tier, one pick in level 3 tier).
- [x] Mission-end XP earning is implemented (survival + kill XP, objective multiplier).
- [x] Injury application and jump-based recovery are implemented.

## 4. Combat Integration (Unit.gd) [MOSTLY COMPLETE]

### 4.1 Ability Check System
Modify the Unit class (Tactical Layer) to support the new dynamic abilities.

**Cooldown Modification:**
```gdscript
func get_ability_cooldown(ability_name: String) -> int:
    # Example: Captain Level 3 "Warlord"
    if ability_name == "Execute" and "warlord" in data.unlocked_abilities:
        return 0 # Cooldown removed
    return base_cooldown
```

**Damage Modification:**
```gdscript
func get_damage_modifier(target: Unit) -> float:
    # Example: Sniper Level 3 "Apex Predator"
    if "apex_predator" in data.unlocked_abilities and target.hp == target.max_hp:
        return 2.0 # Double damage vs full health
    return 1.0
```

### 4.2 Implementation Status (Code Check)
- [x] Ability-aware combat hooks are integrated in tactical flow (cooldowns and behavior changes tied to unlocked abilities).
- [x] Mission completion applies progression/economy rewards into `GameState` (`cash`, `intel`, `data_logs`, officer XP).
- [~] Additional balancing/cleanup remains, but core phase goals are in place.

## 5. Enemy Evolution (BiomeConfig.gd) [PARTIAL]

### 5.1 Tiered Scaling System
Enemies scale based on GameState.total_jumps_made.
**Data Structure:**
Update BiomeConfig to include Tiers for each enemy type.
* **Tier 1 (Standard):** Existing stats.
* **Tier 2 (Veteran):** +30% HP, +Damage. (Visual: Tint Red).
* **Tier 3 (Elite):** +60% HP, New Passives. (Visual: Tint Black/Gold).

**Spawn Logic (MapGenerator.gd):**
Determine the spawn list based on game depth.
* **Depth 0-15:** 90% Tier 1, 10% Tier 2.
* **Depth 16-30:** 50% Tier 1, 50% Tier 2.
* **Depth 31+:** 100% Tier 2 + Tier 3 Elites.

### 5.2 Dynamic Boss Scaling
Bosses (Station, Asteroid, Planet) are no longer static.
* **Formula:** BossHP = BaseHP * (1.0 + (Average_Squad_Level * 0.5)).

## 6. Win/Loss Conditions [IN PROGRESS]
* **Loss Condition 1 (Critical Failure):** hull_integrity <= 0.0.
* **Loss Condition 2 (Crew Wipe):** roster.all(x => !x.alive).
* **Win Condition:** Completion of the final Story Mission Chain (Triggered via specific Story Node).

## 7. Implementation Phases: Voyage 2.0 Update

**Current Overall Status:** **Mid Phase 5**

### Phase 1: Foundation & Economy Refactor [COMPLETED]
**Goal:** Establish the new data structures and remove legacy "Oregon Trail" systems to prevent logic conflicts.

**GameState.gd Cleanup**
* **Remove:** `colonists` variable and all associated game-over logic tied to population.
* **Remove:** `cryo_stability` from the Management Layer (keep strictly for Tactical turns).
* **Add:** `cash` (int, 100), `intel` (int, 0), `data_logs` (int, 0).
* **Update:** Ensure fuel and scrap logic relies on the new `cash` economy rather than trading posts.

**MarketMenu.tscn Implementation**
* Create a new UI scene accessible from the Management HUD.
* **Implement Static Transactions:**
    * **Buy Fuel:** 10 Cash → +5 Fuel.
    * **Buy Scrap:** 10 Cash → +10 Scrap.
    * **Repair Hull:** 50 Cash → +10% Integrity.

**HUD Update**
* Replace the "Colonist Count" display with Cash, Intel, and Data Logs counters in the top bar.

### Phase 2: The Infinite Map System [COMPLETED]
**Goal:** Replace the linear node graph with the procedural, infinite web.

* [x] **ProgressiveMapGenerator.gd**
* [x] Implements lazy generation of 2-3 child nodes per arrival, 300-500 units away in a 60° spread.
* [x] **Logic:** Random node types across biomes.

* [x] **VoyageManager.gd Navigation Update**
* [x] **Position Tracking:** Uses NodeData.position (world-space Vector2) to track the ship.
* [x] **Movement Logic:** Allow jumping to any connected node (parent-child or proximity within 450 units).
* [x] **Fuel Consumption:** 1 Fuel per jump. If fuel == 0, apply -5% Hull Damage.

* [x] **Node State System**
* [x] Update NodeData to track states: UNVISITED, CLEARED, VISITED, STORY, TRADING, LOCKED.
* [x] **Dead Zones:** If state is CLEARED, no reward on revisit.
* [x] **Amber Pathlines:** Free fuel cost for backtracking along visited nodes.

### Phase 3: The RPG Layer (Officers) [MOSTLY COMPLETE]
**Goal:** Convert static units into evolving characters with persistent data.

**OfficerData.gd Class**
* Create a new Resource class replacing the old dictionary format.
* **Add properties:** `level` (1-3), `xp`, `unlocked_abilities` (Array), `injury_jumps`.

**BarracksMenu.tscn UI**
* Create a management screen to view the 6 officers.
* **Tech Tree UI:**
    * Display Level 2 (Binary Choice) and Level 3 (Trinary Choice) slots.
    * **Implement "Unlock" button:** Checks xp >= Threshold AND data_logs >= Cost.
    * **Action:** Deduct Data Logs → Add Ability ID to `unlocked_abilities`.

**Injury System Integration**
* **Trigger:** In `TacticalManager`, if end_mission_hp < 50%, set `injury_jumps = 2`.
* **Recovery:** In `VoyageManager`, decrement `injury_jumps` on every jump.
* **Roster Check:** Prevent selecting injured officers for missions.

### Phase 4: Tactical Integration & Scaling [MOSTLY COMPLETE]
**Goal:** Connect the RPG layer to the actual combat gameplay.

**Unit.gd Ability Update**
* Modify `get_ability_cooldown()` and `calculate_damage()` to check the `OfficerData.unlocked_abilities` list.
* **Example:** If "Warlord" is in list, Execute cooldown = 0.

**XP & Loot Hooks**
* **Update MissionManager.complete_mission():**
    * Award Cash and Data Logs (RNG drops).
    * Award Intel (Objective completion).
    * Calculate and apply XP to `OfficerData`.

**Enemy Tiers (BiomeConfig.gd)**
* Define stats/sprites for Tier 2 (Veteran) and Tier 3 (Elite) enemies.
* **Update MapGenerator** to select tiers based on `GameState.total_jumps_made`.

**Status Update:** Mission-end XP + reward hooks and ability-linked tactical behavior are implemented; enemy scaling is present but still under ongoing tuning/cleanup.

### Phase 5: The Loop Closer [IN PROGRESS]
**Goal:** Implement the winning conditions and story drivers.

**Story Node Spawning**
* In `VoyageManager`, monitor `GameState.intel`.
* **Trigger:** If `intel >= 3` (1 in dev), find a candidate node and set type to STORY.
* **Reset:** Spend intel (deduct threshold amount) on story chapter completion.
* **Upcoming Enhancement:** Story signals will spawn farther away (~800 units) to require exploration.

**Win/Loss Logic**
* **Loss:** Trigger Game Over if `hull <= 0` OR `all_officers_dead`.
* **Win:** Define the specific "Final Story Mission" that triggers the Victory Screen.

**Status Update:** Story chapter progression, one-active story node enforcement, intel-on-completion spending, and final-story-mission victory trigger are wired. Final narrative choice buttons now use "CHOICE 5A / 5B" labeling convention. Remaining work is content/tuning polish.
