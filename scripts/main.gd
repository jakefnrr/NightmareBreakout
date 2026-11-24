extends Node3D

const SAVE_TIME := "user://nb_time.cfg"
const ITEM_CAP := 3

var mats := {}
var level: Node3D = null
var player: CharacterBody3D = null
var audio: Node = null
var ui: CanvasLayer = null
var snake: CanvasLayer = null
var menu_cam: Camera3D = null
var menu_light: OmniLight3D = null

var doors := {}
var lights := []
var world_items := []
var collected := {}
var inventory: Array = []
var held_index := -1
var pick_counter := 0

var started := false
var total_time := 0.0
var mouse_sensitivity := 0.0021
var master_volume := -6.0
var reduce_lights := false
var stopwatch_label: Label3D = null
var panel_count := 0
var sec_lights: Array = []
var sec_on := false
var room_lights := {}
var lights_out := false
var blackout_timer := 0.0
var scare_tex: Texture2D = null

const ITEMS := {
	"flashlight": {"name": "FLASHLIGHT", "type": "flashlight", "desc": "A heavy tactical flashlight. Press F to toggle. Battery drains only while ON."},
	"battery": {"name": "BATTERY", "type": "battery", "desc": "Spare battery for the flashlight. Only one spare can be carried."},
	"power_cell": {"name": "POWER CELL", "type": "powercell", "desc": "A charged power cell. The Security Room door consumes one."},
	"gold_key": {"name": "GOLD KEY", "type": "key", "desc": "A heavy gold key. Opens the door to Main Room 2."},
	"key_power": {"name": "STORAGE KEY", "type": "key", "desc": "A small brass key. Opens the Power Room door in Room 2."},
	"key_vg": {"name": "SECURITY KEY", "type": "key", "desc": "Security keycard-style key. Opens the Video Game Room door."},
}


func _ready() -> void:
	_load_time()
	_make_materials()
	_build_environment()
	level = Node3D.new()
	level.name = "Level"
	level.set_script(load("res://scripts/level.gd"))
	add_child(level)
	level.build(self)
	_setup_content()
	_setup_lighting()
	_spawn_player()
	_setup_menu_cam()
	audio = Node.new()
	audio.name = "Audio"
	audio.set_script(load("res://scripts/audio.gd"))
	add_child(audio)
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.set_script(load("res://scripts/ui.gd"))
	add_child(ui)
	snake = CanvasLayer.new()
	snake.name = "Snake"
	snake.set_script(load("res://scripts/snake.gd"))
	add_child(snake)
	ui.show_main_menu()


func _exit_tree() -> void:
	_save_time()


# ---------------------------------------------------------------
# MATERIALS / ENVIRONMENT
# ---------------------------------------------------------------

func _tex_noise(base: Color, vary: float, size := 256) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	var n = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.018
	n.fractal_octaves = 4
	var stain = FastNoiseLite.new()
	stain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stain.frequency = 0.006
	stain.fractal_octaves = 2
	for y in size:
		for x in size:
			var v = n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var s = stain.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var grime = clampf((s - 0.52) * 2.2, 0.0, 1.0)
			var val = (v - 0.5) * 2.0 * vary - grime * 0.28
			img.set_pixel(x, y, Color(clampf(base.r + val, 0, 1),
				clampf(base.g + val, 0, 1), clampf(base.b + val, 0, 1)))
	return ImageTexture.create_from_image(img)


