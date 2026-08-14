class_name ProceduralAudio
extends Node

const MIX_RATE := 22050
var music_player: AudioStreamPlayer

func start_music(world: int) -> void:
	if music_player != null:
		music_player.queue_free()
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	music_player.volume_db = -17.0
	var roots := [196.0, 220.0, 174.61]
	music_player.stream = _make_ambient_loop(roots[world - 1])
	add_child(music_player)
	music_player.play()

func play_core() -> void:
	_play_chime([523.25, 659.25, 783.99], 0.10, -7.0)

func play_star() -> void:
	_play_chime([880.0, 1174.66], 0.07, -11.0)

func play_portal() -> void:
	_play_chime([392.0, 523.25, 659.25, 1046.5], 0.12, -5.0)

func play_fail() -> void:
	_play_chime([220.0, 185.0, 146.83], 0.16, -8.0)

func _play_chime(frequencies: Array[float], note_duration: float, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.stream = _make_sequence(frequencies, note_duration)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _make_sequence(frequencies: Array[float], note_duration: float) -> AudioStreamWAV:
	var total_samples := int(MIX_RATE * note_duration * frequencies.size())
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for sample_index in range(total_samples):
		var note_index := mini(int(sample_index / (MIX_RATE * note_duration)), frequencies.size() - 1)
		var local_time := fmod(float(sample_index) / MIX_RATE, note_duration)
		var envelope := sin(clampf(local_time / note_duration, 0.0, 1.0) * PI)
		var value := sin(TAU * frequencies[note_index] * local_time) * envelope * 0.32
		bytes.encode_s16(sample_index * 2, int(value * 32767.0))
	return _wav(bytes, false)

func _make_ambient_loop(root_frequency: float) -> AudioStreamWAV:
	var duration := 6.0
	var total_samples := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	var ratios := [1.0, 1.25, 1.5, 2.0]
	for sample_index in range(total_samples):
		var time := float(sample_index) / MIX_RATE
		var value := 0.0
		for ratio in ratios:
			value += sin(TAU * root_frequency * ratio * time) * 0.035
		value *= 0.75 + sin(TAU * time / duration) * 0.18
		bytes.encode_s16(sample_index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return _wav(bytes, true)

func _wav(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(bytes.size() / 2)
	return stream

