extends Node

const UI := preload("res://scripts/skyroll_ui.gd")
const MENU_SKY := preload("res://assets/ui/menu_sky.png")

const ACTION_LABELS := {
	"move_forward": "Roll Forward",
	"move_back": "Roll Back",
	"move_left": "Turn Left",
	"move_right": "Turn Right",
	"jump": "Jump",
	"restart": "Restart"
}

var screen: Control
var gameplay: Gameplay
var selected_world := 1
var rebinding_action := ""
var rebind_button: Button

func _ready() -> void:
	_ensure_input_map()
	_apply_saved_bindings()
	_show_main_menu()

func _input(event: InputEvent) -> void:
	if rebinding_action.is_empty() or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		rebinding_action = ""
		rebind_button.text = _binding_text(rebind_button.get_meta("action"))
		get_viewport().set_input_as_handled()
		return
	InputMap.action_erase_events(rebinding_action)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = event.physical_keycode
	InputMap.action_add_event(rebinding_action, replacement)
	SaveManager.data.settings.bindings[rebinding_action] = int(event.physical_keycode)
	SaveManager.save()
	rebind_button.text = _binding_text(rebinding_action)
	rebinding_action = ""
	get_viewport().set_input_as_handled()

func _show_main_menu() -> void:
	_clear_current()
	var root := _new_screen(Color("0a2442"), MENU_SKY)
	var column := _center_column(root, 470)
	var eyebrow := _subtitle("A SKYBOUND PUZZLE ADVENTURE")
	eyebrow.add_theme_color_override("font_color", UI.CYAN)
	column.add_child(eyebrow)
	column.add_child(_title("PROJECT SKYROLL", 58, UI.GOLD))
	column.add_child(_subtitle("Roll beyond gravity. Restore the shattered sky."))
	column.add_spacer(false)
	column.add_child(_menu_button("Play", _show_story_or_worlds))
	column.add_child(_menu_button("Level Select", _show_world_select))
	column.add_child(_menu_button("Options", _show_options))
	column.add_child(_menu_button("Credits & Licenses", _show_credits))
	column.add_child(_menu_button("Quit", get_tree().quit))
	var footer := Label.new()
	footer.text = "WASD / D-pad  ·  Space / A to jump  ·  Esc to pause"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_body(footer, 15, Color("b8cde1"))
	column.add_child(footer)

func _show_story_or_worlds() -> void:
	if "intro" in SaveManager.data.story_seen:
		_show_world_select()
		return
	_show_story(
		"THE SHATTERED SKY",
		"The three Sky Anchors have fallen silent.\nFloating islands drift apart into an endless storm.\n\nAeri, the smallest light in the sky, begins to roll.",
		func(): SaveManager.data.story_seen.append("intro"); SaveManager.save(); _show_world_select()
	)

func _show_story(title_text: String, body: String, next: Callable) -> void:
	_clear_current()
	var root := _new_screen(Color("182d4a"))
	var column := _center_column(root, 680)
	column.add_child(_title(title_text, 42, Color("88e9ff")))
	var story := Label.new()
	story.text = body
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.apply_body(story, 24, Color("e6f4ff"))
	story.custom_minimum_size.y = 220
	column.add_child(story)
	column.add_child(_menu_button("Continue", next))

func _show_world_select() -> void:
	_clear_current()
	var root := _new_screen(Color("10243d"))
	var column := _center_column(root, 760)
	column.add_child(_title("CHOOSE A WORLD", 42, Color.WHITE))
	column.add_child(_subtitle("Restore all three Sky Anchors"))
	for world in range(1, 4):
		var first_id := "W%dL01" % world
		var unlocked := SaveManager.is_level_unlocked(first_id)
		var completed := _completed_in_world(world)
		var text := "%d. %s   ·   %d/10" % [world, LevelCatalog.WORLD_NAMES[world], completed]
		var button := _menu_button(text, _show_level_select.bind(world))
		UI.apply_button(button, UI.world_accent(world), 64)
		button.disabled = not unlocked
		column.add_child(button)
	column.add_child(_menu_button("Back", _show_main_menu))

func _show_level_select(world: int) -> void:
	selected_world = world
	_clear_current()
	var root := _new_screen(_world_background(world))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_bottom", 46)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	column.add_child(_title(LevelCatalog.WORLD_NAMES[world].to_upper(), 40, Color.WHITE))
	column.add_child(_subtitle(LevelCatalog.WORLD_SUBTITLES[world]))
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 8)
	column.add_child(divider)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for number in range(1, 11):
		var id := "W%dL%02d" % [world, number]
		var definition := LevelCatalog.get_level(id)
		var result := SaveManager.result_for(id)
		var medals := int(result.get("medals", 0))
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 105)
		button.text = "%02d\n%s\n%s" % [number, definition.title, "★".repeat(medals)]
		button.disabled = not SaveManager.is_level_unlocked(id)
		UI.apply_button(button, UI.world_accent(world), 105)
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_start_level.bind(id))
		grid.add_child(button)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	bottom.add_child(_menu_button("Worlds", _show_world_select, 190))
	bottom.add_child(_menu_button("Main Menu", _show_main_menu, 190))
	column.add_child(bottom)

