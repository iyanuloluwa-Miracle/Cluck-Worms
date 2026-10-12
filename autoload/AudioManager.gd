extends Node
## Audio facade with procedural placeholder SFX (peck, pop, cascade, cluck…).
## Swap in real AudioStreams via register_stream() anytime — same logical names.

@export var master_volume_db: float = 0.0
@export var sfx_volume_db: float = -2.0
@export var music_volume_db: float = -6.0
@export var enable_procedural: bool = true

const MAX_SFX_PLAYERS: int = 10
const SAMPLE_RATE: int = 22050

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	for i: int in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_players.append(player)

	if enable_procedural:
		_build_procedural_bank()
	_apply_volumes()

	EventBus.chicken_shot.connect(_on_chicken_shot)
	EventBus.chicken_swapped.connect(_on_chicken_swapped)
	EventBus.projectile_hit_chain.connect(_on_projectile_hit)
	EventBus.cascade_step.connect(_on_cascade_step)
	EventBus.chain_collapse_started.connect(_on_collapse_started)
	EventBus.chain_reached_end.connect(_on_chain_reached_end)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.near_miss.connect(_on_near_miss)
	EventBus.good_shot.connect(_on_good_shot)
	EventBus.chicken_react.connect(_on_chicken_react)


func register_stream(logical_name: StringName, stream: AudioStream) -> void:
	_streams[logical_name] = stream


