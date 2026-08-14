extends Node

signal save_changed

const SAVE_VERSION := 1
const SAVE_PATH := "user://skyroll_save.json"
const TEMP_PATH := "user://skyroll_save.tmp"
const BACKUP_PATH := "user://skyroll_save.bak"

var data: Dictionary = {}

func _ready() -> void:
	load_save()

func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"unlocked_levels": ["W1L01"],
		"results": {},
		"story_seen": [],
		"settings": {
			"master_volume": 0.85,
			"music_volume": 0.75,
			"sfx_volume": 0.9,
			"fullscreen": false,
			"camera_shake": true,
			"bindings": {}
		}
	}

func load_save() -> void:
	data = defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	data = _migrate_and_merge(parsed)
	apply_settings()

func _migrate_and_merge(parsed: Dictionary) -> Dictionary:
	var merged := defaults()
	if int(parsed.get("version", 0)) <= SAVE_VERSION:
		for key in ["unlocked_levels", "results", "story_seen"]:
			if parsed.has(key):
				merged[key] = parsed[key]
		if parsed.get("settings") is Dictionary:
			for setting in parsed.settings:
				merged.settings[setting] = parsed.settings[setting]
	merged.version = SAVE_VERSION
	return merged

func save() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_backup := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			return false
	var error := DirAccess.rename_absolute(
		absolute_temp,
		absolute_save
	)
	if error != OK and FileAccess.file_exists(BACKUP_PATH):
		DirAccess.rename_absolute(absolute_backup, absolute_save)
	elif error == OK and FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(absolute_backup)
	if error == OK:
		save_changed.emit()
	return error == OK

func is_level_unlocked(level_id: String) -> bool:
	return level_id in data.unlocked_levels

func result_for(level_id: String) -> Dictionary:
	return data.results.get(level_id, {})

func record_result(level_id: String, elapsed: float, medals: int, optional_count: int) -> void:
	var previous: Dictionary = result_for(level_id)
	var best_time := elapsed
	if previous.has("best_time"):
		best_time = minf(float(previous.best_time), elapsed)
	data.results[level_id] = {
		"completed": true,
		"best_time": best_time,
		"medals": maxi(int(previous.get("medals", 0)), medals),
		"optional": maxi(int(previous.get("optional", 0)), optional_count)
	}
	var next_id := LevelCatalog.next_level_id(level_id)
	if not next_id.is_empty() and next_id not in data.unlocked_levels:
		data.unlocked_levels.append(next_id)
	save()

func total_medals() -> int:
	var total := 0
	for result in data.results.values():
		total += int(result.get("medals", 0))
	return total

func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	apply_settings()
	save()

func apply_settings() -> void:
	if not data.has("settings"):
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if bool(data.settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_set_bus_volume("Master", float(data.settings.master_volume))
	_set_bus_volume("Music", float(data.settings.music_volume))
	_set_bus_volume("SFX", float(data.settings.sfx_volume))

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.001, 1.0)))
