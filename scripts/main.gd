extends Node3D

const SAVE_TIME = "user://nb_time.cfg"
const SAVE_SNAP = "user://nb_checkpoint.json"
const ITEM_CAP = 3
const BATTERY_ID = "battery"
const FLASHLIGHT_ID = "flashlight"
const FINAL_KEY_ID = "final_key"

var mats = {}
var facility: Node3D = null
var player: CharacterBody3D = null
var monster: CharacterBody3D = null
var audio: Node = null
var ui: CanvasLayer = null
var puzzle_ui: CanvasLayer = null

var doors = {}
var lights = []
var world_items = []
var dropped_nodes: Array = []
var puzzles = {}
var computers = {}
var documents = {}
var checkpoints = {}
var elevators_data = {}
var collected = {}
var inventory: Array = []
var held_index = -1
var pick_counter = 0

var started = false
var dead = false
var won = false
var power_on = true
var outage_timer = 420.0
var checkpoint_active = ""
var chase_active = false
var final_key_taken = false
var panel_count = 0
var total_time = 0.0
var final_time = 0.0
var mouse_sensitivity = 0.0021
var master_volume = -6.0
var reduce_lights = false
var stopwatch_label: Label3D = null
var initial_snapshot = {}
var checkpoint_snapshot = {}
var door_locks_done = false

const ITEMS = {
	"flashlight": {"name": "FLASHLIGHT", "type": "flashlight", "desc": "A heavy tactical flashlight. Press F to toggle. Battery drains only while ON."},
	"battery": {"name": "BATTERY", "type": "battery", "desc": "Spare battery for the flashlight. Only one spare can be carried."},
	"power_cell": {"name": "POWER CELL", "type": "powercell", "desc": "A charged power cell used by doors and machinery."},
	"key_storage": {"name": "STORAGE KEY", "type": "key", "desc": "Heavy iron key. Opens storage rooms."},
	"key_lab": {"name": "LAB KEY", "type": "key", "desc": "Brass laboratory key."},
	"key_medical": {"name": "MEDICAL KEY", "type": "key", "desc": "White medical key."},
	"key_office": {"name": "OFFICE KEY", "type": "key", "desc": "Office key with a faded tag."},
	"key_maintenance": {"name": "MAINTENANCE KEY", "type": "key", "desc": "Orange maintenance key."},
	"key_security": {"name": "SECURITY KEY", "type": "key", "desc": "Security office key."},
	"keycard_l1": {"name": "SECURITY CARD L1", "type": "keycard", "desc": "Low-level security clearance."},
	"keycard_l2": {"name": "SECURITY CARD L2", "type": "keycard", "desc": "Mid-level security clearance."},
	"keycard_l3": {"name": "SECURITY CARD L3", "type": "keycard", "desc": "High-level security clearance."},
	"keycard_maint": {"name": "MAINTENANCE CARD", "type": "keycard", "desc": "Maintenance clearance card."},
	"crowbar": {"name": "CROWBAR", "type": "tool", "desc": "Pry open panels and emergency seals."},
	FINAL_KEY_ID: {"name": "BLACK KEY", "type": "finalkey", "desc": "A cold black key, heavier than it should be."},
}


func _ready() -> void:
	_load_time()
	_make_materials()
	_build_environment()
	facility = Node3D.new()
	facility.name = "Facility"
	facility.set_script(load("res://scripts/facility.gd"))
	add_child(facility)
	facility.build(self)
	_setup_content()
	_apply_door_locks()
	_load_snapshot()
	_spawn_player()
	monster = CharacterBody3D.new()
	monster.name = "Monster"
	monster.set_script(load("res://scripts/monster.gd"))
	add_child(monster)
	audio = Node.new()
	audio.name = "Audio"
	audio.set_script(load("res://scripts/audio.gd"))
	add_child(audio)
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.set_script(load("res://scripts/ui.gd"))
	add_child(ui)
	puzzle_ui = CanvasLayer.new()
	puzzle_ui.name = "PuzzleUI"
	puzzle_ui.set_script(load("res://scripts/puzzle_ui.gd"))
	add_child(puzzle_ui)
	ui.show_main_menu()


func _exit_tree() -> void:
	_save_time()


# ---------------------------------------------------------------
# MATERIALS / ENVIRONMENT
# ---------------------------------------------------------------

func _tex_noise(base: Color, vary: float, size = 128) -> ImageTexture:
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var n = randf_range(-vary, vary)
			var c = Color(clampf(base.r + n, 0, 1), clampf(base.g + n, 0, 1), clampf(base.b + n, 0, 1))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _mat(color: Color, rough = 0.9, metal = 0.0, emission = Color(0, 0, 0),
		ee = 0.0, tex: Texture2D = null, tex_scale = 6.0) -> StandardMaterial3D:
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
	var grate_tex = _tex_noise(Color(0.25, 0.26, 0.28), 0.06)
	var paint_tex = _tex_noise(Color(0.45, 0.5, 0.52), 0.05)
	mats["concrete"] = _mat(Color(1, 1, 1), 0.95, 0.0, Color(0, 0, 0), 0, concrete_tex)
	mats["concrete_dark"] = _mat(Color(0.55, 0.55, 0.58), 0.95, 0.0, Color(0, 0, 0), 0, concrete_tex)
	mats["metal"] = _mat(Color(1, 1, 1), 0.45, 0.85, Color(0, 0, 0), 0, metal_tex)
	mats["metal_dark"] = _mat(Color(0.5, 0.52, 0.55), 0.5, 0.9, Color(0, 0, 0), 0, metal_tex)
	mats["tile"] = _mat(Color(1, 1, 1), 0.6, 0.1, Color(0, 0, 0), 0, tile_tex)
	mats["grate"] = _mat(Color(0.8, 0.8, 0.82), 0.55, 0.7, Color(0, 0, 0), 0, grate_tex)
	mats["wall_paint"] = _mat(Color(1, 1, 1), 0.8, 0.0, Color(0, 0, 0), 0, paint_tex)
	mats["wood"] = _mat(Color(0.35, 0.22, 0.12), 0.8)
	mats["chair"] = _mat(Color(0.15, 0.15, 0.16), 0.7, 0.3)
	mats["machine"] = _mat(Color(0.55, 0.58, 0.6), 0.4, 0.9)
	mats["machine_dark"] = _mat(Color(0.2, 0.22, 0.24), 0.5, 0.85)
	mats["crate"] = _mat(Color(0.45, 0.32, 0.18), 0.9)
	mats["medical"] = _mat(Color(0.8, 0.85, 0.85), 0.5)
	mats["sheet"] = _mat(Color(0.85, 0.85, 0.8), 0.95)
	mats["plant"] = _mat(Color(0.1, 0.3, 0.12), 0.9)
	mats["debris"] = _mat(Color(0.2, 0.2, 0.2), 1.0)
	mats["pipe"] = _mat(Color(0.5, 0.45, 0.3), 0.5, 0.8)
	mats["elevator"] = _mat(Color(0.6, 0.62, 0.65), 0.35, 0.95)
	mats["door"] = _mat(Color(0.3, 0.34, 0.36), 0.5, 0.8)
	mats["wall_panel"] = _mat(Color(0.34, 0.35, 0.36), 0.85, 0.1)
	mats["hazard"] = _mat(Color(0.7, 0.55, 0.05), 0.6, 0.2, Color(1, 0.6, 0), 0.6)
	mats["screen"] = _mat(Color(0.02, 0.05, 0.04), 0.3, 0.2, Color(0.2, 0.9, 0.5), 1.2)
	mats["paper"] = _mat(Color(0.85, 0.82, 0.7), 0.95)
	mats["key_gold"] = _mat(Color(0.8, 0.6, 0.15), 0.35, 0.9, Color(0, 0, 0), 0)
	mats["key_steel"] = _mat(Color(0.6, 0.62, 0.65), 0.35, 0.9)
	mats["card"] = _mat(Color(0.1, 0.15, 0.2), 0.4, 0.6, Color(0.2, 0.8, 1.0), 0.8)
	mats["cell_blue"] = _mat(Color(0.05, 0.15, 0.4), 0.3, 0.4, Color(0.2, 0.5, 1.0), 1.5)
	mats["battery_green"] = _mat(Color(0.1, 0.4, 0.15), 0.4, 0.5, Color(0.3, 1.0, 0.4), 1.0)
	mats["tool_dark"] = _mat(Color(0.15, 0.15, 0.16), 0.5, 0.85)
	mats["final_black"] = _mat(Color(0.02, 0.02, 0.025), 0.25, 0.6, Color(0.8, 0.05, 0.1), 1.2)
	mats["flag_red"] = _mat(Color(0.7, 0.05, 0.05), 0.7)
	mats["flag_green"] = _mat(Color(0.05, 0.6, 0.15), 0.7)
	mats["skin"] = _mat(Color(0.8, 0.7, 0.6), 0.9)


