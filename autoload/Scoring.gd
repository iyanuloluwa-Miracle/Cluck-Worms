extends Node
## Central, deterministic scoring rules for matches / cascades / stars.

const MIN_MATCH: int = 3


func match_points(count: int, cascade_depth: int, combo: int, has_bonus_worm: bool = false) -> int:
	var extras: int = maxi(count - MIN_MATCH, 0)
	var base: int = count * GameManager.points_per_worm + extras * GameManager.points_per_extra_worm
	if count >= GameManager.large_group_bonus_threshold:
		base += (count - GameManager.large_group_bonus_threshold + 1) * GameManager.large_group_bonus_per_worm
	base += cascade_depth * GameManager.cascade_bonus_per_depth
	if has_bonus_worm:
		base += 150
	var multiplier: float = 1.0 + float(maxi(combo - 1, 0)) * GameManager.combo_multiplier_step
	multiplier = minf(multiplier, GameManager.max_combo_multiplier)
	return int(round(float(base) * multiplier))


## Stars from run score relative to a soft target derived from worm budget.
func stars_for_level(score: int, total_worms: int, lives: int, cascades_this_level: int) -> int:
	var target: int = maxi(total_worms * 90, 1200)
	var stars: int = 1
	if score >= int(float(target) * 0.55):
		stars = 2
	if score >= target or (lives >= 2 and cascades_this_level >= 2):
		stars = 3
	if score >= int(float(target) * 1.35):
		stars = 3
	return clampi(stars, 1, 3)
