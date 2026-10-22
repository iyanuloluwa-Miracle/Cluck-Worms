extends Node
## Audio facade with procedural placeholder SFX (peck, pop, cascade, cluck…).
## Swap in real AudioStreams via register_stream() anytime — same logical names.

@export var enable_procedural: bool = true

const MAX_SFX_PLAYERS: int = 10
const SAMPLE_RATE: int = 22050
const MENU_MUSIC_PATH := "res://audio/music/menu_farmyard_loop.ogg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## Headroom so music sits under gameplay SFX at equal slider values.
const MUSIC_BASE_DB: float = -6.0
const SFX_BASE_DB: float = -2.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _current_music: StringName = &""
var _music_tween: Tween
const STAGE_TRACKS: Array[StringName] = [&"stage_backyard", &"stage_garden", &"stage_coop", &"stage_boss"]
var _compose_task: int = -1
const FRAME_COMPOSE_BUDGET_MS: float = 3.0
var _frame_queue: Array[StringName] = []
var _frame_job: MusicComposer.Job
## Number of stage tracks whose composed version has replaced the fallback drone.
var composed_tracks: int = 0
var _danger: float = 0.0
var _danger_beat_left: float = 0.0


func _ready() -> void:
	# Victory / defeat stingers fire while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)

	for i: int in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	if enable_procedural:
		_build_procedural_bank()
		_start_music_composition()
	_register_music_bank()

	EventBus.danger_warning.connect(func(urgency: float) -> void: _danger = urgency)
	EventBus.level_started.connect(func(_id: StringName, _title: String) -> void: _danger = 0.0)
	EventBus.chicken_shot.connect(_on_chicken_shot)
	EventBus.chicken_swapped.connect(_on_chicken_swapped)
	EventBus.projectile_hit_chain.connect(_on_projectile_hit)
	EventBus.cascade_step.connect(_on_cascade_step)
	EventBus.chain_collapse_started.connect(_on_collapse_started)
	EventBus.chain_reversing.connect(_on_chain_reversing)
	EventBus.boss_introduced.connect(_on_boss_introduced)
	EventBus.boss_damaged.connect(_on_boss_damaged)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_attack.connect(_on_boss_attack)
	EventBus.ability_used.connect(_on_ability_used)
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.level_started.connect(_on_level_started_music)
	EventBus.chain_reached_end.connect(_on_chain_reached_end)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.near_miss.connect(_on_near_miss)
	EventBus.good_shot.connect(_on_good_shot)
	EventBus.chicken_react.connect(_on_chicken_react)
	EventBus.game_state_changed.connect(_on_game_state)
	call_deferred("_sync_music_to_state")


func register_stream(logical_name: StringName, stream: AudioStream) -> void:
	_streams[logical_name] = stream


func play_sfx(logical_name: StringName, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _streams.has(logical_name):
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % MAX_SFX_PLAYERS
	player.stream = _streams[logical_name]
	player.pitch_scale = pitch_scale
	player.volume_db = volume_offset_db
	if DisplayServer.get_name() != "headless":
		player.play()


func play_music(logical_name: StringName, fade_in: bool = false) -> void:
	if not _streams.has(logical_name):
		return
	var target_db: float = 0.0
	if _current_music == logical_name and _music_player.playing:
		_kill_music_tween()
		_music_player.volume_db = target_db
		return
	_kill_music_tween()
	_current_music = logical_name
	_music_player.stream = _streams[logical_name]
	if DisplayServer.get_name() != "headless":
		_music_player.play()
	if fade_in:
		_music_player.volume_db = -40.0
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", target_db, 1.0)
	else:
		_music_player.volume_db = target_db


func stop_music() -> void:
	_kill_music_tween()
	_music_player.stop()
	_current_music = &""


func fade_out_music(duration: float = 0.45) -> void:
	if not _music_player.playing:
		_current_music = &""
		return
	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, duration)
	_music_tween.tween_callback(stop_music)


## Apply linear 0..1 slider values to the Master / Music / SFX buses.
func apply_mix(master: float, sfx: float, music: float, mute: bool) -> void:
	_set_bus_linear(&"Master", master, 0.0, mute)
	_set_bus_linear(MUSIC_BUS, music, MUSIC_BASE_DB, false)
	_set_bus_linear(SFX_BUS, sfx, SFX_BASE_DB, false)


