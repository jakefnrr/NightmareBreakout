extends Node3D

const WALL_H = 3.2
const WALL_T = 0.3
const DOOR_W = 2.4
const DOOR_H = 2.3

var game: Node = null
var rooms := {}
var points := {}
var sec_fixtures := []


func build(g: Node) -> void:
	game = g
	_build_shell()
	_build_room("r1", Rect2(-24, -6, 12, 12), _mat("concrete"), _mat("concrete_dark"), [
		{"side": "E", "at": 0.0, "door": "door_r1_r2"},
		{"side": "E", "at": 3.5, "door": "door_r1_r2_secret"},
	])
	_build_room("ws", Rect2(-12, -16, 16, 10), _mat("concrete_dark"), _mat("concrete_dark"), [
		{"side": "S", "at": -4.0, "door": "door_r2_ws"},
	])
	_build_room("r2", Rect2(-12, -6, 16, 12), _mat("wall_paint"), _mat("concrete"), [
		{"side": "W", "at": 0.0, "door": "door_r1_r2"},
		{"side": "W", "at": 3.5, "door": "door_r1_r2_secret"},
		{"side": "E", "at": 0.0, "door": "door_r2_sec"},
		{"side": "S", "at": -4.0, "door": "door_r2_vg"},
		{"side": "N", "at": -4.0, "door": "door_r2_ws"},
	])
	_build_room("sec", Rect2(4, -6, 12, 12), _mat("metal_dark"), _mat("concrete_dark"), [
		{"side": "W", "at": 0.0, "door": "door_r2_sec"},
	])
	_build_room("vg", Rect2(-12, 6, 16, 8), _mat("wall_paint"), _mat("tile"), [
		{"side": "N", "at": -4.0, "door": "door_r2_vg"},
	])
	_decorate()
	_doors()
	_security_fixtures()


func _mat(key: String) -> Material:
	return game.mats.get(key, game.mats["concrete"])


func room_rect(id: String) -> Rect2:
	return rooms[id]["rect"]


func room_center(id: String) -> Vector3:
	return rooms[id]["center"]


# ---------------------------------------------------------------
# SHELL / GROUND
# ---------------------------------------------------------------

func _build_shell() -> void:
	# Outer ground slab + boundary walls so the block reads as one building.
	var x0 = -25.0; var x1 = 17.0; var z0 = -17.0; var z1 = 15.0
	_box(Vector3((x0 + x1) / 2, -0.3, (z0 + z1) / 2), Vector3(x1 - x0, 0.3, z1 - z0),
		_mat("concrete_dark"), true, "concrete")
	var h = WALL_H + 0.6
	_box(Vector3((x0 + x1) / 2, h / 2, z0), Vector3(x1 - x0, h, WALL_T), _mat("concrete_dark"), true)
	_box(Vector3((x0 + x1) / 2, h / 2, z1), Vector3(x1 - x0, h, WALL_T), _mat("concrete_dark"), true)
	_box(Vector3(x0, h / 2, (z0 + z1) / 2), Vector3(WALL_T, h, z1 - z0), _mat("concrete_dark"), true)
	_box(Vector3(x1, h / 2, (z0 + z1) / 2), Vector3(WALL_T, h, z1 - z0), _mat("concrete_dark"), true)
	_box(Vector3((x0 + x1) / 2, h + 0.1, (z0 + z1) / 2), Vector3(x1 - x0, 0.2, z1 - z0),
		_mat("concrete_dark"), false)


# ---------------------------------------------------------------
# ROOMS
# ---------------------------------------------------------------

func _build_room(id: String, rect: Rect2, floor_mat: Material, ceil_mat: Material,
		gaps: Array) -> void:
	var w = rect.size.x; var d = rect.size.y
	var cx = rect.position.x + w / 2; var cz = rect.position.y + d / 2
	rooms[id] = {"rect": rect, "center": Vector3(cx, 0, cz)}
	# Floor / ceiling (top of floor at y=0).
	_box(Vector3(cx, -0.1, cz), Vector3(w, 0.2, d), floor_mat, true, "concrete")
	_box(Vector3(cx, WALL_H + 0.1, cz), Vector3(w, 0.2, d), ceil_mat, false)
	# Walls with door gaps.
	var by_side := {}
	for g in gaps:
		by_side[g["side"]] = []
		by_side[g["side"]].append(g)
	for side in ["N", "S", "W", "E"]:
		_wall_side(rect, side, by_side.get(side, []))


