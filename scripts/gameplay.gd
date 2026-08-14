class_name Gameplay
extends Node3D

const AUDIO_SCRIPT := preload("res://scripts/procedural_audio.gd")
const UI := preload("res://scripts/skyroll_ui.gd")
const CLOUD_SCENES: Array[PackedScene] = [
	preload("res://assets/3d/environment/cloud_bank_a.glb"),
	preload("res://assets/3d/environment/cloud_bank_b.glb"),
	preload("res://assets/3d/environment/cloud_bank_c.glb")
]
const LANDMARK_SCENES := {
	1: preload("res://assets/3d/environment/landmark_w1.glb"),
	2: preload("res://assets/3d/environment/landmark_w2.glb"),
	3: preload("res://assets/3d/environment/landmark_w3.glb")
}

signal completed(summary: Dictionary)
signal quit_requested
signal restart_requested(level_id: String)

var level: LevelDefinition
var board: GridBoard
var player: GridMover
var camera: FollowCamera
var time_remaining := 0.0
var elapsed := 0.0
var keys_collected := 0
var fruit_collected := 0
var running := false
var restarting := false
var hud_time: Label
var hud_cores: Label
var hud_optional: Label
var message: Label
var pause_panel: PanelContainer
var camera_shake_enabled := true
var audio: Node
var audio_enabled := true

func setup(level_definition: LevelDefinition) -> void:
	level = level_definition

func _ready() -> void:
	if level == null:
		level = LevelCatalog.get_level("W1L01")
	_build_environment()
	if audio_enabled:
		audio = AUDIO_SCRIPT.new()
		add_child(audio)
		audio.start_music(level.world)
	board = GridBoard.new()
	add_child(board)
	board.build(level)
	board.key_collected.connect(_on_key_collected)
	board.fruit_collected.connect(_on_fruit_collected)
	board.exit_reached.connect(_on_exit_reached)
	player = GridMover.new()
	add_child(player)
	player.setup(level, board)
	player.landed.connect(_on_landed)
	player.fell.connect(_on_player_failed.bind("FELL INTO THE SKY"))
	camera = FollowCamera.new()
	add_child(camera)
	camera.setup(player)
	camera.camera_shake_enabled = camera_shake_enabled
	camera.global_position = player.global_position - player.current_forward() * 6.6 + player.current_up() * 4.2
	_build_hud()
	time_remaining = level.time_limit
	running = true
	board.set_exit_active(false)
	_update_hud()

func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	elapsed += delta
	_update_hud()
	if time_remaining <= 0.0:
		_on_player_failed("TIME UP")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("restart") and running:
		_restart_level()

func _on_landed(cube: Vector3i, normal: Vector3i) -> void:
	if not running:
		return
	var interaction := board.interact(cube, normal, keys_collected >= level.keys.size())
	if interaction.hazard:
		_on_player_failed("WATCH THE HAZARDS")
	elif interaction.collapse:
		var old_cube := cube
		var old_normal := normal
		get_tree().create_timer(0.3).timeout.connect(board.collapse_cell.bind(old_cube, old_normal))
	elif interaction.ice:
		player.force_forward()

func _on_key_collected(_cell_key: String) -> void:
	keys_collected += 1
	if audio != null: audio.play_core()
	time_remaining += 4.0
	if keys_collected >= level.keys.size():
		board.set_exit_active(true)
		_show_message("EXIT OPEN", Color("7dff7d"), 1.2)
	_update_hud()

func _on_fruit_collected(_cell_key: String) -> void:
	fruit_collected += 1
	if audio != null: audio.play_star()
	time_remaining += 2.0
	_update_hud()

func _on_exit_reached() -> void:
	if not running:
		return
	running = false
	player.input_enabled = false
	if audio != null: audio.play_portal()
	var medals := 1
	if fruit_collected >= level.fruits.size():
		medals += 1
	if elapsed <= level.par_time:
		medals += 1
	completed.emit({
		"level_id": level.id,
		"elapsed": elapsed,
		"remaining": time_remaining,
		"medals": medals,
		"optional": fruit_collected,
		"optional_total": level.fruits.size()
	})