func _set_bus_linear(bus_name: StringName, linear: float, base_db: float, force_mute: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var silent: bool = force_mute or linear <= 0.001
	AudioServer.set_bus_mute(idx, silent)
	if not silent:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)) + base_db)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _register_music_bank() -> void:
	# Exported assets are imported resources; the original OGG is not in the PCK.
	var menu: AudioStream = load(MENU_MUSIC_PATH) as AudioStream if ResourceLoader.exists(MENU_MUSIC_PATH) else null
	if menu == null and FileAccess.file_exists(MENU_MUSIC_PATH):
		menu = AudioStreamOggVorbis.load_from_file(MENU_MUSIC_PATH)
	if menu == null:
		push_warning("AudioManager: missing menu music at %s" % MENU_MUSIC_PATH)
		return
	if menu is AudioStreamOggVorbis:
		(menu as AudioStreamOggVorbis).loop = true
	register_stream(&"menu", menu)


func _sync_music_to_state() -> void:
	_on_game_state(-1, int(GameManager.state))


func _on_game_state(_previous: int, next: int) -> void:
	if next == GameManager.State.MAIN_MENU:
		play_music(&"menu", true)
	elif next == GameManager.State.PLAYING:
		pass
	elif _current_music == &"menu":
		fade_out_music()


func _on_level_started_music(_id: StringName, _name: String) -> void:
	var track: StringName = &"stage_backyard"
	if GameManager.current_level_def and GameManager.current_level_def.is_boss_level:
		track = &"stage_boss"
	else:
		match GameManager.stage_index:
			1:
				track = &"stage_garden"
			2:
				track = &"stage_coop"
			_:
				track = &"stage_backyard"
	play_music(track, true)


func _on_boss_attack(_id: StringName, _attack: StringName) -> void:
	play_sfx(&"boss_warn", 0.9)


func _on_ability_used(_id: StringName) -> void:
	play_sfx(&"ability")


func _on_achievement(_id: StringName) -> void:
	play_sfx(&"achievement", 1.05)


# ---------------------------------------------------------------------------
# Procedural bank
# ---------------------------------------------------------------------------

func _build_procedural_bank() -> void:
	_streams[&"danger"] = _arpeggio([164.8, 130.8], 0.065, 0.3)
	_streams[&"peck"] = _tone_blip(880.0, 0.045, 0.45, true)
	_streams[&"shoot"] = _tone_blip(620.0, 0.06, 0.4, true)
	_streams[&"pop"] = _noise_burst(0.07, 0.55, 900.0)
	_streams[&"match"] = _tone_blip(740.0, 0.08, 0.5, false)
	_streams[&"cascade"] = _arpeggio([523.25, 659.25, 783.99], 0.055, 0.45)
	_streams[&"impact"] = _noise_burst(0.05, 0.5, 400.0)
	_streams[&"collapse"] = _tone_blip(220.0, 0.1, 0.35, true)
	_streams[&"reverse"] = _tone_blip(180.0, 0.14, 0.4, true)
	_streams[&"boss_intro"] = _arpeggio([196.0, 247.0, 294.0, 392.0], 0.09, 0.42)
	_streams[&"boss_hit"] = _noise_burst(0.08, 0.55, 500.0)
	_streams[&"boss_defeat"] = _arpeggio([392.0, 523.25, 659.25, 784.0], 0.08, 0.48)
	_streams[&"boss_warn"] = _tone_blip(160.0, 0.16, 0.42, true)
	_streams[&"ability"] = _arpeggio([440.0, 554.0, 659.0], 0.04, 0.4)
	_streams[&"achievement"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.05, 0.4)
	_streams[&"swap"] = _tone_blip(440.0, 0.05, 0.35, false)
	# Looping procedural stage beds (replace with real ogg via register_stream).
	_streams[&"stage_backyard"] = _loop_bed(196.0, 2.4, 0.10)
	_streams[&"stage_garden"] = _loop_bed(220.0, 2.4, 0.10)
	_streams[&"stage_coop"] = _loop_bed(164.8, 2.5, 0.11)
	_streams[&"stage_boss"] = _loop_bed(130.8, 2.6, 0.12)
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


