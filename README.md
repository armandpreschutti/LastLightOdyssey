# Last Light Odyssey

> "The last journey of the human race isn't a hero's quest; it's a survival marathon."

Last Light Odyssey is a space-faring survival manager built in Godot 4.6. Drawing inspiration from the grueling resource management of The Oregon Trail and the tactical depth of Fallout 1/2, players must guide the remnants of humanity across a 50-node star map to reach "New Earth."

## Core Gameplay Loop

*   **Strategic Navigation**: Plot a course through a procedural star map while managing **Fuel**, **Ship Integrity**, and **1,000 sleeping Colonists**.
*   **Random Event Resolution**: Survive solar flares, pirate ambushes, and system failures using your officers' expertise to mitigate losses.
*   **Tactical Scavenging**: Deploy a team of 3 officers to isometric, turn-based combat zones to scavenge for scrap and fuel.
*   **Pressure Mechanics**: Battle the **Cryo-Stability Timer**; spend too long on a mission, and your life-support systems will begin to fail, killing colonists every turn.

## Features

### 1. The Management Layer ("The Trail")

*   **Procedural Star Map**: 50 nodes across 16 rows, featuring branching paths, backtracking risks, and variable fuel costs.
*   **Resource Management**:
    *   **Colonists**: Your "Health" and final score.
    *   **Fuel**: Your clock. Running out triggers "Drift Mode" (−50 colonists per jump).
    *   **Ship Integrity**: Damaged by hazards; reaching 0% results in a Game Over.
    *   **Scrap**: Currency for trading and ship repairs.
*   **Specialist Mitigation**: Use specific officer roles (Medic, Tech, Scout, etc.) to spend Scrap and prevent catastrophic losses during random events.

### 2. The Tactical Layer ("The Search")

*   **Turn-Based Combat**: A unit-by-unit AP (Action Point) system featuring 6 unique officer archetypes:
    *   **Captain**: Can **Execute** weakened enemies.
    *   **Heavy**: Tank with **Armor Plating** and a devastating **Charge** melee attack.
    *   **Sniper**: Long-range specialist with **Precision Shot**.
    *   **Tech**: Deploys auto-firing **Turrets**.
    *   **Medic**: Combat healer with **Patch** and HP visibility.
    *   **Scout**: High visibility and **Overwatch** reaction shots.
*   **Cover & Flanking**: Tactical positioning matters. Flanking an enemy bypasses their cover and deals +50% bonus damage.
*   **Smart AI**: Enemies recognize when they are being flanked and will actively reposition to effective cover.

### 3. Procedural Environments

The game features three distinct biomes, each rendered programmatically with unique generation algorithms:

*   **Derelict Station**: BSP (Binary Space Partitioning) rooms and corridors.
*   **Asteroid Mine**: Organic cave networks generated via Cellular Automata.
*   **Planetary Surface**: Open terrain with clusters of alien vegetation and cover.

## Technical Implementation Status: Phase 12 (Narrative & Feedback)

| System | Status |
| :--- | :--- |
| **Core Engine** | Godot 4.6 / GL Compatibility |
| **Star Map** | 50-node procedural graph |
| **Tactical Combat** | AP System, LOS, Pathfinding |
| **Save/Load** | JSON-based persistence |
| **Tutorial** | 9-step guided onboarding |
| **Smart AI** | Flanking awareness & Repositioning |
| **Narrative** | Intro scene & Colonist Milestone events |
| **Audio** | Music & SFX Integration (In Progress) |

## Project Structure

*   `/scenes`: Separated into `management/` (Star Map) and `tactical/` (Combat).
*   `/scripts/autoload`: Global singletons for **GameState**, **EventManager**, and **TutorialManager**.
*   `/assets/sprites`: 52 custom PNG assets for characters, UI, and objects.
*   `BiomeConfig.gd`: Centralized definitions for procedural rendering colors and enemy spawn rates.

## Getting Started

1.  Clone the repository.
2.  Open `project.godot` in **Godot 4.6** or newer.
3.  Run `main.tscn` to start the Title Screen.

## Development Philosophy

The project follows a "Mechanics First" approach. The core tension is derived from resource scarcity and permanent consequences. Dead officers stay dead, and every jump toward New Earth is a calculated risk.