func _start_level(level_id: String) -> void:
	_clear_current()
	gameplay = Gameplay.new()
	gameplay.setup(LevelCatalog.get_level(level_id))
	gameplay.camera_shake_enabled = bool(SaveManager.data.settings.camera_shake)
	gameplay.completed.connect(_on_level_completed)
	gameplay.quit_requested.connect(_show_level_select.bind(LevelCatalog.get_level(level_id).world))
	gameplay.restart_requested.connect(_start_level)
	add_child(gameplay)

func _on_level_completed(summary: Dictionary) -> void:
	var level := LevelCatalog.get_level(summary.level_id)
	SaveManager.record_result(summary.level_id, summary.elapsed, summary.medals, summary.optional)
	_update_achievements(level)
	if is_instance_valid(gameplay):
		gameplay.queue_free()
	gameplay = null
	_show_results(level, summary)

func _show_results(level: LevelDefinition, summary: Dictionary) -> void:
	_clear_current()
	var root := _new_screen(_world_background(level.world))
	var column := _center_column(root, 560)
	column.add_child(_title("LEVEL COMPLETE", 46, Color("fff073")))
	column.add_child(_subtitle("%s · %s" % [level.id, level.title]))
	var stats := Label.new()
	stats.text = "Time    %02d:%02d\nFruit    %d/%d\nMedals    %s" % [
		int(summary.elapsed) / 60,
		int(summary.elapsed) % 60,
		summary.optional,
		summary.optional_total,
		"★".repeat(summary.medals)
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_body(stats, 26, Color("f5fbff"))
	stats.custom_minimum_size.y = 160
	column.add_child(stats)
	var next_id := LevelCatalog.next_level_id(level.id)
	if not next_id.is_empty():
		column.add_child(_menu_button("Next Level", _start_level.bind(next_id)))
	column.add_child(_menu_button("Replay", _start_level.bind(level.id)))
	column.add_child(_menu_button("Level Select", _show_level_select.bind(level.world)))
	if level.number == 10:
		var anchor_text: String = ["", "The Garden Anchor blooms again.", "The Weatherworks sing through the clouds.", "The islands reunite beneath a new sun."][level.world]
		var story := Label.new()
		story.text = anchor_text
		story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.apply_body(story, 18, UI.GOLD)
		column.add_child(story)

func _show_options() -> void:
	_clear_current()
	var root := _new_screen(Color("18253e"))
	var column := _center_column(root, 620)
	column.add_child(_title("OPTIONS", 42, Color.WHITE))
	column.add_child(_volume_row("Master Volume", "master_volume"))
	column.add_child(_volume_row("Music Volume", "music_volume"))
	column.add_child(_volume_row("SFX Volume", "sfx_volume"))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.add_theme_font_override("font", UI.body_font())
	fullscreen.add_theme_font_size_override("font_size", 18)
	fullscreen.button_pressed = bool(SaveManager.data.settings.fullscreen)
	fullscreen.toggled.connect(func(value: bool): SaveManager.set_setting("fullscreen", value))
	column.add_child(fullscreen)
	var shake := CheckButton.new()
	shake.text = "Camera Shake"
	shake.add_theme_font_override("font", UI.body_font())
	shake.add_theme_font_size_override("font_size", 18)
	shake.button_pressed = bool(SaveManager.data.settings.camera_shake)
	shake.toggled.connect(func(value: bool): SaveManager.set_setting("camera_shake", value))
	column.add_child(shake)
	var heading := Label.new()
	heading.text = "KEYBOARD BINDINGS"
	UI.apply_title(heading, 20, UI.CYAN)
	column.add_child(heading)
	var bindings := GridContainer.new()
	bindings.columns = 2
	for action in ACTION_LABELS:
		var label := Label.new()
		label.text = ACTION_LABELS[action]
		UI.apply_body(label, 17, Color("e3f2ff"))
		bindings.add_child(label)
		var button := Button.new()
		button.set_meta("action", action)
		button.text = _binding_text(action)
		UI.apply_button(button, UI.CYAN, 42)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_begin_rebind.bind(action, button))
		bindings.add_child(button)
	column.add_child(bindings)
	column.add_child(_menu_button("Back", _show_main_menu))

