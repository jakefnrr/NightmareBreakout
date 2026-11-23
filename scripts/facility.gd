extends Node3D

const COLS := 5
const ROWS := 4
const SLOT_W := 3
const SLOT_H := 3
const GAP := 1
const CELL := 4.0
const ROOM_H := 3.2
const FLOOR_H := 4.0
const WALL_T := 0.35
const DOOR_W := 2.2
const DOOR_H := 2.35

# Floors bottom -> top: sublevel, basement, ground, upper.
var floors := [
	{"y": -8.0, "tag": "SUBLEVEL"},
	{"y": -4.0, "tag": "BASEMENT"},
	{"y": 0.0, "tag": "GROUND"},
	{"y": 4.0, "tag": "UPPER"},
]

var total_cells_x := COLS * (SLOT_W + GAP) - GAP
var total_cells_z := ROWS * (SLOT_H + GAP) - GAP

var game: Node = null
var types := {}       # "fi_c_r" -> type
var themes := {}      # "fi_c_r" -> theme
var infos := {}       # "fi_c_r" -> info dict
var cell_slot := []   # [fi][j][i] -> slot key or -1
var slot_open := {}   # "fi_key" -> {side: true}
var door_mids := {}   # "fi_key" -> {side: Vector2i room cell}
var links := []       # stair/elevator links for pathfinding
var elevators := []   # [{c,r}]
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 1337


func floor_y(fi: int) -> float:
	return floors[fi]["y"]


func floor_tag(fi: int) -> String:
	return floors[fi]["tag"]


func slot_key(fi: int, c: int, r: int) -> String:
	return "%d_%d_%d" % [fi, c, r]


func cell_x(i: int) -> float:
	return (i - (total_cells_x - 1) / 2.0) * CELL


func cell_z(j: int) -> float:
	return (j - (total_cells_z - 1) / 2.0) * CELL


func slot_cell_range(c: int, r: int) -> Vector4i:
	var i0 := c * (SLOT_W + GAP)
	var j0 := r * (SLOT_H + GAP)
	return Vector4i(i0, i0 + SLOT_W - 1, j0, j0 + SLOT_H - 1)


func slot_rect_world(fi: int, c: int, r: int) -> Rect2:
	var rg := slot_cell_range(c, r)
	var x0 := cell_x(rg.x) - CELL / 2.0
	var x1 := cell_x(rg.y) + CELL / 2.0
	var z0 := cell_z(rg.z) - CELL / 2.0
	var z1 := cell_z(rg.w) + CELL / 2.0
	return Rect2(x0, z0, x1 - x0, z1 - z0)


func slot_center_world(fi: int, c: int, r: int, y_off := 0.9) -> Vector3:
	var rg := slot_cell_range(c, r)
	var ci := (rg.x + rg.y) / 2.0
	var cj := (rg.z + rg.w) / 2.0
	return Vector3(cell_x(int(ci)), floor_y(fi) + y_off, cell_z(int(cj)))


func build(g: Node) -> void:
	game = g
	_assign_layout()
	_build_cell_map()
	_build_floors_and_ceilings()
	_build_boundary_walls()
	_build_rooms()
	_build_corridor_features()
	_build_stairs()


# ---------------------------------------------------------------
# LAYOUT
# ---------------------------------------------------------------

