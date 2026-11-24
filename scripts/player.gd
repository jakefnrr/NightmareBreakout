extends CharacterBody3D

const WALK_SPEED = 4.0
const ACCEL = 12.0
const FRICTION = 10.0
const GRAVITY = 18.0
const JUMP_SPEED = 5.2
const MOUSE_SENS = 0.0021
const PITCH_LIMIT = 1.45
const EYE_HEIGHT = 1.62
const INTERACT_DIST = 3.4
const BATTERY_DRAIN_PER_SEC = 100.0 / 60.0

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var torch: SpotLight3D = $Head/Camera3D/Flashlight
@onready var torch_mesh: Node3D = $Head/Camera3D/FlashlightMesh
@onready var fill: OmniLight3D = $Head/Camera3D/FillLight

var game: Node = null
var has_flashlight = false
var flashlight_on = false
var battery_percent = 0.0
var shake = 0.0
var bob_time = 0.0
var bob_amount = 0.0
var step_timer = 0.0
var current_interact: Dictionary = {}
var prompt_text = ""
var frozen = false
var dead = false
var held_anchor: Node3D = null


func _ready() -> void:
	game = get_node("/root/Main")
	torch.visible = false
	if torch_mesh:
		torch_mesh.visible = false
	held_anchor = Node3D.new()
	held_anchor.name = "HeldItem"
	held_anchor.position = Vector3(0.38, -0.38, -0.6)
	cam.add_child(held_anchor)
	update_held_view()


func update_held_view() -> void:
	if held_anchor == null:
		return
	for c in held_anchor.get_children():
		c.queue_free()
	var id := ""
	if game != null and game.held_index >= 0 and game.held_index < game.inventory.size():
		id = game.inventory[game.held_index]
	# Only ONE thing shows in hand: the flashlight viewmodel appears only
	# when the flashlight itself (or nothing) is selected.
	if torch_mesh:
		torch_mesh.visible = has_flashlight and (id == "" or id == "flashlight")
	if id == "" or id == "flashlight" or game == null:
		return
	var m = game._item_mesh(id)
	m.scale = Vector3.ONE * 1.1
	m.rotation = Vector3(0.3, 0.6, 0.2)
	held_anchor.add_child(m)


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 0.6)


func can_control() -> bool:
	return game != null and game.is_playing() and not frozen and not dead \
		and not game.ui_blocking() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func set_flashlight_owned(v: bool) -> void:
	has_flashlight = v
	if torch_mesh:
		torch_mesh.visible = v
	if not v:
		flashlight_on = false
		torch.visible = false
	fill.visible = false


func set_battery(percent: float) -> void:
	battery_percent = clampf(percent, 0.0, 100.0)
	if battery_percent <= 0.0 and flashlight_on:
		flashlight_on = false
		torch.visible = false
		fill.visible = false


func toggle_flashlight() -> void:
	if not has_flashlight or battery_percent <= 0.0 or not game.is_playing():
		return
	flashlight_on = not flashlight_on
	_apply_torch()
	if game.audio:
		game.audio.play_sfx("flashlight")


func _apply_torch() -> void:
	torch.visible = flashlight_on
	fill.visible = flashlight_on


func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.is_playing():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and not game.ui_blocking():
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS,
			-PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not game.ui_blocking():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var is_echo = event is InputEventKey and event.echo
	if event.is_action_pressed("interact") and not is_echo:
		if current_interact.size() > 0 and not game.ui_blocking():
			game.interact(current_interact)
	elif event.is_action_pressed("flashlight") and not is_echo:
		toggle_flashlight()
	elif event.is_action_pressed("inventory") and not is_echo:
		game.toggle_inventory()
	elif event is InputEventKey and event.keycode == KEY_Q and event.pressed and not event.echo:
		game.toggle_inventory()
	elif event.is_action_pressed("ui_cancel") and not is_echo:
		game.toggle_pause_or_close()


func _physics_process(delta: float) -> void:
	if not can_control():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta * 8.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish = (transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * WALK_SPEED
	velocity.x = lerpf(velocity.x, wish.x, minf(1.0, ACCEL * delta))
	velocity.z = lerpf(velocity.z, wish.z, minf(1.0, ACCEL * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_pressed("jump"):
		velocity.y = JUMP_SPEED
	else:
		velocity.y = 0.0
	move_and_slide()

	var h_speed = Vector2(velocity.x, velocity.z).length()
	bob_amount = lerpf(bob_amount, clampf(h_speed / WALK_SPEED, 0.0, 1.2),
		minf(1.0, 8.0 * delta))
	bob_time += delta * (4.0 + h_speed * 1.4)
	head.position.y = EYE_HEIGHT + sin(bob_time * 2.0) * 0.03 * bob_amount
	head.rotation.z = sin(bob_time) * 0.007 * bob_amount

	if h_speed > 0.5 and is_on_floor():
		step_timer -= delta * h_speed
		if step_timer <= 0.0:
			step_timer = 2.6
			var surface = get_surface()
			if game.audio:
				game.audio.play_footstep(surface)
	else:
		step_timer = minf(step_timer, 0.4)

	if shake > 0.001:
		shake = move_toward(shake, 0.0, delta * 1.6)
		cam.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.1
	else:
		cam.position = Vector3.ZERO


func _process(delta: float) -> void:
	update_interact()
	if flashlight_on and game and game.is_playing() and not game.ui_blocking():
		battery_percent = maxf(0.0, battery_percent - BATTERY_DRAIN_PER_SEC * delta)
		if battery_percent <= 0.0:
			flashlight_on = false
			_apply_torch()
		elif battery_percent <= 10.0:
			# Occasional flicker near empty.
			var n = sin(Time.get_ticks_msec() * 0.09) + sin(Time.get_ticks_msec() * 0.031)
			torch.visible = n > -0.2
			fill.visible = torch.visible
			if torch.visible:
				torch.light_energy = randf_range(3.5, 5.5)
			else:
				torch.light_energy = 0.0
		else:
			_apply_torch()
			torch.light_energy = 5.0


func update_interact() -> void:
	current_interact = {}
	prompt_text = ""
	if not can_control() or not cam:
		return
	var space = get_world_3d().direct_space_state
	var from = cam.global_position
	var to = from - cam.global_transform.basis.z * INTERACT_DIST
	var q = PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [get_rid()])
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	if col == null:
		return
	var data: Variant = col.get_meta("interact", null)
	if data is Dictionary:
		current_interact = data.duplicate()
		current_interact["node"] = col
		prompt_text = game.get_prompt(data)


func get_surface() -> String:
	var space = get_world_3d().direct_space_state
	var from = global_position + Vector3(0, 0.5, 0)
	var to = global_position + Vector3(0, -3.0, 0)
	var q = PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [get_rid()])
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return "concrete"
	var col: Object = hit.get("collider")
	if col and col.has_meta("surface"):
		return str(col.get_meta("surface"))
	return "concrete"
