class_name SurfaceRules
extends RefCounted

const UP := Vector3i(0, 1, 0)
const DOWN := Vector3i(0, -1, 0)
const NORTH := Vector3i(0, 0, -1)
const SOUTH := Vector3i(0, 0, 1)
const EAST := Vector3i(1, 0, 0)
const WEST := Vector3i(-1, 0, 0)

static func cell_key(cube: Vector3i, normal: Vector3i) -> String:
	return "%d,%d,%d|%d,%d,%d" % [cube.x, cube.y, cube.z, normal.x, normal.y, normal.z]

static func right_vector(up: Vector3i, forward: Vector3i) -> Vector3i:
	return Vector3i(Vector3(forward).cross(Vector3(up)).round())

static func turn_left(up: Vector3i, forward: Vector3i) -> Vector3i:
	return -right_vector(up, forward)

static func turn_right(up: Vector3i, forward: Vector3i) -> Vector3i:
	return right_vector(up, forward)

static func is_orientation_valid(up: Vector3i, forward: Vector3i) -> bool:
	return up.length_squared() == 1 and forward.length_squared() == 1 and Vector3(up).dot(Vector3(forward)) == 0.0

static func movement_result(
	cells: Dictionary,
	cube: Vector3i,
	up: Vector3i,
	forward: Vector3i,
	direction_sign: int = 1
) -> Dictionary:
	var move_direction := forward * direction_sign
	var same_cube := cube + move_direction
	var same_key := cell_key(same_cube, up)
	if _is_active(cells, same_key):
		return _result(true, "same", same_cube, up, forward)

	# Convex edge: continue around the outside of the current cube.
	var convex_key := cell_key(cube, move_direction)
	if _is_active(cells, convex_key):
		var convex_forward := -up * direction_sign
		return _result(true, "convex", cube, move_direction, convex_forward)

	# Concave edge: climb the inward face of the adjacent cube.
	var concave_normal := -move_direction
	var concave_key := cell_key(same_cube, concave_normal)
	if _is_active(cells, concave_key):
		var concave_forward := up * direction_sign
		return _result(true, "concave", same_cube, concave_normal, concave_forward)

	return _result(false, "fall", same_cube, up, forward)

static func jump_result(
	cells: Dictionary,
	cube: Vector3i,
	up: Vector3i,
	forward: Vector3i
) -> Dictionary:
	var target_cube := cube + forward * 2
	var target_key := cell_key(target_cube, up)
	if _is_active(cells, target_key):
		return _result(true, "jump", target_cube, up, forward)
	return _result(false, "fall", target_cube, up, forward)

static func basis_from(up: Vector3i, forward: Vector3i) -> Basis:
	var right := Vector3(right_vector(up, forward))
	return Basis(right, Vector3(up), -Vector3(forward)).orthonormalized()

static func _is_active(cells: Dictionary, key: String) -> bool:
	return cells.has(key) and bool(cells[key].get("active", true))

static func _result(found: bool, transition: String, cube: Vector3i, up: Vector3i, forward: Vector3i) -> Dictionary:
	return {
		"found": found,
		"transition": transition,
		"cube": cube,
		"normal": up,
		"forward": forward
	}
