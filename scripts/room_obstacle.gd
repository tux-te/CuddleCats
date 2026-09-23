extends Control

# Princess Petal runs a little obstacle course: walk, jump a hurdle,
# walk, jump, walk, jump, then celebrate at the finish flag. Reuses her
# existing walk and jump sprite sheets - no new art needed.

const Feedback = preload("res://scripts/room_feedback.gd")

const WALK_SEGMENTS := [[60.0, 300.0], [380.0, 580.0], [660.0, 860.0], [940.0, 1120.0]]
const JUMP_SEGMENTS := [[300.0, 380.0], [580.0, 660.0], [860.0, 940.0]]
const BASE_Y := 280.0
const JUMP_HEIGHT := 45.0
const SIT := "res://Sprites/petal_cutout.png"

@onready var runner: TextureRect = %Runner
@onready var go_button: Button = %GoButton

var walk_frames: Array[Texture2D] = []
var jump_frames: Array[Texture2D] = []
var is_running := false

func _ready() -> void:
	for i in range(10):
		walk_frames.append(load("res://Sprites/petal_walk/frame_%02d.png" % i))
	for i in range(5):
		jump_frames.append(load("res://Sprites/petal_jump/frame_%02d.png" % i))
	runner.texture = load(SIT)
	go_button.pressed.connect(_on_go)

func _on_go() -> void:
	if is_running:
		return
	is_running = true
	go_button.disabled = true

	for i in range(JUMP_SEGMENTS.size()):
		await _run_walk(WALK_SEGMENTS[i][0], WALK_SEGMENTS[i][1])
		await _run_jump(JUMP_SEGMENTS[i][0], JUMP_SEGMENTS[i][1])
	await _run_walk(WALK_SEGMENTS[3][0], WALK_SEGMENTS[3][1])

	if not is_instance_valid(self):
		return
	PetalState.obstacle_course()
	Feedback.pop(self, "🏆 She did it!", runner.global_position + Vector2(0, -20))
	await _celebrate()

	if not is_instance_valid(self):
		return
	runner.position = Vector2(WALK_SEGMENTS[0][0], BASE_Y)
	go_button.disabled = false
	is_running = false

func _run_walk(from_x: float, to_x: float) -> void:
	var steps := 10
	runner.position.y = BASE_Y
	for i in range(steps):
		runner.texture = walk_frames[i % walk_frames.size()]
		runner.position.x = lerp(from_x, to_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(self):
			return

func _run_jump(from_x: float, to_x: float) -> void:
	var steps := jump_frames.size()
	for i in range(steps):
		runner.texture = jump_frames[i]
		var t := float(i + 1) / float(steps)
		runner.position.x = lerp(from_x, to_x, t)
		runner.position.y = BASE_Y - JUMP_HEIGHT * sin(PI * t)
		await get_tree().create_timer(0.09).timeout
		if not is_instance_valid(self):
			return
	runner.position.y = BASE_Y

func _celebrate() -> void:
	for i in range(jump_frames.size()):
		runner.texture = jump_frames[i]
		await get_tree().create_timer(0.1).timeout
		if not is_instance_valid(self):
			return
	runner.texture = load(SIT)
