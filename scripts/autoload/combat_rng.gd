extends Node
## Combat RNG - Forgiving random number generator for attack rolls
## Uses a "bad luck protection" system to prevent frustrating miss streaks
## 
## How it works:
## - Tracks consecutive misses per unit
## - After each miss, adds a stacking bonus to the next shot
## - The displayed hit chance is still accurate on average, but streaks are reduced
## - Resets on hit or when unit changes targets

#region Configuration
## Bonus hit chance added per consecutive miss (e.g., 0.10 = +10% per miss)
const MISS_STREAK_BONUS: float = 0.08  # Increased from 5% to 8% per miss for more forgiveness

## Maximum bonus from miss streaks (caps the protection)
const MAX_MISS_STREAK_BONUS: float = 0.30  # Increased from 20% to 30% max bonus

## Whether to apply bad luck protection to player units
const PROTECT_PLAYER: bool = true

## Whether to apply bad luck protection to enemy units (set false for harder game)
const PROTECT_ENEMIES: bool = false
#endregion

#region State Tracking
## Tracks consecutive misses per unit (keyed by unit instance ID)
var _player_miss_streaks: Dictionary = {}
var _enemy_miss_streaks: Dictionary = {}
#endregion


## Roll for attack success with bad luck protection
## Returns true if the attack hits
func roll_attack(hit_chance: float, is_player: bool, unit_id: int) -> bool:
	var base_chance = hit_chance / 100.0
	var effective_chance = base_chance
	
	# Apply bad luck protection if enabled for this unit type
	var should_protect = (is_player and PROTECT_PLAYER) or (not is_player and PROTECT_ENEMIES)
	var streak_dict = _player_miss_streaks if is_player else _enemy_miss_streaks
	
	if should_protect:
		var miss_streak = streak_dict.get(unit_id, 0)
		var bonus = minf(miss_streak * MISS_STREAK_BONUS, MAX_MISS_STREAK_BONUS)
		effective_chance = minf(base_chance + bonus, 0.95)  # Cap at 95% even with bonus
		

	# Roll the dice
	var roll = randf()
	var hit = roll <= effective_chance
	
	# Update streak tracking
	if should_protect:
		if hit:
			# Reset streak on hit
			streak_dict[unit_id] = 0
		else:
			# Increment streak on miss
			streak_dict[unit_id] = streak_dict.get(unit_id, 0) + 1
	
	return hit


## Reset miss streak for a specific unit (call when unit dies or mission ends)
func reset_unit_streak(is_player: bool, unit_id: int) -> void:
	var streak_dict = _player_miss_streaks if is_player else _enemy_miss_streaks
	streak_dict.erase(unit_id)


## Reset all streaks (call at mission start/end)
func reset_all_streaks() -> void:
	_player_miss_streaks.clear()
	_enemy_miss_streaks.clear()


## Get current miss streak for a unit (for UI/debugging)
func get_miss_streak(is_player: bool, unit_id: int) -> int:
	var streak_dict = _player_miss_streaks if is_player else _enemy_miss_streaks
	return streak_dict.get(unit_id, 0)


## Get the effective hit chance including bad luck protection bonus
## Useful for showing the player their "real" chance after misses
func get_effective_hit_chance(hit_chance: float, is_player: bool, unit_id: int) -> float:
	var should_protect = (is_player and PROTECT_PLAYER) or (not is_player and PROTECT_ENEMIES)
	
	if not should_protect:
		return hit_chance
	
	var streak_dict = _player_miss_streaks if is_player else _enemy_miss_streaks
	var miss_streak = streak_dict.get(unit_id, 0)
	var bonus = minf(miss_streak * MISS_STREAK_BONUS, MAX_MISS_STREAK_BONUS)
	
	return minf(hit_chance + bonus * 100.0, 95.0)
