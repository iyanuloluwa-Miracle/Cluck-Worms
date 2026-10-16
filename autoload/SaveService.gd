extends Node
## Local-first persistence: scores, stars, unlocks, settings, tutorial, achievements.

const SAVE_PATH: String = "user://cluck_and_worms_save.cfg"
## Bump when the save layout changes; older files are migrated on load.
const SAVE_VERSION: int = 2
## Stats-only writes are batched to at most one disk write per interval.
const STATS_FLUSH_INTERVAL: float = 2.0
const SECTION_PROGRESS: String = "progress"
const SECTION_LEVELS: String = "levels"
const SECTION_SETTINGS: String = "settings"
const SECTION_ACHIEVEMENTS: String = "achievements"
const SECTION_LEADERBOARD: String = "leaderboard"
const SECTION_STATS: String = "stats"
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

## Lifetime statistics (never invented — only incremented from real events).
var total_matches: int = 0
var total_shots: int = 0
var levels_completed: int = 0
var bosses_defeated: int = 0
var largest_match: int = 0
var play_time_seconds: float = 0.0

## level_id -> { "stars": int, "best_score": int }
var level_records: Dictionary = {}
## achievement_id -> true
var achievements: Dictionary = {}
## Local top runs: [{ "name": String, "score": int }, ...] sorted desc.
var leaderboard: Array = []
var current_player_name: String = "Farmer Cluck"
var profiles: Array = ["Farmer Cluck"]
## False until the player confirms a name in the NEW USER modal.
var profile_setup_done: bool = false

## Active save file. Tests point this at a scratch file.
var save_path: String = SAVE_PATH
## Version the loaded file was written with (0 = missing / pre-versioning).
var loaded_version: int = 0
var _stats_dirty: bool = false
var _stats_flush_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
	call_deferred("_apply_audio")


func _process(delta: float) -> void:
	if not _stats_dirty:
		return
	_stats_flush_timer -= delta
	if _stats_flush_timer <= 0.0:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _stats_dirty:
			save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(save_path)
	_reset_defaults()
	loaded_version = 0
	if err != OK:
		return
	loaded_version = _read_int(cfg, SECTION_PROGRESS, "save_version", 1, 0, 1000)
	high_score = _read_int(cfg, SECTION_PROGRESS, "high_score", 0, 0, 1 << 40)
	best_combo = _read_int(cfg, SECTION_PROGRESS, "best_combo", 0, 0, 100000)
	stages_cleared = _read_int(cfg, SECTION_PROGRESS, "stages_cleared", 0, 0, 1000)
	max_level_unlocked = _read_int(cfg, SECTION_PROGRESS, "max_level_unlocked", 1, 1, 1000)
	tutorial_done = _read_bool(cfg, SECTION_PROGRESS, "tutorial_done", false)
	level_records = _sanitize_records(cfg.get_value(SECTION_LEVELS, "records", {}))
	achievements = _sanitize_flags(cfg.get_value(SECTION_ACHIEVEMENTS, "flags", {}))
	reduced_shake = _read_bool(cfg, SECTION_SETTINGS, "reduced_shake", false)
	reduced_fx = _read_bool(cfg, SECTION_SETTINGS, "reduced_fx", false)
	master_volume = _read_float(cfg, SECTION_SETTINGS, "master_volume", 1.0, 0.0, 1.0)
	sfx_volume = _read_float(cfg, SECTION_SETTINGS, "sfx_volume", 1.0, 0.0, 1.0)
	music_volume = _read_float(cfg, SECTION_SETTINGS, "music_volume", 0.7, 0.0, 1.0)
	mute_all = _read_bool(cfg, SECTION_SETTINGS, "mute_all", false)
	var name_v: Variant = cfg.get_value(SECTION_PROGRESS, "player_name", "Farmer Cluck")
	current_player_name = String(name_v).strip_edges().left(24) if name_v is String else "Farmer Cluck"
	if current_player_name.is_empty():
		current_player_name = "Farmer Cluck"
	profiles = []
	var profiles_v: Variant = cfg.get_value(SECTION_PROGRESS, "profiles", [])
	if profiles_v is Array:
		for p: Variant in profiles_v:
			if p is String and not String(p).strip_edges().is_empty() and not profiles.has(p):
				profiles.append(String(p))
	if not profiles.has(current_player_name):
		profiles.append(current_player_name)
	# Grandfather existing installs that predate this flag.
	if cfg.has_section_key(SECTION_PROGRESS, "profile_setup_done"):
		profile_setup_done = _read_bool(cfg, SECTION_PROGRESS, "profile_setup_done", false)
	else:
		profile_setup_done = true
	leaderboard = []
	var board_v: Variant = cfg.get_value(SECTION_LEADERBOARD, "entries", [])
	if board_v is Array:
		for entry: Variant in board_v:
			if entry is Dictionary and (entry as Dictionary).has("score"):
				leaderboard.append({
					"name": String((entry as Dictionary).get("name", "You")),
					"score": maxi(int((entry as Dictionary).get("score", 0)), 0),
				})
	total_matches = _read_int(cfg, SECTION_STATS, "total_matches", 0, 0, 1 << 40)
	total_shots = _read_int(cfg, SECTION_STATS, "total_shots", 0, 0, 1 << 40)
	levels_completed = _read_int(cfg, SECTION_STATS, "levels_completed", 0, 0, 1 << 40)
	bosses_defeated = _read_int(cfg, SECTION_STATS, "bosses_defeated", 0, 0, 1 << 40)
	largest_match = _read_int(cfg, SECTION_STATS, "largest_match", 0, 0, 100000)
	play_time_seconds = _read_float(cfg, SECTION_STATS, "play_time_seconds", 0.0, 0.0, 1.0e9)
	_migrate_leaderboard_from_high_score()


