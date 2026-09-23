extends RefCounted

# Petal "follows" the player into whichever room they open: every room
# places one of these in a corner and she walks in from off-screen using
# her real walk cycle, then settles into her sitting pose - like she just
# trotted in after you. Rooms can also call jump_for_joy() to have her
# hop happily in place (e.g. after a cuddle).

const SIT := "res://Sprites/petal_cutout.png"
const WALK_FRAME_COUNT := 10
const JUMP_FRAME_COUNT := 5

static func spawn(node: TextureRect) -> void:
	var walk_frames: Array[Texture2D] = []
	for i in range(WALK_FRAME_COUNT):
		walk_frames.append(load("res://Sprites/petal_walk/frame_%02d.png" % i))

	node.modulate.a = 1.0
	node.scale = Vector2.ONE
	node.pivot_offset = node.size / 2.0

	var target_x := node.position.x
	var start_x := target_x - 160.0
	node.position.x = start_x

	var steps := 16
	for i in range(steps):
		if not is_instance_valid(node):
			return
		node.texture = walk_frames[i % walk_frames.size()]
		node.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await node.get_tree().create_timer(0.05).timeout

	if not is_instance_valid(node):
		return
	node.texture = load(SIT)
	node.position.x = target_x

static func jump_for_joy(node: TextureRect) -> void:
	var jump_frames: Array[Texture2D] = []
	for i in range(JUMP_FRAME_COUNT):
		jump_frames.append(load("res://Sprites/petal_jump/frame_%02d.png" % i))

	for i in range(jump_frames.size()):
		if not is_instance_valid(node):
			return
		node.texture = jump_frames[i]
		await node.get_tree().create_timer(0.1).timeout
	if is_instance_valid(node):
		node.texture = load(SIT)
