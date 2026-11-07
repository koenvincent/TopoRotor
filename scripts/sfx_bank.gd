class_name SfxBank
extends Node

# Every effect sound is synthesised at start-up from a few lines of maths, so
# the game ships no extra audio files, needs no licences and stays offline.
const RATE = 22050
var players: Dictionary = {}
var muted: bool = false
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4711
	add_sound("chime", chime(), -9.0)
	add_sound("whistle", whistle(), -17.0)
	add_sound("boom", boom(), -7.0)
	add_sound("crackle", crackle(), -13.0)
	add_sound("buzzer", buzzer(), -8.0)
	add_sound("fanfare", fanfare(), -10.0)
	add_sound("whoosh", whoosh(), -15.0)
	add_sound("star", star_ping(), -11.0)

func add_sound(sound_name: String, samples: PackedFloat32Array, volume: float) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = to_stream(samples)
	player.volume_db = volume
	player.max_polyphony = 6
	add_child(player)
	players[sound_name] = player

func play(sound_name: String, pitch: float = 1.0) -> void:
	if muted or not players.has(sound_name):
		return
	var player: AudioStreamPlayer = players[sound_name]
	player.pitch_scale = pitch
	player.play()

func stop_all() -> void:
	for player in players.values():
		player.stop()

static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

static func buffer(seconds: float) -> PackedFloat32Array:
	var samples = PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples

# Bright bell arpeggio (G5 B5 D6 G6) for a correct answer.
func chime() -> PackedFloat32Array:
	var s = buffer(1.1)
	var notes = [784.0, 987.8, 1174.7, 1568.0]
	for n in notes.size():
		var start = int(n * .075 * RATE)
		for i in range(start, s.size()):
			var t = float(i - start) / RATE
			var env = exp(-t * 5.5) * minf(t * 400.0, 1.0)
			var f = notes[n]
			s[i] += env * .22 * (sin(TAU * f * t) + .35 * sin(TAU * f * 2.0 * t) + .12 * sin(TAU * f * 3.01 * t))
	return s

# Rising rocket whistle with a hiss of sparks.
func whistle() -> PackedFloat32Array:
	var s = buffer(.8)
	var phase = 0.0
	for i in s.size():
		var t = float(i) / RATE
		var f = 650.0 + 1700.0 * pow(t / .8, 1.4) + sin(t * 70.0) * 25.0
		phase += TAU * f / RATE
		var env = minf(t * 12.0, 1.0) * (1.0 - smoothstep(.6, .8, t))
		s[i] = env * (.45 * sin(phase) + .12 * rng.randf_range(-1.0, 1.0))
	return s

# Deep firework thump: low-passed noise plus a falling sub tone.
func boom() -> PackedFloat32Array:
	var s = buffer(1.7)
	var low = 0.0
	var phase = 0.0
	for i in s.size():
		var t = float(i) / RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * (.09 + .3 * exp(-t * 18.0))
		phase += TAU * (38.0 + 70.0 * exp(-t * 7.0)) / RATE
		var crack = exp(-t * 60.0) * rng.randf_range(-1.0, 1.0)
		s[i] = tanh(2.2 * (low * 1.6 * exp(-t * 2.8) + .8 * sin(phase) * exp(-t * 4.5) + crack * .6)) * .9
	return s

# Glittering crackle after the burst: random short noise grains.
func crackle() -> PackedFloat32Array:
	var s = buffer(1.2)
	for grain in 90:
		var start = int(rng.randf_range(0.0, 1.0) * s.size() * .85)
		var length = rng.randi_range(40, 160)
		var amp = rng.randf_range(.25, .7) * (1.0 - float(start) / s.size())
		for j in length:
			if start + j < s.size():
				s[start + j] += amp * exp(-float(j) / length * 4.0) * rng.randf_range(-1.0, 1.0)
	return s

# Game-show "wrong" buzzer: two detuned square pulses, softly clipped.
func buzzer() -> PackedFloat32Array:
	var s = buffer(.62)
	for i in s.size():
		var t = float(i) / RATE
		var gate = 1.0 if t < .23 or (t > .3 and t < .58) else 0.0
		var local = t if t < .27 else t - .3
		var env = gate * minf(local * 200.0, 1.0) * (1.0 - .35 * local / .28)
		var f = 150.0 - local * 18.0
		var square = signf(sin(TAU * f * t)) * .5 + signf(sin(TAU * (f * 1.012) * t)) * .5
		s[i] = tanh(env * (square * .55 + .45 * sin(TAU * f * .5 * t)) * 1.4) * .75
	return s

# Short brass-like fanfare (C5 E5 G5 C6) for a finished mission.
func fanfare() -> PackedFloat32Array:
	var s = buffer(1.9)
	var notes = [[523.3, 0.0, .16], [659.3, .15, .16], [784.0, .3, .16], [1046.5, .45, 1.3]]
	for note in notes:
		var f: float = note[0]
		var start = int(note[1] * RATE)
		var length = int(note[2] * RATE)
		for j in length:
			var i = start + j
			if i >= s.size():
				break
			var t = float(j) / RATE
			var env = minf(t * 60.0, 1.0) * (1.0 - smoothstep(note[2] - .12, note[2], t))
			var vib = 1.0 + .006 * sin(TAU * 5.5 * t) * minf(t * 3.0, 1.0)
			var v = 0.0
			for h in range(1, 7):
				v += sin(TAU * f * vib * h * t) / h * (1.0 if h < 4 else .5)
			s[i] += env * v * .16
	return s

# Air whoosh for changing flight height.
func whoosh() -> PackedFloat32Array:
	var s = buffer(.55)
	var low = 0.0
	for i in s.size():
		var t = float(i) / RATE
		var cutoff = .03 + .25 * sin(PI * t / .55)
		low += (rng.randf_range(-1.0, 1.0) - low) * cutoff
		s[i] = low * sin(PI * t / .55) * 1.4
	return s

# Light ping per star in the summary.
func star_ping() -> PackedFloat32Array:
	var s = buffer(.5)
	for i in s.size():
		var t = float(i) / RATE
		s[i] = exp(-t * 9.0) * minf(t * 500.0, 1.0) * .4 * (sin(TAU * 1318.5 * t) + .4 * sin(TAU * 2637.0 * t))
	return s
