#!/usr/bin/env python3
"""Generate a looping farmyard menu theme (cheerful, mid-tempo, puzzle-game vibe)."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SR = 44100
BPM = 112.0
BEAT = 60.0 / BPM
BARS = 16
BEATS_PER_BAR = 4
DURATION = BARS * BEATS_PER_BAR * BEAT

# C major pentatonic-ish farmyard loop — bright but soft.
ROOT = 261.63  # C4
SCALE = [
	ROOT,
	ROOT * 9 / 8,  # D
	ROOT * 5 / 4,  # E
	ROOT * 3 / 2,  # G
	ROOT * 5 / 3,  # A
	ROOT * 2,  # C5
	ROOT * 9 / 4,  # D5
	ROOT * 5 / 2,  # E5
]

# Chord tones per bar (I – vi – IV – V) repeated.
CHORDS = [
	[0, 2, 3],  # C E G
	[5, 0, 2],  # A C E (vi relative feel via A)
	[3, 5, 0],  # F-ish via G A C — use F major approx: index remap
	[3, 5, 1],  # G B D-ish
]

# Better chord freqs (I vi IV V in C):
CHORD_FREQS = [
	[261.63, 329.63, 392.00],  # C
	[220.00, 261.63, 329.63],  # Am
	[174.61, 220.00, 261.63],  # F
	[196.00, 246.94, 293.66],  # G
]

# Melody in scale degrees over 16 bars (4 beats each), -1 = rest.
MELODY = [
	# bar 1-4
	4, 4, 5, 4, 2, 2, 0, -1,
	5, 5, 4, 2, 3, 3, 2, -1,
	4, 5, 7, 5, 4, 2, 0, 2,
	3, 2, 0, -1, 0, 2, 3, 4,
	# bar 5-8
	5, 5, 4, 5, 7, 5, 4, -1,
	4, 2, 0, 2, 3, 4, 5, -1,
	7, 5, 4, 2, 0, 2, 4, 5,
	4, 3, 2, 0, 2, -1, 0, -1,
	# bar 9-12 (variation)
	4, -1, 4, 5, 4, 2, 0, -1,
	5, -1, 5, 4, 2, 3, 2, -1,
	4, 5, 7, 5, 4, 5, 7, 5,
	4, 2, 0, 2, 3, 4, 5, 4,
	# bar 13-16 (resolve)
	5, 4, 2, 0, 2, 3, 4, -1,
	5, 7, 5, 4, 2, 0, 2, -1,
	4, 5, 4, 2, 0, -1, 0, 2,
	4, 5, 4, 2, 0, -1, -1, -1,
]


def env_adsr(t: float, dur: float, a=0.02, d=0.08, s=0.65, r=0.12) -> float:
	if t < 0 or t > dur:
		return 0.0
	if t < a:
		return t / a
	if t < a + d:
		return 1.0 - (1.0 - s) * ((t - a) / d)
	if t < dur - r:
		return s
	if dur <= r:
		return s * max(0.0, 1.0 - t / dur)
	return s * max(0.0, (dur - t) / r)


def soft_saw(phase: float) -> float:
	# Softened saw: fundamental + quiet harmonics.
	x = phase % 1.0
	return (
		math.sin(2 * math.pi * x)
		+ 0.35 * math.sin(4 * math.pi * x)
		+ 0.15 * math.sin(6 * math.pi * x)
	) / 1.5


def pluck(phase: float, bright: float = 0.4) -> float:
	x = phase % 1.0
	return (
		math.sin(2 * math.pi * x)
		+ bright * 0.45 * math.sin(4 * math.pi * x)
		+ bright * 0.2 * math.sin(6 * math.pi * x)
	)


def noise() -> float:
	# Deterministic-ish cheap noise from phase hash — replaced per-sample below.
	return 0.0


def main() -> None:
	n = int(DURATION * SR)
	left = [0.0] * n
	right = [0.0] * n
	beat_samples = int(BEAT * SR)
	bar_samples = beat_samples * BEATS_PER_BAR

	# Walking bass on chord roots, eighth notes feel.
	bass_pat = [0, -1, 0, 2, 0, -1, 0, 1]  # chord tone indices / rest

	for i in range(n):
		t = i / SR
		bar = int(t / (BEATS_PER_BAR * BEAT)) % len(CHORD_FREQS)
		chord = CHORD_FREQS[bar]
		beat_in_bar = (t / BEAT) % BEATS_PER_BAR
		eighth = int((t / (BEAT * 0.5))) % 8

		# Pad chords (stereo spread)
		pad = 0.0
		for ci, f in enumerate(chord):
			ph = f * t
			pad += soft_saw(ph) * 0.11 * env_adsr((t % (BEATS_PER_BAR * BEAT)), BEATS_PER_BAR * BEAT, 0.15, 0.2, 0.7, 0.25)
		# gentle tremolo
		pad *= 0.85 + 0.15 * math.sin(2 * math.pi * 2.5 * t)

		# Bass
		bass = 0.0
		bi = bass_pat[eighth]
		if bi >= 0:
			bf = chord[min(bi, len(chord) - 1)] * 0.5
			local = (t / (BEAT * 0.5)) % 1.0
			bass = math.sin(2 * math.pi * bf * t) * 0.22 * env_adsr(local * BEAT * 0.5, BEAT * 0.5, 0.01, 0.05, 0.5, 0.08)

		# Melody — quarter notes from MELODY (2 entries per beat in list? list is 8 per 4 beats = eighths)
		mel = 0.0
		mi = int(t / (BEAT * 0.5)) % len(MELODY)
		deg = MELODY[mi]
		if deg >= 0:
			mf = SCALE[min(deg, len(SCALE) - 1)]
			local = (t / (BEAT * 0.5)) % 1.0
			mel = pluck(mf * t, 0.5) * 0.28 * env_adsr(local * BEAT * 0.5, BEAT * 0.5, 0.01, 0.06, 0.45, 0.12)
			# soft octave sparkle
			mel += pluck(mf * 2 * t, 0.25) * 0.06 * env_adsr(local * BEAT * 0.5, BEAT * 0.5, 0.01, 0.08, 0.3, 0.15)

		# Light shaker on offbeats
		perc = 0.0
		if eighth % 2 == 1:
			local = (t / (BEAT * 0.5)) % 1.0
			# hashed noise
			h = math.sin(i * 12.9898) * 43758.5453
			nse = (h - math.floor(h)) * 2.0 - 1.0
			perc = nse * 0.07 * env_adsr(local * BEAT * 0.5, BEAT * 0.5, 0.001, 0.02, 0.15, 0.08)

		# Soft kick on 1 and 3
		kick = 0.0
		if int(beat_in_bar) in (0, 2) and (t % BEAT) < 0.12:
			kt = t % BEAT
			kf = 90.0 * (1.0 - kt / 0.12) + 45.0
			kick = math.sin(2 * math.pi * kf * kt) * 0.18 * env_adsr(kt, 0.12, 0.001, 0.04, 0.3, 0.05)

		mix = pad + bass + mel + perc + kick
		# Soft clip
		mix = math.tanh(mix * 1.15)
		# Stereo: pad L/R slight, melody center, bass center
		left[i] = mix * 0.92 + pad * 0.05
		right[i] = mix * 0.92 - pad * 0.05

	# Fade edges tiny for seamless loop (crossfade 40ms)
	xf = int(0.04 * SR)
	for i in range(xf):
		w = i / xf
		left[i] = left[i] * w + left[n - xf + i] * (1.0 - w)
		right[i] = right[i] * w + right[n - xf + i] * (1.0 - w)
	# Zero the duplicated tail region conceptually by matching start — truncate not needed if we overwrite start.

	wav_out = Path("audio/music/menu_farmyard_loop.wav")
	ogg_out = Path("audio/music/menu_farmyard_loop.ogg")
	wav_out.parent.mkdir(parents=True, exist_ok=True)
	with wave.open(str(wav_out), "w") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(SR)
		frames = bytearray()
		for i in range(n):
			for s in (left[i], right[i]):
				v = int(max(-1.0, min(1.0, s)) * 32767.0)
				frames += struct.pack("<h", v)
		w.writeframes(frames)
	print(f"Wrote {wav_out} ({DURATION:.1f}s, {n} samples)")
	print(f"Encode with: ffmpeg -y -i {wav_out} -c:a libvorbis -q:a 5 {ogg_out}")


if __name__ == "__main__":
	main()