func _build_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.07, 0.09)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.03, 0.04)
	env.fog_density = 0.010
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------------------------------------------------------------
# CONTENT SETUP
# ---------------------------------------------------------------

func room_pos(fi: int, c: int, r: int, dx = 0.0, dz = 0.0, dy = 0.9) -> Vector3:
	# Find nearest room-like slot if target is not one.
	var best = Vector3.ZERO
	var bd = 1e9
	for k in facility.infos:
		var inf: Dictionary = facility.infos[k]
		if inf["fi"] != fi:
			continue
		var typ: String = inf["type"]
		if typ not in ["room", "secret", "start", "elevator"]:
			continue
		var d = Vector2(inf["c"] - c, inf["r"] - r).length()
		if d < bd:
			bd = d
			best = facility.slot_center_world(fi, inf["c"], inf["r"], dy)
	if bd > 2.5:
		# fallback: use requested slot center anyway
		return facility.slot_center_world(fi, c, r, dy) + Vector3(dx, 0, dz)
	return best + Vector3(dx, 0, dz)


func corridor_pos(fi: int, i: int, j: int, dy = 0.9) -> Vector3:
	return Vector3(facility.cell_x(i), facility.floor_y(fi) + dy, facility.cell_z(j))


func _setup_content() -> void:
	_place_items()
	_place_puzzles()
	_place_documents()
	_place_computers()
	_place_checkpoints()
	_place_elevators()
	_place_breaker_hatch_map_watch()


func _prop_box(pos: Vector3, size: Vector3, mat: Material, interact = {}, collide = true) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	if interact.size() > 0:
		body.set_meta("interact", interact)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.name = "Col"
	body.add_child(col)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.name = "Mesh"
	body.add_child(mi)
	add_child(body)
	return body


func _item_mesh(item_id: String) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	match ITEMS[item_id]["type"]:
		"key", "finalkey":
			var bm = BoxMesh.new(); bm.size = Vector3(0.28, 0.04, 0.1); mi.mesh = bm
			mi.material_override = mats["final_black"] if item_id == FINAL_KEY_ID else mats["key_gold"]
		"keycard":
			var bm = BoxMesh.new(); bm.size = Vector3(0.55, 0.03, 0.34); mi.mesh = bm
			mi.material_override = mats["card"]
		"battery":
			var cm = CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.07; cm.height = 0.22; mi.mesh = cm
			mi.material_override = mats["battery_green"]
		"powercell":
			var cm = CylinderMesh.new(); cm.top_radius = 0.11; cm.bottom_radius = 0.11; cm.height = 0.3; mi.mesh = cm
			mi.material_override = mats["cell_blue"]
		"tool":
			var bm = BoxMesh.new(); bm.size = Vector3(0.08, 0.5, 0.08); mi.mesh = bm
			mi.material_override = mats["tool_dark"]
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
	var sph = SphereShape3D.new()
	sph.radius = 0.55
	col.shape = sph
	col.name = "Col"
	body.add_child(col)
	var holder = Node3D.new()
	holder.name = "ItemMesh"
	var mi = _item_mesh(item_id)
	holder.add_child(mi)
	# gentle glow for visibility
	var glow = OmniLight3D.new()
	glow.light_energy = 0.4
	glow.omni_range = 2.0
	glow.light_color = Color(0.6, 0.8, 1.0)
	holder.add_child(glow)
	body.add_child(holder)
	add_child(body)
	world_items.append({"pick_id": pick_id, "item_id": item_id, "node": body, "col": col})


func _place_items() -> void:
	var places = [
		["flashlight", 1, 0, 1], ["crowbar", 2, 0, 2],
		["battery", 2, 4, 0], ["battery", 1, 3, 2], ["battery", 0, 2, 1],
		["power_cell", 1, 2, 2], ["power_cell", 0, 1, 2], ["power_cell", 3, 3, 1], ["power_cell", 1, 4, 1],
		["key_storage", 1, 4, 3], ["key_lab", 3, 0, 2], ["key_medical", 3, 3, 2],
		["key_office", 2, 2, 0], ["key_maintenance", 1, 1, 0], ["key_security", 2, 1, 2],
		["keycard_l1", 2, 3, 1], ["keycard_l2", 0, 4, 3], ["keycard_l3", 3, 2, 1],
		["keycard_maint", 1, 0, 0],
	]
	for p in places:
		var pos = room_pos(int(p[1]), int(p[2]), int(p[3]))
		_world_item(p[0], pos)
	# Final key in sublevel secret (0,0).
	_world_item(FINAL_KEY_ID, room_pos(0, 0, 0))


