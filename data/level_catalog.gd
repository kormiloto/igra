class_name LevelCatalog
extends RefCounted

const WORLD_NAMES := ["", "Sunken Temple", "Cloud Machinery", "Ember Orbit"]
const WORLD_SUBTITLES := [
	"",
	"Learn to read the faces of the ruins",
	"Cross walls, undersides and moving skyworks",
	"Master every orientation before the final exit"
]

static func all_levels() -> Array[LevelDefinition]:
	var result: Array[LevelDefinition] = []
	for world in range(1, 4):
		for number in range(1, 11):
			result.append(_make_level(world, number))
	return result

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
	var builder := _new_builder()
	# Every level starts with a readable top-face runway.
	_step(builder, 2 + (number % 2))
	_turn(builder, 1 if number % 2 == 0 else -1)
	_step(builder, 2 + mini(number / 4, 2))

	# Level 2 introduces one wall; level 3 completes the first underside route.
	if number >= 2:
		_wrap(builder)
		_step(builder, 2 + (number % 3))
	if number >= 3:
		_wrap(builder)
		_step(builder, 2)

	# Later routes weave across multiple local gravity frames.
	if number >= 4:
		_turn(builder, 1)
		_step(builder, 2 + world)
	if number >= 5:
		_wrap(builder)
		_step(builder, 2)
		_turn(builder, -1)
		_step(builder, 2)
	if number >= 7:
		_wrap(builder)
		_step(builder, 2 + (number % 2))
	if number >= 8:
		_turn(builder, -1 if world % 2 == 0 else 1)
		_step(builder, 3)
	if number >= 9:
		_wrap(builder)
		_step(builder, 3)
	if number == 10:
		_turn(builder, 1)
		_step(builder, 3 + world)

	var route: Array[String] = builder.route
	var key_positions: Array[String] = []
	var fruit_positions: Array[String] = []
	for fraction in [0.28, 0.56, 0.78]:
		var index := clampi(int(route.size() * fraction), 1, route.size() - 2)
		if route[index] not in key_positions:
			key_positions.append(route[index])
	for index in range(2, route.size() - 1, 4):
		if route[index] not in key_positions:
			fruit_positions.append(route[index])

	var specials := {}
	if world >= 2 and route.size() > 10:
		var ice_index := _straight_route_index(builder, 6)
		if ice_index > 0:
			specials[route[ice_index]] = "ice"
			key_positions.erase(route[ice_index])
			fruit_positions.erase(route[ice_index])
	if world == 3:
		# Ember hazards sit on a straight run and are deliberately jumpable.
		# Landing on them resets the level; a two-cell jump clears them.
		var hazard_index := _straight_route_index(builder, 3)
		if hazard_index > 0:
			specials[route[hazard_index]] = "hazard"
			key_positions.erase(route[hazard_index])
			fruit_positions.erase(route[hazard_index])
	if world == 3 and route.size() > 14:
		var collapse_index := _straight_route_index(builder, 10)
		if collapse_index > 0:
			specials[route[collapse_index]] = "collapse"
			key_positions.erase(route[collapse_index])
			fruit_positions.erase(route[collapse_index])

	for cell in builder.cells:
		if specials.has(cell.key()):
			cell.type = specials[cell.key()]

	var level_id := "W%dL%02d" % [world, number]
	var limit := 35.0 + route.size() * 2.2 + world * 5.0
	return LevelDefinition.new(
		level_id, world, number, _level_title(world, number), limit, limit * 0.68,
		builder.cells, route, key_positions, fruit_positions,
		Vector3i.ZERO, SurfaceRules.UP, SurfaceRules.NORTH, route[route.size() - 1], specials
	)

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

static func _straight_route_index(builder: Dictionary, preferred: int) -> int:
	var orientations: Array[Dictionary] = builder.orientations
	for index in range(clampi(preferred, 1, orientations.size() - 2), orientations.size() - 1):
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
