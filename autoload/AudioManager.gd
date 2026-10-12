extends Node
## Lightweight audio facade. Plays SFX / music by logical name.
## Slot in real AudioStream resources under assets/audio/ as they arrive.

# ---------------------------------------------------------------------------
# Tunables
# ---------------------------------------------------------------------------

@export var master_volume_db: float = 0.0
@export var sfx_volume_db: float = 0.0
@export var music_volume_db: float = -6.0

## Max simultaneous one-shot SFX players.
const MAX_SFX_PLAYERS: int = 8

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
## Registry: logical name -> AudioStream (populated as assets land).
var _streams: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Master"
	add_child(_music_player)

	for i: int in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = &"Master"
		add_child(player)
		_sfx_players.append(player)

	_apply_volumes()

	# Hook gameplay events for placeholder feedback (no streams yet = silent).
	EventBus.worm_spawned.connect(_on_worm_spawned)
	EventBus.chain_match_found.connect(_on_match_found)
	EventBus.chain_reached_end.connect(_on_chain_reached_end)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.chicken_shot.connect(_on_chicken_shot)
	EventBus.chicken_swapped.connect(_on_chicken_swapped)
	EventBus.projectile_hit_chain.connect(_on_projectile_hit)
	EventBus.cascade_step.connect(_on_cascade_step)
	EventBus.chain_collapse_started.connect(_on_collapse_started)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func register_stream(logical_name: StringName, stream: AudioStream) -> void:
	_streams[logical_name] = stream


func play_sfx(logical_name: StringName, pitch_scale: float = 1.0) -> void:
	if not _streams.has(logical_name):
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	player.stream = _streams[logical_name]
	player.pitch_scale = pitch_scale
	player.volume_db = sfx_volume_db + master_volume_db
	player.play()


func play_music(logical_name: StringName, fade_in: bool = false) -> void:
	if not _streams.has(logical_name):
		return
	_music_player.stream = _streams[logical_name]
	_music_player.volume_db = music_volume_db + master_volume_db
	_music_player.play()
	if fade_in:
		# Simple linear fade-in placeholder.
		_music_player.volume_db = -40.0
		var tween := create_tween()
		tween.tween_property(
			_music_player, "volume_db", music_volume_db + master_volume_db, 1.0
		)


func stop_music() -> void:
	_music_player.stop()


func set_master_volume_db(value: float) -> void:
	master_volume_db = value
	_apply_volumes()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _apply_volumes() -> void:
	_music_player.volume_db = music_volume_db + master_volume_db
	for player: AudioStreamPlayer in _sfx_players:
		player.volume_db = sfx_volume_db + master_volume_db


func _on_worm_spawned(_worm: Worm) -> void:
	play_sfx(&"worm_spawn")


func _on_match_found(_chain: WormChain, _start: int, _count: int, _color: WormColor.Kind) -> void:
	play_sfx(&"match")


func _on_chain_reached_end(_chain: WormChain) -> void:
	play_sfx(&"lose")


func _on_level_completed(_level_id: StringName, _score: int, _lives: int) -> void:
	play_sfx(&"win")


func _on_stage_completed(_stage_id: StringName, _stage_index: int, _score: int) -> void:
	play_sfx(&"win")


func _on_game_over(_final_score: int, _high_score: int, _is_new_high: bool) -> void:
	play_sfx(&"lose")


func _on_life_lost(_lives_remaining: int) -> void:
	play_sfx(&"lose")


func _on_chicken_shot(_color: WormColor.Kind, _origin: Vector2, _dir: Vector2) -> void:
	play_sfx(&"shoot", 1.0 + GameManager.get_rng().randf_range(-0.05, 0.08))


func _on_chicken_swapped(_current: WormColor.Kind, _next: WormColor.Kind) -> void:
	play_sfx(&"swap")


func _on_projectile_hit(_projectile: ShootingWorm, _hit: Worm, _chain: WormChain) -> void:
	play_sfx(&"impact")


func _on_cascade_step(_chain: WormChain, depth: int, _count: int, _color: WormColor.Kind) -> void:
	var pitch: float = 1.0 + float(depth) * 0.08
	play_sfx(&"match", pitch)


func _on_collapse_started(_chain: WormChain, _removed_count: int) -> void:
	play_sfx(&"collapse")
