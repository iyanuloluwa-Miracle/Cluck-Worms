extends Node
## Persistent high-score (and future unlocks) via ConfigFile on user://.

const SAVE_PATH: String = "user://cluck_and_worms_save.cfg"
const SECTION: String = "progress"

var high_score: int = 0
var best_combo: int = 0
var stages_cleared: int = 0


func _ready() -> void:
	load_save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		high_score = 0
		best_combo = 0
		stages_cleared = 0
		return
	high_score = int(cfg.get_value(SECTION, "high_score", 0))
	best_combo = int(cfg.get_value(SECTION, "best_combo", 0))
	stages_cleared = int(cfg.get_value(SECTION, "stages_cleared", 0))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # Preserve unknown keys if file exists.
	cfg.set_value(SECTION, "high_score", high_score)
	cfg.set_value(SECTION, "best_combo", best_combo)
	cfg.set_value(SECTION, "stages_cleared", stages_cleared)
	cfg.save(SAVE_PATH)


## Returns true if a new high score was written.
func try_submit_score(score: int, peak_combo: int = 0) -> bool:
	var is_new_high: bool = score > high_score
	var combo_improved: bool = peak_combo > best_combo
	if is_new_high:
		high_score = score
	if combo_improved:
		best_combo = peak_combo
	if is_new_high or combo_improved:
		save()
	return is_new_high


func record_stage_cleared(stage_index: int) -> void:
	var cleared: int = stage_index + 1
	if cleared > stages_cleared:
		stages_cleared = cleared
		save()