func _puzzle_console(pid: String, pos: Vector3) -> void:
	var p: Dictionary = puzzles[pid]
	var body = _prop_box(pos + Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.6), mats["machine_dark"],
		{"type": "puzzle", "id": pid, "prompt": "USE CONSOLE"})
	var screen = MeshInstance3D.new()
	var sm = BoxMesh.new(); sm.size = Vector3(0.7, 0.5, 0.05)
	screen.mesh = sm; screen.material_override = mats["screen"]
	screen.position = Vector3(0, 0.3, 0.32)
	body.add_child(screen)
	p["node"] = body


func _place_puzzles() -> void:
	# type, solution, fi,c,r, extra
	var defs = [
		["p_keypad1", "keypad", "4821", 2, 2, 0, {}],
		["p_safe1", "safe", [12, 34, 56], 3, 1, 1, {}],
		["p_pattern1", "pattern", [0, 2, 4, 1], 1, 3, 1, {}],
		["p_circuit1", "circuit", [true, false, true, false, true, false], 0, 1, 1, {}],
		["p_gears1", "gears", [3, 6, 1], 3, 0, 0, {}],
		["p_freq1", "frequency", 97.3, 2, 4, 2, {}],
		["p_valves1", "valves", [4, 7, 2], 1, 2, 3, {}],
		["p_weights1", "weights", 17, 0, 3, 1, {}],
		["p_order1", "order", [2, 0, 3, 1], 3, 4, 0, {"names": ["RED", "BLUE", "GREEN", "WHITE"]}],
		["p_logic1", "logic", false, 2, 1, 0, {"lines": ["IF A AND NOT B THEN OUT=TRUE", "A=TRUE B=FALSE", "EVALUATE OUTPUT"]}],
		["p_memory1", "memory", 4, 1, 0, 2, {}],
		["p_pipes1", "pipes", [2, 1, 3, 0], 0, 2, 2, {}],
		["p_magnetic1", "magnetic", [1, -1, 1], 3, 3, 3, {}],
		["p_object1", "object_place", {0: 2, 1: 0, 2: 3, 3: 1}, 2, 3, 3,
			{"item_names": ["CUBE", "SPHERE", "CONE", "RING"], "slot_names": ["A", "B", "C", "D"]}],
		["p_keypad2", "keypad", "7306", 1, 4, 2, {}],
		["p_freq2", "frequency", 101.7, 0, 0, 2, {}],
		["p_order2", "order", [1, 3, 0, 2], 3, 1, 3, {"names": ["ALPHA", "BETA", "GAMMA", "DELTA"]}],
	]
	for d in defs:
		var pid: String = d[0]
		var extra: Dictionary = d[6]
		puzzles[pid] = {"id": pid, "type": d[1], "solution": d[2], "solved": false,
			"state": {}, "node": null}
		for k in extra:
			puzzles[pid][k] = extra[k]
		var pos = room_pos(int(d[3]), int(d[4]), int(d[5]))
		_puzzle_console(pid, pos)
		# Clue document for externally-solved types.
		if d[1] in ["keypad", "safe", "frequency", "valves", "order", "logic", "weights", "magnetic", "object_place"]:
			var doc_pos = pos + Vector3(1.8, 0, 1.8)
			var clue = _clue_text(pid)
			_document(pid + "_clue", doc_pos, "NOTE", clue)
	# Gated secret rooms: puzzle consoles in adjacent corridor.
	_gated_secret(1, 2, 0, "p_gate1", "pipes", [0, 2, 3, 1])
	_gated_secret(0, 4, 3, "p_gate2", "circuit", [false, true, false, true, false, true])


func _corridor_cell_near_room(fi: int, c: int, r: int) -> Vector2i:
	var rg = facility.slot_cell_range(c, r)
	var mi = int((rg.x + rg.y) / 2)
	var mj = int((rg.z + rg.w) / 2)
	# prefer west corridor cell
	return Vector2i(rg.x - 1, mj)


func _gated_secret(fi: int, c: int, r: int, pid: String, ptype: String, sol) -> void:
	# Find hidden door for this room and require puzzle.
	var key = facility.slot_key(fi, c, r)
	for did in doors:
		var rec: Dictionary = doors[did]
		if rec["fi"] == fi and rec["c"] == c and rec["r"] == r and rec["hidden"]:
			rec["req"] = {"puzzle": pid}
	puzzles[pid] = {"id": pid, "type": ptype, "solution": sol, "solved": false,
		"state": {}, "node": null}
	var cell = _corridor_cell_near_room(fi, c, r)
	var pos = corridor_pos(fi, cell.x, cell.y)
	_puzzle_console(pid, pos)
	_document(pid + "_clue", pos + Vector3(1.5, 0, 1.5), "MAINTENANCE ORDER",
		"Realign the mechanism. The order is etched on the panel.\n\nSequence: " + str(sol))


func _clue_text(pid: String) -> String:
	var p: Dictionary = puzzles.get(pid, {})
	var t: String = p.get("type", "")
	var s = p.get("solution")
	match t:
		"keypad": return "Access code found scrawled on a dead terminal:\n\nCODE: %s" % str(s)
		"safe": return "Combination written inside a maintenance manual:\n\nDIALS: %s" % str(s)
		"frequency": return "Frequency allocation slip:\n\nTUNE TO %.1f MHz" % float(s)
		"valves": return "Pressure order on a chalkboard:\n\nVALVES (L->R): %s" % str(s)
		"order": return "Activation sequence listed on a duty roster:\n\nORDER: %s" % \
			" -> ".join(p.get("names", [])) if p.has("names") else "ORDER: %s" % str(s)
		"logic": return "Logic gate truth table:\n\n%s\n\nOUTPUT = %s" % ["\n".join(p.get("lines", [])), str(s)]
		"weights": return "Balance requirement on a scale diagram:\n\nTARGET TOTAL: %d" % int(s)
		"magnetic": return "Polarity chart (N=1, S=-1):\n\nMAGNETS: %s" % str(s)
		"object_place":
			var names: Array = p.get("item_names", [])
			var slots: Array = p.get("slot_names", [])
			var parts = []
			for k in (s as Dictionary).keys():
				parts.append("%s -> %s" % [str(slots[int(k)]), str(names[int((s as Dictionary)[k])])])
			return "Placement diagram:\n\n" + "\n".join(parts)
		_: return "A faint annotation."


func _document(did: String, pos: Vector3, title: String, body: String) -> void:
	documents[did] = {"title": title, "body": body}
	var body_mesh = _prop_box(pos + Vector3(0, 0.75, 0), Vector3(0.45, 0.02, 0.6), mats["paper"],
		{"type": "document", "id": did, "prompt": "READ DOCUMENT"}, false)
	body_mesh.rotation.y = randf() * TAU


