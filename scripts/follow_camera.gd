class_name FollowCamera
extends Camera3D

var target: GridMover
var follow_distance := 7.4
var follow_height := 4.6
var look_ahead := 1.25
var free_look := 0.0
var shake_strength := 0.0
var camera_shake_enabled := true

func setup(follow_target: GridMover) -> void:
	target = follow_target
	current = true
	fov = 58.0

func _process(delta: float) -> void:
	if target == null:
		return
	var up := target.current_up()
	var forward := target.current_forward()
	var right := forward.cross(up).normalized()
	free_look = move_toward(free_look, Input.get_axis("camera_left", "camera_right") * 0.65, delta * 2.8)
	var orbit_forward := (forward * cos(free_look) + right * sin(free_look)).normalized()
	var desired := target.global_position - orbit_forward * follow_distance + up * follow_height
	global_position = global_position.lerp(desired, 1.0 - exp(-delta * 7.0))
	var look_target := target.global_position + forward * look_ahead
	look_at(look_target, up)
	if shake_strength > 0.001 and camera_shake_enabled:
		position += (right * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) * shake_strength
		shake_strength = move_toward(shake_strength, 0.0, delta * 1.5)

func shake(amount: float = 0.18) -> void:
	shake_strength = amount