func _mat(color: Color, rough := 0.9, metal := 0.0, emission := Color(0, 0, 0),
		ee := 0.0, tex: Texture2D = null, tex_scale := 6.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(tex_scale, tex_scale, tex_scale)
	if emission != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = ee
	return m


func _make_materials() -> void:
	var concrete_tex = _tex_noise(Color(0.32, 0.32, 0.33), 0.05)
	var metal_tex = _tex_noise(Color(0.35, 0.37, 0.4), 0.04)
	var tile_tex = _tex_noise(Color(0.4, 0.42, 0.45), 0.04)
	mats["concrete"] = _mat(Color(1, 1, 1), 0.95, 0.0, Color(0, 0, 0), 0, concrete_tex)
	mats["concrete_dark"] = _mat(Color(0.55, 0.55, 0.58), 0.95, 0.0, Color(0, 0, 0), 0, concrete_tex)
	mats["metal"] = _mat(Color(1, 1, 1), 0.45, 0.85, Color(0, 0, 0), 0, metal_tex)
	mats["metal_dark"] = _mat(Color(0.5, 0.52, 0.55), 0.5, 0.9, Color(0, 0, 0), 0, metal_tex)
	mats["tile"] = _mat(Color(1, 1, 1), 0.6, 0.1, Color(0, 0, 0), 0, tile_tex)
	mats["wall_paint"] = _mat(Color(1, 1, 1), 0.8, 0.0, Color(0, 0, 0), 0, _tex_noise(Color(0.45, 0.5, 0.52), 0.05))
	mats["wood"] = _mat(Color(0.35, 0.22, 0.12), 0.8)
	mats["crate"] = _mat(Color(0.45, 0.32, 0.18), 0.9)
	mats["sheet"] = _mat(Color(0.85, 0.85, 0.8), 0.95)
	mats["machine"] = _mat(Color(0.55, 0.58, 0.6), 0.4, 0.9)
	mats["machine_dark"] = _mat(Color(0.2, 0.22, 0.24), 0.5, 0.85)
	mats["pipe"] = _mat(Color(0.5, 0.45, 0.3), 0.5, 0.8)
	mats["door"] = _mat(Color(0.3, 0.34, 0.36), 0.5, 0.8)
	mats["hazard"] = _mat(Color(0.7, 0.55, 0.05), 0.6, 0.2, Color(1, 0.6, 0), 0.6)
	mats["screen"] = _mat(Color(0.02, 0.05, 0.04), 0.3, 0.2, Color(0.2, 0.9, 0.5), 1.2)
	mats["paper"] = _mat(Color(0.85, 0.82, 0.7), 0.95)
	mats["key_gold"] = _mat(Color(0.8, 0.6, 0.15), 0.35, 0.9)
	mats["card"] = _mat(Color(0.1, 0.15, 0.2), 0.4, 0.6, Color(0.2, 0.8, 1.0), 0.8)
	mats["cell_blue"] = _mat(Color(0.05, 0.15, 0.4), 0.3, 0.4, Color(0.2, 0.5, 1.0), 1.5)
	mats["battery_green"] = _mat(Color(0.1, 0.4, 0.15), 0.4, 0.5, Color(0.3, 1.0, 0.4), 1.0)
	mats["tool_dark"] = _mat(Color(0.15, 0.15, 0.16), 0.5, 0.85)
	mats["debris"] = _mat(Color(0.2, 0.2, 0.2), 1.0)
	mats["plant"] = _mat(Color(0.1, 0.3, 0.12), 0.9)
	mats["carpet"] = _mat(Color(0.28, 0.07, 0.22), 0.98)
	mats["fixture_warm"] = _mat(Color(1, 0.9, 0.75), 0.4, 0.0, Color(1, 0.75, 0.45), 2.2)
	mats["fixture_cool"] = _mat(Color(0.85, 0.95, 1), 0.4, 0.0, Color(0.65, 0.85, 1), 2.2)
	mats["fixture_purple"] = _mat(Color(0.8, 0.6, 1), 0.4, 0.0, Color(0.6, 0.35, 1), 2.2)
	mats["fixture_green"] = _mat(Color(0.6, 1, 0.7), 0.4, 0.0, Color(0.35, 1, 0.55), 2.2)
	mats["monitor"] = _mat(Color(0.03, 0.05, 0.08), 0.25, 0.3, Color(0.08, 0.22, 0.4), 0.5)


func _build_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.03, 0.04)
	env.fog_density = 0.008
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------------------------------------------------------------
# CONTENT
# ---------------------------------------------------------------

func _prop_box(pos: Vector3, size: Vector3, mat: Material, interact := {}, collide := true) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	if interact.size() > 0:
		body.set_meta("interact", interact)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new(); shape.size = size
	col.shape = shape; col.name = "Col"
	body.add_child(col)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat
	mi.name = "Mesh"
	body.add_child(mi)
	add_child(body)
	return body


