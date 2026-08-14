class_name LevelDefinition
extends RefCounted

var id: String
var world: int
var number: int
var title: String
var time_limit: float
var par_time: float
var cells: Array[SurfaceCell]
var route: Array[String]
var keys: Array[String]
var fruits: Array[String]
var special_tiles: Dictionary
var spawn_cube: Vector3i
var spawn_normal: Vector3i
var spawn_forward: Vector3i
var exit_key: String

func _init(
	level_id: String,
	level_world: int,
	level_number: int,
	level_title: String,
	limit: float,
	par: float,
	level_cells: Array[SurfaceCell],
	level_route: Array[String],
	level_keys: Array[String],
	level_fruits: Array[String],
	start_cube: Vector3i,
	start_normal: Vector3i,
	start_forward: Vector3i,
	level_exit_key: String,
	specials: Dictionary = {}
) -> void:
	id = level_id
	world = level_world
	number = level_number
	title = level_title
	time_limit = limit
	par_time = par
	cells = level_cells
	route = level_route
	keys = level_keys
	fruits = level_fruits
	spawn_cube = start_cube
	spawn_normal = start_normal
	spawn_forward = start_forward
	exit_key = level_exit_key
	special_tiles = specials

func prerequisite_id() -> String:
	if world == 1 and number == 1:
		return ""
	if number > 1:
		return "W%dL%02d" % [world, number - 1]
	return "W%dL10" % (world - 1)

func cell_by_key(key: String) -> SurfaceCell:
	for cell in cells:
		if cell.key() == key:
			return cell
	return null

