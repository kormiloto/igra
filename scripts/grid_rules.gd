class_name GridRules
extends RefCounted

const DIRECTIONS: Array[Vector3i] = [
	Vector3i(0, 0, -1),
	Vector3i(1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0)
]

static func wrapped_facing(facing: int) -> int:
	return posmod(facing, 4)

static func direction(facing: int) -> Vector3i:
	return DIRECTIONS[wrapped_facing(facing)]

static func turn_left(facing: int) -> int:
	return wrapped_facing(facing - 1)

static func turn_right(facing: int) -> int:
	return wrapped_facing(facing + 1)

static func step(origin: Vector3i, facing: int, amount: int = 1) -> Vector3i:
	return origin + direction(facing) * amount

static func can_step(board: Dictionary, origin: Vector3i, facing: int, amount: int = 1) -> bool:
	var target := step(origin, facing, amount)
	if board.has(target):
		return true
	# Permit a one-unit ramp between adjacent horizontal cells.
	for y_delta in [-1, 1]:
		if board.has(target + Vector3i(0, y_delta, 0)):
			return true
	return false

static func resolved_step(board: Dictionary, origin: Vector3i, facing: int, amount: int = 1) -> Vector3i:
	var target := step(origin, facing, amount)
	if board.has(target):
		return target
	for y_delta in [-1, 1]:
		var ramp_target := target + Vector3i(0, y_delta, 0)
		if board.has(ramp_target):
			return ramp_target
	return target
