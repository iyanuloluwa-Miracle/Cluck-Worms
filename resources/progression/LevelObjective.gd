class_name LevelObjective
extends RefCounted
## Win-condition kinds for campaign / challenge levels.

enum Kind {
	CLEAR_CHAIN,
	DEFEAT_BOSS,
	SCORE_TARGET,
	SURVIVE_TIME,
	LIMITED_SHOTS,
	COMBO_TARGET,
}


static func display_name(kind: Kind) -> String:
	match kind:
		Kind.CLEAR_CHAIN:
			return "Clear the chain"
		Kind.DEFEAT_BOSS:
			return "Defeat the boss"
		Kind.SCORE_TARGET:
			return "Reach the score"
		Kind.SURVIVE_TIME:
			return "Survive the march"
		Kind.LIMITED_SHOTS:
			return "Clear with limited shots"
		Kind.COMBO_TARGET:
			return "Build a combo"
		_:
			return "Complete the level"


static func short_label(kind: Kind) -> String:
	match kind:
		Kind.CLEAR_CHAIN:
			return "CLEAR"
		Kind.DEFEAT_BOSS:
			return "BOSS"
		Kind.SCORE_TARGET:
			return "SCORE"
		Kind.SURVIVE_TIME:
			return "SURVIVE"
		Kind.LIMITED_SHOTS:
			return "SHOTS"
		Kind.COMBO_TARGET:
			return "COMBO"
		_:
			return "GOAL"
