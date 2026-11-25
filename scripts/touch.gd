extends CanvasLayer

# Touch controls for mobile: virtual joystick (bottom-left), right-side
# drag-look, USE / LIGHT buttons (bottom-right), INVENTORY / MENU (top-right).

var game: Node = null
var ui_font: Font = null
var root: Control = null
var play_ui: Control = null
var top_bar: HBoxContainer = null

var joy_base: Control = null
var joy_knob: Control = null
var joy_center := Vector2.ZERO
var joy_touch := -1
var joy_vec := Vector2.ZERO
var look_touch := -1
var look_last := Vector2.ZERO

var use_btn: Button = null
var light_btn: Button = null
var inv_btn: Button = null
var menu_btn: Button = null

const JOY_RADIUS := 85.0
const JOY_VISUAL := 52.0
const LOOK_SENS_MULT := 1.9


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	ui_font = SystemFont.new()
	ui_font.font_names = ["Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans", "sans-serif"]
	visible = game != null and game.touch_enabled
	if not visible:
		return
	_build()


func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
	return s


func _btn(parent: Node, text: String, size: Vector2, font_size: int) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_font_override("font", ui_font)
	b.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.6, 1.0, 0.7))
	b.add_theme_stylebox_override("normal",
		_style(Color(0.03, 0.06, 0.04, 0.55), Color(0.4, 0.9, 0.5, 0.7), 14))
	b.add_theme_stylebox_override("hover",
		_style(Color(0.08, 0.16, 0.09, 0.7), Color(0.6, 1.0, 0.6, 0.9), 14))
	b.add_theme_stylebox_override("pressed",
		_style(Color(0.15, 0.35, 0.18, 0.85), Color(0.8, 1.0, 0.7, 1.0), 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- Play controls (hidden while a panel/minigame is open) ----
	play_ui = Control.new()
	play_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play_ui)

	# Floating joystick — hidden until your thumb touches the left side.
	joy_base = Panel.new()
	joy_base.custom_minimum_size = Vector2(190, 190)
	joy_base.size = Vector2(190, 190)
	joy_base.visible = false
	joy_base.add_theme_stylebox_override("panel",
		_style(Color(0.05, 0.1, 0.06, 0.4), Color(0.5, 1.0, 0.6, 0.5), 95))
	play_ui.add_child(joy_base)
	joy_knob = Panel.new()
	joy_knob.custom_minimum_size = Vector2(76, 76)
	joy_knob.size = Vector2(76, 76)
	joy_knob.position = Vector2(57, 57)
	joy_knob.add_theme_stylebox_override("panel",
		_style(Color(0.2, 0.5, 0.28, 0.75), Color(0.7, 1.0, 0.75, 0.9), 38))
	joy_base.add_child(joy_knob)

	# Bottom-right action buttons.
	var actions = VBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.position = Vector2(-250, -350)
	actions.add_theme_constant_override("separation", 18)
	play_ui.add_child(actions)
	use_btn = _btn(actions, "INTERACT", Vector2(190, 140), 36)
	use_btn.pressed.connect(_on_use)
	light_btn = _btn(actions, "USE FLASHLIGHT", Vector2(190, 76), 24)
	light_btn.pressed.connect(_on_light)

	# Top-right buttons: INVENTORY + MENU.
	top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_bar.position = Vector2(-290, 24)
	top_bar.add_theme_constant_override("separation", 14)
	root.add_child(top_bar)
	inv_btn = _btn(top_bar, "INVENTORY", Vector2(160, 64), 26)
	inv_btn.pressed.connect(func(): game.toggle_inventory())
	menu_btn = _btn(top_bar, "MENU", Vector2(80, 64), 26)
	menu_btn.pressed.connect(func(): game.toggle_pause_or_close())


func _on_use() -> void:
	var p = game.player
	if p and p.current_interact.size() > 0:
		game.interact(p.current_interact)


func _on_light() -> void:
	if game.player:
		game.player.toggle_flashlight()


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _joy_zone(pos: Vector2) -> bool:
	# Anywhere on the left ~45% of the screen spawns the floating stick.
	return pos.x < _viewport_size().x * 0.45


func _on_button(pos: Vector2) -> bool:
	for b in [use_btn, light_btn, inv_btn, menu_btn]:
		if b and b.visible and b.get_global_rect().has_point(pos):
			return true
	return false


func _update_joy(pos: Vector2) -> void:
	var rel = (pos - joy_center) / JOY_RADIUS
	joy_vec = rel.limit_length(1.0)
	if joy_vec.length() < 0.15:
		joy_vec = Vector2.ZERO
	joy_knob.position = Vector2(57, 57) + joy_vec * JOY_VISUAL


func _show_joy_at(pos: Vector2) -> void:
	joy_center = pos
	# Center the 190px base on the touch point, clamped on-screen.
	var half := Vector2(95, 95)
	var s := _viewport_size()
	joy_base.position = Vector2(
		clampf(pos.x - half.x, 10.0, s.x - 200.0),
		clampf(pos.y - half.y, 10.0, s.y - 200.0))
	joy_base.visible = true
	joy_knob.position = Vector2(57, 57)


func _input(event: InputEvent) -> void:
	if game == null or not game.touch_enabled \
			or not game.is_playing() or game.ui_blocking():
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if _joy_zone(pos) and not _on_button(pos):
				joy_touch = event.index
				_show_joy_at(pos)
				_update_joy(pos)
			elif pos.x > _viewport_size().x * 0.45 and not _on_button(pos):
				look_touch = event.index
				look_last = pos
		elif event.index == joy_touch:
			joy_touch = -1
			joy_vec = Vector2.ZERO
			if joy_base:
				joy_base.visible = false
			if joy_knob:
				joy_knob.position = Vector2(57, 57)
		elif event.index == look_touch:
			look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_touch:
			_update_joy(event.position)
		elif event.index == look_touch and game.player:
			var d: Vector2 = event.position - look_last
			look_last = event.position
			var sens: float = game.mouse_sensitivity * LOOK_SENS_MULT
			game.player.rotate_y(-d.x * sens)
			game.player.head.rotation.x = clampf(
				game.player.head.rotation.x - d.y * sens, -1.45, 1.45)


func _process(_delta: float) -> void:
	if game == null or not game.touch_enabled:
		return
	var playing: bool = game.is_playing()
	var blocked: bool = playing and game.ui_blocking()
	if play_ui:
		play_ui.visible = playing and not blocked
	if top_bar:
		top_bar.visible = playing and not blocked
	if not (playing and not blocked):
		if joy_touch != -1 or joy_vec != Vector2.ZERO:
			joy_touch = -1
			joy_vec = Vector2.ZERO
			if joy_base:
				joy_base.visible = false
			if joy_knob:
				joy_knob.position = Vector2(57, 57)
		if game:
			game.touch_move = Vector2.ZERO
		return
	# Feed movement to the player.
	game.touch_move = joy_vec
	# USE button lights up when something is interactable.
	if use_btn:
		var can: bool = game.player != null and game.player.current_interact.size() > 0
		use_btn.modulate = Color(1.6, 1.6, 1.3) if can else Color(0.5, 0.5, 0.5)
