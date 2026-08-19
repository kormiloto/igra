class_name GridMover
extends Node3D

const AERI_SCENE := preload("res://assets/3d/environment/aeri.glb")

signal landed(cube: Vector3i, normal: Vector3i)
signal fell
signal state_changed(state_name: String)

enum MoveState { IDLE, TURNING, ROLLING, JUMPING, FALLING, DEAD }

var board: GridBoard
var surface_cube := Vector3i.ZERO
var surface_normal := SurfaceRules.UP
var forward_axis := SurfaceRules.NORTH
var target_cube := Vector3i.ZERO
var target_normal := SurfaceRules.UP
var target_forward := SurfaceRules.NORTH
var state := MoveState.IDLE
var buffered_action := ""
var action_elapsed := 0.0
var action_duration := 0.24
var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var arc_control := Vector3.ZERO
var start_quaternion := Quaternion.IDENTITY
var end_quaternion := Quaternion.IDENTITY
var transition_type := "same"
var visual: Node3D
var visual_target_yaw := 0.0
var input_enabled := true

func setup(level: LevelDefinition, target_board: GridBoard) -> void:
	board = target_board
	surface_cube = level.spawn_cube
	surface_normal = level.spawn_normal
	forward_axis = level.spawn_forward
	position = board.surface_world_position(surface_cube, surface_normal)
	basis = SurfaceRules.basis_from(surface_normal, forward_axis)
	_create_visual(level.world)

func _process(delta: float) -> void:
	if state == MoveState.IDLE and input_enabled:
		_capture_input()
	if state != MoveState.IDLE and state != MoveState.DEAD:
		_update_action(delta)
	_face_visual_to_movement(delta)

func _face_visual_to_movement(delta: float) -> void:
	if not is_instance_valid(visual):
		return
	# Blender +Y exports as Godot local -Z, so the model's natural zero
	# rotation already faces the mover's forward direction.
	visual.rotation.y = lerp_angle(visual.rotation.y, visual_target_yaw, minf(delta * 14.0, 1.0))

func request_action(action: String) -> void:
	if not input_enabled or state == MoveState.DEAD:
		return
	if state != MoveState.IDLE:
		buffered_action = action
		return
	match action:
		"left": _begin_turn(-1)
		"right": _begin_turn(1)
		"forward": _begin_roll(1)
		"back": _begin_roll(-1)
		"jump": _begin_jump()

func force_forward() -> void:
	if state == MoveState.IDLE:
		_begin_roll(1)
	else:
		buffered_action = "forward"

func die() -> void:
	if state == MoveState.DEAD:
		return
	state = MoveState.DEAD
	input_enabled = false
	state_changed.emit("Dead")
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for mesh in _visual_meshes(visual):
		tween.tween_property(mesh, "transparency", 1.0, 0.42).set_delay(0.08)

func current_up() -> Vector3:
	return basis.y.normalized()

func current_forward() -> Vector3:
	return -basis.z.normalized()

func _capture_input() -> void:
	if Input.is_action_just_pressed("move_left"):
		request_action("left")
	elif Input.is_action_just_pressed("move_right"):
		request_action("right")
	elif Input.is_action_just_pressed("move_forward"):
		request_action("forward")
	elif Input.is_action_just_pressed("move_back"):
		request_action("back")
	elif Input.is_action_just_pressed("jump"):
		request_action("jump")

func _begin_turn(direction: int) -> void:
	visual_target_yaw = 0.0
	state = MoveState.TURNING
	action_elapsed = 0.0
	action_duration = 0.16
	target_cube = surface_cube
	target_normal = surface_normal
	target_forward = SurfaceRules.turn_right(surface_normal, forward_axis) if direction > 0 else SurfaceRules.turn_left(surface_normal, forward_axis)
	start_quaternion = basis.get_rotation_quaternion()
	end_quaternion = SurfaceRules.basis_from(target_normal, target_forward).get_rotation_quaternion()
	state_changed.emit("Turning")

func _begin_roll(direction_sign: int) -> void:
	visual_target_yaw = 0.0 if direction_sign > 0 else PI
	var result := board.resolve_move(surface_cube, surface_normal, forward_axis, direction_sign)
	if not result.found:
		_begin_fall(forward_axis * direction_sign)
		return
	state = MoveState.ROLLING
	action_elapsed = 0.0
	transition_type = result.transition
	action_duration = 0.30 if transition_type != "same" else 0.22
	start_position = position
	target_cube = result.cube
	target_normal = result.normal
	target_forward = result.forward
	end_position = board.surface_world_position(target_cube, target_normal)
	start_quaternion = basis.get_rotation_quaternion()
	end_quaternion = SurfaceRules.basis_from(target_normal, target_forward).get_rotation_quaternion()
	arc_control = (start_position + end_position) * 0.5
	if transition_type == "convex":
		arc_control += (Vector3(surface_normal) + Vector3(target_normal)).normalized() * 0.72
	state_changed.emit("Rolling")

