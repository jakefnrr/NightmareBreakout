extends Node

const MIX_RATE = 22050.0
const POOL_SIZE = 6

var game: Node = null
var players: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var gen: AudioStreamGenerator = null
var gen_player: AudioStreamPlayer = null
var feed_accum = 0.0
var ambience_on = false
var chase = false
var outage = false
var drip_timer = 5.0
var started = false


func _ready() -> void:
	game = get_node("/root/Main")
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		players.append(p)
	_start_ambience()


func is_ambience_ready() -> bool:
	return gen_player != null and gen_player.playing


func _start_ambience() -> void:
	gen = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.6
	gen_player = AudioStreamPlayer.new()
	gen_player.stream = gen
	gen_player.volume_db = -18.0
	gen_player.bus = &"Master"
	add_child(gen_player)
	gen_player.play()
	ambience_on = true


func set_chase(v: bool) -> void:
	if chase == v:
		return
	chase = v
	if v:
		play_sfx("monster_sting")
	else:
		play_sfx("monster_growl")


func set_outage(v: bool) -> void:
	outage = v


func _process(delta: float) -> void:
	if not ambience_on:
		return
	feed_accum += delta
	if feed_accum < 0.05:
		return
	feed_accum = 0.0
	_feed()
	if game and game.is_playing() and not game.ui_blocking():
		drip_timer -= delta
		if drip_timer <= 0.0:
			drip_timer = randf_range(4.0, 11.0)
			if randf() < 0.6:
				play_sfx("drip")


func _feed() -> void:
	var playback = gen_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null or not playback.can_push_buffer(512):
		return
	var frames = PackedVector2Array()
	frames.resize(512)
	var t = Time.get_ticks_msec() / 1000.0
	var chase_gain = 1.0 if chase else 0.0
	var outage_hum = 0.35 if outage else 0.0
	for i in 512:
		var tt = t + i / MIX_RATE
		var slow = 0.6 + 0.4 * sin(tt * 0.4)
		var s = sin(tt * TAU * 46.0) * 0.20 \
			+ sin(tt * TAU * 46.7) * 0.18 \
			+ sin(tt * TAU * 92.3) * 0.07 \
			+ (randf() - 0.5) * 0.035
		s *= slow * (0.55 + 0.25 * chase_gain)
		# Dissonant chase pulse.
		if chase:
			var pulse = pow(0.5 + 0.5 * sin(tt * TAU * 5.5), 3.0)
			s += (sin(tt * TAU * 155.0) * 0.10 + sin(tt * TAU * 164.0) * 0.08) * pulse
		if outage_hum > 0.0:
			s += sin(tt * TAU * 120.0) * 0.05 * outage_hum
		var v = clampf(s, -1.0, 1.0) * (0.9 if chase else 0.55)
		frames[i] = Vector2(v, v)
	playback.push_buffer(frames)


func play_sfx(sfx_name: String, volume_db = 0.0) -> void:
	var stream: AudioStream = cache.get(sfx_name, null)
	if stream == null:
		stream = _synthesize(sfx_name)
		cache[sfx_name] = stream
	if stream == null:
		return
	var p: AudioStreamPlayer = null
	for cand in players:
		if not cand.playing:
			p = cand
			break
	if p == null:
		p = players[randi() % players.size()]
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func play_footstep(surface: String) -> void:
	play_sfx("step_" + surface, -6.0)


