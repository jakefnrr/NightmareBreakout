extends SceneTree


func _initialize() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run(main)


func _run(main) -> void:
	for i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png("/tmp/nb_menu.png")
	print("saved menu")
	main.start_game()
	for i in 30:
		await process_frame
	# Stand in a ground-floor room looking down a corridor.
	main.player.global_position = main.facility.slot_center_world(2, 2, 1, 0.9)
	main.player.rotation.y = -PI / 4
	main.player.head.rotation.x = -0.05
	main.player.set_flashlight_owned(true)
	main.player.set_battery(100.0)
	main.player.flashlight_on = true
	main.player._apply_torch()
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var img2 = root.get_texture().get_image()
	img2.save_png("/tmp/nb_game.png")
	print("saved game")
	quit()