func _on_player_failed(reason: String) -> void:
	if not running or restarting:
		return
	running = false
	restarting = true
	player.die()
	if audio != null: audio.play_fail()
	camera.shake(0.28)
	_show_message(reason, Color("ff7185"), 0.85)
	get_tree().create_timer(0.9).timeout.connect(_restart_level)

func _restart_level() -> void:
	get_tree().paused = false
	restart_requested.emit(level.id)

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_palettes := [
		[Color("092448"), Color("4aabc2"), Color("c4efdc")],
		[Color("071b45"), Color("337eb8"), Color("c3f5ff")],
		[Color("210c35"), Color("a93e59"), Color("ffb25b")]
	]
	var palette: Array = sky_palettes[level.world - 1]
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette[0]
	sky_material.sky_horizon_color = palette[1]
	sky_material.sky_curve = 0.18
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.07
	sky_material.ground_bottom_color = palette[0].darkened(0.62)
	sky_material.ground_horizon_color = palette[2].darkened(0.18)
	sky_material.ground_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = palette[2]
	environment.ambient_light_energy = [0.34, 0.38, 0.32][level.world - 1]
	environment.fog_enabled = true
	environment.fog_light_color = palette[1].lightened(0.10)
	environment.fog_light_energy = 0.46
	environment.fog_density = [0.0034, 0.0042, 0.0038][level.world - 1]
	environment.fog_sky_affect = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = [0.86, 1.0, 0.96][level.world - 1]
	environment.adjustment_contrast = [1.10, 1.13, 1.16][level.world - 1]
	environment.adjustment_saturation = [0.96, 0.94, 0.92][level.world - 1]
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = [Color("ffe0a8"), Color("d8efff"), Color("ffd0a0")][level.world - 1]
	sun.light_energy = [0.86, 1.02, 1.18][level.world - 1]
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(35, 145, 0)
	fill.light_color = [Color("72d8c2"), Color("88a8ff"), Color("ae67ff")][level.world - 1]
	fill.light_energy = 0.24
	add_child(fill)
	_build_atmosphere_decor(palette)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	layer.add_child(margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	margin.add_child(top)
	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", UI.panel_style(Color("071426d9"), Color(UI.world_accent(level.world), 0.62), 14, 8))
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_panel)
	var title := Label.new()
	title.text = "%s   //   %s" % [level.id, level.title.to_upper()]
	UI.apply_title(title, 21, Color("f7fbff"))
	title_panel.add_child(title)
	hud_cores = Label.new()
	hud_optional = Label.new()
	hud_time = Label.new()
	top.add_child(_metric_panel(hud_cores, UI.CYAN))
	top.add_child(_metric_panel(hud_optional, UI.GOLD))
	top.add_child(_metric_panel(hud_time, UI.CORAL))
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.position = Vector2(-260, -48)
	message.size = Vector2(520, 96)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.apply_title(message, 38, Color.WHITE)
	message.add_theme_stylebox_override("normal", UI.panel_style(Color("071426e8"), Color("ffffff44"), 18, 12))
	message.visible = false
	layer.add_child(message)
	var controls := Label.new()
	controls.text = "WASD  MOVE     SPACE  JUMP     R  RETRY     ESC  PAUSE"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(24, -48)
	controls.size = Vector2(620, 30)
	UI.apply_body(controls, 14, Color("d5e6f3b0"))
	layer.add_child(controls)
	pause_panel = _make_pause_panel()
	layer.add_child(pause_panel)

func _metric_panel(label: Label, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style(Color("071426d9"), Color(accent, 0.52), 14, 8))
	label.custom_minimum_size.x = 128
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_title(label, 19, Color.WHITE)
	panel.add_child(label)
	return panel

