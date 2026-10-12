class_name WormType
extends RefCounted
## Special worm kinds that enhance matching without replacing it.

enum Kind {
	NORMAL = 0,
	RAINBOW = 1, ## Wildcard — matches any color in a run.
	BOMB = 2, ## On match, clears nearby chain neighbors.
	SLOW = 3, ## Briefly slows the whole chain when matched.
	BONUS = 4, ## Extra score when cleared.
}


static func display_name(kind: Kind) -> String:
	match kind:
		Kind.RAINBOW:
			return "Rainbow"
		Kind.BOMB:
			return "Bomb"
		Kind.SLOW:
			return "Slow"
		Kind.BONUS:
			return "Bonus"
		_:
			return "Worm"


static func is_special(kind: Kind) -> bool:
	return kind != Kind.NORMAL
