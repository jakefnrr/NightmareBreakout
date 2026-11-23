extends CanvasLayer

var game: Node = null
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var current_id = ""
var current: Dictionary = {}
var run_id = 0
var widgets: Dictionary = {}


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build()


func _build() -> void:
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.05, 0.96)
	sb.border_color = Color(0.4, 0.7, 0.5, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(760, 560)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -280)
	panel.visible = false
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)


func is_blocking() -> bool:
	return panel.visible


func open(pid: String) -> void:
	if not game.puzzles.has(pid):
		return
	current_id = pid
	current = game.puzzles[pid]
	widgets.clear()
	run_id += 1
	for c in content.get_children():
		if c != status:
			c.queue_free()
	status.text = ""
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.pause_for_panel()
	_build_for_type(str(current.get("type", "keypad")))


func close() -> void:
	panel.visible = false
	game.resume_from_panel()


func _label(text: String, size = 20, color = Color(0.85, 0.95, 0.9)) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(l)
	return l


func _button(text: String, cb: Callable, minw = 90.0) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(minw, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	content.add_child(b)
	return b


func _row() -> HBoxContainer:
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	content.add_child(h)
	return h


func _build_for_type(t: String) -> void:
	match t:
		"keypad": _build_keypad()
		"safe": _build_safe()
		"pattern": _build_pattern()
		"circuit": _build_circuit()
		"gears": _build_gears()
		"frequency": _build_frequency()
		"valves": _build_valves()
		"weights": _build_weights()
		"order": _build_order()
		"logic": _build_logic()
		"memory": _build_memory()
		"pipes": _build_pipes()
		"magnetic": _build_magnetic()
		"object_place": _build_object_place()
		_: _build_keypad()


func _finish(ok: bool, msg = "") -> void:
	if ok:
		status.text = ""
		if game.audio:
			game.audio.play_sfx("puzzle_good")
		game.puzzle_solved(current_id)
		close()
	else:
		status.text = msg if msg != "" else "INCORRECT"
		if game.audio:
			game.audio.play_sfx("puzzle_bad")


# ---------------------------------------------------------------
# KEYPAD / SAFE
# ---------------------------------------------------------------

func _build_keypad() -> void:
	_label("ENTER ACCESS CODE", 26)
	var disp = Label.new()
	disp.text = ""
	disp.add_theme_font_size_override("font_size", 34)
	disp.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(disp)
	var buf = {"v": ""}
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for d in ["1","2","3","4","5","6","7","8","9","C","0","E"]:
		var b = Button.new()
		b.text = d
		b.custom_minimum_size = Vector2(90, 48)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func():
			if d == "C": buf.v = ""
			elif d == "E":
				_finish(buf.v == str(current.solution), "WRONG CODE")
			else: buf.v = (buf.v + d).right(6)
			disp.text = buf.v)
		grid.add_child(b)


func _build_safe() -> void:
	_label("COMBINATION SAFE", 26)
	var sol: Array = current.solution
	var vals = [0, 0, 0]
	var labels: Array[Label] = []
	for i in 3:
		var h = _row()
		var b1 = Button.new(); b1.text = "-"; b1.custom_minimum_size = Vector2(70, 48)
		b1.pressed.connect(func(): vals[i] = (vals[i] - 1 + 100) % 100; labels[i].text = "%02d" % vals[i])
		var l = Label.new(); l.text = "00"; l.add_theme_font_size_override("font_size", 34)
		l.custom_minimum_size = Vector2(90, 48); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b2 = Button.new(); b2.text = "+"; b2.custom_minimum_size = Vector2(70, 48)
		b2.pressed.connect(func(): vals[i] = (vals[i] + 1) % 100; labels[i].text = "%02d" % vals[i])
		h.add_child(b1); h.add_child(l); h.add_child(b2)
		labels.append(l)
	_button("TRY", func():
		_finish(vals[0] == int(sol[0]) and vals[1] == int(sol[1]) and vals[2] == int(sol[2]),
			"WRONG COMBINATION"))


# ---------------------------------------------------------------
# PATTERN (sequence memory)
# ---------------------------------------------------------------