func _assign_layout() -> void:
	var ELEV_SLOTS := [Vector2i(2, 1), Vector2i(4, 2)]
	var STAIR_LINKS := [
		{"slot": Vector2i(0, 3), "lo": 0, "hi": 1},
		{"slot": Vector2i(4, 1), "lo": 1, "hi": 2},
		{"slot": Vector2i(1, 0), "lo": 2, "hi": 3},
	]
	var SECRET := {
		0: [Vector2i(0, 0), Vector2i(4, 3)],
		1: [Vector2i(2, 0), Vector2i(4, 3)],
	}
	var OPEN_SLOTS := {
		0: [Vector2i(2, 2)],
		1: [Vector2i(0, 2), Vector2i(4, 0)],
		2: [Vector2i(2, 3), Vector2i(4, 1)],
		3: [Vector2i(2, 1), Vector2i(0, 3)],
	}
	var pools := {
		0: ["lab", "storage", "coolant", "archive", "lab", "storage", "lab", "archive", "coolant", "lab", "storage", "archive", "lab", "coolant", "storage", "archive", "lab", "storage", "coolant", "archive"],
		1: ["maintenance", "storage", "workshop", "security", "lab", "morgue", "generator", "storage", "maintenance", "lab", "workshop", "security", "storage", "morgue", "maintenance", "lab", "workshop", "storage", "security", "maintenance"],
		2: ["office", "cafeteria", "security", "storage", "medical", "server", "breakroom", "lab", "office", "cafeteria", "security", "medical", "server", "office", "storage", "breakroom", "lab", "office", "cafeteria", "security"],
		3: ["lab", "office", "server", "executive", "medical", "cafeteria", "library", "lab", "office", "server", "executive", "medical", "cafeteria", "lab", "office", "server", "library", "medical", "lab", "office"],
	}
	var stair_slot := {}
	for link in STAIR_LINKS:
		var s: Vector2i = link["slot"]
		stair_slot[s] = link
		for fi in [int(link["lo"]), int(link["hi"])]:
			types[slot_key(fi, s.x, s.y)] = "stair"
			links.append({"type": "stair", "c": s.x, "r": s.y,
				"lo": int(link["lo"]), "hi": int(link["hi"])})
	for fi in 4:
		for c in COLS:
			for r in ROWS:
				var k := slot_key(fi, c, r)
				if types.has(k):
					continue
				var sc := Vector2i(c, r)
				if sc in ELEV_SLOTS:
					types[k] = "elevator"
					themes[k] = "elevator"
					if fi == 0:
						elevators.append({"c": c, "r": r})
				elif sc in SECRET.get(fi, []):
					types[k] = "secret"
					themes[k] = "final" if fi == 0 and sc == Vector2i(0, 0) else "secret"
				elif sc in OPEN_SLOTS.get(fi, []):
					types[k] = "open"
					themes[k] = "plaza"
				elif fi == 2 and sc == Vector2i(0, 0):
					types[k] = "start"
					themes[k] = "start"
				elif fi == 1 and sc == Vector2i(2, 2):
					types[k] = "room"
					themes[k] = "power"
				elif fi == 1 and sc == Vector2i(0, 1):
					types[k] = "room"
					themes[k] = "flashlight"
				else:
					types[k] = "room"
					var pool: Array = pools[fi]
					themes[k] = pool[(c * 7 + r * 3 + fi * 5) % pool.size()]
				var rg := slot_cell_range(c, r)
				infos[k] = {"fi": fi, "c": c, "r": r, "i0": rg.x, "i1": rg.y,
					"j0": rg.z, "j1": rg.w, "type": types[k], "theme": themes[k]}
	# Ensure elevators are room-like on every floor (already set for non-stair).
	for e in elevators:
		for fi in 4:
			var k := slot_key(fi, e["c"], e["r"])
			if not types.has(k) or types[k] == "stair":
				pass
			elif types[k] != "elevator":
				types[k] = "elevator"
				themes[k] = "elevator"
				infos[k]["type"] = "elevator"
				infos[k]["theme"] = "elevator"
	for k in infos:
		infos[k]["type"] = types[k]
		infos[k]["theme"] = themes[k]


func _build_cell_map() -> void:
	for fi in 4:
		var grid := []
		for j in total_cells_z:
			var row := []
			for i in total_cells_x:
				row.append(-1)
			grid.append(row)
		cell_slot.append(grid)
	for k in infos:
		var inf: Dictionary = infos[k]
		var fi: int = inf["fi"]
		for j in range(inf["j0"], inf["j1"] + 1):
			for i in range(inf["i0"], inf["i1"] + 1):
				cell_slot[fi][j][i] = k


# ---------------------------------------------------------------
# MATERIALS / BOX HELPERS
# ---------------------------------------------------------------

func _mat(key: String) -> Material:
	return game.mats.get(key, game.mats["concrete"])


func _box(center: Vector3, size: Vector3, mat: Material, collide := true,
		surface := "", parent: Node = null) -> StaticBody3D:
	var p: Node = parent if parent else self
	if not collide:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = center
		p.add_child(mi)
		return null
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if surface != "":
		body.set_meta("surface", surface)
	p.add_child(body)
	return body


func _cyl(center: Vector3, radius: float, height: float, mat: Material,
		collide := true, parent: Node = null) -> StaticBody3D:
	var p: Node = parent if parent else self
	if not collide:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = height
		mi.mesh = cm
		mi.material_override = mat
		mi.position = center
		p.add_child(mi)
		return null
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	body.add_child(mi)
	p.add_child(body)
	return body


