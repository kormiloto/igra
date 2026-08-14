extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var app: Node = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
	root.add_child(app)
	for frame in range(24):
		await process_frame
	var menu_image := root.get_viewport().get_texture().get_image()
	if menu_image.save_png("res://.godot/release_menu.png") != OK:
		quit(1)
		return
	app.call("_show_credits")
	for frame in range(24):
		await process_frame
	var credits_image := root.get_viewport().get_texture().get_image()
	if credits_image.save_png("res://.godot/release_credits.png") != OK:
		quit(1)
		return
	print("Saved release menu and credits QA captures")
	quit(0)
