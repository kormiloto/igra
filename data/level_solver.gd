class_name LevelSolver
extends RefCounted

const ACTIONS: Array[String] = ["left", "right", "forward", "back", "jump"]

static func solve(level: LevelDefinition) -> Dictionary:
	return solve_layout(
		level.cells,
		level.spawn_cube,
		level.spawn_normal,
		level.spawn_forward,
		level.keys,
		level.exit_key,
		level.special_tiles
	)

static func solve_layout(
	cells: Array[SurfaceCell],
	spawn_cube: Vector3i,
	spawn_normal: Vector3i,
	spawn_forward: Vector3i,
	keys: Array[String],
	exit_key: String,
	specials: Dictionary = {}
) -> Dictionary:
	var cell_map := _cell_map(cells)
	var key_bits := {}
	for index in range(keys.size()):
		key_bits[keys[index]] = 1 << index
	var all_keys_mask := (1 << keys.size()) - 1
	var start_key := SurfaceRules.cell_key(spawn_cube, spawn_normal)
	var start_mask: int = int(key_bits.get(start_key, 0))
	var start_state := {
		"cube": spawn_cube,
		"normal": spawn_normal,
		"forward": spawn_forward,
		"mask": start_mask
	}
	var start_id := _state_key(spawn_cube, spawn_normal, spawn_forward, start_mask)
	var queue: Array[Dictionary] = [start_state]
	var read_index := 0
	var visited := {start_id: true}
	var max_states := maxi(cells.size() * 48, 4096)
	var parents := {}
	var state_cells := {start_id: start_key}
	while read_index < queue.size():
		var state: Dictionary = queue[read_index]
		read_index += 1
		var state_id := _state_key(state.cube, state.normal, state.forward, state.mask)
		var cell_key := SurfaceRules.cell_key(state.cube, state.normal)
		if cell_key == exit_key and int(state.mask) == all_keys_mask:
			return _reconstruct_solution(state_id, parents, state_cells, visited.size())
		for action in ACTIONS:
			var next := _transition(cell_map, state, action, specials)
			if not next.found:
				continue
			var next_cell_key := SurfaceRules.cell_key(next.cube, next.normal)
			var next_mask: int = int(state.mask) | int(key_bits.get(next_cell_key, 0))
			var next_id := _state_key(next.cube, next.normal, next.forward, next_mask)
			if visited.has(next_id):
				continue
			visited[next_id] = true
			if visited.size() > max_states:
				return {
					"found": false,
					"actions": [] as Array[String],
					"route": [] as Array[String],
					"action_count": -1,
					"visited_states": visited.size()
				}
			parents[next_id] = {"previous": state_id, "action": action}
			state_cells[next_id] = next_cell_key
			queue.append({
				"cube": next.cube,
				"normal": next.normal,
				"forward": next.forward,
				"mask": next_mask
			})
	return {
		"found": false,
		"actions": [] as Array[String],
		"route": [] as Array[String],
		"action_count": -1,
		"visited_states": visited.size()
	}

static func _reconstruct_solution(goal_id: String, parents: Dictionary, state_cells: Dictionary, visited_count: int) -> Dictionary:
	var actions: Array[String] = []
	var state_chain: Array[String] = [goal_id]
	var cursor := goal_id
	while parents.has(cursor):
		var parent: Dictionary = parents[cursor]
		actions.append(parent.action)
		cursor = parent.previous
		state_chain.append(cursor)
	actions.reverse()
	state_chain.reverse()
	var route: Array[String] = []
	for state_id in state_chain:
		var cell_key: String = state_cells[state_id]
		if route.is_empty() or route[-1] != cell_key:
			route.append(cell_key)
	return {
		"found": true,
		"actions": actions,
		"route": route,
		"action_count": actions.size(),
		"visited_states": visited_count
	}

static func cell_degrees(cells: Array[SurfaceCell]) -> Dictionary:
	var cell_map := _cell_map(cells)
	var result := {}
	for cell in cells:
		var neighbors := {}
		for forward in _forwards_for(cell.normal):
			for direction_sign in [-1, 1]:
				var move := SurfaceRules.movement_result(cell_map, cell.cube, cell.normal, forward, direction_sign)
				if move.found:
					neighbors[SurfaceRules.cell_key(move.cube, move.normal)] = true
			var jump := SurfaceRules.jump_result(cell_map, cell.cube, cell.normal, forward)
			if jump.found:
				neighbors[SurfaceRules.cell_key(jump.cube, jump.normal)] = true
		neighbors.erase(cell.key())
		result[cell.key()] = neighbors.size()
	return result

static func _transition(cell_map: Dictionary, state: Dictionary, action: String, specials: Dictionary) -> Dictionary:
	var result: Dictionary
	match action:
		"left":
			return _turn_result(state, SurfaceRules.turn_left(state.normal, state.forward))
		"right":
			return _turn_result(state, SurfaceRules.turn_right(state.normal, state.forward))
		"forward":
			result = SurfaceRules.movement_result(cell_map, state.cube, state.normal, state.forward, 1)
		"back":
			result = SurfaceRules.movement_result(cell_map, state.cube, state.normal, state.forward, -1)
		"jump":
			result = SurfaceRules.jump_result(cell_map, state.cube, state.normal, state.forward)
		_:
			return {"found": false}
	if not result.found:
		return result
	return _resolve_special_landing(cell_map, result, specials)

static func _resolve_special_landing(cell_map: Dictionary, landing: Dictionary, specials: Dictionary) -> Dictionary:
	var key := SurfaceRules.cell_key(landing.cube, landing.normal)
	# The canonical route deliberately jumps every special tile. This is safe
	# for hazards/collapse and prevents ice from injecting an unplanned move.
	if str(specials.get(key, "")) in ["ice", "hazard", "collapse"]:
		return {"found": false}
	return landing

static func _turn_result(state: Dictionary, forward: Vector3i) -> Dictionary:
	return {
		"found": true,
		"cube": state.cube,
		"normal": state.normal,
		"forward": forward
	}

static func _cell_map(cells: Array[SurfaceCell]) -> Dictionary:
	var result := {}
	for cell in cells:
		result[cell.key()] = {"active": true}
	return result

static func _forwards_for(normal: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for direction in [SurfaceRules.UP, SurfaceRules.DOWN, SurfaceRules.NORTH, SurfaceRules.SOUTH, SurfaceRules.EAST, SurfaceRules.WEST]:
		if Vector3(normal).dot(Vector3(direction)) == 0.0:
			result.append(direction)
	return result

static func _state_key(cube: Vector3i, normal: Vector3i, forward: Vector3i, mask: int) -> String:
	return "%s@%s#%d" % [SurfaceRules.cell_key(cube, normal), str(forward), mask]
