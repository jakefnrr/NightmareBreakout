extends SceneTree

var frames := 0
var main: Node = null


func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30 and main and not main.started:
		main.start_game()
	if frames == 120:
		var img = root.get_texture().get_image()
		img.save_png("/tmp/nb_shot2.png")
		print("SAVED /tmp/nb_shot2.png")
		return true
	return false
