extends Node
## Local-first persistence: scores, stars, unlocks, settings, tutorial, achievements.

const SAVE_PATH: String = "user://cluck_and_worms_save.cfg"
const SECTION_PROGRESS: String = "progress"
const SECTION_LEVELS: String = "levels"
const SECTION_SETTINGS: String = "settings"
const SECTION_ACHIEVEMENTS: String = "achievements"
const SECTION_LEADERBOARD: String = "leaderboard"
const LEADERBOARD_SIZE: int = 8

var high_score: int = 0
var best_combo: int = 0
var stages_cleared: int = 0
var max_level_unlocked: int = 1 ## Campaign level number 1..N
var tutorial_done: bool = false
var reduced_shake: bool = false
var reduced_fx: bool = false
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.7
var mute_all: bool = false

## level_id -> { "stars": int, "best_score": int }
var level_records: Dictionary = {}
## achievement_id -> true
var achievements: Dictionary = {}
## Local top runs: [{ "name": String, "score": int }, ...] sorted desc.
var leaderboard: Array = []
var current_player_name: String = "Farmer Cluck"
var profiles: Array = ["Farmer Cluck"]


func _ready() -> void:
	load_save()
	call_deferred("_apply_audio")


func load_save() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		_reset_defaults()
		return
	high_score = int(cfg.get_value(SECTION_PROGRESS, "high_score", 0))
	best_combo = int(cfg.get_value(SECTION_PROGRESS, "best_combo", 0))
	stages_cleared = int(cfg.get_value(SECTION_PROGRESS, "stages_cleared", 0))
	max_level_unlocked = int(cfg.get_value(SECTION_PROGRESS, "max_level_unlocked", 1))
	tutorial_done = bool(cfg.get_value(SECTION_PROGRESS, "tutorial_done", false))
	level_records = cfg.get_value(SECTION_LEVELS, "records", {}) as Dictionary
	if level_records == null:
		level_records = {}
	achievements = cfg.get_value(SECTION_ACHIEVEMENTS, "flags", {}) as Dictionary
	if achievements == null:
		achievements = {}
	reduced_shake = bool(cfg.get_value(SECTION_SETTINGS, "reduced_shake", false))
	reduced_fx = bool(cfg.get_value(SECTION_SETTINGS, "reduced_fx", false))
	master_volume = float(cfg.get_value(SECTION_SETTINGS, "master_volume", 1.0))
	sfx_volume = float(cfg.get_value(SECTION_SETTINGS, "sfx_volume", 1.0))
	music_volume = float(cfg.get_value(SECTION_SETTINGS, "music_volume", 0.7))
	mute_all = bool(cfg.get_value(SECTION_SETTINGS, "mute_all", false))
	max_level_unlocked = maxi(max_level_unlocked, 1)
	current_player_name = String(cfg.get_value(SECTION_PROGRESS, "player_name", "Farmer Cluck"))
	profiles = cfg.get_value(SECTION_PROGRESS, "profiles", ["Farmer Cluck"]) as Array
	if profiles == null or profiles.is_empty():
		profiles = [current_player_name]
	elif not profiles.has(current_player_name):
		profiles.append(current_player_name)
	leaderboard = cfg.get_value(SECTION_LEADERBOARD, "entries", []) as Array
	if leaderboard == null:
		leaderboard = []
	_migrate_leaderboard_from_high_score()


func _reset_defaults() -> void:
	high_score = 0
	best_combo = 0
	stages_cleared = 0
	max_level_unlocked = 1
	tutorial_done = false
	current_player_name = "Farmer Cluck"
	profiles = ["Farmer Cluck"]
	level_records = {}
	achievements = {}
	leaderboard = []


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(SECTION_PROGRESS, "high_score", high_score)
	cfg.set_value(SECTION_PROGRESS, "best_combo", best_combo)
	cfg.set_value(SECTION_PROGRESS, "stages_cleared", stages_cleared)
	cfg.set_value(SECTION_PROGRESS, "max_level_unlocked", max_level_unlocked)
	cfg.set_value(SECTION_PROGRESS, "tutorial_done", tutorial_done)
	cfg.set_value(SECTION_PROGRESS, "player_name", current_player_name)
	cfg.set_value(SECTION_PROGRESS, "profiles", profiles)
	cfg.set_value(SECTION_LEVELS, "records", level_records)
	cfg.set_value(SECTION_ACHIEVEMENTS, "flags", achievements)
	cfg.set_value(SECTION_LEADERBOARD, "entries", leaderboard)
	cfg.set_value(SECTION_SETTINGS, "reduced_shake", reduced_shake)
	cfg.set_value(SECTION_SETTINGS, "reduced_fx", reduced_fx)
	cfg.set_value(SECTION_SETTINGS, "master_volume", master_volume)
	cfg.set_value(SECTION_SETTINGS, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION_SETTINGS, "music_volume", music_volume)
	cfg.set_value(SECTION_SETTINGS, "mute_all", mute_all)
	cfg.save(SAVE_PATH)


