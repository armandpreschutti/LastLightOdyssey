# Voyage 2.0 Technical Implementation Plan

**Target Engine:** Godot 4.6
**Scope:** Management Layer, Economy, Progression, Map Generation

## 1. Global Architecture & Economy (GameState.gd)

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
| **intel** | int | 0 | Story Progress. Gained from tactical missions. Threshold 10 spawns a Story Node. |
| **data_logs** | int | 0 | Tech Currency. Shared resource used to purchase Ability Tree slots. |

### 1.3 The Market System (MarketMenu.tscn)
Create a new UI scene accessible from the Management HUD. It serves as the primary "bailout" mechanism.
Transactions: Implement functions that directly modify GameState.
* **buy_fuel():** Check cash >= 10. If true: cash -= 10, fuel += 5.
* **buy_scrap():** Check cash >= 10. If true: cash -= 10, scrap += 10.
* **repair_hull():** Check cash >= 50. If true: cash -= 50, hull_integrity += 10.0 (Clamp at 100.0).

## 2. The Infinite Map System (VoyageManager.gd)

### 2.1 Coordinate-Based Generation
Replace the linear array-based StarMapGenerator with an InfiniteGridGenerator.
* **Coordinate System:** Track player position using Vector2(x, y) (Virtual Grid).
* **Data Structure:** `var visited_nodes: Dictionary = {}`
    * **Key:** Vector2 (Grid Coordinate).
    * **Value:** NodeData (Custom Resource).

**Algorithm:**
When VoyageManager initializes or the player moves:
1. Check the 6 adjacent hex coordinates (or 4 grid coordinates) around the player.
2. If a coordinate is NOT in visited_nodes, instantiate a new NodeData object.
3. Randomize Type: 40% Scavenge, 40% Empty/Event, 20% (Reserved).
4. Store in visited_nodes and render the node on the UI.

### 2.2 Node States & Backtracking
Update the NodeData class to include a state Enum:
* **UNVISITED (0):** Default. Clickable. Enters Tactical Mode or Event.
* **CLEARED (1):** Set after mission success. Node is traversable but interacts as a "Dead Zone" (Costs fuel, no reward).
* **STORY (2):** Special state. Overrides standard behavior.

### 2.3 Story Node Spawning Logic
**Trigger:** Monitor GameState.intel in VoyageManager.
**Logic:**
1. When intel >= 10:
2. Search visited_nodes for an UNVISITED node within Range 3 of the player.
3. If none exist, generate a new one at Range 3.
4. Force node.type = STORY_MISSION.
5. Reset intel = 0.

**UI Feedback:** Spawn a "Signal Detected" arrow on the map UI pointing to the coordinate.