## Clamp progression against the live campaign (called once the catalog exists).
## [param level_ids_by_number] maps campaign level number → level id.
func sanitize_against_campaign(level_ids_by_number: Dictionary, stage_count: int) -> void:
	var total: int = level_ids_by_number.size()
	if total <= 0:
		return
	max_level_unlocked = clampi(max_level_unlocked, 1, total)
	stages_cleared = clampi(stages_cleared, 0, stage_count)
	# Every recorded clear unlocks its successor — repairs saves from older versions.
	for number: Variant in level_ids_by_number:
		var id: String = String(level_ids_by_number[number])
		if level_records.has(id):
			max_level_unlocked = clampi(maxi(max_level_unlocked, int(number) + 1), 1, total)


func _read_int(cfg: ConfigFile, section: String, key: String, fallback: int, lo: int, hi: int) -> int:
	var v: Variant = cfg.get_value(section, key, fallback)
	if v is int or v is float:
		return clampi(int(v), lo, hi)
	return fallback


func _read_float(cfg: ConfigFile, section: String, key: String, fallback: float, lo: float, hi: float) -> float:
	var v: Variant = cfg.get_value(section, key, fallback)
	if (v is int or v is float) and not is_nan(float(v)):
		return clampf(float(v), lo, hi)
	return fallback