func _synthesize(n: String) -> AudioStream:
	match n:
		"pickup": return _tone(520, 0.12, 0.5, 4.0)
		"drop": return _noise(0.18, 0.35)
		"door_open": return _sweep(140, 240, 0.35, 0.35)
		"door_close": return _sweep(240, 120, 0.3, 0.3)
		"door_locked": return _tone(180, 0.15, 0.5, 5.0)
		"keycard": return _sweep(700, 1200, 0.12, 0.3)
		"checkpoint": return _chord([392, 523, 659], 0.5, 0.35)
		"power_down": return _sweep(220, 40, 1.2, 0.5)
		"power_up": return _sweep(60, 240, 0.9, 0.45)
		"breaker": return _noise(0.4, 0.5) if randf() < 0.5 else _sweep(90, 160, 0.5, 0.5)
		"puzzle_good": return _chord([523, 659, 784], 0.4, 0.35)
		"puzzle_bad": return _tone(140, 0.35, 0.5, 3.0)
		"monster_sting": return _sweep(60, 900, 0.8, 0.7)
		"monster_growl": return _sweep(120, 50, 0.9, 0.6)
		"death": return _sweep(300, 30, 1.4, 0.7)
		"win": return _chord([392, 494, 587, 784], 1.2, 0.4)
		"drip": return _tone(1400, 0.08, 0.25, 8.0)
		"flashlight": return _tone(2000, 0.05, 0.2, 6.0)
		"elevator": return _sweep(180, 320, 0.8, 0.3)
		"ui_click": return _tone(900, 0.05, 0.25, 8.0)
		"hatch": return _sweep(80, 200, 0.7, 0.5)
		"hidden": return _noise(0.5, 0.4)
		"document": return _noise(0.25, 0.25)
		"terminal": return _sweep(500, 800, 0.2, 0.25)
		"page": return _noise(0.15, 0.2)
		"alarm": return _sweep(600, 600, 0.4, 0.3)
		"jumpscare": return _jumpscare_stream()
		"snake_beep": return _tone(660, 0.06, 0.3, 10.0)
		"snake_eat": return _chord([660, 880], 0.15, 0.3)
		_: return null
	if n.begins_with("step_"):
		return _footstep(n.trim_prefix("step_"))
	return null


func _footstep(surface: String) -> AudioStream:
	var dur = 0.12
	var vol = 0.5
	match surface:
		"metal": dur = 0.16; vol = 0.55
		"tile": dur = 0.10; vol = 0.45
		"carpet": dur = 0.14; vol = 0.35
		"wood": dur = 0.13; vol = 0.5
		"concrete": dur = 0.12; vol = 0.5
		"grate": dur = 0.14; vol = 0.55
	return _noise(dur, vol)


func _wav_bytes(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data = PackedByteArray()
	data.resize(samples.size())
	for i in samples.size():
		var v = int(clampf(samples[i], -1.0, 1.0) * 127.0 + 128.0)
		data[i] = v
	var w = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_8_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


func _tone(freq: float, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n = int(MIX_RATE * dur)
	var s = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t = i / MIX_RATE
		s[i] = sin(t * TAU * freq) * vol * exp(-t * decay)
	return _wav_bytes(s)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n = int(MIX_RATE * dur)
	var s = PackedFloat32Array()
	s.resize(n)
	var phase = 0.0
	for i in n:
		var t = i / MIX_RATE
		var f = lerpf(f0, f1, t / dur)
		phase += TAU * f / MIX_RATE
		s[i] = sin(phase) * vol * (1.0 - t / dur * 0.6)
	return _wav_bytes(s)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n = int(MIX_RATE * dur)
	var s = PackedFloat32Array()
	s.resize(n)
	var last = 0.0
	for i in n:
		var t = i / MIX_RATE
		var white = randf() * 2.0 - 1.0
		last = lerpf(last, white, 0.35)
		s[i] = last * vol * (1.0 - t / dur)
	return _wav_bytes(s)


func _jumpscare_stream() -> AudioStreamWAV:
	var dur = 1.1
	var n = int(MIX_RATE * dur)
	var s = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t = i / MIX_RATE
		var white = randf() * 2.0 - 1.0
		var last = 0.0
		# crude one-pole for body
		last = lerpf(last, white, 0.4)
		var screech = sin(t * TAU * (900.0 + 300.0 * sin(t * 30.0))) * 0.25
		var env = 1.0 - t / dur
		s[i] = (last * 0.9 + screech) * env * 0.95
	return _wav_bytes(s)


func _chord(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n = int(MIX_RATE * dur)
	var s = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t = i / MIX_RATE
		var v = 0.0
		for f in freqs:
			v += sin(t * TAU * float(f))
		s[i] = v / freqs.size() * vol * exp(-t * 1.2)
	return _wav_bytes(s)
