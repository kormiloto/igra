class_name LevelCatalog
extends RefCounted

const LEVEL_SOLVER := preload("res://data/level_solver.gd")

const WORLD_NAMES := ["", "Sunken Temple", "Cloud Machinery", "Ember Orbit"]
const WORLD_SUBTITLES := [
	"",
	"Learn to read the faces of the ruins",
	"Cross walls, undersides and moving skyworks",
	"Master every orientation before the final exit"
]

static var _levels_cache: Array[LevelDefinition] = []

static func all_levels() -> Array[LevelDefinition]:
	if not _levels_cache.is_empty():
		return _levels_cache.duplicate()
	var result: Array[LevelDefinition] = []
	for world in range(1, 4):
		for number in range(1, 11):
			result.append(_make_level(world, number))
	_levels_cache = result
	return _levels_cache.duplicate()

static func get_level(level_id: String) -> LevelDefinition:
	for level in all_levels():
		if level.id == level_id:
			return level
	return null

static func next_level_id(level_id: String) -> String:
	var level := get_level(level_id)
	if level == null or (level.world == 3 and level.number == 10):
		return ""
	if level.number < 10:
		return "W%dL%02d" % [level.world, level.number + 1]
	return "W%dL01" % (level.world + 1)

static func _make_level(world: int, number: int) -> LevelDefinition:
	if world == 1:
		return _make_world_one_level(number)
	return _make_procedural_level(world, number)

static func _make_procedural_level(world: int, number: int) -> LevelDefinition:
	var tier := (world - 2) * 10 + (number - 1)
	var layout := _advanced_world_layout(world, number, tier)
	var builder: Dictionary = layout.builder
	var key_positions: Array[String] = layout.keys
	var fruit_positions: Array[String] = layout.fruits
	var exit_key: String = layout.exit

	var authored_route: Array[String] = builder.route
	var specials := {}
	var reserved_faces: Array = key_positions.duplicate()
	reserved_faces.append_array(fruit_positions)
	reserved_faces.append(exit_key)
	if authored_route.size() > 10:
		var ice_index := _straight_route_index(builder, 5, reserved_faces)
		if ice_index > 0:
			specials[authored_route[ice_index]] = "ice"
	if world == 3:
		var excluded_faces := reserved_faces + specials.keys()
		var hazard_index := _straight_route_index(builder, int(authored_route.size() * 0.35), excluded_faces)
		if hazard_index > 0:
			specials[authored_route[hazard_index]] = "hazard"
		excluded_faces = reserved_faces + specials.keys()
		var collapse_index := _straight_route_index(builder, int(authored_route.size() * 0.65), excluded_faces)
		if collapse_index > 0:
			specials[authored_route[collapse_index]] = "collapse"

	for special_key in specials:
		key_positions.erase(special_key)
		fruit_positions.erase(special_key)

	for cell in builder.cells:
		if specials.has(cell.key()):
			cell.type = specials[cell.key()]

	var level_id := "W%dL%02d" % [world, number]
	var draft := LevelDefinition.new(
		level_id, world, number, _level_title(world, number), 999.0, 998.0,
		builder.cells, authored_route, key_positions, fruit_positions,
		Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH, exit_key, specials
	)
	var solution: Dictionary = LEVEL_SOLVER.solve(draft)
	assert(solution.found, "%s must have a complete authored solution" % level_id)
	var action_count: int = solution.action_count
	var par_time := 12.0 + action_count * 0.75
	var limit := 30.0 + action_count * 1.35
	return LevelDefinition.new(
		level_id, world, number, _level_title(world, number), limit, par_time,
		builder.cells, solution.route, key_positions, fruit_positions,
		Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH, exit_key, specials
	)

