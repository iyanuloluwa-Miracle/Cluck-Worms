class_name MusicComposer
extends RefCounted
## Renders short, seamlessly looping stage tracks (bass, chord pad, pluck
## arpeggio/lead, light drums) to 16-bit PCM. Deterministic per spec seed.
## Work is split into small chunks so it can run on a worker thread in one go
## or a few milliseconds per frame on single-threaded web builds.

const SAMPLE_RATE: int = 22050
const CHUNK: int = 4096
const MAJOR: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const MINOR: Array[int] = [0, 2, 3, 5, 7, 8, 10]

enum Voice { PAD, BASS, PLUCK, KICK, SNARE, HAT }


## Track specs. Chords are [semitone offset from root, is_minor].
static func spec_for(track: StringName) -> Dictionary:
	match track:
		&"stage_garden":
			return {
				"bpm": 100.0, "root": 220.0, "scale": MINOR, "seed": 21,
				"chords": [[0, true], [-2, false], [-4, false], [-2, false]],
				"bass": [0.0, 1.5, 2.0, 3.0], "lead_density": 0.55, "lead_decay": 7.0,
				"pad_amp": 0.07, "kick": [0.0, 2.0], "snare": [], "hat_amp": 0.025, "swing": 0.0,
			}
		&"stage_coop":
			return {
				"bpm": 92.0, "root": 164.81, "scale": MINOR, "seed": 33,
				"chords": [[0, true], [5, true], [0, true], [7, false]],
				"bass": [0.0, 0.75, 2.0, 2.75], "lead_density": 0.45, "lead_decay": 9.0,
				"pad_amp": 0.06, "kick": [0.0, 2.5], "snare": [1.0, 3.0], "hat_amp": 0.03, "swing": 0.12,
			}
		&"stage_boss":
			return {
				"bpm": 132.0, "root": 130.81, "scale": MINOR, "seed": 47,
				"chords": [[0, true], [-4, false], [-2, false], [0, true]],
				"bass": [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], "lead_density": 0.7, "lead_decay": 11.0,
				"pad_amp": 0.05, "kick": [0.0, 1.0, 2.0, 3.0], "snare": [1.0, 3.0], "hat_amp": 0.035, "swing": 0.0,
			}
		_:
			return {
				"bpm": 112.0, "root": 196.0, "scale": MAJOR, "seed": 9,
				"chords": [[0, false], [7, false], [9, true], [5, false]],
				"bass": [0.0, 1.0, 2.0, 3.0], "lead_density": 0.6, "lead_decay": 8.0,
				"pad_amp": 0.06, "kick": [0.0, 2.0], "snare": [1.0, 3.0], "hat_amp": 0.025, "swing": 0.08,
			}


## Blocking render (worker threads, tests).
static func render(spec: Dictionary, bars: int = 8) -> PackedByteArray:
	var job := Job.new(spec, bars)
	while not job.step(1.0e9):
		pass
	return job.output


static func to_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = pcm.size() / 2
	return stream


static func _freq(root: float, semis: int) -> float:
	return root * pow(2.0, float(semis) / 12.0)


static func _nearest_degree(scale: Array[int], semis: int) -> int:
	var octave: int = int(floor(float(semis) / 12.0))
	var within: int = posmod(semis, 12)
	var best: int = 0
	for i: int in range(scale.size()):
		if absi(scale[i] - within) < absi(scale[best] - within):
			best = i
	return clampi(best + octave * scale.size(), 0, scale.size() * 2 - 1)