func _show_credits() -> void:
	_clear_current()
	var root := _new_screen(Color("0b203b"), MENU_SKY)
	var column := _center_column(root, 680)
	column.add_child(_title("CREDITS & LICENSES", 40, UI.GOLD))
	var credits := Label.new()
	credits.text = "PROJECT SKYROLL\nOriginal game design, code, 3D art, UI and procedural audio.\n\nCREATED WITH\nGodot Engine 4.7.1  ·  Blender 5.2 LTS\n\nDEVELOPMENT REFERENCE\nPoly Haven rough_block_wall maps  ·  CC0 1.0\nReference maps are retained with the source pipeline and are not shipped in the runtime kit.\n\nProject Skyroll is an original work and contains no Kula World assets."
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.custom_minimum_size.y = 330
	UI.apply_body(credits, 18, Color("dcecf8"))
	column.add_child(credits)
	column.add_child(_menu_button("Back", _show_main_menu))

func _volume_row(label_text: String, setting: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 190
	UI.apply_body(label, 18, Color("e3f2ff"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveManager.data.settings[setting])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float): SaveManager.set_setting(setting, value))
	row.add_child(slider)
	return row

func _begin_rebind(action: String, button: Button) -> void:
	rebinding_action = action
	rebind_button = button
	button.text = "Press a key…"

func _binding_text(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "Unbound"

func _update_achievements(level: LevelDefinition) -> void:
	if level.id == "W1L01": PlatformService.unlock_achievement("FIRST_FLIGHT")
	if level.id == "W1L10": PlatformService.unlock_achievement("VERDANT_RESTORED")
	if level.id == "W2L10": PlatformService.unlock_achievement("CRYSTAL_RESTORED")
	if level.id == "W3L10": PlatformService.unlock_achievement("SKY_REUNITED")
	PlatformService.set_stat("total_medals", SaveManager.total_medals())
	if SaveManager.total_medals() >= 90:
		PlatformService.unlock_achievement("PERFECT_ORBIT")
	PlatformService.flush()

func _completed_in_world(world: int) -> int:
	var count := 0
	for number in range(1, 11):
		if bool(SaveManager.result_for("W%dL%02d" % [world, number]).get("completed", false)):
			count += 1
	return count

func _clear_current() -> void:
	get_tree().paused = false
	if is_instance_valid(screen):
		screen.queue_free()
	screen = null
	if is_instance_valid(gameplay):
		gameplay.queue_free()
	gameplay = null

func _new_screen(color: Color, backdrop: Texture2D = null) -> Control:
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	if backdrop != null:
		var art := TextureRect.new()
		art.texture = backdrop
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(art)
		var veil := ColorRect.new()
		veil.color = Color("03102070")
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(veil)
	else:
		screen.add_child(UI.make_gradient(color.lightened(0.08), color.darkened(0.42)))
	_add_background_glow(screen, color.lightened(0.3))
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.28)
	return screen

func _center_column(root: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	panel.custom_minimum_size.x = width + 76
	center.add_child(panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 38)
	padding.add_theme_constant_override("margin_right", 38)
	padding.add_theme_constant_override("margin_top", 30)
	padding.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(padding)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.add_theme_constant_override("separation", 18)
	padding.add_child(column)
	return column

func _title(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_title(label, size, color)
	return label

func _subtitle(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.apply_body(label, 19, UI.MUTED)
	return label

func _menu_button(text: String, callback: Callable, width: float = 330) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UI.apply_button(button, UI.CYAN, 54)
	button.pressed.connect(callback)
	return button

func _add_background_glow(root: Control, color: Color) -> void:
	var glow := ColorRect.new()
	glow.color = Color(color, 0.075)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.position = Vector2(-380, -380)
	glow.size = Vector2(760, 760)
	glow.rotation = PI / 4.0
	root.add_child(glow)

func _world_background(world: int) -> Color:
	return [Color("173f39"), Color("203d63"), Color("5d2946")][world - 1]

func _ensure_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("restart", KEY_R)
	_add_key_action("pause", KEY_ESCAPE)
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("restart", JOY_BUTTON_Y)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("camera_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("camera_right", JOY_AXIS_RIGHT_X, 1.0)

func _add_key_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _add_joy_button(action: String, button_index: JoyButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func _apply_saved_bindings() -> void:
	for action in SaveManager.data.settings.bindings:
		if not ACTION_LABELS.has(action): continue
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = int(SaveManager.data.settings.bindings[action])
		InputMap.action_add_event(action, event)
		# Always preserve gamepad support after a keyboard rebind.
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("restart", JOY_BUTTON_Y)
	_add_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_add_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