static func _advanced_world_layout(world: int, number: int, tier: int) -> Dictionary:
	var spec := _advanced_level_spec(number)
	var builder := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_run_advanced_commands(builder, spec.spine)
	var hub := _snapshot(builder)

	_restore(builder, hub)
	_face(builder, spec.exit_dir)
	_run_advanced_commands(builder, spec.exit_path)
	var exit_key := _current_key(builder)

	var branches: Array = spec.branches
	# Each motif has a different natural solution length. These authored bonuses
	# normalize that variation so the global curve keeps rising without turning
	# the ten silhouettes back into one repeated template.
	var primary_bonuses := (
		[5, 5, 8, 4, 10, 0, 10, 12, 10, 0]
		if world == 2 else
		[42, 37, 33, 31, 40, 27, 33, 30, 30, 18]
	)
	for branch_index in range(branches.size()):
		var branch: Dictionary = branches[branch_index]
		_restore(builder, hub)
		_face(builder, branch.direction)
		var bonus: int = primary_bonuses[number - 1] if branch_index == 0 else int(tier / 4)
		_run_advanced_commands(builder, branch.commands, bonus)
		_add_objective(keys, builder)
		_add_previous_objective(fruits, builder)

	if world == 3:
		_restore(builder, hub)
		_face(builder, spec.extra_dir)
		_run_advanced_commands(builder, spec.extra_path, 2 + int(tier / 6))
		_add_previous_objective(fruits, builder)
		_add_objective(fruits, builder)

	return _layout(builder, keys, fruits, exit_key)

