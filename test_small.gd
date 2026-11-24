extends SceneTree

var game: Node = null
var fails := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		fails += 1
		print("FAIL: ", msg)


func _world_pick(rid: String) -> Dictionary:
	for rec in game.world_items:
		if rec["item_id"] == rid:
			return rec
	return {}


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	game = main
	check(game.player != null, "player spawned")
	check(game.doors.size() == 4, "4 doors built")
	check(game.world_items.size() >= 8, "world items placed")
	check(not game.started, "not started before Play")
	game.start_game()
	check(game.started, "game started")
	await process_frame
	check(game.total_time >= 0.0, "timer running state ok")

	# Progression: Room2 key.
	var r = _world_pick("key_room2")
	check(not r.is_empty(), "key_room2 exists")
	game.try_pickup({"item_id": "key_room2", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.has_item("key_room2"), "picked up BRASS KEY")

	# Workspace door needs key.
	game.try_door("door_r1_ws")
	check(game.doors["door_r1_ws"]["open"], "workspace door opens with key")

	# Security door needs power cell; should be locked first.
	game.try_door("door_r2_sec")
	check(not game.doors["door_r2_sec"]["open"], "security door locked without cell")
	r = _world_pick("power_cell")
	game.try_pickup({"item_id": "power_cell", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.has_item("power_cell"), "picked up power cell")
	game.try_door("door_r2_sec")
	check(game.doors["door_r2_sec"]["open"], "security door opens with cell")

	# Video game door needs security key.
	game.try_door("door_r2_vg")
	check(not game.doors["door_r2_vg"]["open"], "vg door locked without key")
	r = _world_pick("key_vg")
	game.try_pickup({"item_id": "key_vg", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.has_item("key_vg"), "picked up SECURITY KEY")
	game.try_door("door_r2_vg")
	check(game.doors["door_r2_vg"]["open"], "vg door opens with key")

	# Security lights start off, switch turns on.
	var any_on = false
	for l in game.sec_lights:
		if l.visible: any_on = true
	check(not any_on, "security lights off initially")
	game._toggle_security_lights()
	any_on = true
	for l in game.sec_lights:
		if not l.visible: any_on = false
	check(any_on, "security lights on after switch")

	# Flashlight.
	r = _world_pick("flashlight")
	game.try_pickup({"item_id": "flashlight", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.player.has_flashlight, "flashlight owned")
	check(game.player.battery_percent == 100.0, "battery at 100%")
	var ev = InputEventAction.new()
	ev.action = "flashlight"
	ev.pressed = true
	game.player._unhandled_input(ev)
	check(game.player.flashlight_on, "flashlight toggled on")
	game.player._unhandled_input(ev)
	check(not game.player.flashlight_on, "flashlight toggled off")

	# Battery swap (free an inventory slot first).
	for i in game.inventory.size():
		if game.inventory[i] == "key_room2":
			game.inventory_drop(i)
			break
	r = _world_pick("battery")
	game.try_pickup({"item_id": "battery", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.has_item("battery"), "battery in inventory")
	for i in game.inventory.size():
		if game.inventory[i] == "battery":
			game.ui.selected_inv = i
	game.player.set_battery(20.0)
	game.inventory_replace_battery()
	check(game.player.battery_percent == 100.0, "battery replaced to 100%")
	check(not game.has_item("battery"), "spare battery consumed")

	# Snake: open, step, game over path, play again, back -> jumpscare.
	game.snake.open()
	check(game.snake.is_open(), "snake open")
	check(paused, "game paused during snake")
	game.snake.dir = Vector2i(1, 0)
	for i in 40:
		game.snake._step()
	check(game.snake.score >= 0, "snake steps ran")
	# Force game over then PLAY AGAIN path (reset).
	game.snake.snake_body = [Vector2i(0, 0)]
	game.snake.dir = Vector2i(-1, 0)
	game.snake._step()
	check(game.snake.gameover, "snake game over detected")
	game.snake.reset()
	check(not game.snake.gameover and game.snake.is_open(), "play again resets")
	game.snake.back()
	check(not game.snake.is_open(), "snake closed on BACK")
	check(game.ui.scare_rect.visible, "jumpscare shown on BACK")
	await create_timer(1.4, true, false, true).timeout
	check(not game.ui.scare_rect.visible, "jumpscare cleared")
	check(not paused, "game resumed after jumpscare")

	# Esc closes snake quietly without scare.
	game.snake.open()
	game.toggle_pause_or_close()
	check(not game.snake.is_open(), "esc closes snake")
	check(not game.ui.scare_rect.visible, "no scare on esc")

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
