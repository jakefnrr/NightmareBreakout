extends CharacterBody3D

const SPEED := 5.4
const REPATH_INTERVAL := 0.45
const KILL_DIST := 1.35

var game: Node = null
var active := false
var chasing := false
var path: Array = []
var path_i := 0
var repath_timer := 0.0
var stuck_timer := 0.0
var last_pos := Vector3.ZERO
var limb_l: Node3D = null
var limb_r: Node3D = null
var body_mesh: MeshInstance3D = null
var head: Node3D = null
var anim_t := 0.0
var growl_timer := 4.0


func _ready() -> void:
	game = get_node("/root/Main")
	_build_model()
	visible = false
	monitoring = false
	monitorable = false


func _build_model() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.01, 0.01, 0.012)
	body_mat.roughness = 1.0
	body_mat.metallic = 0.0

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.3
	col.shape = cap
	col.position.y = 1.15
	add_child(col)

	body_mesh = MeshInstance3D.new()
	var bc := CapsuleMesh.new()
	bc.radius = 0.34
	bc.height = 2.25
	body_mesh.mesh = bc
	body_mesh.material_override = body_mat
	body_mesh.position.y = 1.15
	add_child(body_mesh)

	head = Node3D.new()
	head.position.y = 2.35
	add_child(head)
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.4
	skull.mesh = sm
	skull.material_override = body_mat
	head.add_child(skull)
	for sx in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		eye.mesh = em
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.05, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1, 0.02, 0.02)
		mat.emission_energy_multiplier = 6.0
		eye.material_override = mat
		eye.position = Vector3(sx, 0.03, -0.18)
		head.add_child(eye)

	limb_l = _limb(Vector3(-0.42, 1.9, 0), 1.5)
	limb_r = _limb(Vector3(0.42, 1.9, 0), 1.5)
	var leg_l := _limb(Vector3(-0.2, 0.9, 0), 0.9)
	leg_l.rotation.z = 0.15
	var leg_r := _limb(Vector3(0.2, 0.9, 0), 0.9)
	leg_r.rotation.z = -0.15


func _limb(pos: Vector3, len: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, len, 0.09)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.008, 0.008, 0.01)
	mat.roughness = 1.0
	m.material_override = mat
	m.position.y = -len / 2.0
	pivot.add_child(m)
	return pivot


func activate(player: Node3D) -> void:
	active = true
	chasing = true
	visible = true
	monitoring = true
	var back := -player.global_transform.basis.z
	global_position = player.global_position + back * 3.2 + Vector3(0, 0.1, 0)
	path = []
	path_i = 0
	if game.audio:
		game.audio.set_chase(true)
	_face(player.global_position)


func deactivate() -> void:
	active = false
	chasing = false
	visible = false
	path = []
	if game.audio:
		game.audio.set_chase(false)


func _face(target: Vector3) -> void:
	var d := target - global_position
	d.y = 0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	if not chasing or game == null or not game.is_playing() or game.ui_blocking():
		velocity = Vector3.ZERO
		return
	var player: Node3D = game.player
	if player == null or player.dead:
		return

	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = REPATH_INTERVAL
		if game.facility:
			path = game.facility.find_path(global_position, player.global_position)
			path_i = 0

	var target := player.global_position
	if path_i < path.size():
		var wp: Dictionary = path[path_i]
		if wp.has("link") and wp["link"] is Vector3:
			# Vertical connector: move to it then teleport.
			target = wp["pos"]
			if global_position.distance_to(wp["pos"]) < 1.6:
				global_position = wp["link"]
				path_i += 1
				repath_timer = 0.0
				return
		else:
			target = wp["pos"]
			if global_position.distance_to(Vector3(target.x, global_position.y, target.z)) < 0.7:
				path_i += 1
				if path_i >= path.size():
					path = []
	else:
		path = []

	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var dist := to.length()
	if dist > 0.05:
		var dir := to / dist
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_face(target)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	# Stuck detection -> repath.
	if Vector2(velocity.x, velocity.z).length() < 0.5 and dist > 1.0:
		stuck_timer += delta
		if stuck_timer > 0.8:
			repath_timer = 0.0
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0

	# Kill check.
	var d := global_position.distance_to(player.global_position)
	if d < KILL_DIST and absf(global_position.y - player.global_position.y) < 2.0:
		game.kill_player()

	anim_t += delta * (6.0 + SPEED)
	limb_l.rotation.x = sin(anim_t) * 0.7
	limb_r.rotation.x = -sin(anim_t) * 0.7
	body_mesh.rotation.z = sin(anim_t * 0.5) * 0.05
	head.rotation.z = sin(anim_t * 0.7) * 0.2
	growl_timer -= delta
	if growl_timer <= 0.0 and game.audio:
		growl_timer = randf_range(3.0, 7.0)
		game.audio.play_sfx("monster_growl", -8.0)