func _light(pos: Vector3, color: Color, energy: float, rng_m := 9.0,
		emergency := false, flicker := -1.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	add_child(l)
	game.lights.append({"node": l, "base": energy, "color": color,
		"emergency": emergency, "flicker": flicker, "on": true})
	return l


# ---------------------------------------------------------------
# FLOORS / CEILINGS / BOUNDARY
# ---------------------------------------------------------------

func _floor_top(fi: int) -> float:
	return floor_y(fi)


func _build_floors_and_ceilings() -> void:
	var floor_mats := [_mat("grate"), _mat("concrete_dark"), _mat("concrete"), _mat("tile")]
	var ceil_mat := _mat("concrete_dark")
	for fi in 4:
		var fy := floor_y(fi)
		# Slot floors (skip upper floor of stair links).
		for k in infos:
			var inf: Dictionary = infos[k]
			if inf["fi"] != fi:
				continue
			var typ: String = inf["type"]
			if typ == "stair":
				# floor only on lower floor of its link
				var link := _stair_link_for(fi, inf["c"], inf["r"])
				if link.is_empty() or int(link["lo"]) != fi:
					continue
			var rg := slot_cell_range(inf["c"], inf["r"])
			var x0 := cell_x(rg.x) - CELL / 2.0
			var x1 := cell_x(rg.y) + CELL / 2.0
			var z0 := cell_z(rg.z) - CELL / 2.0
			var z1 := cell_z(rg.w) + CELL / 2.0
			var surf := _surface_for(fi, inf)
			_box(Vector3((x0 + x1) / 2, fy - 0.15, (z0 + z1) / 2),
				Vector3(x1 - x0, 0.3, z1 - z0), floor_mats[fi], true, surf)
		# Corridor strips.
		_build_corridor_floors(fi, floor_mats[fi])
		# Ceilings per slot.
		for k in infos:
			var inf: Dictionary = infos[k]
			if inf["fi"] != fi:
				continue
			var typ: String = inf["type"]
			if typ == "stair":
				var link := _stair_link_for(fi, inf["c"], inf["r"])
				# ceiling only on upper floor of link
				if link.is_empty() or int(link["hi"]) != fi:
					continue
			var rg := slot_cell_range(inf["c"], inf["r"])
			var x0 := cell_x(rg.x) - CELL / 2.0
			var x1 := cell_x(rg.y) + CELL / 2.0
			var z0 := cell_z(rg.z) - CELL / 2.0
			var z1 := cell_z(rg.w) + CELL / 2.0
			_box(Vector3((x0 + x1) / 2, fy + ROOM_H + 0.15, (z0 + z1) / 2),
				Vector3(x1 - x0, 0.3, z1 - z0), ceil_mat, false)
		_build_corridor_ceilings(fi, ceil_mat)


func _stair_link_for(fi: int, c: int, r: int) -> Dictionary:
	for link in links:
		if link["type"] == "stair" and link["c"] == c and link["r"] == r \
				and (int(link["lo"]) == fi or int(link["hi"]) == fi):
			return link
	return {}


func _surface_for(fi: int, inf: Dictionary) -> String:
	var theme: String = inf.get("theme", "")
	match theme:
		"office", "executive", "library", "breakroom": return "carpet"
		"cafeteria", "medical", "lab": return "tile"
		"server", "elevator", "power", "generator", "maintenance", "workshop", \
		"coolant", "morgue", "storage", "archive", "final": return "grate"
		_: return "concrete" if fi != 3 else "tile"


func _build_corridor_floors(fi: int, mat: Material) -> void:
	var fy := floor_y(fi)
	var depth := total_cells_z * CELL
	var width := total_cells_x * CELL
	# Vertical gap columns.
	for c in range(COLS - 1):
		var i := c * (SLOT_W + GAP) + SLOT_W
		var x := cell_x(i)
		_box(Vector3(x, fy - 0.15, 0), Vector3(CELL, 0.3, depth), mat, true, "concrete")
	# Horizontal gap rows: segments under each slot column.
	for r in range(ROWS - 1):
		var j := r * (SLOT_H + GAP) + SLOT_H
		var z := cell_z(j)
		for c in COLS:
			var i0 := c * (SLOT_W + GAP)
			var x0 := cell_x(i0) - CELL / 2.0
			var x1 := cell_x(i0 + SLOT_W - 1) + CELL / 2.0
			_box(Vector3((x0 + x1) / 2, fy - 0.16, z),
				Vector3(x1 - x0, 0.3, CELL), mat, true, "concrete")


func _build_corridor_ceilings(fi: int, mat: Material) -> void:
	var fy := floor_y(fi)
	var depth := total_cells_z * CELL
	var width := total_cells_x * CELL
	for c in range(COLS - 1):
		var i := c * (SLOT_W + GAP) + SLOT_W
		_box(Vector3(cell_x(i), fy + ROOM_H + 0.15, 0),
			Vector3(CELL, 0.3, depth), mat, false)
	for r in range(ROWS - 1):
		var j := r * (SLOT_H + GAP) + SLOT_H
		var z := cell_z(j)
		for c in COLS:
			var i0 := c * (SLOT_W + GAP)
			var x0 := cell_x(i0) - CELL / 2.0
			var x1 := cell_x(i0 + SLOT_W - 1) + CELL / 2.0
			_box(Vector3((x0 + x1) / 2, fy + ROOM_H + 0.15, z),
				Vector3(x1 - x0, 0.3, CELL), mat, false)


func _build_boundary_walls() -> void:
	for fi in 4:
		var fy := floor_y(fi)
		var x0 := cell_x(0) - CELL / 2.0
		var x1 := cell_x(total_cells_x - 1) + CELL / 2.0
		var z0 := cell_z(0) - CELL / 2.0
		var z1 := cell_z(total_cells_z - 1) + CELL / 2.0
		var w := x1 - x0
		var d := z1 - z0
		var mid := (x0 + x1) / 2.0
		var midz := (z0 + z1) / 2.0
		# South/north walls (along x)
		_box(Vector3(mid, fy + ROOM_H / 2, z0), Vector3(w, ROOM_H, WALL_T), _mat("concrete_dark"), true)
		_box(Vector3(mid, fy + ROOM_H / 2, z1), Vector3(w, ROOM_H, WALL_T), _mat("concrete_dark"), true)
		# West/east walls (along z)
		_box(Vector3(x0, fy + ROOM_H / 2, midz), Vector3(WALL_T, ROOM_H, d), _mat("concrete_dark"), true)
		_box(Vector3(x1, fy + ROOM_H / 2, midz), Vector3(WALL_T, ROOM_H, d), _mat("concrete_dark"), true)


# ---------------------------------------------------------------
# ROOMS / WALLS / DOORS
# ---------------------------------------------------------------

func _build_rooms() -> void:
	for k in infos:
		var inf: Dictionary = infos[k]
		var typ: String = inf["type"]
		if typ == "stair":
			continue
		var rect := slot_rect_world(inf["fi"], inf["c"], inf["r"])
		if typ == "open":
			# Open plaza: low planters/pillars only, no perimeter walls.
			_decorate_open(inf, rect)
			# Still allow movement to corridors.
			_register_open_sides(inf)
			continue
		_build_room_shell(inf, rect)
		_decorate_room(inf, rect)
		_add_room_light(inf, rect)


func _register_open_sides(inf: Dictionary) -> void:
	var k := "%s" % slot_key(inf["fi"], inf["c"], inf["r"])
	# open slot key uses fi_c_r already? slot_key returns fi_c_r.
	k = slot_key(inf["fi"], inf["c"], inf["r"])
	slot_open[k] = {"N": true, "S": true, "E": true, "W": true}
	var rg := slot_cell_range(inf["c"], inf["r"])
	var mi := (rg.x + rg.y) / 2
	var mj := (rg.z + rg.w) / 2
	door_mids[k] = {
		"N": Vector2i(int(mi), int(rg.z)),
		"S": Vector2i(int(mi), int(rg.w)),
		"E": Vector2i(int(rg.y), int(mj)),
		"W": Vector2i(int(rg.x), int(mj)),
	}


func _door_sides_for(inf: Dictionary) -> Array:
	# Returns array of [side, kind] where kind normal/hidden.
	var theme: String = inf["theme"]
	var typ: String = inf["type"]
	var h := (inf["c"] * 31 + inf["r"] * 17 + inf["fi"] * 13) % 100
	var sides := []
	if typ == "secret":
		# Hidden door on one side, normal door opposite for flow.
		var hid := ["N", "E", "S", "W"][h % 4]
		var opp := {"N": "S", "S": "N", "E": "W", "W": "E"}[hid]
		sides.append([hid, "hidden"])
		sides.append([opp, "normal"])
		return sides
	if typ == "start":
		return [["E", "normal"], ["S", "normal"]]
	if typ == "elevator":
		return [["W", "normal"], ["E", "normal"]]
	# Rooms: 1 or 2 doors.
	var primary := ["N", "E", "S", "W"][h % 4]
	sides.append([primary, "normal"])
	if h % 3 == 0:
		var secondary := ["N", "E", "S", "W"][(h + 2) % 4]
		sides.append([secondary, "normal"])
	return sides


func _build_room_shell(inf: Dictionary, rect: Rect2) -> void:
	var fi: int = inf["fi"]
	var fy := floor_y(fi)
	var c: int = inf["c"]
	var r: int = inf["r"]
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := x0 + rect.size.x
	var z1 := z0 + rect.size.y
	var zm := (z0 + z1) / 2.0
	var xm := (x0 + x1) / 2.0
	var door_sides := _door_sides_for(inf)
	var open_map := {}
	var mid_map := {}
	var rg := slot_cell_range(c, r)
	var mi := int((rg.x + rg.y) / 2)
	var mj := int((rg.z + rg.w) / 2)
	mid_map = {
		"N": Vector2i(mi, int(rg.z)),
		"S": Vector2i(mi, int(rg.w)),
		"E": Vector2i(int(rg.y), mj),
		"W": Vector2i(int(rg.x), mj),
	}
	for ds in door_sides:
		open_map[ds[0]] = ds[1]
	slot_open[slot_key(fi, c, r)] = open_map
	door_mids[slot_key(fi, c, r)] = mid_map
	# Build each side.
	_build_side(inf, rect, "N", door_sides)
	_build_side(inf, rect, "S", door_sides)
	_build_side(inf, rect, "E", door_sides)
	_build_side(inf, rect, "W", door_sides)


func _build_side(inf: Dictionary, rect: Rect2, side: String, doors: Array) -> void:
	var fi: int = inf["fi"]
	var fy := floor_y(fi)
	var door_kind := ""
	for ds in doors:
		if ds[0] == side:
			door_kind = ds[1]
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := x0 + rect.size.x
	var z1 := z0 + rect.size.y
	var wall_mat := _mat("concrete_dark") if inf["theme"] in ["storage", "archive", "morgue", "coolant"] else _mat("concrete")
	match inf["theme"]:
		"lab", "server", "power", "generator", "maintenance", "workshop", "elevator":
			wall_mat = _mat("metal_dark")
		"office", "executive", "library", "breakroom", "medical", "cafeteria":
			wall_mat = _mat("wall_paint")
	var horizontal := (side == "N" or side == "S")
	var fixed := (z0 if side == "N" else z1) if horizontal else (x0 if side == "W" else x1)
	var a0 := x0 if horizontal else z0
	var a1 := x1 if horizontal else z1
	var amid := (a0 + a1) / 2.0
	if door_kind == "":
		# solid wall
		if horizontal:
			_box(Vector3(amid, fy + ROOM_H / 2, fixed), Vector3(a1 - a0 + WALL_T, ROOM_H, WALL_T), wall_mat)
		else:
			_box(Vector3(fixed, fy + ROOM_H / 2, amid), Vector3(WALL_T, ROOM_H, a1 - a0 + WALL_T), wall_mat)
		return
	# Wall with doorway gap.
	var gap0 := amid - DOOR_W / 2.0
	var gap1 := amid + DOOR_W / 2.0
	# Segment before gap
	if gap0 > a0:
		if horizontal:
			_box(Vector3((a0 + gap0) / 2, fy + ROOM_H / 2, fixed), Vector3(gap0 - a0, ROOM_H, WALL_T), wall_mat)
		else:
			_box(Vector3(fixed, fy + ROOM_H / 2, (a0 + gap0) / 2), Vector3(WALL_T, ROOM_H, gap0 - a0), wall_mat)
	# Segment after gap
	if gap1 < a1:
		if horizontal:
			_box(Vector3((gap1 + a1) / 2, fy + ROOM_H / 2, fixed), Vector3(a1 - gap1, ROOM_H, WALL_T), wall_mat)
		else:
			_box(Vector3(fixed, fy + ROOM_H / 2, (gap1 + a1) / 2), Vector3(WALL_T, ROOM_H, a1 - gap1), wall_mat)
	# Lintel above door
	var lintel_h := ROOM_H - DOOR_H
	if horizontal:
		_box(Vector3(amid, fy + DOOR_H + lintel_h / 2, fixed), Vector3(DOOR_W, lintel_h, WALL_T), wall_mat)
	else:
		_box(Vector3(fixed, fy + DOOR_H + lintel_h / 2, amid), Vector3(WALL_T, lintel_h, DOOR_W), wall_mat)
	# Door panel.
	_add_door(inf, side, door_kind, horizontal, fixed, amid, fy)


func _add_door(inf: Dictionary, side: String, kind: String, horizontal: bool,
		fixed: float, amid: float, fy: float) -> void:
	var fi: int = inf["fi"]
	var c: int = inf["c"]
	var r: int = inf["r"]
	var id := "d_%d_%d_%d_%s" % [fi, c, r, side]
	var center: Vector3
	var size: Vector3
	if horizontal:
		center = Vector3(amid, fy + DOOR_H / 2, fixed)
		size = Vector3(DOOR_W, DOOR_H, WALL_T)
	else:
		center = Vector3(fixed, fy + DOOR_H / 2, amid)
		size = Vector3(WALL_T, DOOR_H, DOOR_W)
	var body := StaticBody3D.new()
	body.name = "Door_" + id
	body.position = center
	body.set_meta("door_id", id)
	var itype := "secret" if kind == "hidden" else "door"
	body.set_meta("interact", {"type": itype, "id": id,
		"prompt": "PRY OPEN PANEL" if kind == "hidden" else "OPEN DOOR"})
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.name = "Col"
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.name = "Panel"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat("door") if kind != "hidden" else _mat("wall_panel")
	body.add_child(mi)
	add_child(body)
	var rec := {"id": id, "node": body, "mesh": mi, "col": col, "open": false,
		"kind": kind, "fi": fi, "c": c, "r": r, "side": side,
		"req": {}, "theme": inf["theme"], "hidden": kind == "hidden"}
	game.doors[id] = rec


func _decorate_open(inf: Dictionary, rect: Rect2) -> void:
	var fy := floor_y(inf["fi"])
	var cx := rect.position.x + rect.size.x / 2
	var cz := rect.position.y + rect.size.y / 2
	# Planters / pillars for plaza.
	for i in 4:
		var px := cx + (i % 2 == 0 ? -3.5 : 3.5)
		var pz := cz + (i < 2 ? -3.5 : 3.5)
		_box(Vector3(px, fy + 0.5, pz), Vector3(1.2, 1.0, 1.2), _mat("concrete_dark"), true)
		_cyl(Vector3(px, fy + 1.1, pz), 0.5, 0.4, _mat("plant"), false)
	_light(Vector3(cx, fy + ROOM_H - 0.5, cz), Color(0.9, 0.85, 0.7), 0.9, 12.0, false, 3.0)


func _decorate_room(inf: Dictionary, rect: Rect2) -> void:
	var theme: String = inf["theme"]
	var fy := floor_y(inf["fi"])
	var cx := rect.position.x + rect.size.x / 2
	var cz := rect.position.y + rect.size.y / 2
	var seed := int(abs(hash("%d_%d_%d" % [inf["fi"], inf["c"], inf["r"]])))
	match theme:
		"office", "executive", "library", "breakroom":
			_desk(cx - 2, fy, cz - 2, fy)
			_desk(cx + 2, fy, cz + 2, fy)
			_box(Vector3(cx, fy + 0.4, cz + 3), Vector3(3, 0.8, 1), _mat("wood"), true)
			_cyl(Vector3(cx - 2, fy + 0.5, cz - 2), 0.3, 0.5, _mat("chair"), true)
		"lab", "coolant":
			_table(cx, fy, cz, 3.0, 1.4)
			_cyl(cx - 3, fy + 0.9, cz - 3, 0.4, 1.8, _mat("machine"), true)
			_cyl(cx + 3, fy + 0.6, cz + 3, 0.5, 1.2, _mat("machine_dark"), true)
		"server":
			for i in 3:
				_box(cx - 3 + i * 3, fy + 1.1, cz - 3, Vector3(1.4, 2.2, 1.0), _mat("metal_dark"), true)
		"medical", "morgue":
			_box(cx, fy + 0.45, cz, Vector3(2.2, 0.5, 0.9), _mat("medical"), true)
			_box(cx, fy + 0.75, cz, Vector2(0, 0) if false else Vector3(2.0, 0.15, 0.8), _mat("sheet"), false)
		"cafeteria":
			for i in 3:
				_box(cx - 3 + i * 3, fy + 0.4, cz, Vector3(1.6, 0.8, 1.6), _mat("wood"), true)
		"storage", "archive", "workshop", "maintenance":
			for i in 4:
				_box(cx - 3 + (i % 2) * 6, fy + 0.6 + (i / 2) * 0.4, cz - 2 + (i % 2) * 4,
					Vector3(1.4, 1.2, 1.4), _mat("crate"), true)
		"security", "power", "generator":
			_box(cx, fy + 0.8, cz, Vector3(2.0, 1.6, 1.0), _mat("machine_dark"), true)
			_cyl(cx - 2, fy + 0.7, cz + 2, 0.5, 1.4, _mat("pipe"), true)
		"flashlight":
			_box(cx, fy + 0.4, cz, Vector3(2.5, 0.8, 1.2), _mat("metal_dark"), true)
		"elevator":
			# Elevator doors decoration on one wall.
			_box(cx, fy + 1.2, rect.position.y + 0.4, Vector3(3.0, 2.4, 0.3), _mat("elevator"), true)
		"start":
			_box(cx - 3, fy + 0.4, cz, Vector3(1.8, 0.8, 1.0), _mat("wood"), true)
			_box(cx + 3, fy + 0.4, cz + 2, Vector3(1.8, 0.8, 1.0), _mat("wood"), true)
		"final":
			_cyl(cx, fy + 0.8, cz, 1.0, 1.6, _mat("machine_dark"), true)
		"plaza":
			pass
		_: 
			_box(cx, fy + 0.4, cz, Vector3(2, 0.8, 1), _mat("crate"), true)
	# Scatter small debris.
	for i in 3:
		var px := rect.position.x + 1.5 + rng.randf() * (rect.size.x - 3)
		var pz := rect.position.y + 1.5 + rng.randf() * (rect.size.y - 3)
		_cyl(px, fy + 0.05, pz, 0.15, 0.1, _mat("debris"), false)


func _desk(x: float, fy: float, z: float, _fy2: float) -> void:
	_box(Vector3(x, fy + 0.75, z), Vector3(1.8, 0.08, 0.9), _mat("wood"), true)
	for sx in [-0.8, 0.8]:
		for sz in [-0.35, 0.35]:
			_box(x + sx, fy + 0.35, z + sz, Vector3(0.06, 0.7, 0.06), _mat("metal_dark"), false)
	_cyl(x + 0.5, fy + 0.45, z + 0.2, 0.2, 0.5, _mat("machine"), false)


func _table(cx: float, fy: float, cz: float, w: float, d: float) -> void:
	_box(Vector3(cx, fy + 0.85, cz), Vector3(w, 0.08, d), _mat("metal"), true)
	for sx in [-w / 2 + 0.2, w / 2 - 0.2]:
		for sz in [-d / 2 + 0.2, d / 2 - 0.2]:
			_box(cx + sx, fy + 0.4, cz + sz, Vector3(0.08, 0.8, 0.08), _mat("metal_dark"), false)


func _add_room_light(inf: Dictionary, rect: Rect2) -> void:
	var fy := floor_y(inf["fi"])
	var cx := rect.position.x + rect.size.x / 2
	var cz := rect.position.y + rect.size.y / 2
	var theme: String = inf["theme"]
	var emergency := theme in ["security", "medical", "elevator", "power", "generator", "morgue", "final"]
	var color := Color(1.0, 0.25, 0.15) if emergency else Color(0.9, 0.92, 1.0)
	var energy := 1.0 if not emergency else 0.8
	var flicker := -1.0
	if theme in ["lab", "server", "maintenance", "workshop", "coolant"]:
		flicker = float((inf["c"] * 7 + inf["r"] * 3 + inf["fi"]) % 10) + 1.0
	_light(Vector3(cx, fy + ROOM_H - 0.5, cz), color, energy, 10.0, emergency, flicker)


func _build_corridor_features() -> void:
	# A few corridor lights at intersections and emergency strips.
	for fi in 4:
		var fy := floor_y(fi)
		for c in range(COLS - 1):
			for r in range(ROWS - 1):
				# intersection of vertical gap col and horizontal gap row
				var i := c * (SLOT_W + GAP) + SLOT_W
				var j := r * (SLOT_H + GAP) + SLOT_H
				var x := cell_x(i)
				var z := cell_z(j)
				var emergency := (i + j + fi) % 4 == 0
				var color := Color(1.0, 0.2, 0.12) if emergency else Color(0.75, 0.85, 1.0)
				_light(Vector3(x, fy + ROOM_H - 0.6, z), color,
					0.7 if emergency else 0.8, 8.0, emergency, -1.0)


# ---------------------------------------------------------------
# STAIRS
# ---------------------------------------------------------------

func _build_stairs() -> void:
	for link in links:
		if link["type"] != "stair":
			continue
		var c: int = link["c"]
		var r: int = link["r"]
		var lo: int = link["lo"]
		var hi: int = link["hi"]
		var y0 := floor_y(lo)
		var y1 := floor_y(hi)
		var rect := slot_rect_world(lo, c, r)
		var x0 := rect.position.x
		var x1 := x0 + rect.size.x
		var z0 := rect.position.y
		var z1 := z0 + rect.size.y
		var cx := (x0 + x1) / 2
		var cz := (z0 + z1) / 2
		var run := x1 - x0
		var rise := y1 - y0
		var slope := sqrt(run * run + rise * rise)
		var ang := atan2(rise, run)
		# Ramp: rises toward +x (east = hi side).
		var ramp := StaticBody3D.new()
		ramp.position = Vector3(cx, (y0 + y1) / 2 - 0.1, cz)
		ramp.rotation.z = ang
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(slope + 0.4, 0.3, z1 - z0 - 0.4)
		col.shape = shape
		ramp.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = shape.size
		mi.mesh = bm
		mi.material_override = _mat("metal")
		ramp.add_child(mi)
		add_child(ramp)
		# Base floor at lower level under ramp.
		_box(Vector3(cx, y0 - 0.15, cz), Vector3(x1 - x0, 0.3, z1 - z0), _mat("concrete_dark"), true, "concrete")
		# Tall side walls (north/south) from y0 to y1+ROOM_H.
		var wall_h := (y1 + ROOM_H) - y0
		_box(Vector3(cx, y0 + wall_h / 2, z0), Vector3(x1 - x0, wall_h, WALL_T), _mat("concrete_dark"), true)
		_box(Vector3(cx, y0 + wall_h / 2, z1), Vector3(x1 - x0, wall_h, WALL_T), _mat("concrete_dark"), true)
		# Ceiling at upper level.
		_box(Vector3(cx, y1 + ROOM_H + 0.15, cz), Vector3(x1 - x0, 0.3, z1 - z0), _mat("concrete_dark"), false)
		# End frames (visual): west low, east high.
		_box(Vector3(x0, y0 + ROOM_H / 2, cz), Vector3(WALL_T, ROOM_H, WALL_T * 6), _mat("concrete_dark"), false)
		_box(Vector3(x1, y1 + ROOM_H / 2, cz), Vector3(WALL_T, ROOM_H, WALL_T * 6), _mat("concrete_dark"), false)
		# Register link for monster pathfinding.
		links.append({"type": "ramp", "c": c, "r": r, "lo": lo, "hi": hi,
			"pos_lo": Vector3(x0 + 0.5, y0, cz), "pos_hi": Vector3(x1 - 0.5, y1, cz)})
		# Mark slot open for pathing on both floors.
		for fi in [lo, hi]:
			var k := slot_key(fi, c, r)
			slot_open[k] = {"N": true, "S": true, "E": true, "W": true}
			var rg := slot_cell_range(c, r)
			var mi2 := int((rg.x + rg.y) / 2)
			var mj2 := int((rg.z + rg.w) / 2)
			door_mids[k] = {
				"N": Vector2i(mi2, int(rg.z)), "S": Vector2i(mi2, int(rg.w)),
				"E": Vector2i(int(rg.y), mj2), "W": Vector2i(int(rg.x), mj2)}


# ---------------------------------------------------------------
# PATHFINDING (for monster)
# ---------------------------------------------------------------

func floor_index_for_y(y: float) -> int:
	var best := 0
	var bd := 999.0
	for fi in 4:
		var d := absf(y - floor_y(fi))
		if d < bd:
			bd = d
			best = fi
	return best


func pos_to_cell(fi: int, pos: Vector3) -> Vector2i:
	var i := int(round(pos.x / CELL + (total_cells_x - 1) / 2.0))
	var j := int(round(pos.z / CELL + (total_cells_z - 1) / 2.0))
	return Vector2i(clampi(i, 0, total_cells_x - 1), clampi(j, 0, total_cells_z - 1))


func cell_world(fi: int, cell: Vector2i) -> Vector3:
	return Vector3(cell_x(cell.x), floor_y(fi), cell_z(cell.y))


func cell_walkable(fi: int, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= total_cells_x or cell.y >= total_cells_z:
		return false
	var sk = cell_slot[fi][cell.y][cell.x]
	if sk == -1:
		return true
	var inf: Dictionary = infos.get(sk, {})
	var typ: String = inf.get("type", "")
	return typ in ["room", "secret", "elevator", "open", "stair", "start"]


func can_move(fi: int, a: Vector2i, b: Vector2i) -> bool:
	var sa = cell_slot[fi][a.y][a.x]
	var sb = cell_slot[fi][b.y][b.x]
	if sa == sb:
		return true
	if sa == -1 and sb == -1:
		return true
	# One corridor, one slot.
	var slot_key_str: String = sb if sa == -1 else sa
	var corridor: Vector2i = a if sa == -1 else b
	var room_cell: Vector2i = b if sa == -1 else a
	var inf: Dictionary = infos.get(slot_key_str, {})
	var typ: String = inf.get("type", "")
	if typ in ["open", "stair"]:
		return true
	if typ not in ["room", "secret", "elevator", "start"]:
		return false
	# Determine side and check door mid.
	var rg := slot_cell_range(inf["c"], inf["r"])
	var i0: int = rg.x; var i1: int = rg.y; var j0: int = rg.z; var j1: int = rg.w
	var side := ""
	var mid := Vector2i.ZERO
	if corridor.x == i0 - 1 and room_cell.x == i0 and corridor.y == room_cell.y:
		side = "W"; mid = Vector2i(i0, int((j0 + j1) / 2))
	elif corridor.x == i1 + 1 and room_cell.x == i1 and corridor.y == room_cell.y:
		side = "E"; mid = Vector2i(i1, int((j0 + j1) / 2))
	elif corridor.y == j0 - 1 and room_cell.y == j0 and corridor.x == room_cell.x:
		side = "N"; mid = Vector2i(int((i0 + i1) / 2), j0)
	elif corridor.y == j1 + 1 and room_cell.y == j1 and corridor.x == room_cell.x:
		side = "S"; mid = Vector2i(int((i0 + i1) / 2), j1)
	else:
		return false
	if room_cell != mid:
		return false
	var k := slot_key(fi, inf["c"], inf["r"])
	var opens: Dictionary = slot_open.get(k, {})
	return opens.has(side)


func find_path(from_pos: Vector3, to_pos: Vector3) -> Array:
	var fi0 := floor_index_for_y(from_pos.y)
	var fi1 := floor_index_for_y(to_pos.y)
	var c0 := pos_to_cell(fi0, from_pos)
	var c1 := pos_to_cell(fi1, to_pos)
	if fi0 == fi1:
		return _astar(fi0, c0, c1)
	# Use nearest elevator serving both floors.
	var best := {}
	var best_score := 1e18
	for e in elevators:
		var ec := Vector2i(e["c"], e["r"])
		# elevator cell on each floor: use slot center cell
		var rg := slot_cell_range(ec.x, ec.y)
		var mid := Vector2i(int((rg.x + rg.y) / 2), int((rg.z + rg.w) / 2))
		var d0 := Vector2(c0 - mid).length() + absf(fi0 - fi1)
		var d1 := Vector2(c1 - mid).length()
		var score := d0 + d1
		if score < best_score:
			best_score = score
			best = {"cell": mid}
	if best.is_empty():
		return []
	var mid: Vector2i = best["cell"]
	var p0 := _astar(fi0, c0, mid)
	var p1 := _astar(fi1, mid, c1)
	var link_pos0 := cell_world(fi0, mid)
	var link_pos1 := cell_world(fi1, mid)
	var out := []
	out.append_array(p0)
	out.append({"pos": link_pos0, "link": link_pos1})
	out.append_array(p1)
	return out


func _astar(fi: int, start: Vector2i, goal: Vector2i) -> Array:
	if not cell_walkable(fi, start):
		start = _nearest_walkable(fi, start)
	if not cell_walkable(fi, goal):
		goal = _nearest_walkable(fi, goal)
	if start == goal:
		return [{"pos": cell_world(fi, goal)}]
	var open := [start]
	var came := {}
	var gs := {start: 0}
	var fs := {start: _heur(start, goal)}
	var closed := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while open.size() > 0:
		# pick lowest f
		var bi := 0
		var bf := 1e18
		for i in open.size():
			var f: float = fs.get(open[i], 1e18)
			if f < bf:
				bf = f
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if cur == goal:
			return _build_path(fi, came, cur)
		closed[cur] = true
		for d in dirs:
			var nb: Vector2i = cur + d
			if closed.has(nb) or not cell_walkable(fi, nb):
				continue
			if not can_move(fi, cur, nb):
				continue
			var ng: int = gs.get(cur, 0) + 1
			if ng < gs.get(nb, 999999):
				came[nb] = cur
				gs[nb] = ng
				fs[nb] = ng + _heur(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return []


func _heur(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _nearest_walkable(fi: int, cell: Vector2i) -> Vector2i:
	if cell_walkable(fi, cell):
		return cell
	for rad in range(1, 8):
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if cell_walkable(fi, c):
					return c
	return cell


func _build_path(fi: int, came: Dictionary, goal: Vector2i) -> Array:
	var cells := [goal]
	var cur: Vector2i = goal
	while came.has(cur):
		cur = came[cur]
		cells.push_front(cur)
	var pts := []
	for c in cells:
		pts.append(cell_world(fi, c))
	if pts.is_empty():
		return []
	var out := [{"pos": pts[0]}]
	for i in range(1, pts.size() - 1):
		var d_in := _dir_between(pts[i - 1], pts[i])
		var d_out := _dir_between(pts[i], pts[i + 1])
		if d_in != d_out:
			out.append({"pos": pts[i]})
	out.append({"pos": pts[pts.size() - 1]})
	return out


func _dir_between(a: Vector3, b: Vector3) -> Vector2i:
	var sx := 1 if b.x > a.x else (-1 if b.x < a.x else 0)
	var sz := 1 if b.z > a.z else (-1 if b.z < a.z else 0)
	return Vector2i(sx, sz)
