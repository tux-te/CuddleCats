extends Control

const FRAME_COUNT := 11
const YAWN_FRAME_TIME := 0.35
const SLEEP_FRAME_TIME := 0.5
const SLEEP_START_INDEX := 7 # frames 7-10 are the falling-asleep part

@onready var petal: TextureRect = %Petal
@onready var prompt: Label = %Prompt
@onready var timer: Timer = %FrameTimer

var frames: Array[Texture2D] = []
var frame_index := 0

func _ready() -> void:
	for i in range(FRAME_COUNT):
		var path := "res://Sprites/petal_sleep/frame_%02d.png" % i
		frames.append(load(path))

	prompt.modulate.a = 0.0
	petal.texture = frames[0]

	timer.timeout.connect(_advance_frame)
	_queue_next_frame()

func _queue_next_frame() -> void:
	timer.wait_time = SLEEP_FRAME_TIME if frame_index >= SLEEP_START_INDEX else YAWN_FRAME_TIME
	timer.start()

func _advance_frame() -> void:
	frame_index += 1
	if frame_index >= frames.size():
		frame_index = frames.size() - 1
		_show_prompt()
		return
	petal.texture = frames[frame_index]
	_queue_next_frame()

func _show_prompt() -> void:
	var tween := create_tween()
	tween.tween_property(prompt, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		_start_game()

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