func _wall_side(rect: Rect2, side: String, gaps: Array) -> void:
	var x0 = rect.position.x; var z0 = rect.position.y
	var x1 = x0 + rect.size.x; var z1 = z0 + rect.size.y
	var horizontal = side == "N" or side == "S"
	var a0 = x0 if horizontal else z0
	var a1 = x1 if horizontal else z1
	var fixed = 0.0
	match side:
		"N": fixed = z0 + WALL_T / 2
		"S": fixed = z1 - WALL_T / 2
		"W": fixed = x0 + WALL_T / 2
		"E": fixed = x1 - WALL_T / 2
	var gs = gaps.duplicate()
	gs.sort_custom(func(a, b): return a["at"] < b["at"])
	var prev = a0
	var mat = _mat("wall_paint") if side in ["N", "S"] else _mat("concrete_dark")
	for g in gs:
		var c = float(g["at"]); var gw = float(g.get("w", DOOR_W))
		var g0 = c - gw / 2; var g1 = c + gw / 2
		if g0 - prev > 0.05:
			_seg(fixed, prev, g0, horizontal, mat)
		# Lintel above the doorway.
		_lintel(fixed, g0, g1, horizontal, mat)
		prev = g1
	if a1 - prev > 0.05:
		_seg(fixed, prev, a1, horizontal, mat)


func _seg(fixed: float, a0: float, a1: float, horizontal: bool, mat: Material) -> void:
	var mid = (a0 + a1) / 2; var len = a1 - a0
	if horizontal:
		_box(Vector3(mid, WALL_H / 2, fixed), Vector3(len, WALL_H, WALL_T), mat, true)
	else:
		_box(Vector3(fixed, WALL_H / 2, mid), Vector3(WALL_T, WALL_H, len), mat, true)


func _lintel(fixed: float, a0: float, a1: float, horizontal: bool, mat: Material) -> void:
	var mid = (a0 + a1) / 2; var len = a1 - a0
	var y = DOOR_H + (WALL_H - DOOR_H) / 2; var hh = WALL_H - DOOR_H
	if horizontal:
		_box(Vector3(mid, y, fixed), Vector3(len, hh, WALL_T), mat, false)
	else:
		_box(Vector3(fixed, y, mid), Vector3(WALL_T, hh, len), mat, false)


# ---------------------------------------------------------------
# DOORS
# ---------------------------------------------------------------

func _doors() -> void:
	# id, position, horizontal (N/S wall => panel width along x), req
	_door("door_r1_r2", Vector3(-12, DOOR_H / 2, 0), false, {"key": "gold_key"})
	_door("door_r1_r2_secret", Vector3(-12, DOOR_H / 2, 3.5), false, {})
	game.doors["door_r1_r2_secret"]["mesh"].material_override = _mat("concrete_dark")
	_door("door_r2_ws", Vector3(-4, DOOR_H / 2, -6), true, {"key": "key_power"})
	_door("door_r2_sec", Vector3(4, DOOR_H / 2, 0), false, {"cell": "power_cell"})
	_door("door_r2_vg", Vector3(-4, DOOR_H / 2, 6), true, {"key": "key_vg"})


func _door(id: String, pos: Vector3, horizontal: bool, req: Dictionary) -> void:
	var size = Vector3(DOOR_W, DOOR_H, 0.7) if horizontal else Vector3(0.7, DOOR_H, DOOR_W)
	var body = StaticBody3D.new()
	body.position = pos
	body.set_meta("interact", {"type": "door", "id": id, "prompt": "DOOR"})
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new(); shape.size = size
	col.shape = shape; col.name = "Col"
	body.add_child(col)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = _mat("door")
	mi.name = "Mesh"
	body.add_child(mi)
	add_child(body)
	game.doors[id] = {"id": id, "node": body, "col": col, "mesh": mi,
		"open": false, "req": req, "horizontal": horizontal}


# ---------------------------------------------------------------
# DECOR / SECURITY FIXTURES
# ---------------------------------------------------------------

func _c(r: String, dx: float, dz: float, y := 0.0) -> Vector3:
	var c: Vector3 = rooms[r]["center"]
	return Vector3(c.x + dx, y, c.z + dz)