func _begin_jump() -> void:
	visual_target_yaw = 0.0
	var result := board.resolve_jump(surface_cube, surface_normal, forward_axis)
	if not result.found:
		_begin_fall(forward_axis)
		return
	state = MoveState.JUMPING
	action_elapsed = 0.0
	action_duration = 0.44
	start_position = position
	target_cube = result.cube
	target_normal = result.normal
	target_forward = result.forward
	end_position = board.surface_world_position(target_cube, target_normal)
	start_quaternion = basis.get_rotation_quaternion()
	end_quaternion = SurfaceRules.basis_from(target_normal, target_forward).get_rotation_quaternion()
	state_changed.emit("Jumping")

func _begin_fall(move_direction: Vector3i) -> void:
	visual_target_yaw = 0.0 if Vector3(move_direction).dot(Vector3(forward_axis)) >= 0.0 else PI
	state = MoveState.FALLING
	action_elapsed = 0.0
	action_duration = 0.82
	start_position = position
	end_position = position + Vector3(move_direction) * 1.2 - Vector3(surface_normal) * 12.0
	start_quaternion = basis.get_rotation_quaternion()
	end_quaternion = start_quaternion
	state_changed.emit("Falling")

func _update_action(delta: float) -> void:
	action_elapsed += delta
	var weight := clampf(action_elapsed / action_duration, 0.0, 1.0)
	var eased := _smooth(weight)
	match state:
		MoveState.TURNING:
			basis = Basis(start_quaternion.slerp(end_quaternion, eased)).orthonormalized()
		MoveState.ROLLING:
			if transition_type == "convex":
				position = _quadratic_bezier(start_position, arc_control, end_position, eased)
			else:
				position = start_position.lerp(end_position, eased)
			basis = Basis(start_quaternion.slerp(end_quaternion, eased)).orthonormalized()
			visual.position.y = sin(weight * PI) * 0.10
		MoveState.JUMPING:
			position = start_position.lerp(end_position, weight) + Vector3(surface_normal) * sin(weight * PI) * 2.0
		MoveState.FALLING:
			position = start_position.lerp(end_position, weight * weight)
	if weight >= 1.0:
		_complete_action()

func _complete_action() -> void:
	if state == MoveState.FALLING:
		die()
		fell.emit()
		return
	var completed_state := state
	surface_cube = target_cube
	surface_normal = target_normal
	forward_axis = target_forward
	position = board.surface_world_position(surface_cube, surface_normal)
	basis = SurfaceRules.basis_from(surface_normal, forward_axis)
	visual.position = Vector3.ZERO
	state = MoveState.IDLE
	state_changed.emit("Idle")
	if completed_state in [MoveState.ROLLING, MoveState.JUMPING]:
		_land_squash()
		landed.emit(surface_cube, surface_normal)
	if not buffered_action.is_empty():
		var next_action := buffered_action
		buffered_action = ""
		request_action(next_action)

func _smooth(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)

func _quadratic_bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a * (1.0 - t) * (1.0 - t) + b * 2.0 * (1.0 - t) * t + c * t * t

func _create_visual(world: int) -> void:
	visual = AERI_SCENE.instantiate() as Node3D
	visual.name = "Aeri"
	visual_target_yaw = 0.0
	visual.rotation.y = visual_target_yaw
	add_child(visual)
	var light := OmniLight3D.new()
	light.name = "AeriGlow"
	light.light_color = [Color.WHITE, Color("ffd478"), Color("7cecff"), Color("ff8b69")][world]
	light.light_energy = 0.20
	light.omni_range = 1.65
	light.shadow_enabled = false
	add_child(light)
	_create_trail(light.light_color)

func _visual_meshes(root: Node) -> Array[GeometryInstance3D]:
	var meshes: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		meshes.append(root as GeometryInstance3D)
	for child in root.get_children():
		meshes.append_array(_visual_meshes(child))
	return meshes

func _create_trail(color: Color) -> void:
	var trail := CPUParticles3D.new()
	trail.name = "StardustTrail"
	trail.amount = 8
	trail.lifetime = 0.34
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.24
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 42.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.25
	trail.initial_velocity_max = 0.85
	trail.scale_amount_min = 0.025
	trail.scale_amount_max = 0.065
	trail.color = Color(0.78, 0.84, 0.88, 0.34)
	var spark := SphereMesh.new()
	spark.radius = 0.07
	spark.height = 0.14
	trail.mesh = spark
	trail.position = Vector3(0, 0, 0.62)
	add_child(trail)

func _land_squash() -> void:
	if not is_instance_valid(visual):
		return
	visual.scale = Vector3(1.10, 0.88, 1.10)
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
