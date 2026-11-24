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
var inv_grid: GridContainer
var inv_detail: Label
var inv_battery: Label
var selected_inv = -1
var settings_from = ""
var sens_slider: HSlider
var vol_slider: HSlider
var lights_check: CheckBox
var doc_text: RichTextLabel
var active_panel: Control = null
var scare_busy = false


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_hud()
	_build_menus()
	_build_panels()
	_build_scare()
	hide_all_panels(false)


func _label(parent: Node, text: String, size: int, color: Color,
		align = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 20)
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
	prompt_label = _label(self, "", 22, Color(0.85, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -110)
	prompt_label.custom_minimum_size = Vector2(600, 40)

	msg_label = _label(self, "", 30, Color(0.95, 1.0, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
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
	inv_detail = _label(ic, "Select an item.", 18, Color(0.75, 0.85, 0.8))
	inv_battery = _label(ic, "", 18, Color(0.5, 1.0, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
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
	dc.add_child(doc_text)
	_button(dc, "CLOSE", func(): hide_all_panels())


func _build_scare() -> void:
	scare_rect = TextureRect.new()
	scare_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scare_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scare_rect.stretch_mode = TextureRect.STRETCH_SCALE
	scare_rect.visible = false
	scare_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scare_rect)


# ---------------------------------------------------------------
# MENUS / PANELS
# ---------------------------------------------------------------

func show_main_menu() -> void:
	main_menu.visible = true


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
		or scare_rect.visible


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
		b.add_theme_font_size_override("font_size", 18)
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
	return ImageTexture.create_from_image(img)


func play_jumpscare() -> void:
	if scare_busy:
		return
	scare_busy = true
	if scare_rect.texture == null:
		scare_rect.texture = _make_scare_texture()
	scare_rect.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game.audio:
		game.audio.play_sfx("jumpscare", 0.0)
	if game.player:
		game.player.add_shake(0.55)
	# Hold the scare, then release safely.
	await get_tree().create_timer(1.15, true, false, true).timeout
	scare_rect.visible = false
	scare_busy = false
	game.resume_from_panel()
