extends SceneTree


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _run(main) -> void:
	for i in 60:
		await process_frame
	var f = main.facility
	var pairs = [
		[Vector3i(2, 0, 0), Vector3i(2, 2, 1)],
		[Vector3i(2, 2, 1), Vector3i(1, 2, 2)],
		[Vector3i(0, 0, 0), Vector3i(3, 4, 0)],
		[Vector3i(1, 4, 3), Vector3i(0, 1, 2)],
		[Vector3i(3, 0, 2), Vector3i(2, 3, 3)],
	]
	for p in pairs:
		var a = f.slot_center_world(p[0].x, p[0].y, p[0].z, 0.9)
		var b = f.slot_center_world(p[1].x, p[1].y, p[1].z, 0.9)
		var path = f.find_path(a, b)
		print("path %s -> %s : %d waypoints" % [str(p[0]), str(p[1]), path.size()])
	# Count reachable rooms from start on each floor via BFS over walkable cells ignoring doors? Just report elevator count.
	print("elevators=%d stairs_links=%d doors=%d lights=%d items=%d puzzles=%d" % [
		f.elevators.size(), f.links.size(), main.doors.size(), main.lights.size(),
		main.world_items.size(), main.puzzles.size()])
	quit()