func _place_documents() -> void:
	# Lore / clue documents scattered.
	var docs = [
		["doc_intro", 2, 0, 0, "MEMO", "You woke on cold concrete. The facility is dead.\nFind a way out. The map is on the wall."],
		["doc_power", 1, 2, 2, "BREAKER LOG", "Main breaker feeds the east wing. During outages, corridor lights fail. Emergency strips stay red."],
		["doc_elev", 3, 2, 1, "ELEVATOR NOTICE", "Lift B requires L2 clearance and a functional relay. Lift A needs grid power."],
		["doc_secret", 0, 4, 3, "SEALED ORDER", "Sublevel archive seal broken from inside. Do not enter without clearance."],
		["doc_final", 0, 0, 0, "WARNING", "Do not touch the black key. It is not ours."],
	]
	for d in docs:
		_document(d[0], room_pos(int(d[1]), int(d[2]), int(d[3])) + Vector3(1.2, 0, -1.2), d[4], d[5])


func _computer(cid: String, pos: Vector3, title: String, lines: Array, actions = []) -> void:
	computers[cid] = {"title": title, "lines": lines, "actions": actions}
	var body = _prop_box(pos + Vector3(0, 1.0, 0), Vector3(1.2, 1.4, 0.5), mats["machine_dark"],
		{"type": "computer", "id": cid, "prompt": "USE TERMINAL"})
	var screen = MeshInstance3D.new()
	var sm = BoxMesh.new(); sm.size = Vector3(1.0, 0.8, 0.05)
	screen.mesh = sm; screen.material_override = mats["screen"]
	screen.position = Vector3(0, 0.25, 0.28)
	body.add_child(screen)


func _place_computers() -> void:
	_computer("pc_security", room_pos(2, 1, 2), "SECURITY TERMINAL",
		["NIGHTMARE RESEARCH FACILITY", "SECURITY OS v3.1", "", "DOOR STATUS: NOMINAL", "CAMERA NETWORK: OFFLINE", "", "> ACCESS LEVEL REQUIRED"],
		[{"label": "UNLOCK L3 DOORS", "callable": func(): security_unlock()}])
	_computer("pc_power", room_pos(1, 2, 2), "POWER MANAGEMENT",
		["GRID STATUS: %s" % ("ONLINE" if power_on else "OFFLINE"), "", "OUTAGE SCHEDULE: RANDOM", "BREAKER: MANUAL RESET REQUIRED"],
		[{"label": "RESTORE POWER", "callable": func(): restore_power()}])
	_computer("pc_lab", room_pos(3, 0, 2), "LAB TERMINAL",
		["SPECIMEN LOG 4471", "CONTAINMENT: STABLE", "", "DO NOT APPROACH SUBJECT 4471", "IT KNOWS THE DOORS."], [])
	_computer("pc_server", room_pos(3, 2, 1), "SERVER TERMINAL",
		["BACKUP NODE: SEALED", "ENCRYPTION: MIL-SPEC", "", "> CLEARANCE L2 REQUIRED"], [])
	_computer("pc_med", room_pos(3, 3, 2), "MEDICAL TERMINAL",
		["PATIENT RECORDS: SEALED", "MORGUE TEMP: -18C", "", "NO SURVIVORS LOGGED"], [])
	_computer("pc_maint", room_pos(1, 1, 0), "MAINTENANCE TERMINAL",
		["TUNNEL MAP: PARTIAL", "ELEVATOR B RELAY: FAULT", "PWR CELL STOCK: LOW"], [])
	_computer("pc_caf", room_pos(2, 0, 0), "CAFETERIA TERMINAL",
		["LAST MENU: SYNTHETIC SOUP", "STAFF: NONE PRESENT", "ELEVATOR: USE LIFT A"], [])


func _place_checkpoints() -> void:
	var spots = [
		[2, 0, 0], [1, 0, 2], [3, 2, 1], [0, 1, 2], [1, 2, 2],
		[2, 4, 2], [0, 0, 0], [3, 4, 0], [1, 3, 1], [2, 1, 0],
	]
	for i in spots.size():
		var fi: int = spots[i][0]; var c: int = spots[i][1]; var r: int = spots[i][2]
		var pos = room_pos(fi, c, r, 2.0, -2.0)
		var id = "cp_%d" % i
		var pole = StaticBody3D.new()
		pole.position = pos
		pole.set_meta("interact", {"type": "checkpoint", "id": id, "prompt": "ACTIVATE CHECKPOINT"})
		var col = CollisionShape3D.new(); var cyl = CylinderShape3D.new()
		cyl.radius = 0.15; cyl.height = 2.2; col.shape = cyl; col.position.y = 1.1
		pole.add_child(col)
		var pm = MeshInstance3D.new(); var pc = CylinderMesh.new()
		pc.top_radius = 0.06; pc.bottom_radius = 0.08; pc.height = 2.2; pm.mesh = pc
		pm.material_override = mats["metal_dark"]; pm.position.y = 1.1
		pole.add_child(pm)
		var flag = MeshInstance3D.new(); var fb = BoxMesh.new()
		fb.size = Vector3(0.7, 0.45, 0.03); flag.mesh = fb
		var fmat = StandardMaterial3D.new(); fmat.albedo_color = Color(0.7, 0.05, 0.05)
		flag.material_override = fmat; flag.position = Vector3(0.38, 1.9, 0)
		pole.add_child(flag)
		add_child(pole)
		checkpoints[id] = {"id": id, "node": pole, "flag": flag, "mat": fmat,
			"fi": fi, "c": c, "r": r, "pos": pos}


func _place_elevators() -> void:
	for e in facility.elevators:
		var c: int = e["c"]; var r: int = e["r"]
		var eid = "elev_%d_%d" % [c, r]
		var floors_list = []
		for fi in 4:
			var pos = facility.slot_center_world(fi, c, r, 0.9)
			floors_list.append({"index": fi, "name": facility.floor_tag(fi), "pos": pos})
		elevators_data[eid] = {"id": eid, "floors": floors_list,
			"req": {"power": true} if eid == "elev_2_1" else {"keycard": "keycard_l2", "puzzle": "elev_repair"}}
		# panel on each floor
		for fi in 4:
			var pos = facility.slot_center_world(fi, c, r, 1.2) + Vector3(0, 0, -4.5)
			_prop_box(pos, Vector3(0.5, 0.8, 0.15), mats["elevator"],
				{"type": "elevator", "id": eid, "prompt": "ELEVATOR"})
	# Elevator repair puzzle in basement near lift B (4,2).
	puzzles["elev_repair"] = {"id": "elev_repair", "type": "pipes", "solution": [1, 3, 0, 2],
		"solved": false, "state": {}, "node": null}
	var pos = corridor_pos(1, facility.slot_cell_range(4, 2).x - 1, int((facility.slot_cell_range(4, 2).z + facility.slot_cell_range(4, 2).w) / 2))
	_puzzle_console("elev_repair", pos)


