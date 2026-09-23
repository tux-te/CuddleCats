extends Control

const Feedback = preload("res://scripts/room_feedback.gd")

const ROOMS := {
	"bedroom": preload("res://scenes/rooms/bedroom.tscn"),
	"living": preload("res://scenes/rooms/living_room.tscn"),
	"dressup": preload("res://scenes/rooms/dress_up_room.tscn"),
	"grooming": preload("res://scenes/rooms/grooming_room.tscn"),
	"obstacle": preload("res://scenes/rooms/obstacle_course.tscn"),
}

const PLAY_FRAME_COUNT := 10

@onready var portrait: TextureRect = %Portrait
@onready var owner_portrait: TextureRect = %OwnerPortrait
@onready var room_slot: Control = %RoomSlot
@onready var name_label: Label = %NameLabel
@onready var mood_label: Label = %MoodLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var clean_bar: ProgressBar = %CleanBar

@onready var accessory_nodes := {
	"bow": %AccessoryBow,
	"flower": %AccessoryFlower,
	"sunglasses": %AccessorySunglasses,
	"scarf": %AccessoryScarf,
}

# Real "wearing it" portraits, checked most-specific combo first. Any
# accessory not covered by a combo here just falls back to the small
# icon overlay instead.
const WORN_COMBOS := [
	{"ids": ["scarf", "sunglasses"], "path": "res://Sprites/worn_scarf_sunglasses.png"},
	{"ids": ["sunglasses"], "path": "res://Sprites/worn_sunglasses.png"},
	{"ids": ["flower"], "path": "res://Sprites/worn_flower.png"},
]

const OWNER_WALK_FRAME_COUNT := 5

var current_room: Control = null
var static_portrait: Texture2D
var static_owner: Texture2D
var play_frames: Array[Texture2D] = []
var is_playing := false

func _ready() -> void:
	static_portrait = load("res://Sprites/petal_cutout.png")
	static_owner = load("res://Sprites/owner.png")
	portrait.texture = static_portrait
	owner_portrait.texture = static_owner
	name_label.text = PetalState.pet_name
	_walk_in_owner()

	for i in range(PLAY_FRAME_COUNT):
		play_frames.append(load("res://Sprites/petal_play/frame_%02d.png" % i))

	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.gui_input.connect(_on_portrait_input)

	for id in accessory_nodes:
		accessory_nodes[id].texture = load("res://Sprites/%s.png" % id)
	_refresh_accessories()

	PetalState.stats_changed.connect(_refresh_stats)
	PetalState.accessories_changed.connect(_refresh_accessories)
	PetalState.play_animation_requested.connect(_play_toy_animation)
	_refresh_stats()

	%BedroomButton.pressed.connect(_show_room.bind("bedroom"))
	%LivingButton.pressed.connect(_show_room.bind("living"))
	%DressUpButton.pressed.connect(_show_room.bind("dressup"))
	%GroomingButton.pressed.connect(_show_room.bind("grooming"))
	%ObstacleButton.pressed.connect(_show_room.bind("obstacle"))

	_show_room("bedroom")

func _on_portrait_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		PetalState.pet_her()
		Feedback.pop(self, ["🥰 purr~", "💕", "😻"].pick_random(), portrait.global_position + Vector2(60, 20))
		_bounce_portrait()

func _walk_in_owner() -> void:
	var walk_frames: Array[Texture2D] = []
	for i in range(OWNER_WALK_FRAME_COUNT):
		walk_frames.append(load("res://Sprites/owner_walk/frame_%02d.png" % i))

	owner_portrait.pivot_offset = owner_portrait.size / 2.0
	var target_x := owner_portrait.position.x
	var start_x := target_x - 140.0
	owner_portrait.position.x = start_x

	var steps := 12
	for i in range(steps):
		owner_portrait.texture = walk_frames[i % walk_frames.size()]
		owner_portrait.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.06).timeout

	owner_portrait.texture = static_owner
	owner_portrait.position.x = target_x

func _bounce_portrait() -> void:
	portrait.pivot_offset = portrait.size / 2.0
	var tween := create_tween()
	tween.tween_property(portrait, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

func _play_toy_animation() -> void:
	if is_playing:
		return
	is_playing = true
	for id in accessory_nodes:
		accessory_nodes[id].visible = false
	for i in range(play_frames.size()):
		portrait.texture = play_frames[i]
		var last := i == play_frames.size() - 1
		await get_tree().create_timer(0.7 if last else 0.18).timeout
	is_playing = false
	_refresh_accessories()

func _show_room(id: String) -> void:
	if current_room:
		current_room.queue_free()
	current_room = ROOMS[id].instantiate()
	room_slot.add_child(current_room)

func _refresh_stats() -> void:
	hunger_bar.value = PetalState.hunger
	happiness_bar.value = PetalState.happiness
	energy_bar.value = PetalState.energy
	clean_bar.value = PetalState.cleanliness
	mood_label.text = PetalState.mood()

func _refresh_accessories() -> void:
	var acc := PetalState.accessories
	var covered := {}
	var chosen_path := ""
	for combo in WORN_COMBOS:
		var all_on := true
		for id in combo["ids"]:
			if not acc[id]:
				all_on = false
				break
		if all_on:
			chosen_path = combo["path"]
			for id in combo["ids"]:
				covered[id] = true
			break

	portrait.texture = load(chosen_path) if chosen_path != "" else static_portrait

	for id in accessory_nodes:
		accessory_nodes[id].visible = acc[id] and not covered.get(id, false)
