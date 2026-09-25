extends RefCounted

# Tiny procedural sound effects - generated as simple sine-wave tones at
# runtime so the game doesn't need any bundled audio files. Each call
# spawns a one-shot AudioStreamPlayer that frees itself when done.

const MIX_RATE := 22050.0

static func _play_tones(parent: Node, freqs: Array, note_len: float, volume_db: float = -8.0) -> void:
	if not is_instance_valid(parent):
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.3

	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = volume_db
	parent.add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback == null:
		player.queue_free()
		return

	var frames_per_note := int(MIX_RATE * note_len)
	for freq in freqs:
		var phase := 0.0
		var increment := float(freq) / MIX_RATE
		for i in range(frames_per_note):
			var envelope := 1.0 - float(i) / float(frames_per_note)
			var sample := sin(phase * TAU) * envelope * 0.5
			phase = fmod(phase + increment, 1.0)
			playback.push_frame(Vector2(sample, sample))

	await parent.get_tree().create_timer(note_len * freqs.size() + 0.15).timeout
	if is_instance_valid(player):
		player.queue_free()

static func pop(parent: Node) -> void:
	_play_tones(parent, [660.0], 0.08, -6.0)

static func chime(parent: Node) -> void:
	_play_tones(parent, [523.25, 783.99], 0.12, -6.0)

static func fanfare(parent: Node) -> void:
	_play_tones(parent, [523.25, 659.25, 783.99, 1046.5], 0.13, -4.0)
