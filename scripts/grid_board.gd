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
	1: {},
	2: {
		"ice": preload("res://assets/3d/environment/w2_tile_ice.glb")
	},
	3: {
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
const PORTAL_FLIPBOOK_FRAMES := [
	preload("res://assets/vfx/portal_flipbook/portal_0001.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0002.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0003.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0004.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0005.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0006.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0007.png"),
	preload("res://assets/vfx/portal_flipbook/portal_0008.png")
]

const PORTAL_VFX_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 portal_color : source_color = vec4(0.005, 1.0, 0.0, 1.0);
uniform float intensity = 0.16;
uniform float phase = 0.0;
varying vec3 fog_position;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	vec2 volume_coord = vec2(VERTEX.x * 4.0 + VERTEX.z * 2.1, VERTEX.y * 4.0 - VERTEX.z * 1.7);
	float deformation = fbm(volume_coord + vec2(TIME * 0.16 + phase, -TIME * 0.13)) - 0.5;
	deformation += sin(dot(VERTEX, vec3(17.0, 23.0, 11.0)) + TIME * 2.6 + phase) * 0.07;
	VERTEX += NORMAL * deformation * 0.26;
	fog_position = VERTEX;
}

void fragment() {
	vec2 flow_uv = vec2(fog_position.x * 3.7 + fog_position.z * 2.1, fog_position.y * 3.5 - fog_position.z * 1.6);
	flow_uv += vec2(TIME * 0.19 + phase, -TIME * 0.24);
	float broad_noise = fbm(flow_uv);
	float fine_noise = fbm(vec2(fog_position.x * 8.0 - fog_position.y * 3.0 - TIME * 0.43, fog_position.z * 7.0 + fog_position.y * 4.0 + TIME * 0.31 + phase));
	float rolling = sin(dot(fog_position, vec3(19.0, 13.0, 17.0)) + TIME * 4.2 + broad_noise * 8.0) * 0.5 + 0.5;
	float veins = smoothstep(0.42, 0.93, broad_noise + fine_noise * 0.58 + rolling * 0.18);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float flicker = 0.82 + 0.18 * sin(TIME * 8.0 + broad_noise * 12.0 + phase);
	float density = (0.20 + broad_noise * 0.38 + veins * 0.42 + rim * 0.12) * flicker * intensity;
	float color_energy = clamp(0.28 + veins * 0.58 + rim * 0.14, 0.0, 1.0);
	vec3 fog_color = mix(portal_color.rgb * 0.20, portal_color.rgb * 0.88, color_energy);
	ALBEDO = fog_color;
	EMISSION = fog_color * density * 0.48;
	ALPHA = clamp(density * 0.90, 0.015, 0.54) * portal_color.a;
}
"""

var cells: Dictionary = {}
var key_pickups: Dictionary = {}
var fruit_pickups: Dictionary = {}
var exit_key := ""
var exit_holder: Node3D
var cube_meshes: Dictionary = {}
var world := 1
var theme_colors := {
	1: [Color("58dfff"), Color("6a765f"), Color("b9f8ff")],
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
	var was_active := bool(exit_holder.get_meta("portal_active", false))
	exit_holder.set_meta("portal_active", active)
	_set_portal_vfx(active)
	var glow := exit_holder.get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		if active and not was_active:
			glow.light_energy = 0.10
			var flare := glow.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			flare.tween_property(glow, "light_energy", 2.4, 0.16)
			flare.tween_property(glow, "light_energy", 1.5, 0.58)
		else:
			glow.light_energy = 1.5 if active else 0.08
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
	var scene := world_tiles.get(cell.type) as PackedScene
	if scene == null:
		return
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
	exit_holder = Node3D.new()
	exit_holder.name = "Exit"
	exit_holder.position = Vector3(cell.cube) * TILE_SIZE + Vector3(cell.normal) * TILE_SIZE * 0.5
	exit_holder.basis = SurfaceRules.basis_from(cell.normal, _fallback_forward(cell.normal))
	var portal_model := (PORTAL_SCENES[world] as PackedScene).instantiate() as Node3D
	portal_model.name = "AuthoredPortalFrame"
	exit_holder.add_child(portal_model)
	_add_portal_vfx(exit_holder)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0, 0.88, 0)
	glow.light_color = [Color("67eaff"), Color("67eaff"), Color("ff7a4d")][world - 1]
	glow.light_energy = 0.08
	glow.omni_range = 5.0
	glow.shadow_enabled = false
	exit_holder.add_child(glow)
	add_child(exit_holder)
	var breathe := exit_holder.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(exit_holder, "rotation:y", 0.055, 1.8).from(-0.055)
	breathe.tween_property(exit_holder, "rotation:y", -0.055, 1.8)

func _add_portal_vfx(root: Node3D) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 11.0)
	frames.set_animation_loop("default", true)
	for texture in PORTAL_FLIPBOOK_FRAMES:
		frames.add_frame("default", texture)
	for index in range(PORTAL_FLIPBOOK_FRAMES.size() - 2, 0, -1):
		frames.add_frame("default", PORTAL_FLIPBOOK_FRAMES[index])
	var plasma := AnimatedSprite3D.new()
	plasma.name = "BlenderPortalVFX"
	plasma.sprite_frames = frames
	plasma.animation = "default"
	plasma.position = Vector3(0.0, 1.02, 0.0)
	plasma.pixel_size = 0.0084
	plasma.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plasma.shaded = false
	plasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plasma.modulate = Color(1.0, 1.0, 1.0, 0.34)
	plasma.play("default")
	root.add_child(plasma)

func _set_portal_vfx(active: bool) -> void:
	if not is_instance_valid(exit_holder):
		return
	var plasma := exit_holder.get_node_or_null("BlenderPortalVFX") as AnimatedSprite3D
	if plasma == null:
		return
	plasma.modulate = Color(1.0, 1.0, 1.0, 1.0 if active else 0.34)
	plasma.speed_scale = 1.0 if active else 0.36

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
