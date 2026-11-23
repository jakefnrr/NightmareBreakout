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
var term_panel: Control
var elev_panel: Control
var death_panel: Control
var win_panel: Control
var inv_grid: GridContainer
var inv_detail: Label
var inv_battery: Label
var selected_inv = -1
var settings_from = ""
var sens_slider: HSlider
var vol_slider: HSlider
var lights_check: CheckBox
var term_text: RichTextLabel
var term_buttons: VBoxContainer
var elev_buttons: VBoxContainer
var doc_text: RichTextLabel
var active_panel: Control = null


func _ready() -> void:
	game = get_node("/root/Main")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_hud()
	_build_menus()
	_build_panels()
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
	prompt_label = _label(self, "", 22, Color(0.85, 1.0, 0.9),
		HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -110)
	prompt_label.custom_minimum_size = Vector2(600, 40)

	msg_label = _label(self, "", 30, Color(0.95, 1.0, 0.95),
		HORIZONTAL_ALIGNMENT_CENTER)
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
	dim.color = Color(0.0, 0.01, 0.015, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(dim)
	var title = _label(main_menu, "NIGHTMARE BREAKOUT", 72,
		Color(0.65, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-500, 120)
	title.custom_minimum_size = Vector2(1000, 110)
	var sub = _label(main_menu, "A HORROR ESCAPE", 26, Color(0.4, 0.8, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-400, 230)
	sub.custom_minimum_size = Vector2(800, 50)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-140, 40)
	box.add_theme_constant_override("separation", 14)
	main_menu.add_child(box)
	_button(box, "PLAY", func(): game.start_game())
	_button(box, "SETTINGS", func(): show_settings("main"))
	_button(box, "QUIT", func(): get_tree().quit())
	var final = _label(main_menu, "", 22, Color(1.0, 0.8, 0.4),
		HORIZONTAL_ALIGNMENT_CENTER)
	final.name = "FinalTime"
	final.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	final.position = Vector2(-400, -140)
	final.custom_minimum_size = Vector2(800, 50)

	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	add_child(pause_menu)
	var pdim = ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.7)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(pdim)
	var ptitle = _label(pause_menu, "PAUSED", 54, Color(0.8, 1.0, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER)
	ptitle.set_anchors_preset(Control.PRESET_CENTER)
	ptitle.position = Vector2(-300, -180)
	ptitle.custom_minimum_size = Vector2(600, 90)
	var pbox = VBoxContainer.new()
	pbox.set_anchors_preset(Control.PRESET_CENTER)
	pbox.position = Vector2(-140, 0)
	pbox.add_theme_constant_override("separation", 12)
	pause_menu.add_child(pbox)
	_button(pbox, "RESUME", func(): game.toggle_pause_or_close())
	_button(pbox, "SETTINGS", func(): show_settings("pause"))
	_button(pbox, "QUIT", func(): get_tree().quit())

	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	add_child(settings_panel)
	var sdim = ColorRect.new()
	sdim.color = Color(0, 0, 0, 0.75)
	sdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.add_child(sdim)
	var spc = _panel(settings_panel, Vector2(560, 420))
	var sc = VBoxContainer.new()
	sc.add_theme_constant_override("separation", 16)
	spc.add_child(sc)
	_label(sc, "SETTINGS", 34, Color(0.85, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.0005
	sens_slider.max_value = 0.006
	sens_slider.step = 0.0001
	sens_slider.value = game.mouse_sensitivity if game else 0.0021
	sens_slider.value_changed.connect(func(v): game.mouse_sensitivity = v)
	sc.add_child(sens_slider)
	_label(sc, "MOUSE SENSITIVITY", 18, Color(0.7, 0.9, 0.8))
	vol_slider = HSlider.new()
	vol_slider.min_value = -40.0
	vol_slider.max_value = 0.0
	vol_slider.step = 1.0
	vol_slider.value = game.master_volume if game else -6.0
	vol_slider.value_changed.connect(func(v): game.master_volume = v; AudioServer.set_bus_volume_db(0, v))
	sc.add_child(vol_slider)
	_label(sc, "VOLUME", 18, Color(0.7, 0.9, 0.8))
	lights_check = CheckBox.new()
	lights_check.text = "REDUCE LIGHTS (PERFORMANCE)"
	lights_check.button_pressed = game.reduce_lights if game else false
	lights_check.toggled.connect(func(v): game.reduce_lights = v; game.apply_quality())
	sc.add_child(lights_check)
	_button(sc, "BACK", func(): hide_settings())

	death_panel = Control.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	add_child(death_panel)
	var dlabel = _label(death_panel, "YOU DIED", 80, Color(0.9, 0.1, 0.1),
		HORIZONTAL_ALIGNMENT_CENTER)
	dlabel.set_anchors_preset(Control.PRESET_CENTER)
	dlabel.position = Vector2(-400, -120)
	dlabel.custom_minimum_size = Vector2(800, 120)

	win_panel = Control.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.visible = false
	add_child(win_panel)
	var wdim = ColorRect.new()
	wdim.color = Color(0.02, 0.08, 0.04, 0.9)
	wdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(wdim)
	var wtitle = _label(win_panel, "YOU ESCAPED", 70, Color(0.4, 1.0, 0.6),
		HORIZONTAL_ALIGNMENT_CENTER)
	wtitle.set_anchors_preset(Control.PRESET_CENTER)
	wtitle.position = Vector2(-400, -160)
	wtitle.custom_minimum_size = Vector2(800, 110)
	var wtime = _label(win_panel, "", 28, Color(0.8, 1.0, 0.85),
		HORIZONTAL_ALIGNMENT_CENTER)
	wtime.name = "WinTime"
	wtime.set_anchors_preset(Control.PRESET_CENTER)
	wtime.position = Vector2(-400, -20)
	wtime.custom_minimum_size = Vector2(800, 60)
	_button(win_panel, "MAIN MENU", func(): get_tree().reload_current_scene()).position = Vector2(-130, 80)


func _build_panels() -> void:
	inventory_panel = Control.new()
	inventory_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_panel.visible = false
	add_child(inventory_panel)
	var idim = ColorRect.new()
	idim.color = Color(0, 0, 0, 0.65)
	idim.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_child(idim)
	var ipc = _panel(inventory_panel, Vector2(860, 520))
	var iv = VBoxContainer.new()
	iv.add_theme_constant_override("separation", 12)
	ipc.add_child(iv)
	_label(iv, "INVENTORY", 32, Color(0.85, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	inv_battery = _label(iv, "", 18, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	inv_grid = GridContainer.new()
	inv_grid.columns = 3
	inv_grid.add_theme_constant_override("h_separation", 14)
	inv_grid.add_theme_constant_override("v_separation", 14)
	iv.add_child(inv_grid)
	inv_detail = _label(iv, "", 18, Color(0.75, 0.9, 0.8))
	inv_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_detail.custom_minimum_size = Vector2(780, 70)
	var ib = HBoxContainer.new()
	ib.alignment = BoxContainer.ALIGNMENT_CENTER
	ib.add_theme_constant_override("separation", 12)
	iv.add_child(ib)
	_button(ib, "SELECT / HOLD", func(): game.inventory_select(selected_inv))
	_button(ib, "DROP", func(): game.inventory_drop(selected_inv))
	_button(ib, "CHANGE BATTERY", func(): game.inventory_replace_battery())
	_button(ib, "CLOSE", func(): hide_all_panels())

	doc_panel = Control.new()
	doc_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	doc_panel.visible = false
	add_child(doc_panel)
	var ddim = ColorRect.new()
	ddim.color = Color(0, 0, 0, 0.7)
	ddim.set_anchors_preset(Control.PRESET_FULL_RECT)
	doc_panel.add_child(ddim)
	var dpc = _panel(doc_panel, Vector2(720, 560))
	var dv = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 12)
	dpc.add_child(dv)
	_label(dv, "DOCUMENT", 30, Color(0.9, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	doc_text = RichTextLabel.new()
	doc_text.bbcode_enabled = false
	doc_text.custom_minimum_size = Vector2(680, 430)
	doc_text.add_theme_font_size_override("normal_font_size", 20)
	doc_text.add_theme_color_override("default_color", Color(0.85, 0.9, 0.85))
	dv.add_child(doc_text)
	_button(dv, "CLOSE", func(): hide_all_panels()).size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	term_panel = Control.new()
	term_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	term_panel.visible = false
	add_child(term_panel)
	var tdim = ColorRect.new()
	tdim.color = Color(0.005, 0.02, 0.015, 0.85)
	tdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	term_panel.add_child(tdim)
	var tpc = _panel(term_panel, Vector2(900, 620))
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	tpc.add_child(tv)
	_label(tv, "TERMINAL", 30, Color(0.4, 1.0, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	term_text = RichTextLabel.new()
	term_text.bbcode_enabled = true
	term_text.custom_minimum_size = Vector2(850, 470)
	term_text.add_theme_font_size_override("normal_font_size", 18)
	term_text.add_theme_color_override("default_color", Color(0.6, 1.0, 0.75))
	term_text.scroll_following = true
	tv.add_child(term_text)
	term_buttons = VBoxContainer.new()
	term_buttons.add_theme_constant_override("separation", 8)
	tv.add_child(term_buttons)
	_button(term_buttons, "CLOSE", func(): hide_all_panels())

	elev_panel = Control.new()
	elev_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	elev_panel.visible = false
	add_child(elev_panel)
	var edim = ColorRect.new()
	edim.color = Color(0, 0, 0, 0.7)
	edim.set_anchors_preset(Control.PRESET_FULL_RECT)
	elev_panel.add_child(edim)
	var epc = _panel(elev_panel, Vector2(520, 460))
	var ev = VBoxContainer.new()
	ev.add_theme_constant_override("separation", 12)
	epc.add_child(ev)
	_label(ev, "ELEVATOR", 32, Color(0.85, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	elev_buttons = VBoxContainer.new()
	elev_buttons.add_theme_constant_override("separation", 10)
	elev_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.add_child(elev_buttons)
	_button(ev, "CLOSE", func(): hide_all_panels()).size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func show_main_menu() -> void:
	main_menu.visible = true
	var ft: Label = main_menu.get_node("FinalTime")
	if game and game.final_time > 0.0:
		ft.text = "FINAL TIME  " + game.format_time(game.final_time)
	else:
		ft.text = ""


func hide_main_menu() -> void:
	main_menu.visible = false


func show_settings(from: String) -> void:
	settings_from = from
	settings_panel.visible = true
	if from == "main":
		main_menu.visible = false
	else:
		pause_menu.visible = false


func hide_settings() -> void:
	settings_panel.visible = false
	if settings_from == "main":
		main_menu.visible = true
	else:
		pause_menu.visible = true


func show_pause() -> void:
	pause_menu.visible = true


func hide_pause() -> void:
	pause_menu.visible = false


func is_blocking() -> bool:
	return active_panel != null or inventory_panel.visible or doc_panel.visible \
		or term_panel.visible or elev_panel.visible or death_panel.visible \
		or win_panel.visible or settings_panel.visible or pause_menu.visible \
		or main_menu.visible


func hide_all_panels(resume = true) -> void:
	for p in [inventory_panel, doc_panel, term_panel, elev_panel]:
		if p:
			p.visible = false
	active_panel = null
	if resume and game:
		game.resume_from_panel()


func show_panel(panel: Control) -> void:
	for p in [inventory_panel, doc_panel, term_panel, elev_panel]:
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


func flash(color: Color, duration = 0.5) -> void:
	fader.color = color
	fader.modulate.a = 0.9
	var tw = create_tween()
	tw.tween_property(fader, "modulate:a", 0.0, duration)


func fade_out_then(cb: Callable) -> void:
	fader.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(fader, "modulate:a", 1.0, 0.45)
	tw.tween_callback(cb)
	tw.tween_interval(0.15)
	tw.tween_property(fader, "modulate:a", 0.0, 0.45)


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
		b.custom_minimum_size = Vector2(240, 52)
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


func show_terminal(data: Dictionary) -> void:
	term_text.clear()
	for line in data.get("lines", []):
		term_text.append_text(str(line) + "\n")
	for c in term_buttons.get_children():
		if c is Button and c.text != "CLOSE":
			c.queue_free()
	for a in data.get("actions", []):
		var b = Button.new()
		b.text = str(a.get("label", "ACTION"))
		b.custom_minimum_size = Vector2(300, 40)
		var cb: Callable = a.get("callable", Callable())
		b.pressed.connect(func():
			if cb.is_valid():
				cb.call()
			hide_all_panels())
		term_buttons.add_child(b)
		term_buttons.move_child(b, term_buttons.get_child_count() - 2)
	show_panel(term_panel)


func show_elevator(data: Dictionary) -> void:
	for c in elev_buttons.get_children():
		c.queue_free()
	_label(elev_buttons, str(data.get("name", "ELEVATOR")), 24,
		Color(0.8, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	for f in data.get("floors", []):
		var fname: String = f.get("name", "FLOOR")
		var idx: int = f.get("index", 0)
		var b = Button.new()
		b.text = fname
		b.custom_minimum_size = Vector2(320, 46)
		b.add_theme_font_size_override("font_size", 20)
		var eid: String = data.get("id", "")
		b.pressed.connect(func(): game.travel_elevator(eid, idx))
		elev_buttons.add_child(b)
	var close = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(320, 40)
	close.pressed.connect(func(): hide_all_panels())
	elev_buttons.add_child(close)
	show_panel(elev_panel)


func show_death() -> void:
	death_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_death() -> void:
	death_panel.visible = false


func show_win(time_sec: float) -> void:
	var wt: Label = win_panel.get_node("WinTime")
	wt.text = "TOTAL TIME  " + game.format_time(time_sec)
	win_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
