class_name WormColor
extends RefCounted
## Shared worm color definitions. Six vibrant, high-contrast hues
## chosen for instant readability on a busy playfield.

enum Kind {
	RED,
	BLUE,
	GREEN,
	YELLOW,
	PURPLE,
	ORANGE,
}

const KIND_COUNT: int = 6

## Primary fill colors — saturated and distinct under compression.
const PALETTE: Dictionary = {
	Kind.RED: Color(0.92, 0.22, 0.28),
	Kind.BLUE: Color(0.20, 0.48, 0.95),
	Kind.GREEN: Color(0.18, 0.78, 0.38),
	Kind.YELLOW: Color(0.98, 0.86, 0.16),
	Kind.PURPLE: Color(0.68, 0.28, 0.92),
	Kind.ORANGE: Color(0.98, 0.52, 0.10),
}

## Slightly darker outline / belly shade for depth.
const OUTLINE_PALETTE: Dictionary = {
	Kind.RED: Color(0.55, 0.08, 0.12),
	Kind.BLUE: Color(0.08, 0.22, 0.55),
	Kind.GREEN: Color(0.06, 0.42, 0.18),
	Kind.YELLOW: Color(0.55, 0.42, 0.05),
	Kind.PURPLE: Color(0.35, 0.10, 0.52),
	Kind.ORANGE: Color(0.55, 0.25, 0.04),
}

## Soft highlight for the head to reinforce facing direction.
const HIGHLIGHT_PALETTE: Dictionary = {
	Kind.RED: Color(1.0, 0.55, 0.55),
	Kind.BLUE: Color(0.55, 0.75, 1.0),
	Kind.GREEN: Color(0.55, 1.0, 0.70),
	Kind.YELLOW: Color(1.0, 0.98, 0.65),
	Kind.PURPLE: Color(0.88, 0.65, 1.0),
	Kind.ORANGE: Color(1.0, 0.78, 0.45),
}


static func get_fill(kind: Kind) -> Color:
	return PALETTE[kind]


static func get_outline(kind: Kind) -> Color:
	return OUTLINE_PALETTE[kind]


static func get_highlight(kind: Kind) -> Color:
	return HIGHLIGHT_PALETTE[kind]


static func random_kind(rng: RandomNumberGenerator, color_count: int = KIND_COUNT) -> Kind:
	var count: int = clampi(color_count, 1, KIND_COUNT)
	return rng.randi_range(0, count - 1) as Kind


static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.RED:
			return "Red"
		Kind.BLUE:
			return "Blue"
		Kind.GREEN:
			return "Green"
		Kind.YELLOW:
			return "Yellow"
		Kind.PURPLE:
			return "Purple"
		Kind.ORANGE:
			return "Orange"
		_:
			return "Unknown"