func _decorate() -> void:
	# Main Room 1: storage boxes + mattress.
	_box(_c("r1", -3.5, -3.5, 0.5), Vector3(1.4, 1.0, 1.4), _mat("crate"), true, "wood")
	_box(_c("r1", -1.8, -3.8, 0.4), Vector3(1.2, 0.8, 1.2), _mat("crate"), true, "wood")
	_box(_c("r1", -3.6, -2.0, 0.35), Vector3(1.0, 0.7, 1.0), _mat("crate"), true, "wood")
	_box(_c("r1", 3.5, 3.5, 0.25), Vector3(2.2, 0.5, 1.2), _mat("sheet"), true, "carpet")
	# Table in Room 1 (holds the gold key).
	var tc = _c("r1", 0, -1)
	_box(Vector3(tc.x, 0.78, tc.z), Vector3(1.7, 0.07, 0.95), _mat("wood"), true, "wood")
	for sx in [-0.75, 0.75]:
		for sz in [-0.4, 0.4]:
			_box(Vector3(tc.x + sx, 0.36, tc.z + sz), Vector3(0.07, 0.72, 0.07), _mat("wood"), false)
	# Crates hiding the secret door on the east wall.
	_box(_c("r1", 4.0, 4.2, 0.5), Vector3(1.3, 1.0, 1.3), _mat("crate"), true, "wood")
	_box(_c("r1", 4.0, 2.6, 0.45), Vector3(1.2, 0.9, 1.1), _mat("crate"), true, "wood")
	_box(_c("r1", 3.4, 3.4, 0.3), Vector3(0.9, 0.6, 0.9), _mat("crate"), true, "wood")
	# Main Room 2: desks + shelf + storage.
	_desk(_c("r2", -4, -3.5))
	_desk(_c("r2", 3.5, -3.5))
	_box(_c("r2", 5.5, 4.5, 1.1), Vector3(2.5, 2.2, 0.6), _mat("metal_dark"), true)
	_box(_c("r2", -5.5, 4.0, 0.6), Vector3(1.8, 1.2, 1.2), _mat("crate"), true, "wood")
	# Workspace: workbenches + shelves + pipes.
	_table(_c("ws", -3, -2.5))
	_table(_c("ws", 2.5, 1.5))
	_box(_c("ws", -5.0, 3.0, 1.2), Vector3(0.6, 2.4, 3.0), _mat("metal_dark"), true)
	_box(_c("ws", -3.6, 3.0, 1.9), Vector3(0.6, 2.4, 3.0), _mat("metal_dark"), true)
	_box(_c("ws", 5.0, -3.5, 0.7), Vector3(1.6, 1.4, 1.0), _mat("machine_dark"), true)
	_cyl(_c("ws", 4.2, -4.0, 0.8), 0.3, 1.6, _mat("pipe"), true)
	# Security room dressing (lights handled separately).
	_desk(_c("sec", -2.5, -3.0))
	_desk(_c("sec", 2.0, -3.0))
	for i in 3:
		_box(_c("sec", 4.6, -4.5 + i * 1.6, 1.0), Vector3(0.8, 2.0, 1.2), _mat("machine_dark"), true)
	_box(_c("sec", -4.8, 3.8, 0.8), Vector3(1.4, 1.6, 0.8), _mat("machine"), true)
	# Video game room: carpet + cabinets + posters.
	_box(_c("vg", 0, 0, 0.03), Vector3(10, 0.06, 6), _mat("carpet"), false, "carpet")
	_box(_c("vg", -5.5, -2.5, 0.9), Vector3(0.9, 1.8, 1.8), _mat("machine_dark"), true)
	_box(_c("vg", 5.5, 2.5, 0.9), Vector3(0.9, 1.8, 1.8), _mat("machine_dark"), true)
	for i in 3:
		var px = _c("vg", -4 + i * 4, -3.4, 1.6)
		var poster = MeshInstance3D.new()
		var pm = BoxMesh.new(); pm.size = Vector3(1.4, 1.8, 0.05)
		poster.mesh = pm
		poster.material_override = _mat("wall_paint") if i % 2 == 0 else _mat("carpet")
		poster.position = px
		add_child(poster)
	# Trim + fixtures for every room.
	for rid in ["r1", "r2", "ws", "sec", "vg"]:
		_trims(rid)
	_fixture("r1", "fixture_warm")
	_fixture("r2", "fixture_cool")
	_fixture("ws", "fixture_cool")
	_fixture("vg", "fixture_purple")
	# Generous interact zones on desk monitors.
	for d in [_c("r2", -4, -3.5), _c("r2", 3.5, -3.5), _c("sec", -2.5, -3.0), _c("sec", 2.0, -3.0)]:
		_zone(Vector3(d.x + 0.4, 1.05, d.z - 0.2), Vector3(1.1, 0.8, 0.9),
			{"type": "computer", "id": "desk", "prompt": "MONITOR"})