func _build_pattern() -> void:
	_label("REPEAT THE SEQUENCE", 26)
	var sol: Array = current.solution
	var n = sol.size()
	var symbols = ["▲", "●", "■", "◆", "★", "✚"]
	var btns: Array[Button] = []
	var row = _row()
	for i in symbols.size():
		var b = Button.new()
		b.text = symbols[i]
		b.custom_minimum_size = Vector2(80, 70)
		b.add_theme_font_size_override("font_size", 30)
		var idx = i
		b.pressed.connect(func(): _pattern_input(idx, btns, sol))
		row.add_child(b)
		btns.append(b)
	var myrun = run_id
	_show_sequence(btns, sol, myrun)


func _show_sequence(btns: Array[Button], sol: Array, myrun: int) -> void:
	await get_tree().create_timer(0.6, true, false, true).timeout
	for idx in sol:
		if myrun != run_id or not panel.visible:
			return
		if idx < btns.size():
			btns[idx].modulate = Color(0.4, 1.0, 0.6)
		await get_tree().create_timer(0.28, true, false, true).timeout
		if idx < btns.size():
			btns[idx].modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.12, true, false, true).timeout
	await get_tree().create_timer(0.4, true, false, true).timeout
	if myrun == run_id and panel.visible:
		status.text = "YOUR TURN"


func _pattern_input(idx: int, btns: Array[Button], sol: Array) -> void:
	if status.text == "":
		return
	var entered: Array = widgets.get("entered", [])
	entered.append(idx)
	widgets["entered"] = entered
	btns[idx].modulate = Color(0.6, 0.8, 1.0)
	if entered.size() == sol.size():
		if entered == sol:
			_finish(true)
		else:
			widgets["entered"] = []
			for b in btns:
				b.modulate = Color(1, 1, 1)
			status.text = "SEQUENCE WRONG — TRY AGAIN"
			if game.audio:
				game.audio.play_sfx("puzzle_bad")


# ---------------------------------------------------------------
# CIRCUIT
# ---------------------------------------------------------------

func _build_circuit() -> void:
	_label("MATCH THE TARGET CIRCUIT", 26)
	var sol: Array = current.solution
	var states = []
	for i in sol.size():
		states.append(false)
	var btns: Array[Button] = []
	var row = _row()
	for i in sol.size():
		var b = Button.new()
		b.text = "OFF"
		b.custom_minimum_size = Vector2(90, 50)
		var idx = i
		b.pressed.connect(func():
			states[idx] = not states[idx]
			b.text = "ON" if states[idx] else "OFF"
			b.modulate = Color(0.5, 1.0, 0.6) if states[idx] else Color(1, 1, 1))
		row.add_child(b)
		btns.append(b)
	# Target display
	var target = _row()
	for v in sol:
		var l = Label.new()
		l.text = "●" if v else "○"
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if v else Color(0.5, 0.5, 0.5))
		target.add_child(l)
	_button("TEST CIRCUIT", func():
		var ok = true
		for i in sol.size():
			if states[i] != bool(sol[i]):
				ok = false
		_finish(ok, "CIRCUIT MISMATCH"))


# ---------------------------------------------------------------
# GEARS
# ---------------------------------------------------------------

func _build_gears() -> void:
	_label("ALIGN ALL GEAR MARKERS", 26)
	var sol: Array = current.solution
	var pos = [0, 0, 0]
	var labels: Array[Label] = []
	for i in 3:
		var h = _row()
		var b1 = Button.new(); b1.text = "◀"; b1.custom_minimum_size = Vector2(70, 50)
		var b2 = Button.new(); b2.text = "▶"; b2.custom_minimum_size = Vector2(70, 50)
		var l = Label.new(); l.text = "0"; l.add_theme_font_size_override("font_size", 30)
		l.custom_minimum_size = Vector2(120, 50); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx = i
		b1.pressed.connect(func(): pos[idx] = (pos[idx] + 7) % 8; labels[idx].text = str(pos[idx]))
		b2.pressed.connect(func(): pos[idx] = (pos[idx] + 1) % 8; labels[idx].text = str(pos[idx]))
		h.add_child(b1); h.add_child(l); h.add_child(b2)
		labels.append(l)
	_button("CHECK ALIGNMENT", func():
		var ok = true
		for i in 3:
			if pos[i] != int(sol[i]):
				ok = false
		_finish(ok, "GEARS MISALIGNED"))


# ---------------------------------------------------------------
# FREQUENCY
# ---------------------------------------------------------------