static func _advanced_level_spec(number: int) -> Dictionary:
	match number:
		1:
			return {
				"spine": [["step", 3]],
				"exit_dir": SurfaceRules.EAST, "exit_path": [["step", 2]],
				"branches": [
					{"direction": SurfaceRules.EAST, "commands": [["step", 6], ["wrap"], ["step", 4]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 5], ["wrap"], ["step", 5], ["right"], ["step", 2]]},
					{"direction": SurfaceRules.NORTH, "commands": [["step", 5], ["wrap"], ["step", 4], ["wrap"], ["step", 3]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["step", 7], ["wrap"], ["step", 5], ["wrap"], ["step", 3]]
			}
		2:
			return {
				"spine": [["step", 2], ["right"], ["step", 3]],
				"exit_dir": SurfaceRules.NORTH, "exit_path": [["step", 2]],
				"branches": [
					{"direction": SurfaceRules.NORTH, "commands": [["step", 6], ["wrap"], ["step", 4], ["right"], ["step", 3]]},
					{"direction": SurfaceRules.EAST, "commands": [["jump"], ["step", 4], ["wrap"], ["step", 5]]},
					{"direction": SurfaceRules.SOUTH, "commands": [["step", 6], ["wrap"], ["step", 4], ["wrap"], ["step", 3]]}
				],
				"extra_dir": SurfaceRules.WEST, "extra_path": [["step", 6], ["wrap"], ["step", 5], ["left"], ["step", 3]]
			}
		3:
			return {
				"spine": [["step", 4]],
				"exit_dir": SurfaceRules.EAST, "exit_path": [["jump"], ["step", 1]],
				"branches": [
					{"direction": SurfaceRules.EAST, "commands": [["step", 6], ["wrap"], ["step", 5], ["wrap"], ["step", 4]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 6], ["wrap"], ["step", 3], ["left"], ["step", 4]]},
					{"direction": SurfaceRules.NORTH, "commands": [["jump"], ["step", 4], ["wrap"], ["step", 6]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["jump"], ["step", 5], ["wrap"], ["step", 6]]
			}
		4:
			return {
				"spine": [["step", 2], ["left"], ["step", 4]],
				"exit_dir": SurfaceRules.SOUTH, "exit_path": [["step", 3], ["left"], ["step", 2]],
				"branches": [
					{"direction": SurfaceRules.NORTH, "commands": [["step", 7], ["wrap"], ["step", 5], ["right"], ["step", 4]]},
					{"direction": SurfaceRules.EAST, "commands": [["step", 5], ["wrap"], ["step", 6], ["left"], ["step", 3]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 5], ["wrap"], ["step", 4], ["wrap"], ["step", 4]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["step", 8], ["wrap"], ["step", 5]]
			}
		5:
			return {
				"spine": [["step", 3], ["right"], ["step", 2]],
				"exit_dir": SurfaceRules.NORTH, "exit_path": [["jump"], ["step", 2]],
				"branches": [
					{"direction": SurfaceRules.EAST, "commands": [["jump"], ["step", 5], ["wrap"], ["step", 5]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 4], ["jump"], ["step", 3], ["wrap"], ["step", 5]]},
					{"direction": SurfaceRules.SOUTH, "commands": [["jump"], ["step", 5], ["wrap"], ["step", 4], ["wrap"], ["step", 3]]}
				],
				"extra_dir": SurfaceRules.NORTH, "extra_path": [["step", 7], ["jump"], ["step", 3], ["wrap"], ["step", 4]]
			}
		6:
			return {
				"spine": [["step", 3], ["left"], ["step", 3], ["right"], ["step", 2]],
				"exit_dir": SurfaceRules.EAST, "exit_path": [["step", 2], ["right"], ["step", 2]],
				"branches": [
					{"direction": SurfaceRules.NORTH, "commands": [["step", 6], ["wrap"], ["step", 4], ["right"], ["step", 4], ["wrap"], ["step", 3]]},
					{"direction": SurfaceRules.EAST, "commands": [["step", 6], ["wrap"], ["step", 5], ["left"], ["step", 5]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 6], ["wrap"], ["step", 4], ["wrap"], ["step", 5]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["step", 9], ["wrap"], ["step", 6], ["right"], ["step", 3]]
			}
		7:
			return {
				"spine": [["step", 2], ["right"], ["step", 3], ["left"], ["step", 3]],
				"exit_dir": SurfaceRules.WEST, "exit_path": [["step", 1]],
				"branches": [
					{"direction": SurfaceRules.EAST, "commands": [["step", 7], ["wrap"], ["step", 6], ["wrap"], ["step", 4]]},
					{"direction": SurfaceRules.NORTH, "commands": [["step", 5], ["wrap"], ["step", 4], ["right"], ["step", 6]]},
					{"direction": SurfaceRules.SOUTH, "commands": [["step", 7], ["wrap"], ["step", 5], ["left"], ["step", 4]]}
				],
				"extra_dir": SurfaceRules.WEST, "extra_path": [["jump"], ["step", 7], ["wrap"], ["step", 6]]
			}
		8:
			return {
				"spine": [["jump"], ["step", 2], ["left"], ["step", 4]],
				"exit_dir": SurfaceRules.SOUTH, "exit_path": [["step", 2], ["right"], ["jump"]],
				"branches": [
					{"direction": SurfaceRules.NORTH, "commands": [["step", 8], ["wrap"], ["step", 5], ["wrap"], ["step", 5]]},
					{"direction": SurfaceRules.EAST, "commands": [["jump"], ["step", 6], ["wrap"], ["step", 6], ["right"], ["step", 3]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 6], ["wrap"], ["step", 4], ["left"], ["step", 6]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["step", 10], ["wrap"], ["step", 6], ["wrap"], ["step", 4]]
			}
		9:
			return {
				"spine": [["step", 4], ["right"], ["step", 4]],
				"exit_dir": SurfaceRules.NORTH, "exit_path": [["step", 3], ["left"], ["step", 3]],
				"branches": [
					{"direction": SurfaceRules.EAST, "commands": [["step", 8], ["wrap"], ["step", 6], ["wrap"], ["step", 6]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 7], ["wrap"], ["step", 6], ["wrap"], ["step", 5]]},
					{"direction": SurfaceRules.SOUTH, "commands": [["step", 8], ["wrap"], ["step", 6], ["left"], ["step", 5]]}
				],
				"extra_dir": SurfaceRules.NORTH, "extra_path": [["step", 9], ["wrap"], ["step", 7], ["right"], ["step", 5]]
			}
		10:
			return {
				"spine": [["step", 3], ["right"], ["step", 3], ["left"], ["jump"], ["step", 2]],
				"exit_dir": SurfaceRules.SOUTH, "exit_path": [["step", 2]],
				"branches": [
					{"direction": SurfaceRules.NORTH, "commands": [["step", 9], ["wrap"], ["step", 7], ["right"], ["step", 5], ["wrap"], ["step", 4]]},
					{"direction": SurfaceRules.EAST, "commands": [["jump"], ["step", 7], ["wrap"], ["step", 7], ["left"], ["step", 5]]},
					{"direction": SurfaceRules.WEST, "commands": [["step", 8], ["wrap"], ["step", 6], ["wrap"], ["step", 6], ["right"], ["step", 4]]}
				],
				"extra_dir": SurfaceRules.SOUTH, "extra_path": [["step", 11], ["wrap"], ["step", 8], ["wrap"], ["step", 5]]
			}
	assert(false, "Unknown advanced level motif: %d" % number)
	return {}

static func _run_advanced_commands(builder: Dictionary, commands: Array, length_bonus: int = 0) -> void:
	var step_count := 0
	for command in commands:
		if command[0] == "step":
			step_count += 1
	var bonus_per_step := int(length_bonus / maxi(step_count, 1))
	var bonus_remainder := length_bonus % maxi(step_count, 1)
	var step_index := 0
	for command in commands:
		var operation: String = command[0]
		match operation:
			"step":
				var segment_bonus := bonus_per_step + (1 if step_index < bonus_remainder else 0)
				var authored_length := maxi(2, int(ceil(float(command[1]) * 0.55)))
				_step(builder, authored_length + segment_bonus)
				step_index += 1
			"jump": _jump_step(builder)
			"wrap": _wrap(builder)
			"left": _turn(builder, -1)
			"right": _turn(builder, 1)

static func _make_world_one_level(number: int) -> LevelDefinition:
	var layout := _world_one_layout(number)
	var builder: Dictionary = layout.builder
	var key_positions: Array[String] = layout.keys
	var fruit_positions: Array[String] = layout.fruits
	var exit_key: String = layout.exit
	var draft := LevelDefinition.new(
		"W1L%02d" % number, 1, number, _level_title(1, number), 999.0, 998.0,
		builder.cells, builder.route, key_positions, fruit_positions,
		Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH, exit_key, {}
	)
	var solution: Dictionary = LEVEL_SOLVER.solve(draft)
	assert(solution.found, "Authored World 1 level %d must be solvable" % number)
	var action_count: int = solution.action_count
	var par_time := 12.0 + action_count * 0.75
	var limit := 30.0 + action_count * 1.35
	return LevelDefinition.new(
		draft.id, 1, number, draft.title, limit, par_time,
		builder.cells, solution.route, key_positions, fruit_positions,
		Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH, exit_key, {}
	)

static func _world_one_layout(number: int) -> Dictionary:
	match number:
		1: return _w1_first_key()
		2: return _w1_first_wall()
		3: return _w1_under_ruins()
		4: return _w1_four_faces()
		5: return _w1_temple_fold()
		6: return _w1_stone_spiral()
		7: return _w1_hidden_side()
		8: return _w1_gravity_lesson()
		9: return _w1_outer_shell()
		10: return _w1_temple_mastery()
	assert(false, "Unknown World 1 level: %d" % number)
	return {}

static func _w1_first_key() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 2)
	var hub := _snapshot(b)
	_branch(b, hub, SurfaceRules.EAST, 2)
	_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 2)
	_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 1)
	_add_objective(fruits, b)
	_step(b, 1)
	var exit := _current_key(b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_step(b, 1)
	_add_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _w1_first_wall() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 2)
	var hub := _snapshot(b)
	_branch(b, hub, SurfaceRules.EAST, 3)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 2)
	var exit := _current_key(b)
	_add_previous_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _w1_under_ruins() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 3)
	var hub := _snapshot(b)
	_branch(b, hub, SurfaceRules.EAST, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 2)
	var exit := _current_key(b)
	return _layout(b, keys, fruits, exit)

