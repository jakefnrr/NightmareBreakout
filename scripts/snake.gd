extends CanvasLayer

var game: Node = null
var open_flag = false
var gameover = false
var score = 0
var dir := Vector2i.RIGHT
var dir_queue: Array = []
var snake_body: Array = []
var food := Vector2i.ZERO
var move_timer = 0.0
var move_interval = 0.13
var GRID = 20
var CELL = 22
var cells: Array = []

var panel: PanelContainer
var score_label: Label
var board_box: Control
var go_box: VBoxContainer
var go_label: Label


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	_build()


func is_open() -> bool:
	return open_flag


func _build() -> void:
	panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.03, 0.97)
	sb.border_color = Color(0.3, 0.9, 0.4, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 620)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-280, -310)
	panel.visible = false
	add_child(panel)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title = Label.new()
	title.text = "SNAKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	v.add_child(title)
	score_label = Label.new()
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	v.add_child(score_label)
	board_box = Control.new()
	board_box.custom_minimum_size = Vector2(GRID * CELL, GRID * CELL)
	board_box.size = board_box.custom_minimum_size
	board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(board_box)
	# Cell grid.
	for y in GRID:
		for x in GRID:
			var r = ColorRect.new()
			r.color = Color(0.03, 0.07, 0.04)
			r.position = Vector2(x * CELL, y * CELL)
			r.size = Vector2(CELL - 1, CELL - 1)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			board_box.add_child(r)
			cells.append(r)
	var hint = Label.new()
	hint.text = "ARROWS / WASD TO MOVE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.8, 0.65))
	v.add_child(hint)
	go_box = VBoxContainer.new()
	go_box.alignment = BoxContainer.ALIGNMENT_CENTER
	go_box.add_theme_constant_override("separation", 10)
	go_box.visible = false
	v.add_child(go_box)
	go_label = Label.new()
	go_label.text = "GAME OVER"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.add_theme_font_size_override("font_size", 30)
	go_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	go_box.add_child(go_label)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	go_box.add_child(row)
	var b1 = Button.new()
	b1.text = "PLAY AGAIN"
	b1.custom_minimum_size = Vector2(160, 44)
	b1.add_theme_font_size_override("font_size", 18)
	b1.pressed.connect(func(): reset())
	row.add_child(b1)
	var b2 = Button.new()
	b2.text = "BACK"
	b2.custom_minimum_size = Vector2(160, 44)
	b2.add_theme_font_size_override("font_size", 18)
	b2.pressed.connect(func(): back())
	row.add_child(b2)


func open() -> void:
	reset()
	panel.visible = true
	open_flag = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.pause_for_panel()


func reset() -> void:
	score = 0
	dir = Vector2i.RIGHT
	dir_queue.clear()
	gameover = false
	snake_body = [Vector2i(10, 10), Vector2i(9, 10), Vector2i(8, 10)]
	move_timer = 0.0
	_new_food()
	go_box.visible = false
	_refresh()


func close_quiet() -> void:
	panel.visible = false
	open_flag = false
	game.resume_from_panel()


func back() -> void:
	# Leave the mini-game without resuming; the jumpscare resumes us.
	panel.visible = false
	open_flag = false
	game.on_snake_back()


func _new_food() -> void:
	var tries = 0
	while tries < 500:
		var f = Vector2i(randi() % GRID, randi() % GRID)
		if f not in snake_body:
			food = f
			return
		tries += 1
	food = snake_body[0]


func _cell_idx(c: Vector2i) -> int:
	return c.y * GRID + c.x


func _refresh() -> void:
	for i in cells.size():
		cells[i].color = Color(0.03, 0.07, 0.04)
	for c in snake_body:
		var idx = _cell_idx(c)
		if idx >= 0 and idx < cells.size():
			cells[idx].color = Color(0.2, 0.85, 0.3) if c != snake_body[0] else Color(0.5, 1.0, 0.5)
	var fi = _cell_idx(food)
	if fi >= 0 and fi < cells.size():
		cells[fi].color = Color(0.9, 0.2, 0.2)
	score_label.text = "SCORE: %d" % score


func _unhandled_input(event: InputEvent) -> void:
	if not open_flag or gameover:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var d = Vector2i.ZERO
		match event.keycode:
			KEY_UP, KEY_W: d = Vector2i(0, -1)
			KEY_DOWN, KEY_S: d = Vector2i(0, 1)
			KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
		if d != Vector2i.ZERO:
			_queue_dir(d)
			get_viewport().set_input_as_handled()


func _queue_dir(d: Vector2i) -> void:
	# Prevent 180-degree turns.
	if dir_queue.size() == 0:
		if d != -dir:
			dir_queue.append(d)
	elif dir_queue.size() < 3:
		var last = dir_queue[dir_queue.size() - 1]
		if d != -last:
			dir_queue.append(d)


func _process(delta: float) -> void:
	if not open_flag or gameover:
		return
	move_timer += delta
	while move_timer >= move_interval:
		move_timer -= move_interval
		_step()
		if gameover:
			return


func _step() -> void:
	if gameover or snake_body.is_empty():
		return
	if dir_queue.size() > 0:
		dir = dir_queue.pop_front()
	var head = snake_body[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= GRID or head.y >= GRID or head in snake_body:
		_gameover()
		return
	snake_body.push_front(head)
	if head == food:
		score += 1
		move_interval = maxf(0.07, move_interval - 0.002)
		if game.audio:
			game.audio.play_sfx("snake_eat")
		_new_food()
	else:
		snake_body.pop_back()
	_refresh()


func _gameover() -> void:
	gameover = true
	snake_body.clear()
	go_box.visible = true
	score_label.text = "SCORE: %d" % score