func _make_pause_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -140)
	panel.size = Vector2(380, 280)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", UI.panel_style(Color("071426f5"), Color("75e6ffaa"), 22, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_title(title, 32, UI.GOLD)
	box.add_child(title)
	var resume := Button.new()
	resume.text = "Resume"
	UI.apply_button(resume, UI.CYAN, 48)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var restart_button := Button.new()
	restart_button.text = "Restart Level"
	UI.apply_button(restart_button, UI.GOLD, 48)
	restart_button.pressed.connect(_restart_level)
	box.add_child(restart_button)
	var quit := Button.new()
	quit.text = "Return to Level Select"
	UI.apply_button(quit, UI.CORAL, 48)
	quit.pressed.connect(func(): get_tree().paused = false; quit_requested.emit())
	box.add_child(quit)
	return panel

func _show_message(text: String, color: Color, duration: float) -> void:
	message.text = text
	message.add_theme_color_override("font_color", color)
	message.modulate = Color(1, 1, 1, 0)
	message.scale = Vector2(0.84, 0.84)
	message.pivot_offset = message.size * 0.5
	message.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(message, "modulate:a", 1.0, 0.18)
	tween.tween_property(message, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(duration)
	tween.tween_property(message, "modulate:a", 0.0, 0.18)
	tween.tween_callback(_hide_message)

func _hide_message() -> void:
	if is_instance_valid(message):
		message.visible = false

func _update_hud() -> void:
	if hud_time == null:
		return
	hud_cores.text = "◆  %d/%d" % [keys_collected, level.keys.size()]
	hud_optional.text = "✦  %d/%d" % [fruit_collected, level.fruits.size()]
	hud_time.text = "◷  %02d:%02d" % [int(time_remaining) / 60, int(time_remaining) % 60]
	hud_time.modulate = Color("ff7185") if time_remaining < 10.0 else Color.WHITE

func _build_atmosphere_decor(palette: Array) -> void:
	for index in range(7):
		var angle := float(index) / 7.0 * TAU + 0.48
		var radius := 28.0 + float((index * 7) % 9)
		var cloud := CLOUD_SCENES[index % CLOUD_SCENES.size()].instantiate() as Node3D
		cloud.name = "Cloud_%02d" % index
		cloud.position = Vector3(cos(angle) * radius, -7.0 + float((index * 5) % 12), sin(angle) * radius)
		cloud.rotation_degrees.y = rad_to_deg(-angle) + float(index * 17)
		var cloud_scale := 1.55 + float(index % 3) * 0.34
		cloud.scale = Vector3(cloud_scale, cloud_scale * 0.54, cloud_scale)
		add_child(cloud)
		var base_position := cloud.position
		var drift := cloud.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(cloud, "position", base_position + Vector3(cos(angle + PI * 0.5), 0.28, sin(angle + PI * 0.5)) * 2.4, 12.0 + float(index % 4))
		drift.tween_property(cloud, "position", base_position, 12.0 + float(index % 4))
	for index in range(3):
		var angle := float(index) / 3.0 * TAU + 0.72
		var landmark := (LANDMARK_SCENES[level.world] as PackedScene).instantiate() as Node3D
		landmark.name = "WorldLandmark_%02d" % index
		landmark.position = Vector3(cos(angle) * 26.0, -2.2 + float((index * 5) % 8), sin(angle) * 26.0)
		landmark.rotation_degrees.y = float(index * 83) - rad_to_deg(angle)
		landmark.scale = Vector3.ONE * (1.22 + float(index % 2) * 0.22)
		add_child(landmark)
	_add_sky_motes(palette)

func _add_sky_motes(palette: Array) -> void:
	var motes := CPUParticles3D.new()
	motes.name = "SkyMotes"
	motes.amount = 42
	motes.lifetime = 10.0
	motes.randomness = 0.85
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(18, 10, 18)
	motes.direction = Vector3(0.15, 1.0, 0.08)
	motes.spread = 32.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.10
	motes.initial_velocity_max = 0.35
	motes.scale_amount_min = 0.025
	motes.scale_amount_max = 0.075
	motes.color = palette[2].lightened(0.18)
	var mote_mesh := PrismMesh.new()
	mote_mesh.size = Vector3(0.055, 0.14, 0.055)
	motes.mesh = mote_mesh
	add_child(motes)