func _item_mesh(item_id: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	match ITEMS[item_id]["type"]:
		"key":
			var bm = BoxMesh.new(); bm.size = Vector3(0.3, 0.04, 0.1); mi.mesh = bm
			mi.material_override = mats["key_gold"]
			var ring = MeshInstance3D.new()
			var tm = TorusMesh.new()
			tm.inner_radius = 0.045; tm.outer_radius = 0.11
			tm.rings = 12; tm.ring_segments = 8
			ring.mesh = tm
			ring.material_override = mats["key_gold"]
			ring.position = Vector3(-0.14, 0, 0)
			ring.rotation.y = PI / 2
			mi.add_child(ring)
		"battery":
			var cm = CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 0.22; mi.mesh = cm
			mi.material_override = mats["battery_green"]
		"powercell":
			var cm = CylinderMesh.new(); cm.top_radius = 0.11; cm.bottom_radius = 0.11; cm.height = 0.3; mi.mesh = cm
			mi.material_override = mats["cell_blue"]
		"flashlight":
			var cm = CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.07; cm.height = 0.35; mi.mesh = cm
			mi.material_override = mats["tool_dark"]
		_:
			var bm = BoxMesh.new(); bm.size = Vector3(0.3, 0.3, 0.3); mi.mesh = bm
			mi.material_override = mats["debris"]
	return mi


func _world_item(item_id: String, pos: Vector3) -> void:
	pick_counter += 1
	var pick_id = "pick_%d" % pick_counter
	var body = StaticBody3D.new()
	body.position = pos
	body.set_meta("interact", {"type": "pickup", "item_id": item_id, "pick_id": pick_id,
		"prompt": "PICK UP " + str(ITEMS[item_id]["name"])})
	var col = CollisionShape3D.new()
	var sph = SphereShape3D.new(); sph.radius = 0.55
	col.shape = sph; col.name = "Col"
	body.add_child(col)
	var holder = Node3D.new()
	holder.name = "ItemMesh"
	holder.add_child(_item_mesh(item_id))
	var glow = OmniLight3D.new()
	glow.light_energy = 0.35
	glow.omni_range = 2.0
	glow.light_color = Color(0.6, 0.8, 1.0)
	holder.add_child(glow)
	body.add_child(holder)
	add_child(body)
	world_items.append({"pick_id": pick_id, "item_id": item_id, "node": body, "col": col})


func _room_pos(rid: String, dx: float, dz: float, y := 0.9) -> Vector3:
	var c: Vector3 = level.room_center(rid)
	return Vector3(c.x + dx, y, c.z + dz)


func _setup_content() -> void:
	# Gold key on the Room 1 table.
	_world_item("gold_key", _room_pos("r1", 0.0, -1.0, 0.92))
	# Storage key on a Room 2 desk (opens the Power Room door).
	_world_item("key_power", _room_pos("r2", -4.0, -3.5, 0.95))
	# Workspace supplies.
	_world_item("flashlight", _room_pos("ws", 0.0, 0.0, 0.95))
	_world_item("battery", _room_pos("ws", -2.0, -2.0, 0.95))
	_world_item("battery", _room_pos("ws", 4.5, 2.5, 0.95))
	_world_item("power_cell", _room_pos("ws", -3.0, 1.0, 0.95))
	_world_item("power_cell", _room_pos("ws", 3.0, -3.0, 0.95))
	_world_item("power_cell", _room_pos("ws", 0.5, 3.0, 0.95))
	# Security room key.
	_world_item("key_vg", _room_pos("sec", -2.5, -3.0, 0.95))
	# Light switch inside Security Room near the west door.
	_prop_box(Vector3(4.45, 1.4, 1.4), Vector3(0.12, 0.35, 0.5), mats["machine_dark"],
		{"type": "switch", "id": "sec_lights", "prompt": "LIGHT SWITCH"})
	# Security terminal.
	_prop_box(_room_pos("sec", 2.0, -3.0, 1.1), Vector3(1.1, 0.9, 0.5), mats["machine_dark"],
		{"type": "computer", "id": "sec_pc", "prompt": "USE TERMINAL"})
	# Arcade machine in Video Game Room.
	var ap = _room_pos("vg", 5.0, -2.0, 0.0)
	_prop_box(ap + Vector3(0, 1.1, 0), Vector3(1.1, 2.2, 0.8), mats["machine_dark"],
		{"type": "arcade", "id": "arcade", "prompt": "PLAY"})
	_prop_box(ap + Vector3(0, 1.7, 0.45), Vector3(0.8, 0.6, 0.05), mats["screen"], {}, false)
	# Power button on the Power Room wall.
	_prop_box(Vector3(3.72, 1.4, -8.0), Vector3(0.12, 0.35, 0.5), mats["hazard"],
		{"type": "power_button", "id": "main", "prompt": "POWER BUTTON"})
	# Generous interact zones for arcade + security terminal.
	var ap2 = _room_pos("vg", 5.0, -2.0, 1.1)
	_zone(ap2, Vector3(2.1, 2.4, 1.5), {"type": "arcade", "id": "arcade", "prompt": "PLAY"})
	_zone(_room_pos("sec", 2.0, -3.0, 1.1), Vector3(1.7, 1.2, 1.0),
		{"type": "computer", "id": "sec_pc", "prompt": "USE TERMINAL"})
	# Stopwatch in Main Room 1.
	_stopwatch(_room_pos("r1", 3.0, 3.0, 0.0))
	# Wall map in Main Room 1, on the east wall next to the exit door.
	_map_board(Vector3(-12.1, 1.9, -3.6), -PI / 2)


func _zone(center: Vector3, size: Vector3, data: Dictionary) -> void:
	var body = StaticBody3D.new()
	body.position = center
	body.set_meta("interact", data)
	var col = CollisionShape3D.new()
	var s = BoxShape3D.new(); s.size = size
	col.shape = s
	col.name = "Col"
	body.add_child(col)
	add_child(body)


func _stopwatch(pos: Vector3) -> void:
	_prop_box(pos + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.3), mats["crate"], {})
	stopwatch_label = Label3D.new()
	stopwatch_label.text = "00:00:00"
	stopwatch_label.font_size = 64
	stopwatch_label.pixel_size = 0.004
	stopwatch_label.modulate = Color(0.4, 1.0, 0.6)
	stopwatch_label.position = pos + Vector3(0, 1.0, 0)
	stopwatch_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(stopwatch_label)


