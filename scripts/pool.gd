extends CanvasLayer

var game: Node = null
var ui_font: Font = null
var open_flag = false
var table: Control = null
var status_label: Label
var msg_label: Label
var over_box: VBoxContainer

# Table geometry (local coords inside the Control).
var FELT := Rect2(Vector2(30, 30), Vector2(560, 300))
var BALL_R := 9.0
var POCKET_R := 20.0

var balls: Array = []  # {pos, vel, color, num, active, group("solid"/"stripe"/"")}
var panel: PanelContainer = null
var xbtn: Button = null
var cue_num := 0
var aiming := false
var aim_from := Vector2.ZERO
var aim_to := Vector2.ZERO
var player_group := ""
var shot_in_progress := false
var msg_timer := 0.0


func _ready() -> void:
	game = get_node("/root/Main")
	ui_font = SystemFont.new()
	ui_font.font_names = ["Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans", "sans-serif"]
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build()


func is_open() -> bool:
	return open_flag


func _build() -> void:
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.03, 0.97)
	sb.border_color = Color(0.2, 0.7, 0.4, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(660, 560)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -280)
	panel.visible = false
	add_child(panel)
	# X button — top right of the screen, same as BACK.
	xbtn = Button.new()
	xbtn.text = "X"
	xbtn.custom_minimum_size = Vector2(56, 56)
	xbtn.add_theme_font_size_override("font_size", 30)
	xbtn.add_theme_font_override("font", ui_font)
	xbtn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	xbtn.position = Vector2(-70, 20)
	xbtn.pressed.connect(func(): back())
	xbtn.visible = false
	add_child(xbtn)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var title = Label.new()
	title.text = "8-BALL — YOU'RE ALONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", ui_font)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	v.add_child(title)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 23)
	status_label.add_theme_font_override("font", ui_font)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	v.add_child(status_label)
	table = TableControl.new()
	table.pool = self
	table.custom_minimum_size = Vector2(620, 360)
	table.size = table.custom_minimum_size
	table.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(table)
	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_font_override("font", ui_font)
	msg_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	v.add_child(msg_label)
	var hint = Label.new()
	hint.text = "AIM WITH MOUSE — CLICK TO SHOOT"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 19)
	hint.add_theme_font_override("font", ui_font)
	hint.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
	v.add_child(hint)
	over_box = VBoxContainer.new()
	over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_box.add_theme_constant_override("separation", 10)
	over_box.visible = false
	v.add_child(over_box)
	var ob = Label.new()
	ob.text = "TABLE OVER"
	ob.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_theme_font_size_override("font_size", 32)
	ob.add_theme_font_override("font", ui_font)
	ob.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	over_box.add_child(ob)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	over_box.add_child(row)
	var b1 = Button.new()
	b1.text = "PLAY AGAIN"
	b1.custom_minimum_size = Vector2(160, 44)
	b1.add_theme_font_size_override("font_size", 23)
	b1.add_theme_font_override("font", ui_font)
	b1.pressed.connect(func(): reset())
	row.add_child(b1)
	var b2 = Button.new()
	b2.text = "BACK"
	b2.custom_minimum_size = Vector2(160, 44)
	b2.add_theme_font_size_override("font_size", 23)
	b2.add_theme_font_override("font", ui_font)
	b2.pressed.connect(func(): back())
	row.add_child(b2)


