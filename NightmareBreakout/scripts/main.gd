extends Node3D

# NIGHTMARE BREAKOUT — first-person horror escape room.
# Collect 3 fuses, then escape through the sealed exit door.

const FUSES_NEEDED := 3
const WALL_H := 3.0
const WALL_T := 0.4
const DOOR_W := 2.0
const DOOR_H := 2.4

var fuses := 0
var door_open := false
var won := false

var player: CharacterBody3D
var door_body: StaticBody3D
var door_mesh: MeshInstance3D
var scare_mob: MeshInstance3D
var scare_timer := 4.0
var scare_boost := 0.0

var flicker_lights: Array = []  # [OmniLight3D, base_energy, seed]

var hud_label: Label
var prompt_label: Label
var msg_label: Label
var sub_label: Label
var flash_rect: ColorRect
var win_panel: Control

var audio_player: AudioStreamPlayer
var audio_gen: AudioStreamGenerator
var audio_t := 0.0

var wall_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var ceil_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var door_mat: StandardMaterial3D


func _ready() -> void:
	wall_mat = _make_mat(Color(0.16, 0.17, 0.14), 0.95)
	floor_mat = _make_mat(Color(0.07, 0.08, 0.07), 0.85)
	ceil_mat = _make_mat(Color(0.05, 0.05, 0.05), 1.0)
	dark_mat = _make_mat(Color(0.02, 0.02, 0.025), 0.6,
		Color(0.35, 0.02, 0.02), 0.6)
	door_mat = _make_mat(Color(0.25, 0.1, 0.08), 0.5,
		Color(1.0, 0.15, 0.05), 1.2)

	_build_environment()
	_build_level()
	_build_fuses()
	_build_exit_door()
	_spawn_scare_mob()
	spawn_player()
	_build_hud()
	_start_drone()
	_show_message("FIND 3 FUSES — ESCAPE", 4.0)


# ---------------------------------------------------------------
# SETUP HELPERS
# ---------------------------------------------------------------

