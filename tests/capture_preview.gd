extends SceneTree

func _initialize() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "restart", "pause", "camera_left", "camera_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_capture")

func _capture() -> void:
	var gameplay := Gameplay.new()
	gameplay.setup(LevelCatalog.get_level("W1L03"))
	gameplay.audio_enabled = false
	root.add_child(gameplay)
	for frame in range(8):
		await process_frame
	# Walk the authored route onto the west wall, then around its lower edge
	# onto the underside. This also smoke-tests surface-relative movement and
	# the camera's changing up vector in a running scene.
	for action in ["forward", "forward", "forward", "left", "forward", "forward", "forward", "forward", "forward", "forward"]:
		gameplay.player.request_action(action)
		while gameplay.player.state != GridMover.MoveState.IDLE:
			if gameplay.player.state == GridMover.MoveState.DEAD:
				push_error("Preview route fell before reaching the underside")
				quit(1)
				return
			await process_frame
		for settle_frame in range(2):
			await process_frame
	if gameplay.player.surface_normal != SurfaceRules.DOWN:
		push_error("Preview route ended on %s instead of the underside" % gameplay.player.surface_normal)
		quit(1)
		return
	for settle_frame in range(90):
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("res://.godot/surface_preview.png")
	if error != OK:
		push_error("Could not save preview: %s" % error_string(error))
		quit(1)
		return
	print("Preview saved to res://.godot/surface_preview.png")
	gameplay.queue_free()
	await process_frame
	quit(0)
