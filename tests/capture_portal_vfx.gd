extends SceneTree

const PREVIEW_PATH := "res://output/portal_vfx_preview.png"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)

	var board := GridBoard.new()
	board.world = 1
	stage.add_child(board)
	var portal := Node3D.new()
	stage.add_child(portal)
	board.exit_holder = portal
	board._add_portal_vfx(portal)
	board._set_portal_vfx(true)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# Match the bright cyan gameplay sky so additive color washout is caught.
	environment.background_color = Color("34869a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8292b0")
	environment.ambient_light_energy = 0.46
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := OmniLight3D.new()
	key.position = Vector3(-1.8, -2.2, 2.8)
	key.light_color = Color("d8c7ff")
	key.light_energy = 5.0
	key.omni_range = 7.0
	stage.add_child(key)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.90, 4.4)
	camera.fov = 36.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.90, 0.0), Vector3.UP)
	camera.make_current()

	for _frame in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(PREVIEW_PATH)
	print("Saved portal VFX preview: %s" % PREVIEW_PATH)
	quit()