func _build_frequency() -> void:
	_label("TUNE TO TARGET FREQUENCY", 26)
	var sol: float = float(current.solution)
	var freq = 92.0
	var disp = Label.new()
	disp.add_theme_font_size_override("font_size", 36)
	disp.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(disp)
	var h = _row()
	var b1 = Button.new(); b1.text = "-0.1"; b1.custom_minimum_size = Vector2(100, 48)
	var b2 = Button.new(); b2.text = "+0.1"; b2.custom_minimum_size = Vector2(100, 48)
	b1.pressed.connect(func(): freq = maxf(87.5, freq - 0.1); disp.text = "%.1f MHz" % freq)
	b2.pressed.connect(func(): freq = minf(108.0, freq + 0.1); disp.text = "%.1f MHz" % freq)
	h.add_child(b1); h.add_child(disp); h.add_child(b2)
	disp.text = "%.1f MHz" % freq
	_button("LOCK FREQUENCY", func():
		_finish(absf(freq - sol) < 0.051, "NO CARRIER — WRONG FREQUENCY"))


# ---------------------------------------------------------------
# VALVES
# ---------------------------------------------------------------

func _build_valves() -> void:
	_label("SET VALVE PRESSURES", 26)
	var sol: Array = current.solution
	var vals = [0, 0, 0]
	for i in 3:
		var h = _row()
		_label("VALVE %d" % (i + 1), 18, Color(0.7, 0.9, 0.8))
		var b1 = Button.new(); b1.text = "-"; b1.custom_minimum_size = Vector2(60, 44)
		var b2 = Button.new(); b2.text = "+"; b2.custom_minimum_size = Vector2(60, 44)
		var l = Label.new(); l.text = "0"; l.add_theme_font_size_override("font_size", 26)
		l.custom_minimum_size = Vector2(70, 44); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var idx = i
		b1.pressed.connect(func(): vals[idx] = max(0, vals[idx] - 1); l.text = str(vals[idx]))
		b2.pressed.connect(func(): vals[idx] = min(10, vals[idx] + 1); l.text = str(vals[idx]))
		h.add_child(b1); h.add_child(l); h.add_child(b2)
	_button("OPEN VALVES", func():
		var ok = true
		for i in 3:
			if vals[i] != int(sol[i]):
				ok = false
		_finish(ok, "PRESSURE MISMATCH"))


# ---------------------------------------------------------------
# WEIGHTS
# ---------------------------------------------------------------

func _build_weights() -> void:
	_label("BALANCE THE SCALE", 26)
	var target: int = int(current.solution)
	_label("RIGHT PAN TOTAL: %d" % target, 22, Color(0.9, 0.8, 0.5))
	var weights = [1, 2, 5, 10]
	var on = [false, false, false, false]
	var btns: Array[Button] = []
	var row = _row()
	for i in weights.size():
		var b = Button.new()
		b.text = str(weights[i])
		b.custom_minimum_size = Vector2(90, 50)
		var idx = i
		b.pressed.connect(func():
			on[idx] = not on[idx]
			b.modulate = Color(0.5, 1.0, 0.6) if on[idx] else Color(1, 1, 1))
		row.add_child(b)
		btns.append(b)
	_button("CHECK BALANCE", func():
		var sum = 0
		for i in weights.size():
			if on[i]:
				sum += weights[i]
		_finish(sum == target, "SCALE NOT BALANCED"))


# ---------------------------------------------------------------
# ORDER
# ---------------------------------------------------------------

func _build_order() -> void:
	_label("ACTIVATE IN CORRECT ORDER", 26)
	var sol: Array = current.solution
	var names: Array = current.get("names", ["A", "B", "C", "D"])
	var entered: Array = []
	var row = _row()
	for i in names.size():
		var b = Button.new()
		b.text = str(names[i])
		b.custom_minimum_size = Vector2(110, 60)
		b.add_theme_font_size_override("font_size", 24)
		var idx = i
		b.pressed.connect(func():
			entered.append(idx)
			if entered.size() == sol.size():
				_finish(entered == sol, "WRONG ORDER")
				if status.text != "":
					entered.clear())
		row.add_child(b)


# ---------------------------------------------------------------
# LOGIC
# ---------------------------------------------------------------

func _build_logic() -> void:
	_label("EVALUATE THE CIRCUIT", 26)
	var lines: Array = current.get("lines", [])
	for ln in lines:
		_label(str(ln), 18, Color(0.7, 0.85, 0.8))
	var sol: bool = bool(current.solution)
	var row = _row()
	_button("OUTPUT = TRUE", func(): _finish(sol == true, "WRONG OUTPUT"), 220)
	_button("OUTPUT = FALSE", func(): _finish(sol == false, "WRONG OUTPUT"), 220)