func _place_breaker_hatch_map_watch() -> void:
	# Breaker in power room (fi1 c2 r2).
	var bpos = room_pos(1, 2, 2, 0, -3.5)
	_prop_box(bpos + Vector3(0, 1.2, 0), Vector3(1.2, 1.6, 0.4), mats["machine_dark"],
		{"type": "breaker", "id": "main", "prompt": "BREAKER PANEL"})
	# Hatch + ladder in start room (fi2 c0 r0) north wall.
	var srect = facility.slot_rect_world(2, 0, 0)
	var hx = srect.position.x + srect.size.x / 2
	var hz = srect.position.y + 0.4
	var fy = facility.floor_y(2)
	# ladder
	for sx in [-0.4, 0.4]:
		_prop_box(Vector3(hx + sx, fy + 1.8, hz), Vector3(0.08, 3.6, 0.08), mats["metal"], {}, false)
	for i in 6:
		_prop_box(Vector3(hx, fy + 0.6 + i * 0.55, hz), Vector3(0.9, 0.06, 0.06), mats["metal"], {}, false)
	# hatch
	_prop_box(Vector3(hx, fy + 3.4, hz), Vector3(1.6, 1.8, 0.3), mats["hazard"],
		{"type": "hatch", "id": "escape", "prompt": "ESCAPE HATCH"})
	# map board on west wall of start room
	var mx = srect.position.x + 0.5
	var mz = srect.position.y + srect.size.y / 2
	_map_board(Vector3(mx, fy + 1.9, mz), -PI / 2)
	# stopwatch on a crate
	var wpos = room_pos(2, 0, 0, -2.5, 2.0)
	_prop_box(wpos, Vector3(0.6, 0.9, 0.6), mats["crate"], {})
	_stopwatch(wpos + Vector3(0, 0.55, 0))


func _map_board(pos: Vector3, rot_y: float) -> void:
	var img = Image.create(1024, 768, false, Image.FORMAT_RGB8)
	img.fill(Color(0.03, 0.05, 0.04))
	# Draw floors.
	var panel_w = 470.0
	var panel_h = 330.0
	var labels = ["SUBLEVEL", "BASEMENT", "GROUND", "UPPER"]
	for fi in 4:
		var px = 20.0 + (fi % 2) * 500.0
		var py = 30.0 + (fi / 2) * 370.0
		img.fill_rect(Rect2i(int(px), int(py), int(panel_w), int(panel_h)), Color(0.05, 0.08, 0.07))
		# scale world to panel
		var sx = panel_w / (facility.total_cells_x * facility.CELL)
		var sz = panel_h / (facility.total_cells_z * facility.CELL)
		for k in facility.infos:
			var inf: Dictionary = facility.infos[k]
			if inf["fi"] != fi:
				continue
			var rect = facility.slot_rect_world(fi, inf["c"], inf["r"])
			var x = px + (rect.position.x + 38.0) * sx
			var y = py + (rect.position.y + 30.0) * sz
			var w = rect.size.x * sx
			var h = rect.size.y * sz
			var col = Color(0.2, 0.3, 0.25)
			match inf["type"]:
				"secret": col = Color(0.5, 0.2, 0.6)
				"elevator": col = Color(0.9, 0.7, 0.2)
				"stair": col = Color(0.2, 0.7, 0.8)
				"open": col = Color(0.15, 0.2, 0.18)
				"start": col = Color(0.2, 0.8, 0.4)
			img.fill_rect(Rect2i(int(x), int(y), int(w), int(h)), col)
		# corridors
		for c in range(facility.COLS - 1):
			for r in range(facility.ROWS - 1):
				var i = c * (facility.SLOT_W + facility.GAP) + facility.SLOT_W
				var j = r * (facility.SLOT_H + facility.GAP) + facility.SLOT_H
				var wx = facility.cell_x(i)
				var wz = facility.cell_z(j)
				img.fill_rect(Rect2i(int(px + (wx + 38) * sx), int(py + (wz + 30) * sz), 4, 4), Color(0.4, 0.4, 0.4))
		# label
		var font = ThemeDB.fallback_font
		# draw label via filled rect text not available; use draw_string? Image has no text. Use simple bar.
		img.fill_rect(Rect2i(int(px), int(py + panel_h + 4), 120, 18), Color(0.1, 0.15, 0.12))
	var tex = ImageTexture.create_from_image(img)
	var pm = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(5.4, 4.0)
	pm.mesh = plane
	pm.material_override = _mat(Color(1, 1, 1), 0.8, 0.0, Color(0.1, 0.2, 0.15), 0.6, tex, 1.0)
	pm.position = pos
	pm.rotation.y = rot_y
	add_child(pm)


func _stopwatch(pos: Vector3) -> void:
	var body = _prop_box(pos, Vector3(0.5, 0.12, 0.3), mats["metal_dark"], {})
	stopwatch_label = Label3D.new()
	stopwatch_label.text = "00:00:00"
	stopwatch_label.font_size = 64
	stopwatch_label.pixel_size = 0.004
	stopwatch_label.modulate = Color(0.4, 1.0, 0.6)
	stopwatch_label.position = pos + Vector3(0, 0.16, 0)
	stopwatch_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(stopwatch_label)


# ---------------------------------------------------------------
# DOOR LOCKS
# ---------------------------------------------------------------

func _apply_door_locks() -> void:
	if door_locks_done:
		return
	door_locks_done = true
	for id in doors:
		var rec: Dictionary = doors[id]
		if rec.get("req", {}).size() > 0:
			continue
		var theme: String = rec.get("theme", "")
		match theme:
			"storage", "archive": rec["req"] = {"key": "key_storage" if rec["fi"] == 1 else "key_maintenance"}
			"office", "library", "breakroom": rec["req"] = {"key": "key_office"}
			"lab", "coolant": rec["req"] = {"key": "key_lab"}
			"medical": rec["req"] = {"key": "key_medical"}
			"security": rec["req"] = {"keycard": "keycard_l1"}
			"server": rec["req"] = {"keycard": "keycard_l2"}
			"executive": rec["req"] = {"keycard": "keycard_l3"}
			"generator", "power": rec["req"] = {"power": true}
			"maintenance", "workshop": rec["req"] = {"keycard": "keycard_maint"}
			"morgue": rec["req"] = {"key": "key_medical"}
			"final", "secret": rec["req"] = {"key": "key_security"}
		# auto doors for some office/cafeteria rooms
		if theme in ["office", "cafeteria", "breakroom", "library"] and rec["kind"] == "normal":
			rec["auto"] = true
	# Hidden doors need crowbar unless already puzzle-gated.
	for id in doors:
		var rec: Dictionary = doors[id]
		if rec["hidden"] and rec["req"].is_empty():
			rec["req"] = {"tool": "crowbar"}


# ---------------------------------------------------------------
# PLAYER / SPAWN
# ---------------------------------------------------------------

func _spawn_player() -> void:
	player = load("res://scenes/player.tscn").instantiate()
	var start = facility.slot_center_world(2, 0, 0, 0.9)
	player.position = start
	add_child(player)