func _trims(rid: String) -> void:
	var r: Rect2 = rooms[rid]["rect"]
	var x0 = r.position.x; var z0 = r.position.y
	var x1 = x0 + r.size.x; var z1 = z0 + r.size.y
	var ix0 = x0 + WALL_T; var iz0 = z0 + WALL_T
	var ix1 = x1 - WALL_T; var iz1 = z1 - WALL_T
	var bm = _mat("concrete_dark")
	# Baseboards along inner wall faces.
	_box(Vector3((ix0 + ix1) / 2, 0.07, iz0 + 0.03), Vector3(ix1 - ix0, 0.14, 0.05), bm, false)
	_box(Vector3((ix0 + ix1) / 2, 0.07, iz1 - 0.03), Vector3(ix1 - ix0, 0.14, 0.05), bm, false)
	_box(Vector3(ix0 + 0.03, 0.07, (iz0 + iz1) / 2), Vector3(0.05, 0.14, iz1 - iz0), bm, false)
	_box(Vector3(ix1 - 0.03, 0.07, (iz0 + iz1) / 2), Vector3(0.05, 0.14, iz1 - iz0), bm, false)
	# Corner conduit pipes.
	for cx in [ix0 + 0.15, ix1 - 0.15]:
		for cz in [iz0 + 0.15, iz1 - 0.15]:
			_cyl(Vector3(cx, WALL_H / 2, cz), 0.07, WALL_H, _mat("pipe"), false)


func _fixture(rid: String, key: String) -> void:
	var c: Vector3 = rooms[rid]["center"]
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(1.5, 0.07, 0.45)
	mi.mesh = bm
	mi.material_override = game.mats.get(key, game.mats["screen"])
	mi.position = Vector3(c.x, WALL_H - 0.12, c.z)
	add_child(mi)


func _zone(center: Vector3, size: Vector3, data: Dictionary) -> void:
	var body = StaticBody3D.new()
	body.position = center
	body.set_meta("interact", data)
	var col = CollisionShape3D.new()
	var s = BoxShape3D.new(); s.size = size
	col.shape = s
	body.add_child(col)
	add_child(body)


func _desk(center: Vector3) -> void:
	_box(Vector3(center.x, 0.75, center.z), Vector3(1.8, 0.08, 0.9), _mat("wood"), true, "wood")
	for sx in [-0.8, 0.8]:
		for sz in [-0.35, 0.35]:
			_box(Vector3(center.x + sx, 0.35, center.z + sz), Vector3(0.06, 0.7, 0.06), _mat("metal_dark"), false)
	# Monitor.
	_box(Vector3(center.x + 0.4, 1.05, center.z - 0.2), Vector3(0.7, 0.5, 0.06), _mat("monitor"), false)


func _table(center: Vector3) -> void:
	_box(Vector3(center.x, 0.85, center.z), Vector3(2.2, 0.08, 1.0), _mat("metal"), true, "metal")
	for sx in [-0.9, 0.9]:
		for sz in [-0.4, 0.4]:
			_box(Vector3(center.x + sx, 0.4, center.z + sz), Vector3(0.08, 0.8, 0.08), _mat("metal_dark"), false)


func _security_fixtures() -> void:
	# Ceiling light fixtures (emissive panels) in the security room; actual
	# OmniLights are created by main so they can be switched.
	var r = rooms["sec"]["rect"]
	for i in 2:
		var fx = r.position.x + 3.0 + i * 6.0
		var fz = r.position.y + r.size.y / 2
		var panel = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = Vector3(1.6, 0.08, 0.5)
		panel.mesh = bm
		panel.material_override = _mat("screen")
		panel.position = Vector3(fx, WALL_H - 0.15, fz)
		add_child(panel)
		sec_fixtures.append(panel)


# ---------------------------------------------------------------
# PRIMITIVES
# ---------------------------------------------------------------

func _box(center: Vector3, size: Vector3, mat: Material, collide = true,
		surface = "", parent: Node = null) -> StaticBody3D:
	var p: Node = parent if parent else self
	if not collide:
		var mi = MeshInstance3D.new()
		var bm = BoxMesh.new(); bm.size = size
		mi.mesh = bm; mi.material_override = mat; mi.position = center
		p.add_child(mi)
		return null
	var body = StaticBody3D.new()
	body.position = center
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new(); shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat
	body.add_child(mi)
	if surface != "":
		body.set_meta("surface", surface)
	p.add_child(body)
	return body


func _cyl(center: Vector3, radius: float, height: float, mat: Material,
		collide = true, parent: Node = null) -> StaticBody3D:
	var p: Node = parent if parent else self
	if not collide:
		var mi = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height
		mi.mesh = cm; mi.material_override = mat; mi.position = center
		p.add_child(mi)
		return null
	var body = StaticBody3D.new()
	body.position = center
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius; shape.height = height
	col.shape = shape
	body.add_child(col)
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = radius; cm.bottom_radius = radius; cm.height = height
	mi.mesh = cm; mi.material_override = mat
	body.add_child(mi)
	p.add_child(body)
	return body