static func _w1_four_faces() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 2)
	var hub := _snapshot(b)
	for direction in [SurfaceRules.EAST, SurfaceRules.WEST, SurfaceRules.NORTH]:
		_restore(b, hub)
		_face(b, direction)
		_step(b, 2)
		_wrap(b)
		_step(b, 1)
		_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_step(b, 2)
	_add_objective(fruits, b)
	_wrap(b)
	_step(b, 1)
	_add_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 1)
	var exit := _current_key(b)
	_restore(b, hub)
	_face(b, SurfaceRules.EAST)
	_step(b, 1)
	_add_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _w1_temple_fold() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 3)
	var hub := _snapshot(b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_jump_step(b)
	_step(b, 1)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.EAST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_step(b, 1)
	var exit := _current_key(b)
	_step(b, 1)
	_add_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _w1_stone_spiral() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 3)
	var hub := _snapshot(b)
	_face(b, SurfaceRules.NORTH)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_turn(b, 1)
	_step(b, 3)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.EAST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_turn(b, -1)
	_step(b, 2)
	_add_objective(keys, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_jump_step(b)
	_add_objective(fruits, b)
	_turn(b, -1)
	_step(b, 1)
	_turn(b, 1)
	_step(b, 1)
	var exit := _current_key(b)
	return _layout(b, keys, fruits, exit)

static func _w1_hidden_side() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 3)
	var hub := _snapshot(b)
	for direction in [SurfaceRules.NORTH, SurfaceRules.SOUTH, SurfaceRules.WEST]:
		_restore(b, hub)
		_face(b, direction)
		_step(b, 3 if direction != SurfaceRules.SOUTH else 4)
		_wrap(b)
		_step(b, 4)
		_add_objective(keys, b)
		_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.EAST)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 1)
	var exit := _current_key(b)
	return _layout(b, keys, fruits, exit)