func start_game() -> void:
	if started:
		return
	started = true
	ui.hide_main_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if checkpoint_snapshot.size() > 0 and checkpoint_active != "":
		_apply_snapshot(checkpoint_snapshot)
	else:
		initial_snapshot = take_snapshot()
		checkpoint_snapshot = initial_snapshot.duplicate(true)
	ui.show_message("FIND A WAY OUT", 3.0)


func is_playing() -> bool:
	return started and not dead and not won


func ui_blocking() -> bool:
	return (ui != null and ui.is_blocking()) or (puzzle_ui != null and puzzle_ui.is_blocking())


func pause_for_panel() -> void:
	panel_count += 1
	if panel_count == 1:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_from_panel() -> void:
	panel_count = max(0, panel_count - 1)
	if panel_count == 0:
		if is_playing():
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			get_tree().paused = false


func toggle_pause_or_close() -> void:
	if puzzle_ui and puzzle_ui.is_blocking():
		puzzle_ui.close()
		return
	if ui and (ui.inventory_panel.visible or ui.doc_panel.visible or ui.term_panel.visible or ui.elev_panel.visible):
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
	if not started or dead or won:
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


func count_item(item_id: String) -> int:
	var n = 0
	for it in inventory:
		if it == item_id:
			n += 1
	return n


func add_item(item_id: String) -> bool:
	if inventory.size() >= ITEM_CAP:
		ui.show_message("INVENTORY FULL", 2.0)
		return false
	if item_id == BATTERY_ID and has_item(BATTERY_ID):
		ui.show_message("ALREADY CARRYING A BATTERY", 2.0)
		return false
	inventory.append(item_id)
	held_index = inventory.size() - 1
	if ui.inventory_panel.visible:
		ui.refresh_inventory()
	return true


func remove_item(item_id: String) -> bool:
	for i in inventory.size():
		if inventory[i] == item_id:
			inventory.remove_at(i)
			if held_index >= inventory.size():
				held_index = inventory.size() - 1
			if ui.inventory_panel.visible:
				ui.refresh_inventory()
			return true
	return false


func try_pickup(data: Dictionary) -> void:
	var item_id: String = data.get("item_id", "")
	var node: Node = data.get("node")
	if not ITEMS.has(item_id):
		return
	# Battery / flashlight uniqueness handled in add_item.
	if not add_item(item_id):
		return
	if item_id == FLASHLIGHT_ID:
		player.set_flashlight_owned(true)
		player.set_battery(100.0)
	# Remove from world.
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
	if item_id == FINAL_KEY_ID and not final_key_taken:
		final_key_taken = true
		_trigger_monster()