func play_sfx(logical_name: StringName, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _streams.has(logical_name):
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	player.stream = _streams[logical_name]
	player.pitch_scale = pitch_scale
	player.volume_db = sfx_volume_db + master_volume_db + volume_offset_db
	player.play()


func play_music(logical_name: StringName, fade_in: bool = false) -> void:
	if not _streams.has(logical_name):
		return
	_music_player.stream = _streams[logical_name]
	_music_player.volume_db = music_volume_db + master_volume_db
	_music_player.play()
	if fade_in:
		_music_player.volume_db = -40.0
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", music_volume_db + master_volume_db, 1.0)


func stop_music() -> void:
	_music_player.stop()


func set_master_volume_db(value: float) -> void:
	master_volume_db = value
	_apply_volumes()


func _apply_volumes() -> void:
	_music_player.volume_db = music_volume_db + master_volume_db
	for player: AudioStreamPlayer in _sfx_players:
		player.volume_db = sfx_volume_db + master_volume_db


# ---------------------------------------------------------------------------
# Procedural bank
# ---------------------------------------------------------------------------

func _build_procedural_bank() -> void:
	_streams[&"peck"] = _tone_blip(880.0, 0.045, 0.45, true)
	_streams[&"shoot"] = _tone_blip(620.0, 0.06, 0.4, true)
	_streams[&"pop"] = _noise_burst(0.07, 0.55, 900.0)
	_streams[&"match"] = _tone_blip(740.0, 0.08, 0.5, false)
	_streams[&"cascade"] = _arpeggio([523.25, 659.25, 783.99], 0.055, 0.45)
	_streams[&"impact"] = _noise_burst(0.05, 0.5, 400.0)
	_streams[&"collapse"] = _tone_blip(220.0, 0.1, 0.35, true)
	_streams[&"swap"] = _tone_blip(440.0, 0.05, 0.35, false)
	_streams[&"cluck"] = _tone_blip(320.0, 0.07, 0.4, true)
	_streams[&"happy_cluck"] = _arpeggio([392.0, 523.25, 659.25], 0.05, 0.4)
	_streams[&"sigh"] = _tone_blip(180.0, 0.12, 0.3, true)
	_streams[&"near_miss"] = _tone_blip(500.0, 0.04, 0.25, true)
	_streams[&"win"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.07, 0.45)
	_streams[&"lose"] = _arpeggio([392.0, 311.0, 247.0], 0.1, 0.4)
	# Aliases used by older hooks
	_streams[&"worm_spawn"] = _streams[&"pop"]


func _tone_blip(freq: float, duration: float, amp: float, falloff: bool) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = 1.0 - t / duration if falloff else sin(PI * t / duration)
		env = clampf(env, 0.0, 1.0)
		var sample: float = sin(TAU * freq * t) * amp * env
		# Soft square harmonic for peck character.
		sample += sin(TAU * freq * 2.0 * t) * amp * 0.2 * env
		var s: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav_from_pcm(data)


func _noise_burst(duration: float, amp: float, filter_hz: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var low: float = 0.0
	var alpha: float = clampf(filter_hz / float(SAMPLE_RATE), 0.01, 0.5)
	for i: int in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = 1.0 - t / duration
		var white: float = rng.randf_range(-1.0, 1.0)
		low = low + alpha * (white - low)
		var sample: float = low * amp * env * env
		var s: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	return _wav_from_pcm(data)


func _arpeggio(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var total: int = int(note_dur * float(freqs.size()) * float(SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(total * 2)
	var write_i: int = 0
	for freq_v in freqs:
		var freq: float = float(freq_v)
		var n: int = int(note_dur * float(SAMPLE_RATE))
		for i: int in range(n):
			if write_i >= total:
				break
			var t: float = float(i) / float(SAMPLE_RATE)
			var env: float = sin(PI * t / note_dur)
			var sample: float = sin(TAU * freq * t) * amp * env
			var s: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
			data[write_i * 2] = s & 0xFF
			data[write_i * 2 + 1] = (s >> 8) & 0xFF
			write_i += 1
	return _wav_from_pcm(data)


func _wav_from_pcm(pcm16: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm16
	return stream


# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

func _on_chicken_shot(_color: WormColor.Kind, _o: Vector2, _d: Vector2) -> void:
	play_sfx(&"peck", 1.0 + GameManager.get_rng().randf_range(-0.04, 0.06))
	play_sfx(&"shoot", 1.0 + GameManager.get_rng().randf_range(-0.05, 0.08), -4.0)


func _on_chicken_swapped(_c: WormColor.Kind, _n: WormColor.Kind) -> void:
	play_sfx(&"swap")
	play_sfx(&"cluck", 1.1, -2.0)


func _on_projectile_hit(_p: ShootingWorm, _h: Worm, _c: WormChain) -> void:
	play_sfx(&"impact", 1.0 + GameManager.get_rng().randf_range(-0.05, 0.05))


func _on_cascade_step(_c: WormChain, depth: int, count: int, _color: WormColor.Kind) -> void:
	var pitch: float = 1.0 + float(depth) * 0.1 + float(count) * 0.02
	play_sfx(&"pop", pitch)
	if depth >= 1:
		play_sfx(&"cascade", 1.0 + float(depth) * 0.06)
	else:
		play_sfx(&"match", pitch, -2.0)


func _on_collapse_started(_c: WormChain, _n: int) -> void:
	play_sfx(&"collapse")


func _on_chain_reached_end(_c: WormChain) -> void:
	play_sfx(&"lose")


func _on_level_completed(_id: StringName, _s: int, _l: int) -> void:
	play_sfx(&"win")
	play_sfx(&"happy_cluck")


func _on_stage_completed(_id: StringName, _i: int, _s: int) -> void:
	play_sfx(&"win")
	play_sfx(&"happy_cluck", 1.05)


func _on_game_over(_s: int, _h: int, _n: bool) -> void:
	play_sfx(&"lose")


func _on_life_lost(_r: int) -> void:
	play_sfx(&"sigh")


func _on_near_miss(_p: Vector2) -> void:
	play_sfx(&"near_miss", 0.95)


func _on_good_shot(_p: Vector2, _count: int) -> void:
	play_sfx(&"happy_cluck", 1.08)


func _on_chicken_react(reaction: StringName, _pos: Vector2) -> void:
	match reaction:
		&"celebrate":
			play_sfx(&"happy_cluck", 1.0 + GameManager.get_rng().randf_range(0.0, 0.1))
		&"peck":
			play_sfx(&"cluck", 1.05, -3.0)
		&"sigh":
			play_sfx(&"sigh")