func _make_mat(color: Color, rough := 0.9,
		emission := Color(0, 0, 0), emit_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emit_energy
	return m


func _add_box(center: Vector3, size: Vector3, material: Material,
		collide := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
	return body


func _wall(x1: float, z1: float, x2: float, z2: float,
		material: Material = null) -> void:
	# Axis-aligned wall segment, centered vertically.
	var mat := material if material else wall_mat
	var dx := absf(x2 - x1)
	var dz := absf(z2 - z1)
	var size: Vector3
	var center: Vector3
	if dx >= dz:
		size = Vector3(dx + WALL_T, WALL_H, WALL_T)
		center = Vector3((x1 + x2) / 2.0, WALL_H / 2.0, (z1 + z2) / 2.0)
	else:
		size = Vector3(WALL_T, WALL_H, dz + WALL_T)
		center = Vector3((x1 + x2) / 2.0, WALL_H / 2.0, (z1 + z2) / 2.0)
	_add_box(center, size, mat)


func _lintel(x: float, z: float, along_x: bool, width: float) -> void:
	# Fills the gap above a doorway up to the ceiling.
	var size := Vector3(width + WALL_T, WALL_H - DOOR_H, WALL_T) \
		if along_x else Vector3(WALL_T, WALL_H - DOOR_H, width + WALL_T)
	_add_box(Vector3(x, DOOR_H + (WALL_H - DOOR_H) / 2.0, z), size, wall_mat)


func _add_light(pos: Vector3, color: Color, energy: float,
		flicker_seed: float = -1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 11.0
	l.omni_attenuation = 1.4
	add_child(l)
	if flicker_seed >= 0.0:
		flicker_lights.append([l, energy, flicker_seed])
	return l


# ---------------------------------------------------------------
# WORLD
# ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.01, 0.005)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.04, 0.09, 0.05)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.05, 0.03)
	env.fog_density = 0.02
	env.fog_sky_affect = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Floor + ceiling
	_add_box(Vector3(0, -0.15, 0), Vector3(34, 0.3, 24), floor_mat)
	_add_box(Vector3(0, WALL_H + 0.15, 0), Vector3(34, 0.3, 24), ceil_mat, false)


func _build_level() -> void:
	# Layout: central hall x[-3,3] z[-8,8]; four rooms around it.
	# North room z[-16,-8], west x[-11,-3] z[-4,4], east x[3,11] z[-4,4].
	# Exit door on south wall (z=8) at x=0.

	# --- Hall side walls (x = ±3), with 2m door gaps at z in [-1,1] ---
	_wall(-3, -8, -3, -1)
	_wall(-3, 1, -3, 8)
	_wall(3, -8, 3, -1)
	_wall(3, 1, 3, 8)
	_lintel(-3, 0, false, DOOR_W)
	_lintel(3, 0, false, DOOR_W)

	# --- Hall north wall (z = -8), gap at x in [-1,1] ---
	_wall(-3, -8, -1, -8)
	_wall(1, -8, 3, -8)
	_lintel(0, -8, true, DOOR_W)

	# --- Hall south wall (z = 8), gap at x in [-1,1] for the EXIT ---
	_wall(-3, 8, -1, 8)
	_wall(1, 8, 3, 8)
	_lintel(0, 8, true, DOOR_W)

	# --- North room walls ---
	_wall(-3, -16, 3, -16)          # far wall
	_wall(-3, -16, -3, -8)          # west side
	_wall(3, -16, 3, -8)            # east side

	# --- West room walls ---
	_wall(-11, -4, -3, -4)          # north side (meets hall west wall)
	_wall(-11, 4, -3, 4)            # south side
	_wall(-11, -4, -11, 4)          # outer wall

	# --- East room walls ---
	_wall(3, -4, 11, -4)
	_wall(3, 4, 11, 4)
	_wall(11, -4, 11, 4)

	# --- Crates / cover ---
	var crate_mat := _make_mat(Color(0.2, 0.14, 0.08), 0.9)
	_add_box(Vector3(-1.6, 0.4, -5.5), Vector3(0.8, 0.8, 0.8), crate_mat)
	_add_box(Vector3(1.7, 0.4, 3.0), Vector3(0.8, 0.8, 0.8), crate_mat)
	_add_box(Vector3(-6.5, 0.4, -2.5), Vector3(0.9, 0.8, 0.9), crate_mat)
	_add_box(Vector3(6.5, 0.4, 2.5), Vector3(0.9, 0.8, 0.9), crate_mat)
	_add_box(Vector3(0, 0.35, -12.0), Vector3(1.4, 0.7, 0.7), crate_mat)
	_add_box(Vector3(-1.8, 0.3, 6.8), Vector3(0.6, 0.6, 0.6), crate_mat)

	# --- Lights (flicker seeds on most) ---
	_add_light(Vector3(0, 2.7, -4), Color(0.65, 1.0, 0.75), 1.1, 1.7)
	_add_light(Vector3(0, 2.7, 4), Color(0.65, 1.0, 0.75), 1.1, 4.2)
	_add_light(Vector3(-7, 2.7, 0), Color(0.7, 0.95, 0.8), 1.0, 8.9)
	_add_light(Vector3(7, 2.7, 0), Color(0.7, 0.95, 0.8), 1.0, 13.3)
	_add_light(Vector3(0, 2.7, -12), Color(0.8, 0.85, 1.0), 0.9, 21.7)
	# Sickly red glow near the exit — never flickers
	_add_light(Vector3(0, 2.4, 6.6), Color(1.0, 0.2, 0.1), 0.7)


func _build_fuses() -> void:
	var spots := [
		Vector3(-7, 1.1, 0),     # west room
		Vector3(7, 1.1, 0),      # east room
		Vector3(0, 1.1, -12),    # north room
	]
	var fuse_mat := _make_mat(Color(1.0, 0.55, 0.1), 0.4,
		Color(1.0, 0.45, 0.05), 3.0)
	for pos in spots:
		var fuse := Node3D.new()
		fuse.position = pos
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.09
		cyl.height = 0.4
		mesh.mesh = cyl
		mesh.material_override = fuse_mat
		fuse.add_child(mesh)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.5, 0.15)
		glow.light_energy = 1.4
		glow.omni_range = 5.0
		fuse.add_child(glow)
		var area := Area3D.new()
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.3
		col.shape = sph
		area.add_child(col)
		fuse.add_child(area)
		area.body_entered.connect(_on_fuse_body.bind(fuse))
		add_child(fuse)


func _build_exit_door() -> void:
	# Door panel fills the south-wall gap at x=0, z=8.
	door_body = StaticBody3D.new()
	door_body.position = Vector3(0, DOOR_H / 2.0, 8)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_W, DOOR_H, 0.35)
	col.shape = shape
	door_body.add_child(col)
	door_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(DOOR_W, DOOR_H, 0.3)
	door_mesh.mesh = bm
	door_mesh.material_override = door_mat
	door_body.add_child(door_mesh)
	add_child(door_body)

	# Warning stripes above the door
	var stripe := _make_mat(Color(0.5, 0.4, 0.05), 0.6,
		Color(1.0, 0.7, 0.0), 0.8)
	_add_box(Vector3(0, DOOR_H + 0.18, 8), Vector3(DOOR_W + 0.3, 0.16, 0.1), stripe, false)

	# Exit trigger just inside the doorway
	var zone := Area3D.new()
	zone.position = Vector3(0, 1.2, 7.2)
	var zcol := CollisionShape3D.new()
	var zshape := BoxShape3D.new()
	zshape.size = Vector3(DOOR_W, DOOR_H, 1.4)
	zcol.shape = zshape
	zone.add_child(zcol)
	zone.body_entered.connect(_on_exit_body)
	add_child(zone)


func _spawn_scare_mob() -> void:
	# Black silhouette that haunts the rooms.
	scare_mob = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.85
	scare_mob.mesh = cap
	scare_mob.material_override = _make_mat(
		Color(0.005, 0.005, 0.005), 1.0,
		Color(0.25, 0.0, 0.0), 0.35)
	scare_mob.position = Vector3(-7, 0.95, 0)
	add_child(scare_mob)


func spawn_player() -> void:
	player = load("res://scenes/Player.tscn").instantiate()
	player.position = Vector3(0, 0.9, 6.5)
	add_child(player)


# ---------------------------------------------------------------
# GAMEPLAY
# ---------------------------------------------------------------

func _on_fuse_body(body: Node, fuse: Node3D) -> void:
	if body != player or won:
		return
	fuses += 1
	fuse.queue_free()
	hud_label.text = "FUSES  %d / %d" % [fuses, FUSES_NEEDED]
	_flash_screen(Color(1.0, 0.5, 0.1, 0.35))
	player.add_shake(0.25)
	if fuses >= FUSES_NEEDED:
		_open_door()
	else:
		_show_message("FUSE ACQUIRED  (%d/%d)" % [fuses, FUSES_NEEDED], 2.0)


func _open_door() -> void:
	door_open = true
	# Disable collision immediately, slide the panel down into the floor.
	for c in door_body.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(door_mesh, "position:y", -(DOOR_H + 0.4), 1.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_show_message("SOMETHING UNLOCKED — GET TO THE EXIT", 3.5)


func _on_exit_body(body: Node) -> void:
	if body != player or won:
		return
	if door_open:
		_win()
	else:
		_show_message("SEALED. FIND %d MORE FUSES." % (FUSES_NEEDED - fuses), 2.5)


func _win() -> void:
	won = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	win_panel.visible = true


func _show_message(text: String, duration: float) -> void:
	msg_label.text = text
	msg_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(duration * 0.6)
	tw.tween_property(msg_label, "modulate:a", 0.0, duration * 0.4)


func _flash_screen(color: Color) -> void:
	flash_rect.color = color
	flash_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(flash_rect, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------
# SCARE MOB AI
# ---------------------------------------------------------------

var mob_spots := [
	Vector3(-7, 0.95, -2), Vector3(-9, 0.95, 3),
	Vector3(7, 0.95, -2), Vector3(9, 0.95, 3),
	Vector3(0, 0.95, -12), Vector3(-2, 0.95, -14),
	Vector3(2, 0.95, -14), Vector3(0, 0.95, -4),
	Vector3(0, 0.95, 4),
]

func _process(delta: float) -> void:
	# Flickering lights
	for entry in flicker_lights:
		var light: OmniLight3D = entry[0]
		var base: float = entry[1]
		var seed: float = entry[2]
		var wave := 0.72 + 0.28 * sin(Time.get_ticks_msec() * 0.013 + seed * 7.0)
		var dropout := 1.0
		# Random hard cutouts
		var n := sin(Time.get_ticks_msec() * 0.11 + seed * 3.1)
		if n > 0.965:
			dropout = 0.12
		light.light_energy = base * wave * dropout

	# Scare mob: teleport around, vanish if player gets close
	scare_timer -= delta
	if scare_timer <= 0.0:
		scare_timer = randf_range(5.0, 11.0)
		var spot: Vector3 = mob_spots[randi() % mob_spots.size()]
		if player and spot.distance_to(player.global_position) < 4.5:
			spot = mob_spots[randi() % mob_spots.size()]
		scare_mob.global_position = spot
		scare_mob.visible = true

	if player and scare_mob.visible \
			and scare_mob.global_position.distance_to(player.global_position) < 2.4:
		# Jumpscare: vanish + red flash + shake + audio swell
		scare_mob.visible = false
		scare_timer = randf_range(9.0, 16.0)
		_flash_screen(Color(0.6, 0.0, 0.0, 0.8))
		player.add_shake(0.5)
		scare_boost = 1.4

	# Door prompt
	if player and not door_open:
		var d := player.global_position.distance_to(Vector3(0, 1.2, 7.6))
		prompt_label.visible = d < 3.0
	else:
		prompt_label.visible = false

	# Drone audio
	scare_boost = maxf(0.0, scare_boost - delta * 0.5)
	_feed_drone(delta)


# ---------------------------------------------------------------
# AMBIENT DRONE (procedural, no audio files needed)
# ---------------------------------------------------------------

func _start_drone() -> void:
	audio_gen = AudioStreamGenerator.new()
	audio_gen.mix_rate = 22050.0
	audio_gen.buffer_length = 0.5
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_gen
	audio_player.volume_db = -16.0
	audio_player.bus = &"Master"
	add_child(audio_player)
	audio_player.play()


func _feed_drone(_delta: float) -> void:
	var playback := audio_player.get_stream_playback() \
		as AudioStreamGeneratorPlayback
	if playback == null or not playback.can_push_buffer(1024):
		return
	var frames := PackedVector2Array()
	frames.resize(1024)
	var rate := audio_gen.mix_rate
	var boost := 1.0 + scare_boost * 2.5
	for i in 1024:
		audio_t += 1.0 / rate
		var t := audio_t
		# Detuned low drone + slow swell + faint noise
		var s := sin(t * TAU * 55.0) * 0.30 \
			+ sin(t * TAU * 55.6) * 0.28 \
			+ sin(t * TAU * 110.2) * 0.10 \
			+ (randf() - 0.5) * 0.06
		s *= 0.55 + 0.45 * sin(t * 0.35)  # slow breathing swell
		s *= boost
		frames[i] = Vector2(s, s)
	playback.push_buffer(frames)


# ---------------------------------------------------------------
# HUD
# ---------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	hud_label = _make_label(layer, "FUSES  0 / 3",
		Vector2(24, 20), HORIZONTAL_ALIGNMENT_LEFT, 22)
	hud_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
	hud_label.add_theme_constant_override("outline_size", 6)
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))

	prompt_label = _make_label(layer, "EXIT — SEALED",
		Vector2(0, -70), HORIZONTAL_ALIGNMENT_CENTER, 20)
	prompt_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.9))
	prompt_label.visible = false
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-100, -90)
	prompt_label.custom_minimum_size = Vector2(200, 40)

	msg_label = _make_label(layer, "",
		Vector2(0, -160), HORIZONTAL_ALIGNMENT_CENTER, 30)
	msg_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
	msg_label.add_theme_constant_override("outline_size", 8)
	msg_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	msg_label.set_anchors_preset(Control.PRESET_CENTER)
	msg_label.position = Vector2(-400, -200)
	msg_label.custom_minimum_size = Vector2(800, 60)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	sub_label = _make_label(layer, "",
		Vector2(0, -100), HORIZONTAL_ALIGNMENT_CENTER, 16)
	sub_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
	sub_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_label.position = Vector2(-300, 60)
	sub_label.custom_minimum_size = Vector2(600, 40)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1)
	flash_rect.modulate.a = 0.0
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_rect)

	# Win panel
	win_panel = Control.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.visible = false
	layer.add_child(win_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.01, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(dim)
	var title := _make_label(win_panel, "YOU ESCAPED",
		Vector2(0, -60), HORIZONTAL_ALIGNMENT_CENTER, 64)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0.2, 0.05, 1))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-400, -160)
	title.custom_minimum_size = Vector2(800, 100)
	var hint := _make_label(win_panel, "NIGHTMARE BREAKOUT — CLEARED",
		Vector2(0, 40), HORIZONTAL_ALIGNMENT_CENTER, 18)
	hint.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-400, -10)
	hint.custom_minimum_size = Vector2(800, 40)


func _make_label(parent: Node, text: String, pos: Vector2,
		align: HorizontalAlignment, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