class TableControl extends Control:
	var pool = null
	func _draw() -> void:
		if pool == null:
			return
		var FELT = pool.FELT
		var BALL_R = pool.BALL_R
		var POCKET_R = pool.POCKET_R
		# Wood rail.
		draw_rect(Rect2(FELT.position - Vector2(18, 18), FELT.size + Vector2(36, 36)), Color(0.25, 0.12, 0.05), true)
		# Felt.
		draw_rect(FELT, Color(0.05, 0.3, 0.12), true)
		# Head string + spots.
		draw_line(Vector2(FELT.position.x + FELT.size.x * 0.25, FELT.position.y),
			Vector2(FELT.position.x + FELT.size.x * 0.25, FELT.position.y + FELT.size.y), Color(1, 1, 1, 0.15), 1.0)
		# Pockets.
		for p in [FELT.position, FELT.position + Vector2(FELT.size.x, 0),
				FELT.position + Vector2(0, FELT.size.y), FELT.end,
				FELT.position + Vector2(FELT.size.x / 2, 0), FELT.position + Vector2(FELT.size.x / 2, FELT.size.y)]:
			draw_circle(p, POCKET_R * 0.9, Color(0.01, 0.01, 0.01))
		# Aim line.
		if pool.aiming:
			var cue = pool._cue()
			if not cue.is_empty():
				var dir = (pool.aim_to - cue["pos"]).normalized()
				draw_line(cue["pos"], cue["pos"] + dir * 140.0, Color(1, 1, 0.4, 0.7), 2.0)
		# Balls.
		for b in pool.balls:
			if not b["active"]:
				continue
			draw_circle(b["pos"], BALL_R, b["color"])
			if b["num"] > 0:
				# Number dot.
				draw_circle(b["pos"] + Vector2(-3, -3), 3.0, Color.WHITE)
				draw_string(ThemeDB.fallback_font, b["pos"] + Vector2(-4, 3), str(b["num"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.BLACK)


func open() -> void:
	reset()
	panel.visible = true
	xbtn.visible = true
	open_flag = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.pause_for_panel()


func close_quiet() -> void:
	panel.visible = false
	xbtn.visible = false
	open_flag = false
	game.resume_from_panel()


func back() -> void:
	panel.visible = false
	xbtn.visible = false
	open_flag = false
	game.on_pool_back()


func reset() -> void:
	balls.clear()
	player_group = ""
	shot_in_progress = false
	over_box.visible = false
	# Cue ball.
	balls.append({"pos": FELT.position + Vector2(90, FELT.size.y / 2), "vel": Vector2.ZERO,
		"color": Color(0.95, 0.95, 0.9), "num": 0, "active": true, "group": ""})
	cue_num = 0
	# Rack: 8-ball in the middle, others random.
	var nums = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]
	nums.shuffle()
	var apex = FELT.position + Vector2(FELT.size.x - 80, FELT.size.y / 2)
	var row_gap = BALL_R * 2.0 + 1.0
	var idx = 0
	for row in 5:
		for k in row + 1:
			var num = 8 if (row == 2 and k == 1) else nums[idx]
			if num != 8:
				idx += 1
			var p = apex + Vector2(row * row_gap * 0.87, (k - row / 2.0) * row_gap)
			var col = Color(0.85, 0.15, 0.15) if num == 8 else _ball_color(num)
			balls.append({"pos": p, "vel": Vector2.ZERO, "color": col,
				"num": num, "active": true,
				"group": "solid" if num <= 7 else ("stripe" if num >= 9 else "")})
	_msg("BREAK — POT ANY BALL", 3.0)
	_refresh_status()
	table.queue_redraw()


func _ball_color(num: int) -> Color:
	match num:
		1: return Color(1.0, 0.85, 0.1)   # yellow
		2: return Color(0.15, 0.35, 0.9)  # blue
		3: return Color(0.9, 0.15, 0.15)  # red
		4: return Color(0.6, 0.2, 0.8)    # purple
		5: return Color(0.95, 0.5, 0.1)   # orange
		6: return Color(0.1, 0.6, 0.2)    # green
		7: return Color(0.6, 0.4, 0.2)    # brown
		9: return Color(1.0, 0.85, 0.1)
		10: return Color(0.15, 0.35, 0.9)
		11: return Color(0.9, 0.15, 0.15)
		12: return Color(0.6, 0.2, 0.8)
		13: return Color(0.95, 0.5, 0.1)
		14: return Color(0.1, 0.6, 0.2)
		_: return Color(0.6, 0.4, 0.2)


func _cue() -> Dictionary:
	for b in balls:
		if b["num"] == 0 and b["active"]:
			return b
	return {}


func _remaining(group := "") -> int:
	var n = 0
	for b in balls:
		if b["active"] and b["num"] > 0 and (group == "" or b["group"] == group):
			n += 1
	return n


func _refresh_status() -> void:
	var s = "OBJECT BALLS LEFT: %d" % _remaining()
	if player_group != "":
		s += "  |  YOUR GROUP: %s (%d left)" % [player_group.to_upper(), _remaining(player_group)]
	status_label.text = s


func _msg(t: String, dur := 2.5) -> void:
	msg_label.text = t
	msg_timer = dur


func _process(delta: float) -> void:
	if not open_flag:
		return
	if msg_timer > 0.0:
		msg_timer -= delta
		if msg_timer <= 0.0:
			msg_label.text = ""
	_step_balls(delta)
	table.queue_redraw()


func _step_balls(delta: float) -> void:
	var moving = false
	for b in balls:
		if not b["active"]:
			continue
		if b["vel"].length() > 1.0:
			moving = true
			b["pos"] += b["vel"] * delta
			# Friction.
			b["vel"] *= maxf(0.0, 1.0 - 1.8 * delta)
			# Cushions.
			if b["pos"].x < FELT.position.x + BALL_R:
				b["pos"].x = FELT.position.x + BALL_R; b["vel"].x = absf(b["vel"].x) * 0.85
			if b["pos"].x > FELT.end.x - BALL_R:
				b["pos"].x = FELT.end.x - BALL_R; b["vel"].x = -absf(b["vel"].x) * 0.85
			if b["pos"].y < FELT.position.y + BALL_R:
				b["pos"].y = FELT.position.y + BALL_R; b["vel"].y = absf(b["vel"].y) * 0.85
			if b["pos"].y > FELT.end.y - BALL_R:
				b["pos"].y = FELT.end.y - BALL_R; b["vel"].y = -absf(b["vel"].y) * 0.85
			# Pockets.
			for p in [FELT.position, FELT.position + Vector2(FELT.size.x, 0),
					FELT.position + Vector2(0, FELT.size.y), FELT.end,
					FELT.position + Vector2(FELT.size.x / 2, 0), FELT.position + Vector2(FELT.size.x / 2, FELT.size.y)]:
				if b["pos"].distance_to(p) < POCKET_R * 0.75:
					b["active"] = false
					b["vel"] = Vector2.ZERO
					_on_pot(b)
					break
	# Ball-ball collisions.
	for i in balls.size():
		var a = balls[i]
		if not a["active"]:
			continue
		for j in range(i + 1, balls.size()):
			var c = balls[j]
			if not c["active"]:
				continue
			var d = c["pos"] - a["pos"]
			var dist = d.length()
			if dist > 0.01 and dist < BALL_R * 2.0:
				var n = d / dist
				var overlap = BALL_R * 2.0 - dist
				a["pos"] -= n * overlap / 2.0
				c["pos"] += n * overlap / 2.0
				var rel = (c["vel"] - a["vel"]).dot(n)
				if rel < 0.0:
					var imp = -rel * 0.96
					a["vel"] -= n * imp
					c["vel"] += n * imp
					if game.audio and absf(rel) > 60.0:
						game.audio.play_sfx("snake_beep", -10.0)
	if not moving and shot_in_progress:
		shot_in_progress = false
		_end_shot()


func _on_pot(b: Dictionary) -> void:
	if game.audio:
		game.audio.play_sfx("snake_eat")
	if b["num"] == 0:
		_msg("SCRATCH!", 2.0)
		# Respotted at the end of the shot.
		pending_respot = true
		return
	if b["num"] == 8:
		var legal = player_group != "" and _remaining(player_group) == 0
		_finish(legal)
		return
	if player_group == "" and b["group"] != "":
		player_group = b["group"]
		_msg("YOU'RE %ss — POT THEM ALL, THEN THE 8" % player_group, 3.5)
	elif player_group != "" and b["group"] != player_group:
		_msg("OPPONENT'S BALL — SHOOT AGAIN", 2.5)
	_refresh_status()


var pending_respot := false


func _end_shot() -> void:
	if pending_respot:
		pending_respot = false
		var cue = _cue()
		if not cue.is_empty():
			cue["active"] = true
			cue["pos"] = FELT.position + Vector2(90, FELT.size.y / 2)
			cue["vel"] = Vector2.ZERO
	# Lose if your group is cleared but 8-ball still on table and you potted opponent ball — handled loosely.
	_refresh_status()


func _finish(won: bool) -> void:
	over_box.visible = true
	_msg("" if won else "YOU POTTED THE 8 EARLY", 0.1)
	if game.audio:
		game.audio.play_sfx("win" if won else "puzzle_bad")
	_refresh_status()


func _input(event: InputEvent) -> void:
	if not open_flag or over_box.visible:
		return
	if event is InputEventMouseMotion:
		var cue = _cue()
		if not cue.is_empty():
			aim_to = table.get_local_mouse_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			aiming = true
			aim_from = table.get_local_mouse_position()
		elif aiming:
			aiming = false
			_shoot()
	elif event is InputEventScreenTouch:
		# Touch: drag aims via mouse-emulation, tap releases the shot.
		if event.pressed:
			aiming = true
			aim_from = table.get_local_mouse_position()
		elif aiming:
			aiming = false
			_shoot()


func _shoot() -> void:
	var cue = _cue()
	if cue.is_empty() or shot_in_progress:
		return
	var dir = (aim_to - cue["pos"])
	if dir.length() < 10.0:
		return
	dir = dir.normalized()
	var power = 900.0
	cue["vel"] = dir * power
	shot_in_progress = true
	if game.audio:
		game.audio.play_sfx("door_open", -8.0)