# ---------------------------------------------------------------
# MEMORY (which item moved)
# ---------------------------------------------------------------

func _build_memory() -> void:
	_label("MEMORIZE THE DISPLAY", 26)
	var sol: int = int(current.solution)
	var symbols = ["▲", "●", "■", "◆", "★", "✚"]
	var btns: Array[Button] = []
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for i in symbols.size():
		var b = Button.new()
		b.text = symbols[i]
		b.custom_minimum_size = Vector2(120, 80)
		b.add_theme_font_size_override("font_size", 34)
		var idx = i
		b.pressed.connect(func(): _finish(idx == sol, "WRONG POSITION"))
		grid.add_child(b)
		btns.append(b)
	var myrun = run_id
	_memorize(btns, sol, myrun)


func _memorize(btns: Array[Button], sol: int, myrun: int) -> void:
	status.text = "WATCH..."
	for i in btns.size():
		if myrun != run_id or not panel.visible:
			return
		btns[i].modulate = Color(0.4, 1.0, 0.6)
		await get_tree().create_timer(0.22, true, false, true).timeout
		btns[i].modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.05, true, false, true).timeout
	await get_tree().create_timer(0.5, true, false, true).timeout
	if myrun != run_id or not panel.visible:
		return
	if sol >= 0 and sol < btns.size():
		btns[sol].text = "✖"
		await get_tree().create_timer(1.6, true, false, true).timeout
		if myrun != run_id or not panel.visible:
			return
	for i in btns.size():
		btns[i].text = str(i + 1)
	status.text = "WHICH POSITION CHANGED?"


# ---------------------------------------------------------------
# PIPES
# ---------------------------------------------------------------

func _build_pipes() -> void:
	_label("CONNECT INLET TO OUTLET", 26)
	var sol: Array = current.solution
	var dirs = {"N": 0, "E": 1, "S": 2, "W": 3}
	var shapes = {
		"straight": [dirs.E, dirs.W],
		"elbow": [dirs.N, dirs.E],
		"tee": [dirs.N, dirs.E, dirs.S],
		"cross": [dirs.N, dirs.E, dirs.S, dirs.W],
	}
	# Each piece: [shape, base_rot]
	var pieces = [
		["elbow", 0], ["straight", 0],
		["tee", 0], ["elbow", 0],
	]
	var rots = [0, 0, 0, 0]
	var btns: Array[Button] = []
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for i in pieces.size():
		var b = Button.new()
		b.custom_minimum_size = Vector2(160, 100)
		b.add_theme_font_size_override("font_size", 16)
		var idx = i
		b.pressed.connect(func():
			rots[idx] = (rots[idx] + 1) % 4
			_update_pipe_label(b, pieces[idx][0], rots[idx]))
		grid.add_child(b)
		btns.append(b)
		_update_pipe_label(b, pieces[idx][0], 0)
	_label("CLICK A PIPE TO ROTATE IT", 16, Color(0.6, 0.8, 0.7))
	_button("TEST FLOW", func(): _finish(_pipes_connected(pieces, rots, shapes), "NO FLOW"))


func _update_pipe_label(b: Button, shape: String, rot: int) -> void:
	var arrows = ["↑", "→", "↓", "←"]
	var base = {
		"straight": [1, 3], "elbow": [0, 1], "tee": [0, 1, 2], "cross": [0, 1, 2, 3]
	}
	var ds: Array = base[shape]
	var names = []
	for d in ds:
		var nd = (d + rot) % 4
		names.append(arrows[nd])
	b.text = shape.to_upper() + "\n" + " ".join(names)


func _pipe_dirs(shape: String, rot: int) -> Array:
	var base = {
		"straight": [1, 3], "elbow": [0, 1], "tee": [0, 1, 2], "cross": [0, 1, 2, 3]
	}
	var out = []
	for d in base[shape]:
		out.append((int(d) + rot) % 4)
	return out


