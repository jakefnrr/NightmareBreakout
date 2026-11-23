extends SceneTree

var main
var failures = 0


func _initialize() -> void:
	for p in ["user://nb_checkpoint.json", "user://nb_time.cfg"]:
		var abs_path = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(abs_path)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS  " + name)
	else:
		failures += 1
		print("FAIL  " + name)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func find_item(item_id: String) -> Dictionary:
	for rec in main.world_items:
		if rec["item_id"] == item_id and not main.collected.has(rec["pick_id"]):
			return rec
	return {}


func pickup(rec: Dictionary) -> void:
	main.player.global_position = rec["node"].global_position + Vector3(0, 0.3, 0)
	await frames(8)
	main.try_pickup({"type": "pickup", "item_id": rec["item_id"],
		"pick_id": rec["pick_id"], "node": rec["node"]})


func _run() -> void:
	await frames(90)
	print("== NIGHTMARE BREAKOUT HEADLESS TEST ==")
	main.start_game()
	await frames(5)
	check(main.started, "game started")
	check(main.facility.infos.size() > 50, "facility rooms built (%d)" % main.facility.infos.size())

	# Flashlight
	var fl = find_item("flashlight")
	check(not fl.is_empty(), "flashlight exists")
	if not fl.is_empty():
		await pickup(fl)
		check(main.has_item("flashlight") and main.player.has_flashlight, "flashlight picked up")

	# Battery drain
	main.player.set_flashlight_owned(true)
	main.player.set_battery(100.0)
	main.player.flashlight_on = true
	main.player._apply_torch()
	var b0 = main.player.battery_percent
	await frames(90)
	check(main.player.battery_percent < b0, "battery drains (%.1f -> %.1f)" % [b0, main.player.battery_percent])

	# Battery pickup + replace
	var bat = find_item("battery")
	check(not bat.is_empty(), "battery exists")
	if not bat.is_empty():
		await pickup(bat)
		check(main.has_item("battery"), "battery picked up")
		var idx = main.inventory.find("battery")
		main.ui.selected_inv = idx
		main.inventory_replace_battery()
		check(main.player.battery_percent == 100.0 and not main.has_item("battery"), "battery replaced")

	# Door lock: give storage key, open storage door; lab door stays locked.
	main.add_item("key_storage")
	var storage_door = ""
	var lab_door = ""
	for id in main.doors:
		var rec: Dictionary = main.doors[id]
		if rec.get("req", {}).get("key", "") == "key_storage" and not rec.get("open", false):
			storage_door = id
		if rec.get("req", {}).get("key", "") == "key_lab" and not rec.get("open", false):
			lab_door = id
	check(storage_door != "", "found storage door")
	check(lab_door != "", "found lab door")
	if storage_door != "":
		main.try_door(storage_door)
		check(main.doors[storage_door].get("open", false), "storage door opened with key")
	if lab_door != "":
		main.try_door(lab_door)
		check(not main.doors[lab_door].get("open", false), "lab door stays locked without key")

	# Puzzle gate
	var gate_door = ""
	for id in main.doors:
		var rec: Dictionary = main.doors[id]
		if rec.get("req", {}).get("puzzle", "") == "p_gate1":
			gate_door = id
	check(gate_door != "", "found puzzle-gated door")
	if gate_door != "":
		check(not main.doors[gate_door].get("req", {}).is_empty(), "gate locked before solve")
		main.puzzle_solved("p_gate1")
		check(main.doors[gate_door].get("req", {}).is_empty(), "gate unlocked after solve")
	check(main.puzzles.get("p_gate1", {}).get("solved", false), "puzzle marked solved")

	# Checkpoint + death restore
	main.activate_checkpoint("cp_0")
	await frames(3)
	check(main.checkpoint_active == "cp_0", "checkpoint activated")
	check(main.checkpoint_snapshot.size() > 0, "checkpoint snapshot saved")
	var snap_inv = main.checkpoint_snapshot.get("inventory", []).duplicate()
	main.player.global_position += Vector3(6, 0, 6)
	main.inventory.append("crowbar")
	main.kill_player()
	var waited = 0
	while main.dead and waited < 900:
		await process_frame
		waited += 1
	check(not main.dead, "player respawned after death")
	check(main.inventory == snap_inv, "inventory restored (%s vs %s)" % [str(main.inventory), str(snap_inv)])
	check(main.monster == null or not main.monster.active, "monster inactive after restore")

	# Power outage / restore
	main._start_outage()
	check(not main.power_on, "outage started")
	main.restore_power()
	check(main.power_on, "power restored")

	# Elevator
	var elev_before = main.player.global_position.y
	main.open_elevator("elev_2_1")
	await frames(3)
	check(main.ui.elev_panel.visible, "elevator panel opened")
	main.travel_elevator("elev_2_1", 0)
	await frames(140)
	check(main.player.global_position.y < -5.0, "elevator traveled to sublevel (y=%.1f)" % main.player.global_position.y)

	# Monster trigger via final key
	var fk = find_item("final_key")
	check(not fk.is_empty(), "final key exists")
	if not fk.is_empty():
		await pickup(fk)
		check(main.final_key_taken and main.chase_active, "final key triggers chase")
		check(main.monster != null and main.monster.active, "monster active")
	# Escape: ensure final key in inventory then try hatch.
	if not main.has_item("final_key"):
		main.inventory.append("final_key")
	main.try_escape()
	check(main.won, "escape wins game")
	check(main.final_time >= 0.0, "final time recorded")

	print("== DONE failures=%d ==" % failures)
	quit(1 if failures > 0 else 0)