func _start_music_composition() -> void:
	# Rendering takes ~1-2s per track in GDScript, so it runs off the main thread;
	# single-threaded web builds render a few milliseconds per frame instead.
	if OS.has_feature("web") and not OS.has_feature("threads"):
		_frame_queue = STAGE_TRACKS.duplicate()
		return
	_compose_task = WorkerThreadPool.add_task(_compose_all_tracks, false, "Compose stage music")


func _process(_delta: float) -> void:
	if GameManager.can_player_act() and _danger > 0.18:
		_danger_beat_left -= _delta
		if _danger_beat_left <= 0.0:
			play_sfx(&"danger", lerpf(0.9, 1.15, _danger), -5.0)
			_danger_beat_left = lerpf(1.35, 0.38, _danger)
	else:
		_danger_beat_left = 0.0
	if _frame_queue.is_empty():
		return
	if _frame_job == null:
		_frame_job = MusicComposer.Job.new(MusicComposer.spec_for(_frame_queue[0]), 8)
	if _frame_job.step(FRAME_COMPOSE_BUDGET_MS):
		_on_track_composed(_frame_queue.pop_front(), _frame_job.output)
		_frame_job = null


func _compose_all_tracks() -> void:
	for track: StringName in STAGE_TRACKS:
		var pcm: PackedByteArray = MusicComposer.render(MusicComposer.spec_for(track))
		_on_track_composed.call_deferred(track, pcm)


func _on_track_composed(track: StringName, pcm: PackedByteArray) -> void:
	_streams[track] = MusicComposer.to_stream(pcm)
	composed_tracks += 1
	if _current_music == track and _music_player.playing:
		_current_music = &""
		play_music(track, true)


func _exit_tree() -> void:
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if _compose_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_compose_task)
		_compose_task = -1


func _loop_bed(freq: float, duration: float, amp: float) -> AudioStreamWAV:
	var stream: AudioStreamWAV = _tone_blip(freq, duration, amp, false)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(duration * float(SAMPLE_RATE))
	return stream


# ---------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------

func _on_chicken_shot(_color: WormColor.Kind, _o: Vector2, _d: Vector2) -> void:
	play_sfx(&"peck", 1.0 + GameManager.get_fx_rng().randf_range(-0.04, 0.06))
	play_sfx(&"shoot", 1.0 + GameManager.get_fx_rng().randf_range(-0.05, 0.08), -4.0)


func _on_chicken_swapped(_c: WormColor.Kind, _n: WormColor.Kind) -> void:
	play_sfx(&"swap")
	play_sfx(&"cluck", 1.1, -2.0)


func _on_projectile_hit(_p: ShootingWorm, _h: Worm, _c: WormChain) -> void:
	play_sfx(&"impact", 1.0 + GameManager.get_fx_rng().randf_range(-0.05, 0.05))


func _on_cascade_step(_c: WormChain, depth: int, count: int, _color: WormColor.Kind) -> void:
	var pitch: float = 1.0 + float(depth) * 0.1 + float(count) * 0.02
	play_sfx(&"pop", pitch)
	if depth >= 1:
		play_sfx(&"cascade", 1.0 + float(depth) * 0.06)
	else:
		play_sfx(&"match", pitch, -2.0)


func _on_collapse_started(_c: WormChain, _n: int) -> void:
	play_sfx(&"collapse")


func _on_chain_reversing(_c: WormChain) -> void:
	play_sfx(&"reverse", 0.92)


func _on_boss_introduced(_id: StringName, _name: String) -> void:
	play_sfx(&"boss_intro")


func _on_boss_damaged(_id: StringName, _amount: float, _pos: Vector2) -> void:
	play_sfx(&"boss_hit", 1.0 + GameManager.get_fx_rng().randf_range(-0.05, 0.08))


func _on_boss_defeated(_id: StringName) -> void:
	play_sfx(&"boss_defeat")


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
			play_sfx(&"happy_cluck", 1.0 + GameManager.get_fx_rng().randf_range(0.0, 0.1))
		&"peck":
			play_sfx(&"cluck", 1.05, -3.0)
		&"sigh":
			play_sfx(&"sigh")