func _map_board(pos: Vector3, rot_y: float) -> void:
	var img = Image.create(1024, 768, false, Image.FORMAT_RGB8)
	img.fill(Color(0.03, 0.05, 0.04))
	# Draw the 5-room layout to scale.
	var bx = -26.0; var bz = -18.0; var bw = 45.0; var bd = 34.0
	var sx = 980.0 / bw; var sz = 700.0 / bd
	var ox = 22.0; var oy = 30.0
	var rooms_draw = {
		"r1": Color(0.2, 0.8, 0.4), "ws": Color(0.9, 0.7, 0.2), "r2": Color(0.3, 0.5, 0.9),
		"sec": Color(0.9, 0.3, 0.3), "vg": Color(0.8, 0.4, 0.9),
	}
	for rid in rooms_draw:
		var r: Rect2 = level.room_rect(rid)
		var x = ox + (r.position.x - bx) * sx
		var y = oy + (r.position.y - bz) * sz
		img.fill_rect(Rect2i(int(x), int(y), int(r.size.x * sx), int(r.size.y * sz)), rooms_draw[rid])
	# Door markers at their true positions.
	for did in doors:
		var rec: Dictionary = doors[did]
		var dp: Vector3 = rec["node"].position
		var dx = int(ox + (dp.x - bx) * sx)
		var dy = int(oy + (dp.z - bz) * sz)
		img.fill_rect(Rect2i(dx - 5, dy - 5, 10, 10), Color(1, 1, 1))
	img.flip_x()
	var tex = ImageTexture.create_from_image(img)
	var pm = MeshInstance3D.new()
	var plane = PlaneMesh.new(); plane.size = Vector2(4.8, 3.6)
	pm.mesh = plane
	pm.material_override = _mat(Color(1, 1, 1), 0.8, 0.0, Color(0.1, 0.2, 0.15), 0.6, tex, 1.0)
	pm.position = pos
	pm.rotation.y = rot_y
	add_child(pm)
	# Room labels on the map.
	var names = {"r1": "ROOM 1", "ws": "POWER", "r2": "ROOM 2", "sec": "SECURITY", "vg": "ARCADE"}
	var pw = 4.8; var ph = 3.6
	for rid in names:
		var r: Rect2 = level.room_rect(rid)
		var rcx = r.position.x + r.size.x / 2
		var rcz = r.position.y + r.size.y / 2
		var ix = ox + (rcx - bx) * sx
		var iy = oy + (rcz - bz) * sz
		var lx = (0.5 - ix / 1024.0) * pw
		var ly = (0.5 - iy / 768.0) * ph
		var lbl = Label3D.new()
		lbl.text = names[rid]
		lbl.font_size = 64
		lbl.pixel_size = 0.0035
		lbl.modulate = Color(1, 1, 1, 0.95)
		lbl.no_depth_test = true
		lbl.position = pos + Vector3(-0.07, ly, lx)
		lbl.rotation.y = rot_y
		add_child(lbl)


