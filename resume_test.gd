extends SceneTree

var failures = 0


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS  " + name)
	else:
		failures += 1
		print("FAIL  " + name)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	for p in ["user://nb_checkpoint.json", "user://nb_time.cfg"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _run(main) -> void:
	await frames(70)
	main.start_game()
	await frames(5)
	# Move player somewhere distinct, then activate checkpoint.
	main.player.global_position = main.facility.slot_center_world(1, 3, 1, 0.9)
	await frames(5)
	main.activate_checkpoint("cp_4")
	await frames(3)
	var snap_pos: Array = main.checkpoint_snapshot["player_pos"]
	var snap_inv: Array = main.checkpoint_snapshot["inventory"]
	print("snapshot pos=%s inv=%s" % [str(snap_pos), str(snap_inv)])
	# Simulate quit + relaunch.
	main.queue_free()
	await frames(8)
	var main2 = load("res://scenes/main.tscn").instantiate()
	root.add_child(main2)
	await frames(70)
	check(main2.checkpoint_active == "cp_4", "checkpoint id persisted (%s)" % main2.checkpoint_active)
	main2.start_game()
	await frames(5)
	var p = main2.player.global_position
	check(absf(p.x - snap_pos[0]) < 1.0 and absf(p.z - snap_pos[2]) < 1.0,
		"player position restored (%.1f,%.1f vs %.1f,%.1f)" % [p.x, p.z, snap_pos[0], snap_pos[2]])
	check(main2.inventory == snap_inv, "inventory restored on relaunch")
	print("== RESUME TEST DONE failures=%d ==" % failures)
	quit(1 if failures > 0 else 0)
