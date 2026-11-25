extends CanvasLayer

var game: Node = null
var prompt_label: Label
var msg_label: Label
var fader: ColorRect
var vignette: ColorRect
var main_menu: Control
var pause_menu: Control
var settings_panel: Control
var inventory_panel: Control
var doc_panel: Control
var scare_rect: TextureRect
var scare_player: AudioStreamPlayer = null
var inv_grid: GridContainer
var inv_detail: Label
var inv_battery: Label
var selected_inv = -1
var settings_from = ""
var sens_slider: HSlider
var vol_slider: HSlider
var lights_check: CheckBox
var doc_text: RichTextLabel
var win_panel: Control
var win_time: Label
var chase_banner: Label
var active_panel: Control = null
var scare_busy = false
var ui_font: Font = null


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	ui_font = SystemFont.new()
	ui_font.font_names = ["Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans", "sans-serif"]
	_set_custom_cursor()
	_build_hud()
	_build_menus()
	_build_panels()
	_build_scare()
	hide_all_panels(false)


func _set_custom_cursor() -> void:
	# BIG obvious cursor: thick yellow ring + green cross + white dot.
	# 96x96 so it reads clearly on any background.
	const S := 96
	const C := 48.0
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ring = Color(1.0, 0.85, 0.1, 0.98)
	var cross = Color(0.2, 1.0, 0.4, 0.95)
	var dot = Color(1, 1, 1, 1.0)
	var dark = Color(0, 0, 0, 0.85)
	for y in S:
		for x in S:
			var dx = x + 0.5 - C
			var dy = y + 0.5 - C
			var d = sqrt(dx * dx + dy * dy)
			var px := Color(0, 0, 0, 0)
			# Dark outline under everything for contrast.
			var on_ring = absf(d - 30.0) < 5.0
			var on_cross = (absf(dx) < 2.6 and absf(dy) > 12.0 and absf(dy) < 42.0) \
				or (absf(dy) < 2.6 and absf(dx) > 12.0 and absf(dx) < 42.0)
			var on_dot = d < 6.0
			if on_ring or on_cross or on_dot:
				px = dark
			# Colored layers on top.
			if on_ring and absf(d - 30.0) < 3.4:
				px = ring
			elif on_cross and absf((dx if absf(dx) < absf(dy) else dy)) < 1.4:
				px = cross
			elif on_dot and d < 4.5:
				px = dot
			if px.a > 0.0:
				img.set_pixel(x, y, px)
	var tex = ImageTexture.create_from_image(img)
	var hot = Vector2(C, C)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_IBEAM, Input.CURSOR_POINTING_HAND,
			Input.CURSOR_CROSS, Input.CURSOR_WAIT, Input.CURSOR_BUSY, Input.CURSOR_DRAG,
			Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN, Input.CURSOR_VSIZE,
			Input.CURSOR_HSIZE, Input.CURSOR_BDIAGSIZE, Input.CURSOR_FDIAGSIZE,
			Input.CURSOR_MOVE, Input.CURSOR_VSPLIT, Input.CURSOR_HSPLIT, Input.CURSOR_HELP]:
		Input.set_custom_mouse_cursor(tex, shape, hot)


