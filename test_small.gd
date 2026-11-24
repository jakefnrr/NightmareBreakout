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
	check(game.doors.size() == 5, "5 doors built")
	check(game.world_items.size() >= 8, "world items placed")
	check(not game.started, "not started before Play")
	game.start_game()
	check(game.started, "game started")
	await process_frame

	# Room 1 gold key -> Room 2 door.
	var r = _world_pick("gold_key")
	check(not r.is_empty(), "gold_key exists")
	game.try_pickup({"item_id": "gold_key", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.has_item("gold_key"), "picked up GOLD KEY")
	game.try_door("door_r1_r2")
	check(game.doors["door_r1_r2"]["open"], "room2 door opens with gold key")
	check(not game.has_item("gold_key"), "gold key consumed")
	for i in 60:
		await process_frame
	check(game.doors["door_r1_r2"]["mesh"].position.y < -0.5, "door mesh sank open")
	check(game.doors["door_r1_r2"]["col"].disabled, "door collision off")

	# Secret door behind Room 1 crates opens freely.
	game.try_door("door_r1_r2_secret")
	check(game.doors["door_r1_r2_secret"]["open"], "secret door opens")

	# Power room door needs the desk key.
	game.try_door("door_r2_ws")
	check(not game.doors["door_r2_ws"]["open"], "power room door locked without key")
	r = _world_pick("key_power")
	check(not r.is_empty(), "key_power exists")
	game.try_pickup({"item_id": "key_power", "node": r["node"], "pick_id": r["pick_id"]})
	game.try_door("door_r2_ws")
	check(game.doors["door_r2_ws"]["open"], "power room door opens with key")

	# Security door needs power cell.
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

	# Security lights off -> switch on.
	var any_on = false
	for l in game.sec_lights:
		if l.visible: any_on = true
	check(not any_on, "security lights off initially")
	game._toggle_security_lights()
	any_on = true
	for l in game.sec_lights:
		if not l.visible: any_on = false
	check(any_on, "security lights on after switch")

	# Flashlight + battery swap.
	r = _world_pick("flashlight")
	game.try_pickup({"item_id": "flashlight", "node": r["node"], "pick_id": r["pick_id"]})
	check(game.player.has_flashlight, "flashlight owned")
	check(game.player.battery_percent == 100.0, "battery at 100%")
	for i in game.inventory.size():
		if game.inventory[i] == "gold_key":
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

	# Blackout system.
	check(not game.lights_out, "lights on before blackout")
	game._trigger_blackout()
	check(game.lights_out, "blackout triggered")
	var r1_lit = false
	for l in game.room_lights["r1"]:
		if l.visible: r1_lit = true
	check(not r1_lit, "room lights off during blackout")
	var batt = _world_pick("battery")
	check(not batt.is_empty(), "spare battery spawned in power room")
	game._power_button()
	check(not game.lights_out, "power button restores lights")
	r1_lit = false
	for l in game.room_lights["r1"]:
		if l.visible: r1_lit = true
	check(r1_lit, "room lights back on")

	# Snake + jumpscare.
	game.snake.open()
	check(game.snake.is_open(), "snake open")
	check(paused, "game paused during snake")
	game.snake.dir = Vector2i(1, 0)
	for i in 40:
		game.snake._step()
		if game.snake.gameover:
			break
	check(game.snake.score >= 0, "snake steps ran")
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
	game.snake.open()
	game.toggle_pause_or_close()
	check(not game.snake.is_open(), "esc closes snake")
	check(not game.ui.scare_rect.visible, "no scare on esc")

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