func _read_bool(cfg: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var v: Variant = cfg.get_value(section, key, fallback)
	if v is bool:
		return v
	if v is int:
		return int(v) != 0
	return fallback


func _sanitize_records(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not (raw is Dictionary):
		return clean
	for key: Variant in raw:
		var rec: Variant = (raw as Dictionary)[key]
		if not (rec is Dictionary):
			continue
		clean[String(key)] = {
			"stars": clampi(int((rec as Dictionary).get("stars", 0)), 0, 3),
			"best_score": maxi(int((rec as Dictionary).get("best_score", 0)), 0),
		}
	return clean


func _sanitize_flags(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not (raw is Dictionary):
		return clean
	for key: Variant in raw:
		if bool((raw as Dictionary)[key]):
			clean[String(key)] = true
	return clean


func _reset_defaults() -> void:
	high_score = 0
	best_combo = 0
	stages_cleared = 0
	max_level_unlocked = 1
	tutorial_done = false
	current_player_name = "Farmer Cluck"
	profiles = ["Farmer Cluck"]
	profile_setup_done = false
	level_records = {}
	achievements = {}
	leaderboard = []
	total_matches = 0
	total_shots = 0
	levels_completed = 0
	bosses_defeated = 0
	largest_match = 0
	play_time_seconds = 0.0


func save() -> void:
	_stats_dirty = false
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_PROGRESS, "save_version", SAVE_VERSION)
	cfg.set_value(SECTION_PROGRESS, "high_score", high_score)
	cfg.set_value(SECTION_PROGRESS, "best_combo", best_combo)
	cfg.set_value(SECTION_PROGRESS, "stages_cleared", stages_cleared)
	cfg.set_value(SECTION_PROGRESS, "max_level_unlocked", max_level_unlocked)
	cfg.set_value(SECTION_PROGRESS, "tutorial_done", tutorial_done)
	cfg.set_value(SECTION_PROGRESS, "player_name", current_player_name)
	cfg.set_value(SECTION_PROGRESS, "profiles", profiles)
	cfg.set_value(SECTION_PROGRESS, "profile_setup_done", profile_setup_done)
	cfg.set_value(SECTION_LEVELS, "records", level_records)
	cfg.set_value(SECTION_ACHIEVEMENTS, "flags", achievements)
	cfg.set_value(SECTION_LEADERBOARD, "entries", leaderboard)
	cfg.set_value(SECTION_STATS, "total_matches", total_matches)
	cfg.set_value(SECTION_STATS, "total_shots", total_shots)
	cfg.set_value(SECTION_STATS, "levels_completed", levels_completed)
	cfg.set_value(SECTION_STATS, "bosses_defeated", bosses_defeated)
	cfg.set_value(SECTION_STATS, "largest_match", largest_match)
	cfg.set_value(SECTION_STATS, "play_time_seconds", play_time_seconds)
	cfg.set_value(SECTION_SETTINGS, "reduced_shake", reduced_shake)
	cfg.set_value(SECTION_SETTINGS, "reduced_fx", reduced_fx)
	cfg.set_value(SECTION_SETTINGS, "master_volume", master_volume)
	cfg.set_value(SECTION_SETTINGS, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION_SETTINGS, "music_volume", music_volume)
	cfg.set_value(SECTION_SETTINGS, "mute_all", mute_all)
	var err: Error = cfg.save(save_path)
	if err != OK:
		push_warning("SaveService: could not write %s (error %d)" % [save_path, err])


## Batch frequent stat writes instead of hitting disk every event.
func request_save() -> void:
	if not _stats_dirty:
		_stats_dirty = true
		_stats_flush_timer = STATS_FLUSH_INTERVAL


func record_match_stat(count: int, _is_cascade: bool = false) -> void:
	total_matches += 1
	largest_match = maxi(largest_match, count)
	EventBus.stats_changed.emit()
	request_save()


func record_shot() -> void:
	total_shots += 1


func record_level_completed() -> void:
	levels_completed += 1
	EventBus.stats_changed.emit()
	save()


func record_boss_defeat() -> void:
	bosses_defeated += 1
	EventBus.stats_changed.emit()
	save()


var _play_time_save_accum: float = 0.0


func add_play_time(delta: float) -> void:
	if delta <= 0.0:
		return
	play_time_seconds += delta
	_play_time_save_accum += delta
	if _play_time_save_accum >= 30.0:
		_play_time_save_accum = 0.0
		request_save()


func get_stats_summary() -> Dictionary:
	return {
		"high_score": high_score,
		"best_combo": best_combo,
		"total_matches": total_matches,
		"total_shots": total_shots,
		"levels_completed": levels_completed,
		"bosses_defeated": bosses_defeated,
		"largest_match": largest_match,
		"play_time_seconds": play_time_seconds,
		"stages_cleared": stages_cleared,
		"achievements_unlocked": achievements.size(),
	}


func set_player_name(new_name: String) -> void:
	var clean: String = new_name.strip_edges()
	if clean.is_empty():
		clean = "Farmer Cluck"
	current_player_name = clean
	if not profiles.has(clean):
		profiles.append(clean)
	profile_setup_done = true
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
	AudioManager.apply_mix(master_volume, sfx_volume, music_volume, mute_all)