func inventory_select(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	held_index = i
	ui.refresh_inventory()


func inventory_drop(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	var item_id: String = inventory[i]
	inventory.remove_at(i)
	if held_index >= inventory.size():
		held_index = inventory.size() - 1
	if item_id == FLASHLIGHT_ID:
		player.set_flashlight_owned(false)
	_spawn_dropped(item_id)
	if audio:
		audio.play_sfx("drop")
	ui.refresh_inventory()


func inventory_replace_battery() -> void:
	var sel = ui.selected_inv
	if sel < 0 or sel >= inventory.size():
		ui.show_message("SELECT A BATTERY", 2.0)
		return
	if inventory[sel] != BATTERY_ID:
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
	var id: String = data.get("id", "")
	match t:
		"pickup":
			return "E — " + str(ITEMS.get(data.get("item_id", ""), {}).get("name", "PICK UP"))
		"door", "secret":
			var rec: Dictionary = doors.get(id, {})
			if rec.get("open", false):
				return ""
			var req: Dictionary = rec.get("req", {})
			if req.size() == 0:
				return "E — " + str(data.get("prompt", "OPEN"))
			return "LOCKED — " + _req_text(req)
		"checkpoint": return "E — ACTIVATE CHECKPOINT"
		"breaker": return "E — BREAKER PANEL" if not power_on else "E — POWER PANEL"
		"hatch": return "E — ESCAPE HATCH"
		"elevator": return "E — ELEVATOR"
		"computer": return "E — USE TERMINAL"
		"document": return "E — READ"
		"puzzle": return "E — USE CONSOLE"
		_: return str(data.get("prompt", "E — INTERACT"))


func _req_text(req: Dictionary) -> String:
	if req.has("key"): return "NEEDS " + str(ITEMS[req["key"]]["name"])
	if req.has("keycard"): return "NEEDS " + str(ITEMS[req["keycard"]]["name"])
	if req.has("power"): return "NEEDS POWER"
	if req.has("cell"): return "NEEDS POWER CELL"
	if req.has("puzzle"): return "MECHANISM SEALED"
	if req.has("tool"): return "NEEDS " + str(ITEMS[req["tool"]]["name"])
	return "LOCKED"


func interact(data: Dictionary) -> void:
	if not is_playing() or ui_blocking():
		return
	var t: String = data.get("type", "")
	match t:
		"pickup": try_pickup(data)
		"door", "secret": try_door(str(data.get("id", "")))
		"checkpoint": activate_checkpoint(str(data.get("id", "")))
		"breaker": restore_power()
		"hatch": try_escape()
		"elevator": open_elevator(str(data.get("id", "")))
		"computer": open_computer(str(data.get("id", "")))
		"document": open_document(str(data.get("id", "")))
		"puzzle": puzzle_ui.open(str(data.get("id", "")))


func _req_ok(req: Dictionary) -> bool:
	if req.has("key") and not has_item(req["key"]): return false
	if req.has("keycard") and not _has_keycard(req["keycard"]): return false
	if req.has("power") and not power_on: return false
	if req.has("cell") and not has_item("power_cell"): return false
	if req.has("puzzle") and not puzzles.get(req["puzzle"], {}).get("solved", false): return false
	if req.has("tool") and not has_item(req["tool"]): return false
	return true


func _has_keycard(card_id: String) -> bool:
	# Hierarchy: l3 satisfies l1/l2, l2 satisfies l1.
	if has_item(card_id): return true
	if card_id == "keycard_l1" and (has_item("keycard_l2") or has_item("keycard_l3")): return true
	if card_id == "keycard_l2" and has_item("keycard_l3"): return true
	return false


func try_door(id: String) -> void:
	var rec: Dictionary = doors.get(id, {})
	if rec.is_empty() or rec.get("open", false):
		return
	var req: Dictionary = rec.get("req", {})
	if req.size() > 0 and not _req_ok(req):
		if audio: audio.play_sfx("door_locked")
		ui.show_message("LOCKED — " + _req_text(req), 2.5)
		return
	# Consume power cell for cell doors.
	if req.has("cell"):
		remove_item("power_cell")
	rec["open"] = true
	_set_door_open(rec, true)
	if audio: audio.play_sfx("door_open")


func _set_door_open(rec: Dictionary, animate = true) -> void:
	var col: CollisionShape3D = rec["col"]
	col.set_deferred("disabled", true)
	var mesh: MeshInstance3D = rec["mesh"]
	if animate:
		var tw = create_tween()
		tw.tween_property(mesh, "position:y", mesh.position.y - 2.6, 0.8)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		mesh.position.y -= 2.6
		mesh.visible = false


func security_unlock() -> void:
	if not _has_keycard("keycard_l3"):
		ui.show_message("INSUFFICIENT CLEARANCE", 2.5)
		return
	var n = 0
	for id in doors:
		var rec: Dictionary = doors[id]
		if not rec.get("open", false) and (rec["req"].has("keycard") or rec.get("theme") == "security"):
			rec["req"] = {}
			n += 1
	ui.show_message("SECURITY DOORS UNLOCKED (%d)" % n, 2.5)


func restore_power() -> void:
	if power_on:
		ui.show_message("POWER ALREADY ONLINE", 2.0)
		return
	power_on = true
	outage_timer = randf_range(360.0, 600.0)
	_apply_power()
	if audio:
		audio.play_sfx("power_up")
		ui.show_message("POWER RESTORED", 3.0)


func open_computer(cid: String) -> void:
	var c: Dictionary = computers.get(cid, {})
	if c.is_empty(): return
	var lines: Array = []
	for ln in c.get("lines", []):
		lines.append(str(ln))
	# refresh dynamic power terminal
	if cid == "pc_power":
		lines[0] = "GRID STATUS: %s" % ("ONLINE" if power_on else "OFFLINE")
	var actions: Array = []
	for a in c.get("actions", []):
		actions.append({"label": a.get("label", "ACTION"), "callable": a.get("callable", Callable())})
	ui.show_terminal({"lines": lines, "actions": actions})


func open_document(did: String) -> void:
	var d: Dictionary = documents.get(did, {})
	if d.is_empty(): return
	ui.show_document(str(d.get("title", "DOCUMENT")), str(d.get("body", "")))
	if audio: audio.play_sfx("document")


func open_elevator(eid: String) -> void:
	var e: Dictionary = elevators_data.get(eid, {})
	if e.is_empty(): return
	var req: Dictionary = e.get("req", {})
	if req.size() > 0 and not _elev_req_ok(req):
		ui.show_message("ELEVATOR LOCKED — " + _req_text(req), 2.5)
		if audio: audio.play_sfx("door_locked")
		return
	var floors = []
	for f in e.get("floors", []):
		floors.append({"index": int(f["index"]), "name": str(f["name"])})
	ui.show_elevator({"id": eid, "name": "LIFT " + eid.replace("elev_", ""), "floors": floors})


func _elev_req_ok(req: Dictionary) -> bool:
	if req.has("power") and not power_on: return false
	if req.has("keycard") and not _has_keycard(req["keycard"]): return false
	if req.has("puzzle") and not puzzles.get(req["puzzle"], {}).get("solved", false): return false
	return true


func travel_elevator(eid: String, target_fi: int) -> void:
	var e: Dictionary = elevators_data.get(eid, {})
	if e.is_empty(): return
	var spawn = Vector3.ZERO
	var found = false
	for f in e.get("floors", []):
		if int(f["index"]) == target_fi:
			spawn = f["pos"]
			found = true
	if not found: return
	ui.hide_all_panels()
	player.frozen = true
	ui.fade_out_then(func():
		player.global_position = spawn
		player.rotation.y = 0.0
		player.velocity = Vector3.ZERO
		player.frozen = false
		if audio: audio.play_sfx("elevator")
	)


func puzzle_solved(pid: String) -> void:
	var p: Dictionary = puzzles.get(pid, {})
	if p.is_empty(): return
	p["solved"] = true
	# Unlock doors gated by this puzzle.
	for id in doors:
		var rec: Dictionary = doors[id]
		if rec.get("req", {}).get("puzzle", "") == pid:
			rec["req"] = {}
			if not rec.get("open", false):
				ui.show_message("A SEAL RELEASED", 2.5)
	if pid == "elev_repair":
		if elevators_data.has("elev_4_2"):
			elevators_data["elev_4_2"]["req"].erase("puzzle")
		ui.show_message("ELEVATOR REPAIRED", 3.0)


func activate_checkpoint(id: String) -> void:
	var cp: Dictionary = checkpoints.get(id, {})
	if cp.is_empty(): return
	# flags
	for cid in checkpoints:
		var rec: Dictionary = checkpoints[cid]
		rec["mat"].albedo_color = Color(0.05, 0.6, 0.15) if cid == id else Color(0.7, 0.05, 0.05)
	checkpoint_active = id
	checkpoint_snapshot = take_snapshot()
	_save_snapshot()
	if audio: audio.play_sfx("checkpoint")
	ui.show_message("CHECKPOINT ACTIVATED", 2.5)


func try_escape() -> void:
	if has_item(FINAL_KEY_ID):
		_win()
	else:
		ui.show_message("SEALED. THE BLACK KEY IS REQUIRED.", 3.0)
		if audio: audio.play_sfx("door_locked")


func _trigger_monster() -> void:
	if monster == null or chase_active: return
	chase_active = true
	monster.activate(player)
	ui.show_message("", 0.1)


func kill_player() -> void:
	if dead or won or not started: return
	dead = true
	player.dead = true
	if monster: monster.deactivate()
	chase_active = false
	if audio: audio.play_sfx("death")
	ui.show_death()
	await get_tree().create_timer(1.7, true, false, true).timeout
	_apply_snapshot(checkpoint_snapshot if checkpoint_snapshot.size() > 0 else initial_snapshot)
	dead = false
	player.dead = false
	ui.hide_death()


func _win() -> void:
	won = true
	final_time = total_time
	_save_time()
	_clear_snapshot()
	if monster: monster.deactivate()
	chase_active = false
	player.dead = true
	if audio: audio.play_sfx("win")
	ui.show_win(final_time)


# ---------------------------------------------------------------
# POWER / OUTAGES
# ---------------------------------------------------------------

func _apply_power() -> void:
	for entry in lights:
		var l: OmniLight3D = entry["node"]
		var emergency: bool = entry["emergency"]
		if emergency:
			l.visible = true
			l.light_energy = entry["base"]
		else:
			l.visible = power_on
			l.light_energy = entry["base"] if power_on else 0.0
	# doors requiring power that are closed remain closed; open ones stay.


func _start_outage() -> void:
	power_on = false
	_apply_power()
	if audio:
		audio.set_outage(true)
		audio.play_sfx("power_down")
	ui.show_message("POWER FAILURE", 3.5)


# ---------------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------------

func take_snapshot() -> Dictionary:
	var p_pos = player.global_position if player else Vector3.ZERO
	var p_rot = player.rotation.y if player else 0.0
	var cam_pitch = player.head.rotation.x if player else 0.0
	var drops = []
	for n in dropped_nodes:
		drops.append({"item_id": n.get_meta("interact", {}).get("item_id", ""),
			"pos": [n.global_position.x, n.global_position.y, n.global_position.z],
			"rot": [n.rotation.x, n.rotation.y, n.rotation.z]})
	var door_states = {}
	for id in doors:
		var rec: Dictionary = doors[id]
		door_states[id] = {"open": rec.get("open", false), "req": rec.get("req", {})}
	var puzzle_states = {}
	for pid in puzzles:
		puzzle_states[pid] = {"solved": puzzles[pid].get("solved", false)}
	return {
		"player_pos": [p_pos.x, p_pos.y, p_pos.z],
		"player_rot": p_rot,
		"cam_pitch": cam_pitch,
		"inventory": inventory.duplicate(),
		"held_index": held_index,
		"battery": player.battery_percent if player else 0.0,
		"collected": collected.keys(),
		"dropped": drops,
		"doors": door_states,
		"puzzles": puzzle_states,
		"power_on": power_on,
		"checkpoint_active": checkpoint_active,
		"chase_active": chase_active,
		"final_key_taken": final_key_taken,
	}


func _apply_snapshot(snap: Dictionary) -> void:
	if snap.is_empty(): return
	# player
	if player and snap.has("player_pos"):
		var pp: Array = snap["player_pos"]
		player.global_position = Vector3(pp[0], pp[1], pp[2])
		player.rotation.y = snap.get("player_rot", 0.0)
		player.head.rotation.x = snap.get("cam_pitch", 0.0)
		player.velocity = Vector3.ZERO
	# inventory / flashlight
	inventory = snap.get("inventory", []).duplicate()
	held_index = snap.get("held_index", -1)
	if player:
		player.set_flashlight_owned(inventory.has(FLASHLIGHT_ID))
		player.set_battery(snap.get("battery", 0.0))
	# collected world items
	collected = {}
	for k in snap.get("collected", []):
		collected[k] = true
	for rec in world_items:
		var vis: bool = not collected.has(rec["pick_id"])
		rec["node"].visible = vis
		rec["col"].disabled = not vis
	# dropped items
	for n in dropped_nodes:
		n.queue_free()
	dropped_nodes.clear()
	for d in snap.get("dropped", []):
		var item_id: String = d.get("item_id", "")
		_spawn_dropped(item_id)
		var n: RigidBody3D = dropped_nodes[dropped_nodes.size() - 1]
		var pp: Array = d.get("pos", [0, 0, 0])
		n.global_position = Vector3(pp[0], pp[1], pp[2])
	# doors
	for id in doors:
		var rec: Dictionary = doors[id]
		var st: Dictionary = snap.get("doors", {}).get(id, {})
		rec["req"] = st.get("req", rec.get("req", {}))
		if st.get("open", false) and not rec.get("open", false):
			rec["open"] = true
			_set_door_open(rec, false)
	# puzzles
	for pid in puzzles:
		puzzles[pid]["solved"] = snap.get("puzzles", {}).get(pid, {}).get("solved", false)
	# power
	power_on = snap.get("power_on", true)
	_apply_power()
	checkpoint_active = snap.get("checkpoint_active", "")
	final_key_taken = snap.get("final_key_taken", false)
	for cid in checkpoints:
		var rec: Dictionary = checkpoints[cid]
		rec["mat"].albedo_color = Color(0.05, 0.6, 0.15) if cid == checkpoint_active else Color(0.7, 0.05, 0.05)
	# monster
	chase_active = snap.get("chase_active", false)
	if monster:
		if chase_active:
			monster.activate(player)
		else:
			monster.deactivate()
	if audio:
		audio.set_chase(chase_active)
		audio.set_outage(not power_on)
	if ui.inventory_panel.visible:
		ui.refresh_inventory()


func _save_snapshot() -> void:
	var f = FileAccess.open(SAVE_SNAP, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(checkpoint_snapshot))
		f.close()


func _load_snapshot() -> void:
	if FileAccess.file_exists(SAVE_SNAP):
		var f = FileAccess.open(SAVE_SNAP, FileAccess.READ)
		var txt = f.get_as_text()
		f.close()
		var data = JSON.parse_string(txt)
		if data is Dictionary:
			checkpoint_snapshot = data
			checkpoint_active = str(data.get("checkpoint_active", ""))


func _clear_snapshot() -> void:
	var path = ProjectSettings.globalize_path(SAVE_SNAP)
	if FileAccess.file_exists(SAVE_SNAP):
		DirAccess.remove_absolute(path)


func _load_time() -> void:
	if FileAccess.file_exists(SAVE_TIME):
		var c = ConfigFile.new()
		if c.load(SAVE_TIME) == OK:
			total_time = c.get_value("time", "total", 0.0)
			final_time = c.get_value("time", "final", 0.0)


func _save_time() -> void:
	var c = ConfigFile.new()
	c.set_value("time", "total", total_time)
	c.set_value("time", "final", final_time)
	c.save(SAVE_TIME)


func format_time(sec: float) -> String:
	sec = max(0.0, sec)
	var h = int(sec / 3600.0)
	var m = int((sec - h * 3600.0) / 60.0)
	var s = int(sec - h * 3600.0 - m * 60.0)
	return "%02d:%02d:%02d" % [h, m, s]


func set_sensitivity(v: float) -> void:
	mouse_sensitivity = v


func apply_quality() -> void:
	# Reduce light count / shadows when enabled.
	for entry in lights:
		var l: OmniLight3D = entry["node"]
		l.omni_range = 6.0 if reduce_lights else 10.0


# ---------------------------------------------------------------
# PROCESS
# ---------------------------------------------------------------

func _process(delta: float) -> void:
	if started and not won and not get_tree().paused:
		total_time += delta
	# stopwatch label
	if stopwatch_label:
		stopwatch_label.text = format_time(total_time)
	# outage
	if is_playing() and not chase_active:
		if power_on:
			outage_timer -= delta
			if outage_timer <= 0.0:
				_start_outage()
	# flicker lights
	var t = Time.get_ticks_msec() / 1000.0
	for entry in lights:
		var l: OmniLight3D = entry["node"]
		var flick: float = entry.get("flicker", -1.0)
		if flick >= 0.0 and l.visible:
			var wave = 0.7 + 0.3 * sin(t * 13.0 + flick * 7.0)
			var drop = 1.0
			if sin(t * 31.0 + flick * 3.0) > 0.96:
				drop = 0.15
			l.light_energy = entry["base"] * wave * drop
	# auto doors
	if player and is_playing():
		for id in doors:
			var rec: Dictionary = doors[id]
			if rec.get("auto") and not rec.get("open", false):
				var d = player.global_position.distance_to(rec["node"].global_position)
				if d < 2.4:
					try_door(id)
	# prompt
	if player and ui:
		ui.update_prompt(player.prompt_text if is_playing() and not ui_blocking() else "")
