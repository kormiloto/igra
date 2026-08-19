extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "restart", "pause", "camera_left", "camera_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.size = Vector2i(1920, 1080)
	call_deferred("_measure")

func _measure() -> void:
	var gameplay := Gameplay.new()
	gameplay.setup(LevelCatalog.get_level("W1L05"))
	gameplay.audio_enabled = false
	root.add_child(gameplay)
	var samples: Array[float] = []
	for frame in range(180):
		await process_frame
		if frame >= 60:
			samples.append(float(Performance.get_monitor(Performance.TIME_FPS)))
	var average_fps := 0.0
	for sample in samples:
		average_fps += sample
	average_fps /= maxf(float(samples.size()), 1.0)
	print("World 1 Forward+ 1080p average FPS: %.1f" % average_fps)
	gameplay.queue_free()
	await process_frame
	quit(0 if average_fps >= 55.0 else 1)
