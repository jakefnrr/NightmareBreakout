extends CharacterBody3D

const WALK_SPEED := 3.8
const SPRINT_SPEED := 6.0
const ACCEL := 14.0
const GRAVITY := 18.0
const MOUSE_SENS := 0.0022
const PITCH_LIMIT := 1.45
const EYE_HEIGHT := 1.62

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera3D
@onready var torch: SpotLight3D = $Head/Camera3D/Flashlight

var shake := 0.0
var bob_time := 0.0
var bob_amount := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(
			head.rotation.x - event.relative.y * MOUSE_SENS,
			-PITCH_LIMIT, PITCH_LIMIT
		)
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				torch.visible = not torch.visible
			KEY_ESCAPE:
				var paused := not get_tree().paused
				get_tree().paused = paused
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE if paused
					else Input.MOUSE_MODE_CAPTURED
				)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	input = input.normalized()

	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var wish := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized() * speed

	velocity.x = lerpf(velocity.x, wish.x, minf(1.0, ACCEL * delta))
	velocity.z = lerpf(velocity.z, wish.z, minf(1.0, ACCEL * delta))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Head bob
	var h_speed := Vector2(velocity.x, velocity.z).length()
	bob_amount = lerpf(bob_amount, clampf(h_speed / WALK_SPEED, 0.0, 1.4), minf(1.0, 8.0 * delta))
	bob_time += delta * (4.0 + h_speed * 1.4)
	head.position.y = EYE_HEIGHT + sin(bob_time * 2.0) * 0.035 * bob_amount
	head.rotation.z = sin(bob_time) * 0.008 * bob_amount

	# Camera shake decay + offset
	if shake > 0.001:
		shake = move_toward(shake, 0.0, delta * 1.6)
		cam.position = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * shake * 0.12
	else:
		cam.position = Vector3.ZERO