func _pipes_connected(pieces: Array, rots: Array, shapes: Dictionary) -> bool:
	# 2x2 grid; inlet at left of cell0, outlet at right of cell3.
	# cell index: 0=(0,0) 1=(1,0) 2=(0,1) 3=(1,1)
	var cell_dirs = []
	for i in pieces.size():
		cell_dirs.append(_pipe_dirs(pieces[i][0], rots[i]))
	# adjacency offsets: E=+1 (same row), W=-1, S=+2 (next row), N=-2
	var coords = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var index_of = {}
	for i in coords.size():
		index_of[coords[i]] = i
	var opp = {0: 2, 1: 3, 2: 0, 3: 1}
	var delta = {0: Vector2i(0, -1), 1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0)}
	var visited = [false, false, false, false]
	var queue = [0]
	visited[0] = true
	while queue.size() > 0:
		var ci: int = queue.pop_front()
		var dirs: Array = cell_dirs[ci]
		for d in dirs:
			var np: Vector2i = coords[ci] + delta[d]
			if index_of.has(np):
				var ni: int = index_of[np]
				if not visited[ni] and opp[d] in cell_dirs[ni]:
					visited[ni] = true
					queue.append(ni)
	# outlet east of cell3 requires dir E (1) open on cell3; inlet west of cell0 needs dir W (3)
	return (3 in cell_dirs[0]) and visited[3] and (1 in cell_dirs[3])


# ---------------------------------------------------------------
# MAGNETIC
# ---------------------------------------------------------------

func _build_magnetic() -> void:
	_label("SET MAGNET POLARITIES", 26)
	var sol: Array = current.solution
	var states = [1, 1, 1]
	var labels: Array[Label] = []
	for i in 3:
		var h = _row()
		_label("MAGNET %d" % (i + 1), 18)
		var b = Button.new()
		b.text = "N"
		b.custom_minimum_size = Vector2(120, 50)
		b.add_theme_font_size_override("font_size", 22)
		var idx = i
		b.pressed.connect(func():
			states[idx] = -states[idx]
			b.text = "N" if states[idx] == 1 else "S"
			labels[idx].text = "FIELD ↑" if states[idx] == 1 else "FIELD ↓")
		var l = Label.new(); l.text = "FIELD ↑"; l.add_theme_font_size_override("font_size", 18)
		l.custom_minimum_size = Vector2(120, 50)
		h.add_child(b); h.add_child(l)
		labels.append(l)
	_button("TEST FIELD", func():
		var ok = true
		for i in 3:
			if states[i] != int(sol[i]):
				ok = false
		_finish(ok, "FIELD COLLAPSED"))


# ---------------------------------------------------------------
# OBJECT PLACEMENT
# ---------------------------------------------------------------

func _build_object_place() -> void:
	_label("PLACE OBJECTS IN MATCHING SLOTS", 26)
	var sol: Dictionary = current.solution
	var item_names: Array = current.get("item_names", ["CUBE", "SPHERE", "CONE", "RING"])
	var slot_names: Array = current.get("slot_names", ["SLOT A", "SLOT B", "SLOT C", "SLOT D"])
	var placed = {}
	var slot_btns: Array[Button] = []
	widgets["selected_slot"] = -1
	widgets["placed"] = placed
	widgets["item_names"] = item_names
	widgets["slot_btns"] = slot_btns
	var row = _row()
	for i in slot_names.size():
		var b = Button.new()
		b.text = str(slot_names[i]) + "\n[empty]"
		b.custom_minimum_size = Vector2(150, 70)
		var idx = i
		b.pressed.connect(func(): _select_slot(idx))
		slot_btns.append(b)
		row.add_child(b)
	var row2 = _row()
	for i in item_names.size():
		var b = Button.new()
		b.text = str(item_names[i])
		b.custom_minimum_size = Vector2(120, 50)
		var idx = i
		b.pressed.connect(func(): _place_selected_item(idx))
		row2.add_child(b)
	_label("CLICK A SLOT, THEN AN OBJECT", 16, Color(0.6, 0.8, 0.7))
	_button("CHECK PLACEMENT", func():
		var ok = placed.size() == sol.size()
		for s in sol.keys():
			if int(placed.get(s, -1)) != int(sol[s]):
				ok = false
		_finish(ok, "OBJECTS REJECTED"))


func _select_slot(i: int) -> void:
	widgets["selected_slot"] = i
	status.text = "SLOT %d SELECTED" % (i + 1)


func _place_selected_item(item_idx: int) -> void:
	var slot: int = widgets.get("selected_slot", -1)
	if slot < 0:
		status.text = "SELECT A SLOT FIRST"
		return
	var placed: Dictionary = widgets["placed"]
	var slot_btns: Array[Button] = widgets["slot_btns"]
	var item_names: Array = widgets["item_names"]
	placed[slot] = item_idx
	slot_btns[slot].text = "SLOT %d\n%s" % [slot + 1, str(item_names[item_idx])]
	status.text = ""