func set_player_name(new_name: String) -> void:
	var clean: String = new_name.strip_edges()
	if clean.is_empty():
		clean = "Farmer Cluck"
	current_player_name = clean
	if not profiles.has(clean):
		profiles.append(clean)
	save()
	EventBus.player_profile_changed.emit(current_player_name)


func try_submit_score(score: int, peak_combo: int = 0) -> bool:
	var is_new_high: bool = score > high_score
	var combo_improved: bool = peak_combo > best_combo
	if is_new_high:
		high_score = score
	if combo_improved:
		best_combo = peak_combo
	var board_changed: bool = _insert_leaderboard(score, current_player_name)
	if is_new_high or combo_improved or board_changed:
		save()
	return is_new_high


func get_leaderboard() -> Array:
	return leaderboard.duplicate(true)


func _insert_leaderboard(score: int, player_name: String = "You") -> bool:
	if score <= 0:
		return false
	if leaderboard.size() >= LEADERBOARD_SIZE:
		var last: Dictionary = leaderboard[leaderboard.size() - 1] as Dictionary
		if score <= int(last.get("score", 0)):
			return false
	# Skip exact duplicate of current #1 (retry spam).
	if not leaderboard.is_empty():
		var top: Dictionary = leaderboard[0] as Dictionary
		if int(top.get("score", 0)) == score and String(top.get("name", "")) == player_name:
			return false
	leaderboard.append({"name": player_name, "score": score})
	leaderboard.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("score", 0)) > int((b as Dictionary).get("score", 0))
	)
	if leaderboard.size() > LEADERBOARD_SIZE:
		leaderboard.resize(LEADERBOARD_SIZE)
	return true


func _migrate_leaderboard_from_high_score() -> void:
	if leaderboard.is_empty() and high_score > 0:
		leaderboard = [{"name": "You", "score": high_score}]
		save()


func record_stage_cleared(stage_index: int) -> void:
	var cleared: int = stage_index + 1
	if cleared > stages_cleared:
		stages_cleared = cleared
		save()


func record_level_result(level_id: StringName, level_number: int, stars: int, score: int) -> void:
	var key: String = String(level_id)
	var prev: Dictionary = level_records.get(key, {"stars": 0, "best_score": 0}) as Dictionary
	var best_stars: int = maxi(int(prev.get("stars", 0)), clampi(stars, 0, 3))
	var best: int = maxi(int(prev.get("best_score", 0)), score)
	level_records[key] = {"stars": best_stars, "best_score": best}
	# Unlock next campaign level.
	max_level_unlocked = maxi(max_level_unlocked, level_number + 1)
	save()


func get_level_stars(level_id: StringName) -> int:
	var rec: Variant = level_records.get(String(level_id), null)
	if rec is Dictionary:
		return int((rec as Dictionary).get("stars", 0))
	return 0


func get_level_best_score(level_id: StringName) -> int:
	var rec: Variant = level_records.get(String(level_id), null)
	if rec is Dictionary:
		return int((rec as Dictionary).get("best_score", 0))
	return 0


func is_level_unlocked(level_number: int) -> bool:
	return level_number <= max_level_unlocked


func unlock_achievement(id: StringName) -> bool:
	var key: String = String(id)
	if achievements.get(key, false):
		return false
	achievements[key] = true
	save()
	EventBus.achievement_unlocked.emit(id)
	return true


func has_achievement(id: StringName) -> bool:
	return bool(achievements.get(String(id), false))


func set_tutorial_done(done: bool = true) -> void:
	tutorial_done = done
	save()


func apply_settings(
	p_master: float,
	p_sfx: float,
	p_music: float,
	p_mute: bool,
	p_shake: bool,
	p_fx: bool
) -> void:
	master_volume = clampf(p_master, 0.0, 1.0)
	sfx_volume = clampf(p_sfx, 0.0, 1.0)
	music_volume = clampf(p_music, 0.0, 1.0)
	mute_all = p_mute
	reduced_shake = p_shake
	reduced_fx = p_fx
	_apply_audio()
	save()


func _apply_audio() -> void:
	if AudioManager == null:
		return
	var mute_mul: float = 0.0 if mute_all else 1.0
	AudioManager.master_volume_db = linear_to_db(maxi(master_volume * mute_mul, 0.0001)) if master_volume * mute_mul > 0.0 else -80.0
	AudioManager.sfx_volume_db = linear_to_db(maxi(sfx_volume, 0.0001)) - 2.0 if sfx_volume > 0.0 else -80.0
	AudioManager.music_volume_db = linear_to_db(maxi(music_volume, 0.0001)) - 6.0 if music_volume > 0.0 else -80.0
	AudioManager.set_master_volume_db(AudioManager.master_volume_db)