func _label(parent: Node, text: String, size: int, color: Color,
		align = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", ui_font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 54)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_font_override("font", ui_font)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _panel(parent: Node, size = Vector2(720, 480)) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.94)
	sb.border_color = Color(0.2, 0.5, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = size
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.position = Vector2(-size.x / 2, -size.y / 2)
	parent.add_child(pc)
	return pc


func _build_hud() -> void:
	prompt_label = _label(self, "", 27, Color(0.85, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -110)
	prompt_label.custom_minimum_size = Vector2(600, 40)

	msg_label = _label(self, "", 38, Color(0.95, 1.0, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	msg_label.set_anchors_preset(Control.PRESET_CENTER)
	msg_label.position = Vector2(-500, -220)
	msg_label.custom_minimum_size = Vector2(1000, 80)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	vignette = ColorRect.new()
	vignette.color = Color(0, 0, 0, 0.35)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	fader = ColorRect.new()
	fader.color = Color(0, 0, 0, 1)
	fader.modulate.a = 0.0
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fader)


func _build_menus() -> void:
	main_menu = Control.new()
	main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_menu)
	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.015, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(dim)
	var title = _label(main_menu, "NIGHTMARE BREAKOUT", 76,
		Color(0.65, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 0
	title.offset_right = 0
	title.offset_top = 120
	title.offset_bottom = 240
	title.custom_minimum_size = Vector2(0, 120)
	var sub = _label(main_menu, "A HORROR ESCAPE", 26, Color(0.4, 0.8, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_left = 0
	sub.offset_right = 0
	sub.offset_top = 250
	sub.offset_bottom = 300
	sub.custom_minimum_size = Vector2(0, 50)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140, 60)
	box.add_theme_constant_override("separation", 14)
	main_menu.add_child(box)
	_button(box, "PLAY", func(): game.start_game())
	_button(box, "SETTINGS", func(): show_settings("main"))
	_button(box, "QUIT", func(): get_tree().quit())

	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	add_child(pause_menu)
	var pdim = ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.6)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(pdim)
	var pbox = VBoxContainer.new()
	pbox.set_anchors_preset(Control.PRESET_CENTER)
	pbox.add_theme_constant_override("separation", 14)
	pause_menu.add_child(pbox)
	_button(pbox, "RESUME", func(): game.toggle_pause_or_close())
	_button(pbox, "SETTINGS", func(): show_settings("pause"))
	_button(pbox, "QUIT", func(): get_tree().quit())

	settings_panel = _panel(self, Vector2(560, 420))
	settings_panel.visible = false
	var sc = VBoxContainer.new()
	sc.add_theme_constant_override("separation", 16)
	settings_panel.add_child(sc)
	_label(sc, "SETTINGS", 34, Color(0.8, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var sl = HBoxContainer.new()
	sl.add_theme_constant_override("separation", 12)
	sc.add_child(sl)
	_label(sl, "MOUSE SENSITIVITY", 18, Color(0.8, 0.9, 0.85))
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.006
	sens_slider.step = 0.0001
	sens_slider.value = game.mouse_sensitivity if game else 0.0021
	sens_slider.custom_minimum_size = Vector2(260, 30)
	sens_slider.value_changed.connect(func(v): game.mouse_sensitivity = v)
	sl.add_child(sens_slider)
	var vl = HBoxContainer.new()
	vl.add_theme_constant_override("separation", 12)
	sc.add_child(vl)
	_label(vl, "MASTER VOLUME", 18, Color(0.8, 0.9, 0.85))
	vol_slider = HSlider.new()
	vol_slider.min_value = -30.0
	vol_slider.max_value = 6.0
	vol_slider.step = 0.5
	vol_slider.value = game.master_volume if game else -6.0
	vol_slider.custom_minimum_size = Vector2(260, 30)
	vol_slider.value_changed.connect(func(v):
		game.master_volume = v
		AudioServer.set_bus_volume_db(0, v))
	vl.add_child(vol_slider)
	lights_check = CheckBox.new()
	lights_check.text = "REDUCED LIGHTING"
	lights_check.button_pressed = game.reduce_lights if game else false
	lights_check.toggled.connect(func(v):
		game.reduce_lights = v
		game.apply_quality())
	sc.add_child(lights_check)
	_button(sc, "BACK", func(): hide_settings())


func _build_panels() -> void:
	inventory_panel = _panel(self, Vector2(860, 520))
	inventory_panel.visible = false
	var ic = VBoxContainer.new()
	ic.add_theme_constant_override("separation", 10)
	inventory_panel.add_child(ic)
	_label(ic, "INVENTORY", 30, Color(0.8, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	inv_grid = GridContainer.new()
	inv_grid.columns = 3
	inv_grid.add_theme_constant_override("h_separation", 10)
	inv_grid.add_theme_constant_override("v_separation", 10)
	ic.add_child(inv_grid)
	inv_detail = _label(ic, "Select an item.", 21, Color(0.75, 0.85, 0.8))
	inv_battery = _label(ic, "", 21, Color(0.5, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	var ib = HBoxContainer.new()
	ib.alignment = BoxContainer.ALIGNMENT_CENTER
	ib.add_theme_constant_override("separation", 12)
	ic.add_child(ib)
	_button(ib, "SELECT / HOLD", func(): game.inventory_select(selected_inv))
	_button(ib, "DROP", func(): game.inventory_drop(selected_inv))
	_button(ib, "CHANGE BATTERY", func(): game.inventory_replace_battery())
	_button(ib, "CLOSE", func(): hide_all_panels())

	doc_panel = _panel(self, Vector2(720, 560))
	doc_panel.visible = false
	var dc = VBoxContainer.new()
	doc_panel.add_child(dc)
	doc_text = RichTextLabel.new()
	doc_text.bbcode_enabled = true
	doc_text.fit_content = true
	doc_text.scroll_active = false
	doc_text.custom_minimum_size = Vector2(660, 460)
	doc_text.add_theme_font_size_override("normal_font_size", 26)
	doc_text.add_theme_font_size_override("bold_font_size", 30)
	doc_text.add_theme_font_override("normal_font", ui_font)
	doc_text.add_theme_font_override("bold_font", ui_font)
	dc.add_child(doc_text)
	_button(dc, "CLOSE", func(): hide_all_panels())

	# Win panel.
	win_panel = _panel(self, Vector2(560, 380))
	win_panel.visible = false
	var wc = VBoxContainer.new()
	wc.alignment = BoxContainer.ALIGNMENT_CENTER
	wc.add_theme_constant_override("separation", 16)
	win_panel.add_child(wc)
	_label(wc, "YOU ESCAPED", 44, Color(0.6, 1.0, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	win_time = _label(wc, "", 26, Color(0.9, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_button(wc, "MAIN MENU", func(): get_tree().reload_current_scene())

	# Chase banner — massive top-center warning.
	chase_banner = _label(self, "GET TO THE EXIT IN THE STARTING ROOM!", 58,
		Color(1.0, 0.15, 0.1), HORIZONTAL_ALIGNMENT_CENTER)
	chase_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	chase_banner.offset_left = 0
	chase_banner.offset_right = 0
	chase_banner.offset_top = 24
	chase_banner.offset_bottom = 96
	chase_banner.custom_minimum_size = Vector2(0, 60)
	chase_banner.visible = false


func _build_scare() -> void:
	scare_rect = TextureRect.new()
	scare_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scare_rect.stretch_mode = TextureRect.STRETCH_SCALE
	scare_rect.visible = false
	scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scare_rect)
	scare_player = AudioStreamPlayer.new()
	scare_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(scare_player)


# ---------------------------------------------------------------
# MENUS / PANELS
# ---------------------------------------------------------------

func show_main_menu() -> void:
	main_menu.visible = true
	# Scene reloads (death / win -> menu) keep the mouse captured — release it
	# so the menu buttons are clickable.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_main_menu() -> void:
	main_menu.visible = false


func show_pause() -> void:
	pause_menu.visible = true


func hide_pause() -> void:
	pause_menu.visible = false


func show_settings(from: String) -> void:
	settings_from = from
	settings_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_settings() -> void:
	settings_panel.visible = false
	if settings_from == "pause" and game.is_playing():
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		game.resume_from_panel()


func is_blocking() -> bool:
	return active_panel != null or inventory_panel.visible or doc_panel.visible \
		or settings_panel.visible or pause_menu.visible or main_menu.visible \
		or win_panel.visible or scare_rect.visible


func hide_all_panels(resume = true) -> void:
	for p in [inventory_panel, doc_panel]:
		if p:
			p.visible = false
	active_panel = null
	if resume and game:
		game.resume_from_panel()


func show_panel(panel: Control) -> void:
	for p in [inventory_panel, doc_panel]:
		if p:
			p.visible = (p == panel)
	active_panel = panel
	if panel:
		panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		game.pause_for_panel()
	else:
		game.resume_from_panel()


func _unhandled_input(event: InputEvent) -> void:
	# Panels pause the tree, so the player can't hear Q/I/Esc — handle
	# closing them here (this layer always processes).
	if game == null or not game.is_playing():
		return
	if event is InputEventKey and event.echo:
		return
	var inv_key = event.is_action_pressed("inventory") \
		or (event is InputEventKey and event.keycode == KEY_Q and event.pressed)
	if inv_key and (inventory_panel.visible or doc_panel.visible):
		hide_all_panels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") \
			and (inventory_panel.visible or doc_panel.visible or settings_panel.visible):
		game.toggle_pause_or_close()
		get_viewport().set_input_as_handled()


func update_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func show_message(text: String, duration = 2.5) -> void:
	msg_label.text = text
	msg_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(duration * 0.65)
	tw.tween_property(msg_label, "modulate:a", 0.0, duration * 0.35)


func refresh_inventory() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	if game == null:
		return
	for i in game.inventory.size():
		var id: String = game.inventory[i]
		var it: Dictionary = game.ITEMS.get(id, {})
		var b = Button.new()
		b.text = ("▶ " if i == game.held_index else "  ") + str(it.get("name", id))
		b.custom_minimum_size = Vector2(220, 52)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_font_override("font", ui_font)
		var idx = i
		b.pressed.connect(func(): selected_inv = idx; refresh_inventory())
		inv_grid.add_child(b)
	inv_battery.text = "FLASHLIGHT BATTERY: %d%%" % int(game.player.battery_percent) \
		if game.player else ""
	if selected_inv >= 0 and selected_inv < game.inventory.size():
		var it: Dictionary = game.ITEMS.get(game.inventory[selected_inv], {})
		inv_detail.text = "%s\n%s" % [str(it.get("name", "")), str(it.get("desc", ""))]
	else:
		inv_detail.text = "Select an item."


func show_inventory() -> void:
	selected_inv = game.held_index if game.held_index >= 0 else 0
	refresh_inventory()
	show_panel(inventory_panel)


func show_document(title: String, body: String) -> void:
	doc_text.text = "[b]%s[/b]\n\n%s" % [title, body]
	show_panel(doc_panel)


func show_win(t: float) -> void:
	win_time.text = "TIME: %s" % game.format_time(t)
	win_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_chase_banner() -> void:
	chase_banner.visible = true


# ---------------------------------------------------------------
# JUMPSCARE
# ---------------------------------------------------------------

func _make_scare_texture() -> Texture2D:
	var w = 512; var h = 512
	var img = Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.01, 0.0, 0.01))
	for y in h:
		for x in w:
			var nx = (x - w * 0.5) / (w * 0.30)
			var ny = (y - h * 0.44) / (h * 0.42)
			var d = nx * nx + ny * ny
			if d < 1.0:
				# pale, blotchy face
				var blotch = randf_range(-14, 14)
				img.set_pixel(x, y, Color(0.72 + blotch / 400.0, 0.66 + blotch / 400.0, 0.62 + blotch / 400.0))
	# eyes
	for ey in [0.38, 0.52]:
		var ex = w * (0.40 if ey < 0.45 else 0.60)
		var eyv = h * ey
		for y in range(int(eyv - 26), int(eyv + 26)):
			for x in range(int(ex - 34), int(ex + 34)):
				var dx = (x - ex) / 34.0; var dy = (y - eyv) / 26.0
				if dx * dx + dy * dy < 1.0:
					img.set_pixel(x, y, Color(0.0, 0.0, 0.0))
	# mouth: stretched dark opening
	var my = h * 0.66
	for y in range(int(my - 40), int(my + 46)):
		for x in range(int(w * 0.34), int(w * 0.66)):
			var nx = (x - w * 0.5) / (w * 0.16)
			var ny = (y - my) / (h * 0.10)
			if nx * nx + ny * ny < 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0))
	# Teeth: jagged white spikes along the top and bottom of the mouth.
	for i in 9:
		var tx = w * 0.36 + i * (w * 0.28 / 8.0)
		for s in [-1, 1]:
			var base_y = my + s * 30.0
			for ty in range(int(min(base_y, base_y + s * 22)), int(max(base_y, base_y + s * 22)) + 1):
				for txo in range(int(tx - 6), int(tx + 6)):
					var half_w = 6.0 * (1.0 - abs(ty - base_y) / 22.0)
					if abs(txo - tx) < half_w and ty >= 0 and ty < h and txo >= 0 and txo < w:
						img.set_pixel(txo, ty, Color(0.9, 0.88, 0.8))
	# Blood: dark red splatter around the mouth and cheeks.
	for i in 260:
		var bx = randf_range(w * 0.2, w * 0.8)
		var by = randf_range(h * 0.5, h * 0.95)
		var r = randf_range(1.0, 7.0)
		for yy in range(int(by - r), int(by + r)):
			for xx in range(int(bx - r), int(bx + r)):
				if xx >= 0 and xx < w and yy >= 0 and yy < h and Vector2(xx - bx, yy - by).length() < r:
					img.set_pixel(xx, yy, Color(0.35 + randf() * 0.1, 0.02, 0.02))
	# Drips from the eyes.
	for ex in [w * 0.40, w * 0.60]:
		for i in 40:
			var dy = randf_range(0, 90)
			var dx = randf_range(-4, 4)
			var px = int(ex + dx); var py = int(h * 0.52 + dy)
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, Color(0.3, 0.02, 0.02))
	return ImageTexture.create_from_image(img)


func _scare_texture(kind: String) -> Texture2D:
	# Custom jumpscare images; fall back to the procedural face.
	var path := "res://scare_arcade.jpg" if kind == "arcade" else "res://scare_pool.jpg"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		if t:
			return t
	return _make_scare_texture()


func play_jumpscare(kind := "arcade") -> void:
	if scare_busy:
		return
	scare_busy = true
	scare_rect.texture = _scare_texture(kind)
	scare_rect.visible = true
	scare_rect.pivot_offset = scare_rect.size / 2.0
	scare_rect.scale = Vector2(0.25, 0.25)
	var lunge = create_tween()
	lunge.tween_property(scare_rect, "scale", Vector2(1.25, 1.25), 0.14)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Custom scare sound if one exists for this minigame, else synth sting.
	var snd_path := "res://scare_arcade.mp3" if kind == "arcade" else ""
	var played_custom := false
	if snd_path != "" and ResourceLoader.exists(snd_path):
		var st: AudioStream = load(snd_path)
		if st and scare_player:
			scare_player.stream = st
			scare_player.play()
			played_custom = true
	if not played_custom and game.audio:
		game.audio.play_sfx("jumpscare", 0.0)
	if game.player:
		game.player.add_shake(0.8)
	# Hold the scare, then release safely.
	await get_tree().create_timer(1.3, true, false, true).timeout
	lunge.kill()
	scare_rect.visible = false
	scare_rect.scale = Vector2.ONE
	scare_busy = false
	game.resume_from_panel()
