# Last Light Odyssey

> "The last journey of the human race isn't a hero's quest; it's a survival marathon."

Last Light Odyssey is a space-faring survival manager built in Godot 4.6. Drawing inspiration from the grueling resource management of The Oregon Trail and the tactical depth of Fallout 1/2, players must guide the remnants of humanity across a 50-node star map to reach "New Earth."

## Core Gameplay Loop

*   **Strategic Navigation**: Plot a course through a procedural star map while managing **Fuel** and **Ship Integrity**.
*   **Random Event Resolution**: Survive solar flares, pirate ambushes, and system failures using your officers' expertise to mitigate losses.
*   **Tactical Scavenging**: Deploy a team of 3 officers to isometric, turn-based combat zones to scavenge for cash and fuel.
*   **Pressure Mechanics**: Battle against **Structural Stress**; the ship takes damage each tactical turn, creating pressure to finish missions quickly.

## Features

### Quick Start
*   **Progressive Star Map**: Infinite procedural graph generating new nodes in a cone as the player travels.
*   **Resource Management**:
    *   **Fuel**: Your clock. Running out triggers "Drift Mode" (−5 hull integrity per jump).
    *   **Hull**: Your survival. Reaches 0% and the mission fails.
    *   **Cash**: Your economy. Used for fuel, repairs, and mitigating negative events.
*   **Specialist Mitigation**: Use specific officer roles (Medic, Tech, Scout, etc.) to mitigate catastrophic losses during random events.
*   **Tactical Gameplay**: Turn-based grid combat. Extract your officers to survive.
*   **Narrative**: Branching story campaign with an Intel threshold of 3.

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
| **Star Map** | Progressive procedural graph |
| **Tactical Combat** | AP System, LOS, Pathfinding |
| **Save/Load** | JSON-based persistence |
| **Tutorial** | Contextual system triggered on encounter |
| **Smart AI** | Flanking awareness & Repositioning |
| **Narrative** | Branching campaign tree |
| **Threats** | Raiders chase mechanic |
| **Navigation** | Wormholes for long-distance jumps |

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