## 3. Roster & Progression (OfficerData.gd)

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
var injury_jumps: int   # 0 = Ready. >0 = Unavailable for selection.
```

### 3.2 The Injury System
**Trigger:** In TacticalManager.end_mission():
* If officer.current_hp < (officer.max_hp * 0.5) AND officer.alive == true:
    * Set officer.injury_jumps = 2.

**UI:** Display "Injured (2 Jumps)" in the Roster view.

**Recovery:** In VoyageManager.process_jump():
* Iterate through all officers.
* If injury_jumps > 0: injury_jumps -= 1.

### 3.3 XP & Leveling Logic
**XP Sources (TacticalManager):**
* **Kills:** +10 XP (to killer).
* **Survival:** +20 XP (to all living squad members).
* **Objective:** +15% Multiplier to total XP (if successful).

**Tech Tree Implementation (BarracksMenu.gd):**
Create a UI for unlocking skills.
**Requirements:**
* **Level 2 Unlock:** Requires 100 XP + 5 Data Logs.
* **Level 3 Unlock:** Requires 300 XP + 10 Data Logs.

**Selection:**
* **Level 2:** User selects Option A OR Option B.
* **Level 3:** User selects Option A OR Option B OR Option C.

**Action:** On confirm, append the selected Ability ID to unlocked_abilities and deduct Data Logs from GameState.

## 4. Combat Integration (Unit.gd)

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

## 5. Enemy Evolution (BiomeConfig.gd)

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

## 6. Win/Loss Conditions
* **Loss Condition 1 (Critical Failure):** hull_integrity <= 0.0.
* **Loss Condition 2 (Crew Wipe):** roster.all(x => !x.alive).
* **Win Condition:** Completion of the final Story Mission Chain (Triggered via specific Story Node).

## 7. Implementation Phases: Voyage 2.0 Update

### Phase 1: Foundation & Economy Refactor
**Goal:** Establish the new data structures and remove legacy "Oregon Trail" systems to prevent logic conflicts.

**GameState.gd Cleanup**
* **Remove:** `colonists` variable and all associated game-over logic tied to population.
* **Remove:** `cryo_stability` from the Management Layer (keep strictly for Tactical turns).
* **Add:** `cash` (int, 100), `intel` (int, 0), `data_logs` (int, 0).
* **Update:** Ensure fuel and scrap logic relies on the new `cash` economy rather than trading posts.

**MarketMenu.tscn Implementation**
* Create a new UI scene accessible from the Management HUD.
* **Implement Static Transactions:**
    * **Buy Fuel:** 10 Cash $\rightarrow$ +5 Fuel.
    * **Buy Scrap:** 10 Cash $\rightarrow$ +10 Scrap.
    * **Repair Hull:** 50 Cash $\rightarrow$ +10% Integrity.

**HUD Update**
* Replace the "Colonist Count" display with Cash, Intel, and Data Logs counters in the top bar.

### Phase 2: The Infinite Map System
**Goal:** Replace the linear node graph with the procedural, infinite web.

**InfiniteGridGenerator.gd**
* Create this new script to handle coordinate-based generation.
* Implement logic to generate NodeData for (x+1, y), (x-1, y), (x, y+1), (x, y-1) relative to the player.
* **Logic:** 40% Scavenge, 40% Empty/Event.

**VoyageManager.gd Navigation Update**
* **Grid Tracking:** Add `current_grid_position` (Vector2) to track the ship.
* **Movement Logic:** Allow clicking any adjacent node (removing the "forward-only" restriction).
* **Fuel Consumption:** 1 Fuel per jump. If fuel == 0, apply -5% Hull Damage.

**Node State System**
* Update NodeData to track states: UNVISITED, CLEARED, STORY.
* **Dead Zones:** If state is CLEARED, disable the "Scavenge" button (traversal only).

### Phase 3: The RPG Layer (Officers)
**Goal:** Convert static units into evolving characters with persistent data.

**OfficerData.gd Class**
* Create a new Resource class replacing the old dictionary format.
* **Add properties:** `level` (1-3), `xp`, `unlocked_abilities` (Array), `injury_jumps`.

**BarracksMenu.tscn UI**
* Create a management screen to view the 6 officers.
* **Tech Tree UI:**
    * Display Level 2 (Binary Choice) and Level 3 (Trinary Choice) slots.
    * **Implement "Unlock" button:** Checks xp >= Threshold AND data_logs >= Cost.
    * **Action:** Deduct Data Logs $\rightarrow$ Add Ability ID to `unlocked_abilities`.

**Injury System Integration**
* **Trigger:** In `TacticalManager`, if end_mission_hp < 50%, set `injury_jumps = 2`.
* **Recovery:** In `VoyageManager`, decrement `injury_jumps` on every jump.
* **Roster Check:** Prevent selecting injured officers for missions.

### Phase 4: Tactical Integration & Scaling
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

### Phase 5: The Loop Closer
**Goal:** Implement the winning conditions and story drivers.

**Story Node Spawning**
* In `VoyageManager`, monitor `GameState.intel`.
* **Trigger:** If `intel >= 10`, find a node at Range 3 and set type to STORY.
* **Reset:** Set `intel = 0` immediately upon spawn.

**Win/Loss Logic**
* **Loss:** Trigger Game Over if `hull <= 0` OR `all_officers_dead`.
* **Win:** Define the specific "Final Story Mission" that triggers the Victory Screen.
