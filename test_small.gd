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


func _pickup(item_id: String) -> void:
	var r = _world_pick(item_id)
	check(not r.is_empty(), "%s exists" % item_id)
	if r.is_empty():
		return
	game.try_pickup({"item_id": item_id, "node": r["node"], "pick_id": r["pick_id"]})


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	game = main
	check(game.player != null, "player spawned")
	check(game.doors.size() == 6, "6 doors built")
	check(game.world_items.size() >= 9, "world items placed")
	check(not game.started, "not started before Play")
	game.start_game()
	check(game.started, "game started")
	await process_frame

	# --- Progression: keys and doors ---
	_pickup("gold_key")
	check(game.has_item("gold_key"), "picked up GOLD KEY")
	game.try_door("door_start_main")
	check(game.doors["door_start_main"]["open"], "start->main door opens")
	check(not game.has_item("gold_key"), "gold key consumed")
	for i in 30:
		await process_frame
	check(game.doors["door_start_main"]["col"].disabled, "door collision off")

	game.try_door("door_main_power")
	check(not game.doors["door_main_power"]["open"], "power door locked without key")
	_pickup("key_power")
	game.try_door("door_main_power")
	check(game.doors["door_main_power"]["open"], "power door opens with DESK KEY")

	# Flashlight + batteries + cells in the Power Room.
	_pickup("flashlight")
	check(game.player.has_flashlight, "flashlight owned")
	check(game.player.battery_percent == 100.0, "battery at 100%")
	_pickup("battery")
	check(game.has_item("battery"), "battery in inventory")
	for i in game.inventory.size():
		if game.inventory[i] == "battery":
			game.ui.selected_inv = i
	game.player.set_battery(20.0)
	game.inventory_replace_battery()
	check(game.player.battery_percent == 100.0, "battery replaced to 100%")
	check(not game.has_item("battery"), "spare battery consumed")

	# Drop a battery to keep inventory under cap, then arcade + storage keys.
	_pickup("battery")
	for i in game.inventory.size():
		if game.inventory[i] == "battery":
			game.inventory_drop(i)
			break
	_pickup("key_arcade")
	game.try_door("door_main_arcade")
	check(game.doors["door_main_arcade"]["open"], "arcade door opens with ARCADE KEY")

	game.try_door("door_main_storage")
	check(not game.doors["door_main_storage"]["open"], "storage door locked without key")
	_pickup("key_storage")
	game.try_door("door_main_storage")
	check(game.doors["door_main_storage"]["open"], "storage door opens with POOL KEY")

	# --- Blackout system ---
	check(not game.lights_out, "lights on before blackout")
	game._trigger_blackout()
	check(game.lights_out, "blackout triggered")
	var batt = _world_pick("battery")
	check(not batt.is_empty(), "spare battery spawned in power room")
	game._power_button()
	check(not game.lights_out, "power button restores lights")
	var main_lit = false
	for l in game.room_lights["main"]:
		if l.visible: main_lit = true
	check(main_lit, "main room light back on")

	# --- Notes / monitor ---
	game.open_computer("desk")
	check(game.ui.doc_panel.visible, "note opens")
	game.ui.hide_all_panels()

	# --- Snake + jumpscare ---
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
	await create_timer(1.5, true, false, true).timeout
	check(not game.ui.scare_rect.visible, "jumpscare cleared")
	check(not paused, "game resumed after jumpscare")
	game.snake.open()
	game.toggle_pause_or_close()
	check(not game.snake.is_open(), "esc closes snake")

	# --- Pool minigame + jumpscare ---
	game.pool.open()
	check(game.pool.is_open(), "pool open")
	check(game.pool.balls.size() == 16, "16 pool balls racked")
	check(paused, "game paused during pool")
	game.pool.close_quiet()
	check(not game.pool.is_open(), "pool closed")
	game.pool.open()
	game.pool.back()
	check(not game.pool.is_open(), "pool closed on BACK")
	check(game.ui.scare_rect.visible, "jumpscare shown on pool BACK")
	await create_timer(1.5, true, false, true).timeout
	check(not game.ui.scare_rect.visible, "pool jumpscare cleared")

	# --- Power-cell closet at the end of Storage ---
	game.try_door("door_storage_cell")
	check(not game.doors["door_storage_cell"]["open"], "cell door locked without cell")
	_pickup("power_cell")
	check(game.has_item("power_cell"), "picked up power cell")
	game.try_door("door_storage_cell")
	check(game.doors["door_storage_cell"]["open"], "cell door opens with POWER CELL")
	check(not game.has_item("power_cell"), "power cell consumed")

	# --- Final key: monster only when walking OUT of storage ---
	# Teleport into storage so the visit registers, grab the key, then leave.
	game.player.global_position = Vector3(10, 0.5, 0)
	await process_frame
	await physics_frame
	_pickup("key_final")
	check(game.key_taken, "final key taken")
	await process_frame
	check(not game.chase_active, "no monster while still inside storage")
	game.player.global_position = Vector3(-4, 0.5, 0)
	await process_frame
	await process_frame
	check(game.chase_active, "chase started on exit from storage")
	check(game.monster != null, "monster spawned")
	check(game.ui.chase_banner.visible, "chase banner shown")
	check(game.audio.chase, "chase audio layer on")
	check(game.monster.speed < 4.0, "monster slightly slower than player")
	game.try_door("door_exit")
	check(game.doors["door_exit"]["open"], "exit door opens with FINAL KEY")
	check(game.won, "game won")
	check(game.ui.win_panel.visible, "win panel shown")

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
