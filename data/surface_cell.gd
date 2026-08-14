class_name SurfaceCell
extends RefCounted

var cube: Vector3i
var normal: Vector3i
var type: String

func _init(cell_cube: Vector3i, cell_normal: Vector3i, cell_type: String = "normal") -> void:
	cube = cell_cube
	normal = cell_normal
	type = cell_type

func key() -> String:
	return SurfaceRules.cell_key(cube, normal)

