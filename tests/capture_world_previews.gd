extends SceneTree

const CAPTURES := [
	["W1L05", "res://.godot/world_1_preview.png"],
	["W2L06", "res://.godot/world_2_preview.png"],
	["W3L07", "res://.godot/world_3_preview.png"]
]

func _initialize() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "restart", "pause", "camera_left", "camera_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("_capture_all")

func _capture_all() -> void:
	for capture in CAPTURES:
		var gameplay := Gameplay.new()
		gameplay.setup(LevelCatalog.get_level(capture[0]))
		gameplay.audio_enabled = false
		root.add_child(gameplay)
		for frame in range(42):
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var error := image.save_png(capture[1])
		if error != OK:
			push_error("Could not save %s: %s" % [capture[1], error_string(error)])
			quit(1)
			return
		gameplay.queue_free()
		await process_frame
	print("Saved three world visual QA captures")
	quit(0)
