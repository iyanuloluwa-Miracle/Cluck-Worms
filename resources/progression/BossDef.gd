class_name BossDef
extends Resource
## Data for a stage-ending boss encounter. Gameplay stays Zuma-based —
## bosses take damage from matches and direct hits during vulnerability
## windows, and pressure the chain with telegraphed attacks.

enum Kind {
	GARDEN_GUARDIAN,
	WORM_QUEEN,
	GOLDEN_ROOSTER,
}

@export var id: StringName = &"boss_garden_guardian"
@export var display_name: String = "Garden Guardian"
@export var title: String = "Keeper of the Backyard"
@export var kind: Kind = Kind.GARDEN_GUARDIAN
@export var max_health: float = 100.0
@export var phases: int = 2
## Damage per worm removed by a match while the boss is vulnerable.
@export var damage_per_worm: float = 4.0
@export var cascade_damage_bonus: float = 6.0
## Damage from a projectile striking the boss while vulnerable.
@export var direct_hit_damage: float = 4.0
## Damage multiplier during the post-attack weak window.
@export var weak_multiplier: float = 1.5
@export var weak_duration: float = 2.5
@export var intro_duration: float = 2.2
@export var telegraph_duration: float = 1.2
@export var attack_interval: float = 8.0
## Shell / shield duration after phase changes (0 = none).
@export var armor_duration: float = 0.0
## Hit circle radius for direct projectile hits.
@export var body_radius: float = 58.0

@export_group("Arena")
@export var arena_position: Vector2 = Vector2(640, 262)
@export var chicken_position: Vector2 = Vector2(640, 480)
@export var arena_path: PackedVector2Array = PackedVector2Array()


static func garden_guardian() -> BossDef:
	var b := BossDef.new()
	b.id = &"boss_garden_guardian"
	b.display_name = "Garden Guardian"
	b.title = "Keeper of the Backyard"
	b.kind = Kind.GARDEN_GUARDIAN
	b.max_health = 90.0
	b.phases = 2
	b.damage_per_worm = 5.0
	b.cascade_damage_bonus = 8.0
	b.direct_hit_damage = 4.0
	b.intro_duration = 2.4
	b.telegraph_duration = 1.4
	b.attack_interval = 9.0
	b.arena_path = PathFactory.path_boss_guardian_grove()
	return b


static func worm_queen() -> BossDef:
	var b := BossDef.new()
	b.id = &"boss_worm_queen"
	b.display_name = "Worm Queen"
	b.title = "Sovereign of the Wild Garden"
	b.kind = Kind.WORM_QUEEN
	b.max_health = 130.0
	b.phases = 3
	b.damage_per_worm = 4.5
	b.cascade_damage_bonus = 10.0
	b.direct_hit_damage = 3.5
	b.intro_duration = 2.6
	b.telegraph_duration = 1.2
	b.armor_duration = 6.0
	b.attack_interval = 8.0
	b.arena_path = PathFactory.path_boss_queen_hive()
	return b


static func golden_rooster() -> BossDef:
	var b := BossDef.new()
	b.id = &"boss_golden_rooster"
	b.display_name = "Golden Rooster"
	b.title = "Tyrant of the Forbidden Coop"
	b.kind = Kind.GOLDEN_ROOSTER
	b.max_health = 180.0
	b.phases = 3
	b.damage_per_worm = 4.0
	b.cascade_damage_bonus = 12.0
	b.direct_hit_damage = 3.0
	b.intro_duration = 3.4
	b.telegraph_duration = 1.1
	b.armor_duration = 2.2
	b.attack_interval = 7.0
	b.body_radius = 62.0
	b.arena_path = PathFactory.path_boss_rooster_roost()
	return b
