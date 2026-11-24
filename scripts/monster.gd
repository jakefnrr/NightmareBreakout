extends CharacterBody3D

const SPEED := 3.6
const CATCH_DIST := 1.1

var game: Node = null
var target: CharacterBody3D = null
var speed := SPEED
var body_mesh: Node3D = null
var eye_l: OmniLight3D = null
var eye_r: OmniLight3D = null
var growl_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO


func setup(g: Node, t: CharacterBody3D, pos := Vector3.ZERO) -> void:
	game = g
	target = t
	_build_visual()
	if pos != Vector3.ZERO:
		global_position = pos
	else:
		# Spawn deep in the Storage Room, far from the player.
		var sr = game.level.room_rect("storage")
		var c = sr.get_center()
		global_position = Vector3(c.x + 4.0, 0.0, c.y + 4.0)
	last_pos = global_position


func _build_visual() -> void:
	body_mesh = Node3D.new()
	add_child(body_mesh)
	var skin = StandardMaterial3D.new()
	skin.albedo_color = Color(0.14, 0.02, 0.03)
	skin.roughness = 1.0
	# Tall gaunt body.
	var body = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.42
	cap.height = 2.2
	body.mesh = cap
	body.material_override = skin
	body.position = Vector3(0, 1.15, 0)
	body_mesh.add_child(body)
	# Head.
	var head = MeshInstance3D.new()
	var hs = SphereMesh.new()
	hs.radius = 0.3
	hs.height = 0.6
	head.mesh = hs
	head.material_override = skin
	head.position = Vector3(0, 2.35, 0)
	head.scale = Vector3(0.9, 1.15, 0.95)
	body_mesh.add_child(head)
	# Glowing eyes.
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0.05, 0.02)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.02, 0.0)
	eye_mat.emission_energy_multiplier = 12.0
	for sx in [-0.11, 0.11]:
		var e = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = 0.045
		es.height = 0.09
		e.mesh = es
		e.material_override = eye_mat
		e.position = Vector3(sx, 2.4, -0.26)
		body_mesh.add_child(e)
	# Long arms.
	for sx in [-0.55, 0.55]:
		var arm = MeshInstance3D.new()
		var am = CapsuleMesh.new()
		am.radius = 0.09
		am.height = 1.5
		arm.mesh = am
		arm.material_override = skin
		arm.position = Vector3(sx, 1.3, -0.1)
		arm.rotation.x = 0.25
		arm.rotation.z = sx * 0.15
		body_mesh.add_child(arm)
	# Collision.
	var col = CollisionShape3D.new()
	var cs = CapsuleShape3D.new()
	cs.radius = 0.45
	cs.height = 2.2
	col.shape = cs
	col.position = Vector3(0, 1.15, 0)
	add_child(col)
	# Blinding red glow — lights up the room like a second flashlight.
	eye_l = OmniLight3D.new()
	eye_l.position = Vector3(0, 2.3, 0)
	eye_l.light_color = Color(1, 0.02, 0.0)
	eye_l.light_energy = 6.0
	eye_l.omni_range = 9.0
	eye_l.omni_attenuation = 1.2
	eye_l.shadow_enabled = false
	add_child(eye_l)


func _physics_process(delta: float) -> void:
	if game == null or target == null or game.won:
		return
	if not game.is_playing() or game.ui_blocking():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to = target.global_position - global_position
	to.y = 0.0
	var dist = to.length()
	if dist < CATCH_DIST:
		game._monster_caught()
		return
	var dir = to.normalized()
	# Steer toward the player, slightly slower than WALK_SPEED (4.0).
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	velocity.y = -1.0 if not is_on_floor() else 0.0
	move_and_slide()
	# Face the player.
	if dist > 0.1:
		var look = global_position + dir
		look.y = global_position.y
		look_at(look, Vector3.UP)
	# Stuck detection: if barely moving for a while, nudge sideways.
	if global_position.distance_to(last_pos) < 0.05:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
		last_pos = global_position
	if stuck_timer > 1.2:
		velocity += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		stuck_timer = 0.0
	# Occasional growls, louder when close.
	growl_timer -= delta
	if growl_timer <= 0.0:
		growl_timer = randf_range(2.5, 6.0) * clampf(dist / 12.0, 0.4, 1.0)
		if game.audio:
			game.audio.play_sfx("monster_growl", -8.0 if dist > 8.0 else 0.0)