## Incremental renderer. Events: [voice, to_bed, start_sample, length, freq, amp, extra, i0, i1].
class Job:
	extends RefCounted

	var output := PackedByteArray()
	var _events: Array = []
	var _bed := PackedFloat32Array()
	var _buf := PackedFloat32Array()
	var _noise := RandomNumberGenerator.new()
	var _n: int = 0
	var _phase: int = 0
	var _cursor: int = 0
	var _gain: float = 1.0

	func _init(spec: Dictionary, bars: int) -> void:
		var bpm: float = spec["bpm"]
		var root: float = spec["root"]
		var scale: Array[int] = spec["scale"]
		var chords: Array = spec["chords"]
		var beat: float = 60.0 / bpm
		var bar_samples: int = int(4.0 * beat * float(SAMPLE_RATE))
		_n = bar_samples * bars
		_bed.resize(bar_samples * chords.size())
		_noise.seed = int(spec["seed"]) * 31 + 7
		var rng := RandomNumberGenerator.new()
		rng.seed = int(spec["seed"])
		var sr: float = float(SAMPLE_RATE)

		# The bed (pad, bass, drums) repeats with the chord cycle: render once, tile later.
		for bar: int in range(chords.size()):
			var chord: Array = chords[bar]
			var c_root: int = int(chord[0])
			var minor: bool = bool(chord[1])
			var t0: float = float(bar * 4) * beat
			for tone: int in [c_root, c_root + (3 if minor else 4), c_root + 7]:
				_add(Voice.PAD, true, t0, 4.0 * beat + 0.4, _freq(root, tone), float(spec["pad_amp"]), 4.0 * beat * sr)
			for pos: float in spec["bass"]:
				var bass_tone: int = c_root - 12 + (7 if pos == 1.5 or pos == 2.75 else 0)
				_add(Voice.BASS, true, t0 + pos * beat, beat * 0.9, _freq(root, bass_tone), 0.22, 0.0)
			for pos: float in spec["kick"]:
				_add(Voice.KICK, true, t0 + pos * beat, 0.22, 0.0, 0.32, 0.0)
			for pos: float in spec["snare"]:
				_add(Voice.SNARE, true, t0 + pos * beat, 0.16, 0.0, 0.12, 0.0)
			for e: int in range(8):
				if e % 2 == 1 or float(spec["hat_amp"]) > 0.03:
					var hat_swing: float = float(spec["swing"]) * beat if e % 2 == 1 else 0.0
					_add(Voice.HAT, true, t0 + float(e) * beat * 0.5 + hat_swing, 0.05, 0.0, float(spec["hat_amp"]), 0.0)

		# Lead: chord tones on strong 8ths, scale steps between; phrase tails thin out.
		var prev_lead: int = 0
		for bar: int in range(bars):
			var chord: Array = chords[bar % chords.size()]
			var c_root: int = int(chord[0])
			var minor: bool = bool(chord[1])
			var t0: float = float(bar * 4) * beat
			var triad: Array[int] = [c_root, c_root + (3 if minor else 4), c_root + 7]
			var phrase_end: bool = bar % 4 == 3
			for e: int in range(8):
				var density: float = float(spec["lead_density"]) * (0.6 if phrase_end and e >= 4 else 1.0)
				if rng.randf() > density:
					continue
				var pitch: int
				if e % 2 == 0:
					pitch = triad[rng.randi_range(0, 2)] + 12
				else:
					var deg: int = clampi(prev_lead + rng.randi_range(-2, 2), 0, scale.size() * 2 - 1)
					pitch = scale[deg % scale.size()] + 12 * int(deg / scale.size()) + 12
				prev_lead = MusicComposer._nearest_degree(scale, pitch - 12)
				var swing: float = float(spec["swing"]) * beat if e % 2 == 1 else 0.0
				_add(Voice.PLUCK, false, t0 + float(e) * beat * 0.5 + swing, beat * 0.9, _freq(root, pitch), 0.14, float(spec["lead_decay"]))

	func _freq(root: float, semis: int) -> float:
		return MusicComposer._freq(root, semis)

	func _add(voice: int, to_bed: bool, start: float, dur: float, f: float, amp: float, extra: float) -> void:
		var s0: int = int(start * SAMPLE_RATE)
		var length: int = int(dur * SAMPLE_RATE)
		var i0: int = 0
		# Drum voices carry filter/sweep state, and are short: never split them.
		var chunk: int = CHUNK if voice <= Voice.PLUCK else length
		while i0 < length:
			var i1: int = mini(i0 + chunk, length)
			_events.append([voice, to_bed, s0, length, f, amp, extra, i0, i1])
			i0 = i1

	## Advances rendering; returns true when [member output] is ready.
	func step(budget_ms: float) -> bool:
		var deadline: int = Time.get_ticks_usec() + int(budget_ms * 1000.0)
		while Time.get_ticks_usec() < deadline:
			match _phase:
				0:
					if _cursor < _events.size() and bool(_events[_cursor][1]):
						_run(_events[_cursor])
						_cursor += 1
					else:
						while _buf.size() < _n:
							_buf.append_array(_bed)
						_buf.resize(_n)
						_phase = 1
				1:
					if _cursor < _events.size():
						_run(_events[_cursor])
						_cursor += 1
					else:
						var peak: float = 0.001
						for v: float in _buf:
							peak = maxf(peak, absf(v))
						_gain = 0.85 / peak * 32767.0
						output.resize(_n * 2)
						_cursor = 0
						_phase = 2
				2:
					var end: int = mini(_cursor + CHUNK * 4, _n)
					for i: int in range(_cursor, end):
						output.encode_s16(i * 2, int(_buf[i] * _gain))
					_cursor = end
					if _cursor >= _n:
						_phase = 3
				_:
					return true
		return _phase == 3

	func _run(ev: Array) -> void:
		var target: PackedFloat32Array = _bed if bool(ev[1]) else _buf
		var voice: int = ev[0]
		var s0: int = ev[2]
		var length: int = ev[3]
		var f: float = ev[4]
		var amp: float = ev[5]
		var extra: float = ev[6]
		var i0: int = ev[7]
		var i1: int = ev[8]
		var n: int = target.size()
		var sr: float = float(SAMPLE_RATE)
		match voice:
			Voice.PAD:
				var hold: int = int(extra)
				var attack: int = int(0.35 * sr)
				var release: float = float(maxi(length - hold, 1))
				var w: float = TAU * f / sr
				var w2: float = w * 1.006
				for i: int in range(i0, i1):
					var env: float = 1.0
					if i < attack:
						env = float(i) / float(attack)
					elif i >= hold:
						env = 1.0 - float(i - hold) / release
					var idx: int = (s0 + i) % n
					target[idx] += (sin(w * i) + 0.45 * sin(w2 * i)) * env * amp
			Voice.BASS:
				var tail: float = 0.03 * sr
				var inc: float = f / sr
				var k: float = exp(-3.5 / sr)
				var env: float = pow(k, i0)
				for i: int in range(i0, i1):
					var p: float = fmod(inc * float(i), 1.0)
					var tri: float = 1.0 - 4.0 * absf(p - 0.5)
					var gate: float = minf(float(i) / 220.0, 1.0) * minf(float(length - i) / tail, 1.0)
					target[(s0 + i) % n] += tri * env * gate * amp
					env *= k
			Voice.PLUCK:
				var w: float = TAU * f / sr
				var k: float = exp(-extra / sr)
				var kb: float = exp(-6.0 / sr)
				var env: float = pow(k, i0)
				var bright: float = 0.35 * pow(kb, i0)
				for i: int in range(i0, i1):
					var ph: float = w * i
					var atk: float = minf(float(i) / 90.0, 1.0)
					target[(s0 + i) % n] += (sin(ph) + bright * sin(ph * 2.0)) * env * atk * amp
					env *= k
					bright *= kb
			Voice.KICK:
				var k: float = exp(-14.0 / sr)
				var ks: float = exp(-30.0 / sr)
				var env: float = 1.0
				var sweep: float = 85.0
				var ph: float = 0.0
				for i: int in range(i0, i1):
					ph += TAU * (45.0 + sweep) / sr
					target[(s0 + i) % n] += sin(ph) * env * amp
					env *= k
					sweep *= ks
			Voice.SNARE:
				var k: float = exp(-22.0 / sr)
				var kt: float = exp(-30.0 / sr)
				var w: float = TAU * 185.0 / sr
				var env: float = 1.0
				var tone_env: float = 0.5
				var low: float = 0.0
				for i: int in range(i0, i1):
					low += 0.35 * (_noise.randf_range(-1.0, 1.0) - low)
					target[(s0 + i) % n] += (low * env + sin(w * i) * tone_env) * amp
					env *= k
					tone_env *= kt
			_:
				var k: float = exp(-70.0 / sr)
				var env: float = 1.0
				var low: float = 0.0
				for i: int in range(i0, i1):
					var white: float = _noise.randf_range(-1.0, 1.0)
					low += 0.6 * (white - low)
					target[(s0 + i) % n] += (white - low) * env * amp
					env *= k
