class_name GridBoard
extends Node3D

signal key_collected(cell_key: String)
signal fruit_collected(cell_key: String)
signal exit_reached

const TILE_SIZE := 2.0
const BALL_RADIUS := 0.72

const BLOCK_SCENES := {
	1: [
		preload("res://assets/3d/environment/w1_block_a.glb"),
		preload("res://assets/3d/environment/w1_block_b.glb"),
		preload("res://assets/3d/environment/w1_block_c.glb")
	],
	2: [
		preload("res://assets/3d/environment/w2_block_a.glb"),
		preload("res://assets/3d/environment/w2_block_b.glb"),
		preload("res://assets/3d/environment/w2_block_c.glb")
	],
	3: [
		preload("res://assets/3d/environment/w3_block_a.glb"),
		preload("res://assets/3d/environment/w3_block_b.glb"),
		preload("res://assets/3d/environment/w3_block_c.glb")
	]
}

const TILE_SCENES := {
	1: {"normal": preload("res://assets/3d/environment/w1_tile_normal.glb")},
	2: {
		"normal": preload("res://assets/3d/environment/w2_tile_normal.glb"),
		"ice": preload("res://assets/3d/environment/w2_tile_ice.glb")
	},
	3: {
		"normal": preload("res://assets/3d/environment/w3_tile_normal.glb"),
		"hazard": preload("res://assets/3d/environment/w3_tile_hazard.glb"),
		"collapse": preload("res://assets/3d/environment/w3_tile_collapse.glb"),
		"ice": preload("res://assets/3d/environment/w2_tile_ice.glb")
	}
}

const SKY_CORE_SCENE := preload("res://assets/3d/environment/sky_core.glb")
const SUNFRUIT_SCENE := preload("res://assets/3d/environment/sunfruit.glb")
const PORTAL_SCENES := {
	1: preload("res://assets/3d/environment/portal_w1.glb"),
	2: preload("res://assets/3d/environment/portal_w2.glb"),
	3: preload("res://assets/3d/environment/portal_w3.glb")
}

var cells: Dictionary = {}
var key_pickups: Dictionary = {}
var fruit_pickups: Dictionary = {}
var exit_key := ""
var exit_holder: Node3D
var cube_meshes: Dictionary = {}
var world := 1
var theme_colors := {
	1: [Color("d8a45f"), Color("40352d"), Color("7df1ae")],
	2: [Color("55c8e2"), Color("30386f"), Color("d8f8ff")],
	3: [Color("e5674f"), Color("4c203b"), Color("ffd46a")]
}

func build(level: LevelDefinition) -> void:
	name = "SurfaceBoard"
	world = level.world
	exit_key = level.exit_key
	for cell in level.cells:
		var key := cell.key()
		cells[key] = {"cell": cell, "type": cell.type, "active": true}
		_create_cube(cell.cube)
		_create_face_plate(cell)
	for key in level.keys:
		_create_pickup(key, true)
	for key in level.fruits:
		_create_pickup(key, false)
	_create_exit(level.exit_key)

func has_surface(cube: Vector3i, normal: Vector3i) -> bool:
	var key := SurfaceRules.cell_key(cube, normal)
	return cells.has(key) and bool(cells[key].active)

func resolve_move(cube: Vector3i, normal: Vector3i, forward: Vector3i, direction_sign: int) -> Dictionary:
	return SurfaceRules.movement_result(cells, cube, normal, forward, direction_sign)

func resolve_jump(cube: Vector3i, normal: Vector3i, forward: Vector3i) -> Dictionary:
	return SurfaceRules.jump_result(cells, cube, normal, forward)

func surface_world_position(cube: Vector3i, normal: Vector3i) -> Vector3:
	return Vector3(cube) * TILE_SIZE + Vector3(normal) * (TILE_SIZE * 0.5 + BALL_RADIUS)

func cell_from_key(key: String) -> SurfaceCell:
	if not cells.has(key):
		return null
	return cells[key].cell

func interact(cube: Vector3i, normal: Vector3i, all_keys_collected: bool) -> Dictionary:
	var key := SurfaceRules.cell_key(cube, normal)
	var result := {"hazard": false, "ice": false, "collapse": false}
	if key_pickups.has(key):
		_spawn_collect_burst(key_pickups[key].global_position, theme_colors[world][2])
		key_pickups[key].queue_free()
		key_pickups.erase(key)
		key_collected.emit(key)
	if fruit_pickups.has(key):
		_spawn_collect_burst(fruit_pickups[key].global_position, Color("ff5f91"))
		fruit_pickups[key].queue_free()
		fruit_pickups.erase(key)
		fruit_collected.emit(key)
	if key == exit_key and all_keys_collected:
		exit_reached.emit()
	if cells.has(key):
		var tile_type: String = cells[key].type
		result.hazard = tile_type == "hazard"
		result.ice = tile_type == "ice"
		result.collapse = tile_type == "collapse"
	return result

