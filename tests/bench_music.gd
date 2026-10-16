extends SceneTree
## Times and sanity-checks MusicComposer:
## godot --headless --path . --script res://tests/bench_music.gd


func _rms(pcm: PackedByteArray) -> float:
	var acc: float = 0.0
	var count: int = 0
	for i: int in range(0, pcm.size() - 1, 64):
		var v: float = float(pcm.decode_s16(i)) / 32767.0
		acc += v * v
		count += 1
	return sqrt(acc / maxf(float(count), 1.0))


func _init() -> void:
	var composer: GDScript = load("res://scripts/audio/MusicComposer.gd")
	var failed: int = 0
	for track: StringName in [&"stage_backyard", &"stage_garden", &"stage_coop", &"stage_boss"]:
		var spec: Dictionary = composer.spec_for(track)
		var t0: int = Time.get_ticks_msec()
		var pcm: PackedByteArray = composer.render(spec)
		var ms: int = Time.get_ticks_msec() - t0
		var rms: float = _rms(pcm)
		var bed_only: Dictionary = spec.duplicate()
		bed_only["lead_density"] = 0.0
		var bed_rms: float = _rms(composer.render(bed_only))
		var again: PackedByteArray = composer.render(spec)
		var ok: bool = rms > 0.05 and bed_rms > 0.05 and again == pcm
		if not ok:
			failed += 1
		print("%s %s: %.1fs audio in %d ms, rms=%.3f, bed_rms=%.3f, deterministic=%s" % [
			"OK  " if ok else "FAIL", track, float(pcm.size() / 2) / 22050.0, ms, rms, bed_rms, again == pcm])
	# Incremental path must produce identical audio to the blocking path.
	var job = composer.Job.new(composer.spec_for(&"stage_coop"), 8)
	var frames: int = 0
	while not job.step(4.0):
		frames += 1
	var same: bool = job.output == composer.render(composer.spec_for(&"stage_coop"))
	print("%s incremental render matches blocking render (%d frames at 4 ms)" % ["OK  " if same else "FAIL", frames])
	if not same:
		failed += 1
	quit(1 if failed > 0 else 0)