static func _w1_gravity_lesson() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 1)
	var exit := _current_key(b)
	_step(b, 2)
	var hub := _snapshot(b)
	for direction in [SurfaceRules.EAST, SurfaceRules.WEST]:
		_restore(b, hub)
		_face(b, direction)
		_step(b, 2)
		_wrap(b)
		_step(b, 2)
		_turn(b, 1 if direction == SurfaceRules.EAST else -1)
		_step(b, 2)
		_add_objective(keys, b)
		_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_jump_step(b)
	_turn(b, -1)
	_step(b, 1)
	_add_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _w1_outer_shell() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 3)
	var hub := _snapshot(b)
	var side_directions := [SurfaceRules.NORTH, SurfaceRules.EAST, SurfaceRules.SOUTH, SurfaceRules.WEST]
	for index in range(side_directions.size()):
		_restore(b, hub)
		_face(b, side_directions[index])
		_step(b, 3 + index)
		_wrap(b)
		_step(b, 4 + index)
		if index < 3:
			_add_objective(keys, b)
			if index < 2:
				_add_previous_objective(fruits, b)
		else:
			_wrap(b)
			_step(b, 3)
			_add_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_jump_step(b)
	_add_objective(fruits, b)
	_step(b, 1)
	var exit := _current_key(b)
	return _layout(b, keys, fruits, exit)

static func _w1_temple_mastery() -> Dictionary:
	var b := _new_builder()
	var keys: Array[String] = []
	var fruits: Array[String] = []
	_step(b, 1)
	var exit := _current_key(b)
	_step(b, 2)
	var hub := _snapshot(b)
	_restore(b, hub)
	_face(b, SurfaceRules.NORTH)
	_jump_step(b)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_turn(b, 1)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.EAST)
	_step(b, 3)
	_wrap(b)
	_step(b, 2)
	_wrap(b)
	_jump_step(b)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.WEST)
	_step(b, 3)
	_wrap(b)
	_step(b, 2)
	_turn(b, -1)
	_step(b, 2)
	_wrap(b)
	_step(b, 2)
	_add_objective(keys, b)
	_add_previous_objective(fruits, b)
	_restore(b, hub)
	_face(b, SurfaceRules.SOUTH)
	_jump_step(b)
	_step(b, 2)
	_add_objective(fruits, b)
	return _layout(b, keys, fruits, exit)

static func _layout(builder: Dictionary, keys: Array[String], fruits: Array[String], exit_key: String) -> Dictionary:
	keys.erase(exit_key)
	fruits.erase(exit_key)
	for key in keys:
		fruits.erase(key)
	return {"builder": builder, "keys": keys, "fruits": fruits, "exit": exit_key}

static func _snapshot(builder: Dictionary) -> Dictionary:
	return {"cube": builder.cube, "normal": builder.normal, "forward": builder.forward}

