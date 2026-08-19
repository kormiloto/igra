extends SceneTree

const CAPTURES := [
	["W1L01", "res://output/qa/world1_level01_first_key.png"],
	["W1L05", "res://output/qa/world1_level05_temple_fold.png"],
	["W1L10", "res://output/qa/world1_level10_temple_mastery.png"]
]

func _initialize() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "restart", "pause", "camera_left", "camera_right"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	root.size = Vector2i(1920, 1080)
	call_deferred("_capture")

func _capture() -> void:
	for capture in CAPTURES:
		var gameplay := Gameplay.new()
		gameplay.setup(LevelCatalog.get_level(capture[0]))
		gameplay.audio_enabled = false
		root.add_child(gameplay)
		for frame in range(18):
			await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var error := image.save_png(capture[1])
		if error != OK:
			push_error("Could not save %s: %s" % [capture[1], error_string(error)])
			quit(1)
			return
		gameplay.queue_free()
		await process_frame
	print("Saved World 1 L01/L05/L10 gameplay QA captures")
	quit(0)