func collapse_cell(cube: Vector3i, normal: Vector3i) -> void:
	var key := SurfaceRules.cell_key(cube, normal)
	if not cells.has(key):
		return
	cells[key].active = false
	var plate: Node3D = cells[key].get("plate")
	if is_instance_valid(plate):
		var tween := create_tween().set_parallel(true)
		tween.tween_property(plate, "scale", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(plate, "rotation", plate.rotation + Vector3(0.25, 0.45, 0.12), 0.28)
		tween.chain().tween_callback(plate.queue_free)

func set_exit_active(active: bool) -> void:
	if not is_instance_valid(exit_holder):
		return
	_set_portal_materials(exit_holder, active)
	var glow := exit_holder.get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_energy = 2.1 if active else 0.08
	var tween := exit_holder.create_tween()
	tween.tween_property(exit_holder, "scale", Vector3.ONE * (1.08 if active else 1.0), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_cube(cube_position: Vector3i) -> void:
	var cube_key := "%d,%d,%d" % [cube_position.x, cube_position.y, cube_position.z]
	if cube_meshes.has(cube_key):
		return
	var scenes: Array = BLOCK_SCENES[world]
	var variant_index := posmod(cube_position.x * 17 + cube_position.y * 31 + cube_position.z * 47, scenes.size())
	var block := (scenes[variant_index] as PackedScene).instantiate() as Node3D
	block.name = "Block_%s" % cube_key.replace(",", "_")
	block.position = Vector3(cube_position) * TILE_SIZE
	block.rotation_degrees.y = float(posmod(cube_position.x * 7 + cube_position.y * 11 + cube_position.z * 13, 4)) * 90.0
	add_child(block)
	cube_meshes[cube_key] = block

func _create_face_plate(cell: SurfaceCell) -> void:
	var world_tiles: Dictionary = TILE_SCENES[world]
	var scene := world_tiles.get(cell.type, world_tiles["normal"]) as PackedScene
	var plate := scene.instantiate() as Node3D
	plate.name = "Face_%s" % cell.key().replace(",", "_").replace("|", "_")
	plate.position = Vector3(cell.cube) * TILE_SIZE + Vector3(cell.normal) * (TILE_SIZE * 0.5)
	plate.basis = SurfaceRules.basis_from(cell.normal, _fallback_forward(cell.normal))
	add_child(plate)
	cells[cell.key()].plate = plate

func _create_pickup(key: String, required: bool) -> void:
	var cell := cell_from_key(key)
	if cell == null:
		return
	var holder := Node3D.new()
	holder.name = ("Core_" if required else "Sunfruit_") + key.replace(",", "_").replace("|", "_")
	holder.position = surface_world_position(cell.cube, cell.normal) + Vector3(cell.normal) * 0.68
	holder.basis = SurfaceRules.basis_from(cell.normal, _fallback_forward(cell.normal))
	var model_scene: PackedScene = SKY_CORE_SCENE if required else SUNFRUIT_SCENE
	var model := model_scene.instantiate() as Node3D
	model.name = "Model"
	holder.add_child(model)
	var glow := OmniLight3D.new()
	glow.light_color = theme_colors[world][2] if required else Color("ff5f91")
	glow.light_energy = 0.72 if required else 0.48
	glow.omni_range = 3.4
	glow.shadow_enabled = false
	holder.add_child(glow)
	add_child(holder)
	if required:
		key_pickups[key] = holder
	else:
		fruit_pickups[key] = holder
	var spin := holder.create_tween().set_loops()
	spin.tween_property(model, "rotation:y", TAU, 2.4 if required else 3.1).from(0.0)
	var base_position := holder.position
	var bob := holder.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(holder, "position", base_position + Vector3(cell.normal) * 0.18, 0.88)
	bob.tween_property(holder, "position", base_position, 0.88)

func _create_exit(key: String) -> void:
	var cell := cell_from_key(key)
	if cell == null:
		return
	exit_holder = (PORTAL_SCENES[world] as PackedScene).instantiate() as Node3D
	exit_holder.name = "Exit"
	exit_holder.position = Vector3(cell.cube) * TILE_SIZE + Vector3(cell.normal) * TILE_SIZE * 0.5
	exit_holder.basis = SurfaceRules.basis_from(cell.normal, _fallback_forward(cell.normal))
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0, 0.95, 0)
	glow.light_color = theme_colors[world][2]
	glow.light_energy = 0.08
	glow.omni_range = 5.0
	glow.shadow_enabled = false
	exit_holder.add_child(glow)
	add_child(exit_holder)
	var breathe := exit_holder.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(exit_holder, "rotation:y", 0.055, 1.8).from(-0.055)
	breathe.tween_property(exit_holder, "rotation:y", -0.055, 1.8)

func _set_portal_materials(root: Node, active: bool) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var visual_name := mesh_instance.name.to_lower()
		var is_energy_surface := visual_name.contains("glass") or visual_name.contains("energy") or visual_name.contains("vortex") or visual_name.contains("core")
		if is_energy_surface and mesh_instance.mesh != null:
			for surface in range(mesh_instance.mesh.get_surface_count()):
				if active:
					mesh_instance.set_surface_override_material(surface, null)
					continue
				var source := mesh_instance.get_active_material(surface)
				if not source is BaseMaterial3D:
					continue
				var material := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
				material.albedo_color = material.albedo_color.darkened(0.72)
				material.emission_enabled = false
				material.emission_energy_multiplier = 0.0
				mesh_instance.set_surface_override_material(surface, material)
	for child in root.get_children():
		_set_portal_materials(child, active)

func _spawn_collect_burst(world_position: Vector3, color: Color) -> void:
	var burst := Node3D.new()
	burst.position = to_local(world_position)
	add_child(burst)
	for index in range(12):
		var spark := MeshInstance3D.new()
		var crystal := PrismMesh.new()
		crystal.size = Vector3(0.09, 0.20, 0.09)
		spark.mesh = crystal
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color * 1.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = material
		burst.add_child(spark)
		var angle := float(index) / 12.0 * TAU
		var direction := Vector3(cos(angle), sin(angle), sin(angle * 2.0) * 0.55).normalized()
		var tween := spark.create_tween().set_parallel(true)
		tween.tween_property(spark, "position", direction * 1.25, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.42).set_delay(0.12)
	get_tree().create_timer(0.55).timeout.connect(burst.queue_free)

func _fallback_forward(normal: Vector3i) -> Vector3i:
	return SurfaceRules.NORTH if Vector3(normal).dot(Vector3(SurfaceRules.NORTH)) == 0.0 else SurfaceRules.UP