static func _restore(builder: Dictionary, snapshot: Dictionary) -> void:
	builder.cube = snapshot.cube
	builder.normal = snapshot.normal
	builder.forward = snapshot.forward

static func _face(builder: Dictionary, forward: Vector3i) -> void:
	assert(Vector3(builder.normal).dot(Vector3(forward)) == 0.0)
	builder.forward = forward

static func _branch(builder: Dictionary, root: Dictionary, forward: Vector3i, count: int) -> void:
	_restore(builder, root)
	_face(builder, forward)
	_step(builder, count)

static func _jump_step(builder: Dictionary) -> void:
	builder.cube += builder.forward * 2
	_add_current(builder)

static func _current_key(builder: Dictionary) -> String:
	return SurfaceRules.cell_key(builder.cube, builder.normal)

static func _add_objective(target: Array[String], builder: Dictionary) -> void:
	var key := _current_key(builder)
	if key not in target:
		target.append(key)

static func _add_previous_objective(target: Array[String], builder: Dictionary) -> void:
	var route: Array[String] = builder.route
	if route.size() >= 2:
		var key: String = route[route.size() - 2]
		if key not in target:
			target.append(key)

static func _new_builder() -> Dictionary:
	var builder := {
		"cube": Vector3i.ZERO,
		"normal": SurfaceRules.UP,
		"forward": SurfaceRules.NORTH,
		"cells": [] as Array[SurfaceCell],
		"route": [] as Array[String],
		"orientations": [] as Array[Dictionary]
	}
	_add_current(builder)
	return builder

static func _add_current(builder: Dictionary) -> void:
	var cell := SurfaceCell.new(builder.cube, builder.normal)
	var key := cell.key()
	if key not in builder.route:
		builder.cells.append(cell)
		builder.route.append(key)
		builder.orientations.append({"normal": builder.normal, "forward": builder.forward})

static func _step(builder: Dictionary, count: int) -> void:
	for index in range(count):
		builder.cube += builder.forward
		_add_current(builder)

static func _turn(builder: Dictionary, direction: int) -> void:
	if direction > 0:
		builder.forward = SurfaceRules.turn_right(builder.normal, builder.forward)
	else:
		builder.forward = SurfaceRules.turn_left(builder.normal, builder.forward)

static func _wrap(builder: Dictionary) -> void:
	var old_normal: Vector3i = builder.normal
	builder.normal = builder.forward
	builder.forward = -old_normal
	_add_current(builder)

static func _straight_route_index(builder: Dictionary, preferred: int, excluded: Array = []) -> int:
	var orientations: Array[Dictionary] = builder.orientations
	var route: Array[String] = builder.route
	var cells: Array[SurfaceCell] = builder.cells
	for index in range(clampi(preferred, 1, orientations.size() - 2), orientations.size() - 1):
		if route[index] in excluded:
			continue
		var incoming := cells[index].cube - cells[index - 1].cube
		var outgoing := cells[index + 1].cube - cells[index].cube
		if incoming.length_squared() != 1 or incoming != outgoing:
			continue
		if orientations[index - 1].normal == orientations[index].normal and orientations[index].normal == orientations[index + 1].normal:
			if orientations[index - 1].forward == orientations[index].forward and orientations[index].forward == orientations[index + 1].forward:
				return index
	return -1

static func _level_title(world: int, number: int) -> String:
	var names := {
		1: ["First Key", "The First Wall", "Under the Ruins", "Four Faces", "Temple Fold", "Stone Spiral", "Hidden Side", "Gravity Lesson", "Outer Shell", "Temple Mastery"],
		2: ["Cloud Face", "Blue Wall", "Under the Engine", "Prism Turn", "Frozen Fold", "Sky Circuit", "Machine Skin", "Inverted Route", "Six Directions", "Weather Core"],
		3: ["Ember Face", "Hot Corner", "Below the Flame", "Orbit Fold", "Red Circuit", "Gravity Furnace", "Outer Fire", "Inverted Crown", "Final Spiral", "Last Exit"]
	}
	return names[world][number - 1]