# ---------------------------------------------------------------
# LIGHTING
# ---------------------------------------------------------------

func _omni(pos: Vector3, color: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = true
	add_child(l)
	return l


func _room_light(rid: String, pos: Vector3, color: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l = _omni(pos, color, energy, rng_m)
	if not room_lights.has(rid):
		room_lights[rid] = []
	room_lights[rid].append(l)
	lights.append(l)
	return l


func _setup_lighting() -> void:
	# Main Room 1: moody warm (two fixtures for coverage).
	_room_light("r1", level.room_center("r1") + Vector3(0, 2.7, 0), Color(1, 0.82, 0.6), 0.95, 10)
	_room_light("r1", level.room_center("r1") + Vector3(-2, 2.7, -3), Color(1, 0.7, 0.5), 0.6, 7)
	# Main Room 2: neutral.
	_room_light("r2", level.room_center("r2") + Vector3(0, 2.7, 0), Color(0.85, 0.92, 1.0), 1.15, 11)
	# Power Room: cool work light.
	_room_light("ws", level.room_center("ws") + Vector3(0, 2.7, 0), Color(0.75, 0.88, 1.0), 1.0, 10)
	# Video Game Room: purple arcade glow.
	_room_light("vg", level.room_center("vg") + Vector3(0, 2.6, 0), Color(0.65, 0.45, 1.0), 1.0, 11)
	# Security room: OFF until switch. Two fixtures + faint emergency.
	var sr = level.room_rect("sec")
	for i in 2:
		var fx = sr.position.x + 3.0 + i * 6.0
		var fz = sr.position.y + sr.size.y / 2
		var l = _omni(Vector3(fx, 2.9, fz), Color(0.45, 1.0, 0.6), 1.25, 10)
		l.visible = false
		sec_lights.append(l)
		if not room_lights.has("sec"):
			room_lights["sec"] = []
		room_lights["sec"].append(l)
		lights.append(l)
	var emerg = _omni(level.room_center("sec") + Vector3(0, 2.8, 0), Color(1, 0.15, 0.1), 0.12, 8)
	lights.append(emerg)


func _trigger_blackout() -> void:
	lights_out = true
	blackout_timer = randf_range(45.0, 90.0)
	for rid in room_lights:
		for l in room_lights[rid]:
			l.visible = false
	# A spare battery always appears in the Power Room.
	_world_item("battery", _room_pos("ws", randf_range(-4.0, 4.0), randf_range(-3.0, 3.0), 0.95))
	if audio: audio.play_sfx("power_down")
	ui.show_message("POWER FAILURE — GO TO THE POWER ROOM", 4.0)


func _power_button() -> void:
	if lights_out:
		lights_out = false
		blackout_timer = randf_range(50.0, 95.0)
		for rid in room_lights:
			for l in room_lights[rid]:
				l.visible = (rid != "sec") or sec_on
		if audio: audio.play_sfx("power_up")
		ui.show_message("POWER RESTORED", 2.0)
	else:
		if audio: audio.play_sfx("ui_click")
		ui.show_message("POWER NOMINAL", 1.6)


func _toggle_security_lights() -> void:
	sec_on = not sec_on
	for l in sec_lights:
		l.visible = sec_on and not lights_out
	if audio:
		audio.play_sfx("power_up" if sec_on else "power_down")
	ui.show_message("LIGHTS ON" if sec_on else "LIGHTS OFF", 1.6)


# ---------------------------------------------------------------
# PLAYER / MENU CAM
# ---------------------------------------------------------------

func _spawn_player() -> void:
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(-18, 0, 2)
	player.get_node("Head/Camera3D").current = false
	add_child(player)


func _setup_menu_cam() -> void:
	menu_cam = Camera3D.new()
	menu_cam.name = "MenuCam"
	menu_cam.position = Vector3(-4, 20, 24)
	menu_cam.fov = 60.0
	menu_cam.current = true
	add_child(menu_cam)
	menu_cam.look_at(Vector3(-4, 0, -1), Vector3.UP)
	# Soft overview light so the main menu shows the whole facility.
	menu_light = OmniLight3D.new()
	menu_light.position = Vector3(-4, 8, -1)
	menu_light.light_color = Color(0.75, 0.9, 0.95)
	menu_light.light_energy = 3.2
	menu_light.omni_range = 40.0
	menu_light.omni_attenuation = 0.4
	menu_light.shadow_enabled = false
	add_child(menu_light)


func start_game() -> void:
	if started:
		return
	started = true
	ui.hide_main_menu()
	if menu_light:
		menu_light.visible = false
	menu_cam.current = false
	player.cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.show_message("FIND A WAY OUT", 3.0)


func is_playing() -> bool:
	return started


func ui_blocking() -> bool:
	return (ui != null and ui.is_blocking()) or (snake != null and snake.is_open())


func pause_for_panel() -> void:
	panel_count += 1
	if panel_count == 1:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_from_panel() -> void:
	panel_count = max(0, panel_count - 1)
	if panel_count == 0:
		get_tree().paused = false
		if started:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_pause_or_close() -> void:
	if snake != null and snake.is_open():
		snake.close_quiet()
		return
	if ui and (ui.inventory_panel.visible or ui.doc_panel.visible):
		ui.hide_all_panels()
		return
	if ui and ui.settings_panel.visible:
		ui.hide_settings()
		return
	if ui and ui.pause_menu.visible:
		ui.hide_pause()
		if is_playing():
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not started:
		return
	var paused = not get_tree().paused
	get_tree().paused = paused
	if paused:
		ui.show_pause()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		ui.hide_pause()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_inventory() -> void:
	if not is_playing():
		return
	if ui.inventory_panel.visible:
		ui.hide_all_panels()
		return
	ui.hide_all_panels()
	ui.show_inventory()


# ---------------------------------------------------------------
# ITEMS / INVENTORY
# ---------------------------------------------------------------

func has_item(item_id: String) -> bool:
	return item_id in inventory


func add_item(item_id: String) -> bool:
	if inventory.size() >= ITEM_CAP:
		ui.show_message("INVENTORY FULL", 2.0)
		return false
	if item_id == "battery" and has_item("battery"):
		ui.show_message("ALREADY CARRYING A BATTERY", 2.0)
		return false
	inventory.append(item_id)
	held_index = inventory.size() - 1
	if ui.inventory_panel.visible:
		ui.refresh_inventory()
	if player:
		player.update_held_view()
	return true


func remove_item(item_id: String) -> bool:
	for i in inventory.size():
		if inventory[i] == item_id:
			inventory.remove_at(i)
			if held_index >= inventory.size():
				held_index = inventory.size() - 1
			if ui.inventory_panel.visible:
				ui.refresh_inventory()
			if player:
				player.update_held_view()
			return true
	return false


func try_pickup(data: Dictionary) -> void:
	var item_id: String = data.get("item_id", "")
	var node = data.get("node")
	if not ITEMS.has(item_id):
		return
	if not add_item(item_id):
		return
	if item_id == "flashlight":
		player.set_flashlight_owned(true)
		player.set_battery(100.0)
		if blackout_timer <= 0.0:
			blackout_timer = randf_range(50.0, 95.0)
	if node != null and dropped_nodes.has(node):
		dropped_nodes.erase(node)
		node.queue_free()
	else:
		var pick_id: String = data.get("pick_id", "")
		if pick_id != "":
			collected[pick_id] = true
		for rec in world_items:
			if rec["pick_id"] == pick_id:
				rec["node"].visible = false
				rec["col"].disabled = true
				break
	if audio:
		audio.play_sfx("pickup")


var dropped_nodes: Array = []


func inventory_select(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	held_index = i
	ui.refresh_inventory()
	if player:
		player.update_held_view()


func inventory_drop(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	var item_id: String = inventory[i]
	inventory.remove_at(i)
	if held_index >= inventory.size():
		held_index = inventory.size() - 1
	if item_id == "flashlight":
		player.set_flashlight_owned(false)
	_spawn_dropped(item_id)
	if audio:
		audio.play_sfx("drop")
	ui.refresh_inventory()
	if player:
		player.update_held_view()


func inventory_replace_battery() -> void:
	var sel = ui.selected_inv
	if sel < 0 or sel >= inventory.size():
		ui.show_message("SELECT A BATTERY", 2.0)
		return
	if inventory[sel] != "battery":
		ui.show_message("NOT A BATTERY", 2.0)
		return
	if not player.has_flashlight:
		ui.show_message("NO FLASHLIGHT", 2.0)
		return
	inventory.remove_at(sel)
	if held_index >= inventory.size():
		held_index = inventory.size() - 1
	player.set_battery(100.0)
	if audio:
		audio.play_sfx("keycard")
	ui.show_message("BATTERY REPLACED", 2.0)
	ui.refresh_inventory()
	if player:
		player.update_held_view()


func _spawn_dropped(item_id: String) -> void:
	pick_counter += 1
	var body = RigidBody3D.new()
	body.position = player.global_position + (-player.global_transform.basis.z) * 0.9 + Vector3(0, 0.6, 0)
	body.rotation.y = randf() * TAU
	body.set_meta("interact", {"type": "pickup", "item_id": item_id, "pick_id": "drop_%d" % pick_counter,
		"prompt": "PICK UP " + str(ITEMS[item_id]["name"]), "dropped": true})
	var col = CollisionShape3D.new()
	var sph = SphereShape3D.new(); sph.radius = 0.45
	col.shape = sph; col.name = "Col"
	body.add_child(col)
	var holder = Node3D.new()
	holder.add_child(_item_mesh(item_id))
	body.add_child(holder)
	add_child(body)
	dropped_nodes.append(body)


# ---------------------------------------------------------------
# INTERACTION
# ---------------------------------------------------------------

func get_prompt(data: Dictionary) -> String:
	var t: String = data.get("type", "")
	match t:
		"pickup":
			return "[E] PICK UP " + str(ITEMS.get(data.get("item_id", ""), {}).get("name", "ITEM"))
		"door":
			var rec: Dictionary = doors.get(data.get("id", ""), {})
			if rec.get("open", false):
				return ""
			var req: Dictionary = rec.get("req", {})
			if req.size() == 0:
				return "[E] OPEN"
			return "[E] LOCKED — " + _req_text(req)
		"switch": return "[E] LIGHT SWITCH"
		"arcade": return "[E] PLAY"
		"computer": return "[E] USE " + str(data.get("prompt", "TERMINAL"))
		"power_button": return "[E] POWER BUTTON"
		_: return "[E] " + str(data.get("prompt", "INTERACT"))


func _req_text(req: Dictionary) -> String:
	if req.has("key"): return "NEEDS " + str(ITEMS[req["key"]]["name"])
	if req.has("cell"): return "NEEDS POWER CELL"
	return "LOCKED"


func interact(data: Dictionary) -> void:
	if not is_playing() or ui_blocking():
		return
	var t: String = data.get("type", "")
	match t:
		"pickup": try_pickup(data)
		"door": try_door(str(data.get("id", "")))
		"switch": _toggle_security_lights()
		"power_button": _power_button()
		"arcade": open_snake()
		"computer": open_computer(str(data.get("id", "")))


func _req_ok(req: Dictionary) -> bool:
	if req.has("key") and not has_item(req["key"]): return false
	if req.has("cell") and not has_item(req["cell"]): return false
	return true


func try_door(id: String) -> void:
	var rec: Dictionary = doors.get(id, {})
	if rec.is_empty() or rec.get("open", false):
		return
	var req: Dictionary = rec.get("req", {})
	if req.size() > 0 and not _req_ok(req):
		if audio: audio.play_sfx("door_locked")
		ui.show_message("LOCKED — " + _req_text(req), 2.5)
		return
	if req.has("cell"):
		remove_item(req["cell"])
	if req.has("key"):
		remove_item(req["key"])
		rec["open"] = true
		_set_door_open(rec)
		if audio: audio.play_sfx("door_open")
		ui.show_message(str(ITEMS[req["key"]]["name"]) + " USED", 1.5)
		return
	rec["open"] = true
	_set_door_open(rec)
	if audio: audio.play_sfx("door_open")


func _set_door_open(rec: Dictionary) -> void:
	var col: CollisionShape3D = rec["col"]
	col.disabled = true
	col.set_deferred("disabled", true)
	var dbody: StaticBody3D = rec["node"]
	dbody.collision_layer = 0
	dbody.collision_mask = 0
	var mesh: MeshInstance3D = rec["mesh"]
	var tw = create_tween()
	tw.tween_property(mesh, "position:y", mesh.position.y - 2.6, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): mesh.visible = false)


func open_computer(cid: String) -> void:
	if cid == "sec_pc":
		ui.show_document("SECURITY TERMINAL",
			"CAMERA NETWORK: OFFLINE\nDOOR LOG: SEALED\n\nA note is pinned to the monitor:\n\n'The thing in the sub-basement still walks the halls at night. Do not answer the arcade machine after dark.'")
		if audio: audio.play_sfx("document")
	elif cid == "desk":
		ui.show_document("MONITOR",
			"NO SIGNAL\n\nThe screen flickers once, then goes dark.\nNothing useful here — just an old terminal.")
		if audio: audio.play_sfx("document")


func open_snake() -> void:
	if snake:
		snake.open()


func on_snake_back() -> void:
	if ui:
		ui.play_jumpscare()


func on_snake_quit() -> void:
	pass


# ---------------------------------------------------------------
# PROCESS
# ---------------------------------------------------------------

func _process(delta: float) -> void:
	if started and not get_tree().paused:
		total_time += delta
	if stopwatch_label:
		stopwatch_label.text = format_time(total_time)
	# Random blackouts once the player has the flashlight.
	if started and not get_tree().paused and not ui_blocking() \
			and player.has_flashlight and not lights_out:
		blackout_timer -= delta
		if blackout_timer <= 0.0:
			_trigger_blackout()
	# Prompt
	if player and ui:
		ui.update_prompt(player.prompt_text if is_playing() and not ui_blocking() else "")


func format_time(sec: float) -> String:
	sec = max(0.0, sec)
	var h = int(sec / 3600.0)
	var m = int((sec - h * 3600.0) / 60.0)
	var s = int(sec - h * 3600.0 - m * 60.0)
	return "%02d:%02d:%02d" % [h, m, s]


func _save_time() -> void:
	var c = ConfigFile.new()
	c.set_value("time", "total", total_time)
	c.save(SAVE_TIME)


func _load_time() -> void:
	if FileAccess.file_exists(SAVE_TIME):
		var c = ConfigFile.new()
		if c.load(SAVE_TIME) == OK:
			total_time = c.get_value("time", "total", 0.0)


func set_sensitivity(v: float) -> void:
	mouse_sensitivity = v


func apply_quality() -> void:
	for l in lights:
		if l is OmniLight3D:
			l.omni_range = 7.0 if reduce_lights else 11.0
