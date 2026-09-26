extends RefCounted

# The active pet (see PetalState.PETS) "follows" the player into whichever
# room they open: every room places one of these in a corner and she walks
# in from off-screen using her real walk cycle, then settles into her
# sitting pose - like she just trotted in after you. Rooms can also call
# jump_for_joy() to have her hop happily in place (e.g. after a cuddle).
#
# Not every pet has art for every animation yet. Wherever frames are
# missing, these fall back to a plain tween on her sit pose instead of
# skipping the beat entirely.

static func spawn(node: TextureRect) -> void:
	node.modulate.a = 1.0
	node.scale = Vector2.ONE
	node.pivot_offset = node.size / 2.0
	node.texture = load(PetalState.cutout_path())

	var target_x := node.position.x
	var start_x := target_x - 160.0
	node.position.x = start_x

	var walk_frames := PetalState.anim_frames("walk")
	var steps := 16
	for i in range(steps):
		if not is_instance_valid(node):
			return
		if not walk_frames.is_empty():
			node.texture = walk_frames[i % walk_frames.size()]
		node.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await node.get_tree().create_timer(0.05).timeout

	if not is_instance_valid(node):
		return
	node.texture = load(PetalState.cutout_path())
	node.position.x = target_x

static func jump_for_joy(node: TextureRect) -> void:
	var jump_frames := PetalState.anim_frames("jump")
	if jump_frames.is_empty():
		await _bounce_tween(node)
		return
	for frame in jump_frames:
		if not is_instance_valid(node):
			return
		node.texture = frame
		await node.get_tree().create_timer(0.1).timeout
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

static func _bounce_tween(node: TextureRect) -> void:
	var pose_key := "jump_still" if PetalState.has_anim("jump_still") else "wave"
	if PetalState.has_anim(pose_key):
		node.texture = load(PetalState.static_pose(pose_key))
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(1.15, 0.85), 0.12)
	tween.tween_property(node, "scale", Vector2(0.9, 1.1), 0.12)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_ELASTIC)
	await node.get_tree().create_timer(0.9).timeout
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

# Plays her yawn-to-asleep sequence and leaves her sleeping (doesn't
# revert to the sitting pose) - call wake(node) to bring her back.
static func sleep(node: TextureRect) -> void:
	var sleep_frames := PetalState.anim_frames("sleep")
	if sleep_frames.is_empty():
		if PetalState.has_anim("sleep_still"):
			node.texture = load(PetalState.static_pose("sleep_still"))
		return
	for i in range(sleep_frames.size()):
		if not is_instance_valid(node):
			return
		node.texture = sleep_frames[i]
		var last := i == sleep_frames.size() - 1
		await node.get_tree().create_timer(0.7 if last else 0.3).timeout

static func wake(node: TextureRect) -> void:
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

static func dance(node: TextureRect, loops: int = 2) -> void:
	var dance_frames := PetalState.anim_frames("dance")
	if dance_frames.is_empty():
		for _loop in range(loops):
			await _wiggle_tween(node)
		return
	for _loop in range(loops):
		for frame in dance_frames:
			if not is_instance_valid(node):
				return
			node.texture = frame
			await node.get_tree().create_timer(0.15).timeout
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

static func _wiggle_tween(node: TextureRect) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "rotation_degrees", -8.0, 0.15)
	tween.tween_property(node, "rotation_degrees", 8.0, 0.3)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.15)
	await tween.finished
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

# Trick training: sit / come / wave. None of these need dedicated art -
# they read from whatever pose art the pet already has (falling back to
# her sit pose) and act the trick out with a tween.
static func perform_trick(node: TextureRect, trick_id: String) -> void:
	match trick_id:
		"wave":
			await _trick_wave(node)
		"sit":
			await _trick_sit(node)
		"come":
			await _trick_come(node)
		"sing":
			await _trick_sing(node)

static func _trick_sing(node: TextureRect) -> void:
	if PetalState.has_anim("trick_sing"):
		await _play_frames_once(node, "trick_sing", 0.15)

static func _trick_wave(node: TextureRect) -> void:
	if PetalState.has_anim("trick_wave"):
		await _play_frames_once(node, "trick_wave", 0.12)
		return
	if PetalState.has_anim("wave"):
		node.texture = load(PetalState.static_pose("wave"))
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.set_loops(3)
	tween.tween_property(node, "rotation_degrees", 10.0, 0.15)
	tween.tween_property(node, "rotation_degrees", -6.0, 0.15)
	await tween.finished
	node.rotation_degrees = 0.0
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

static func _trick_sit(node: TextureRect) -> void:
	if PetalState.has_anim("trick_sit"):
		await _play_frames_once(node, "trick_sit", 0.12)
		return
	node.texture = load(PetalState.cutout_path())
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(1.08, 0.82), 0.12)
	tween.tween_property(node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BOUNCE)
	await tween.finished

# Plays a pet's named frame-set once, front to back, then settles on her
# sitting pose. Used for tricks that have real drawn frames instead of
# just a tween on the cutout (see PETS entries like "trick_sit").
static func _play_frames_once(node: TextureRect, anim_key: String, frame_delay: float) -> void:
	var frames := PetalState.anim_frames(anim_key)
	for frame in frames:
		if not is_instance_valid(node):
			return
		node.texture = frame
		await node.get_tree().create_timer(frame_delay).timeout
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())

static func _trick_come(node: TextureRect) -> void:
	if PetalState.has_anim("trick_come"):
		await _play_frames_once(node, "trick_come", 0.12)
		return
	if PetalState.has_anim("come_still"):
		node.texture = load(PetalState.static_pose("come_still"))
	else:
		node.texture = load(PetalState.cutout_path())
	node.pivot_offset = node.size / 2.0
	var base_scale := node.scale
	for _i in range(2):
		if not is_instance_valid(node):
			return
		var tween := node.create_tween()
		tween.tween_property(node, "scale", base_scale * 1.18, 0.16).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "scale", base_scale, 0.16).set_trans(Tween.TRANS_SINE)
		await tween.finished
	if is_instance_valid(node):
		node.texture = load(PetalState.cutout_path())
