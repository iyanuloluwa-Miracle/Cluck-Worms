class_name AchievementCatalog
extends RefCounted
## Display metadata for persistent achievement ids.


static func all_ids() -> Array[StringName]:
	return [
		&"first_match",
		&"combo_5",
		&"combo_10",
		&"cascade_master",
		&"three_star",
		&"chain_breaker",
		&"boss_slayer",
		&"precision_shooter",
		&"stage_clear_1",
		&"stage_clear_2",
		&"stage_clear_3",
		&"campaign_champion",
		&"daily_done",
	] as Array[StringName]


static func title(id: StringName) -> String:
	match id:
		&"first_match":
			return "First Match"
		&"combo_5":
			return "Combo Starter"
		&"combo_10":
			return "Combo Master"
		&"cascade_master":
			return "Chain Breaker"
		&"three_star":
			return "Perfect Peck"
		&"chain_breaker":
			return "Gap Closer"
		&"boss_slayer":
			return "Boss Slayer"
		&"precision_shooter":
			return "Precision Shooter"
		&"stage_clear_1":
			return "Backyard Cleared"
		&"stage_clear_2":
			return "Wild Garden Cleared"
		&"stage_clear_3":
			return "Forbidden Coop Cleared"
		&"campaign_champion":
			return "Campaign Champion"
		&"daily_done":
			return "Daily Farmer"
		_:
			return String(id).capitalize()


static func description(id: StringName) -> String:
	match id:
		&"first_match":
			return "Pop your first group of worms."
		&"combo_5":
			return "Reach a 5× combo."
		&"combo_10":
			return "Reach a 10× combo."
		&"cascade_master":
			return "Trigger 3 cascades in one level."
		&"three_star":
			return "Earn 3 stars on any level."
		&"chain_breaker":
			return "Cause a chain reverse after a match."
		&"boss_slayer":
			return "Defeat any stage boss."
		&"precision_shooter":
			return "Clear a group of 6 or more worms."
		&"stage_clear_1":
			return "Finish The Backyard."
		&"stage_clear_2":
			return "Finish The Wild Garden."
		&"stage_clear_3":
			return "Finish The Forbidden Coop."
		&"campaign_champion":
			return "Clear every stage."
		&"daily_done":
			return "Complete a Daily Challenge."
		_:
			return ""
