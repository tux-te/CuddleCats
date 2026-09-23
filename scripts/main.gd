extends Control

const Feedback = preload("res://scripts/room_feedback.gd")

const ROOMS := {
	"bedroom": preload("res://scenes/rooms/bedroom.tscn"),
	"living": preload("res://scenes/rooms/living_room.tscn"),
	"dressup": preload("res://scenes/rooms/dress_up_room.tscn"),
	"grooming": preload("res://scenes/rooms/grooming_room.tscn"),
	"obstacle": preload("res://scenes/rooms/obstacle_course.tscn"),
	"garden": preload("res://scenes/rooms/garden.tscn"),
	"photo": preload("res://scenes/rooms/photo_booth.tscn"),
	"party": preload("res://scenes/rooms/party.tscn"),
	"stickers": preload("res://scenes/rooms/sticker_book.tscn"),
}

const PLAY_FRAME_COUNT := 10
const OWNER_WALK_FRAME_COUNT := 5

# Small accessory icons overlaid on whichever room's cat is showing,
# anchored proportionally to her TextureRect so they land on her
# head/neck no matter which room-sized box she's sitting in.
const ACCESSORY_ANCHORS := {
	"bow": {"l": 0.327, "t": 0.025, "r": 0.427, "b": 0.196},
	"flower": {"l": 0.573, "t": 0.025, "r": 0.673, "b": 0.196},
	"sunglasses": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.491},
	"scarf": {"l": 0.333, "t": 0.515, "r": 0.667, "b": 0.699},
}

@onready var room_slot: Control = %RoomSlot
@onready var name_label: Label = %NameLabel
@onready var mood_label: Label = %MoodLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var clean_bar: ProgressBar = %CleanBar

var current_room: Control = null
var room_petal: TextureRect = null
var accessory_nodes := {}
var static_owner: Texture2D
var play_frames: Array[Texture2D] = []
var is_playing := false

func _ready() -> void:
	static_owner = load("res://Sprites/owner.png")
	name_label.text = PetalState.pet_name

	for i in range(PLAY_FRAME_COUNT):
		play_frames.append(load("res://Sprites/petal_play/frame_%02d.png" % i))

	PetalState.stats_changed.connect(_refresh_stats)
	PetalState.accessories_changed.connect(_refresh_accessories)
	PetalState.play_animation_requested.connect(_play_toy_animation)
	_refresh_stats()

	%BedroomButton.pressed.connect(_show_room.bind("bedroom"))
	%LivingButton.pressed.connect(_show_room.bind("living"))
	%DressUpButton.pressed.connect(_show_room.bind("dressup"))
	%GroomingButton.pressed.connect(_show_room.bind("grooming"))
	%ObstacleButton.pressed.connect(_show_room.bind("obstacle"))
	%GardenButton.pressed.connect(_show_room.bind("garden"))
	%PhotoButton.pressed.connect(_show_room.bind("photo"))
	%PartyButton.pressed.connect(_show_room.bind("party"))
	%StickersButton.pressed.connect(_show_room.bind("stickers"))

	_show_room("bedroom")

func _show_room(id: String) -> void:
	if current_room:
		current_room.queue_free()
	room_petal = null
	accessory_nodes.clear()
	current_room = ROOMS[id].instantiate()
	room_slot.add_child(current_room)
	_wire_room_pet()

# Rooms that show Petal (all but the Obstacle Course and Sticker Book)
# expose her via a unique "Petal" TextureRect - that's the one cat in
# the room. We hook petting, her accessories, and the owner cameo onto
# that same node instead of keeping a separate header portrait.
func _wire_room_pet() -> void:
	room_petal = current_room.get_node_or_null("%Petal")
	if not room_petal:
		return

	room_petal.mouse_filter = Control.MOUSE_FILTER_STOP
	room_petal.gui_input.connect(_on_room_pet_input)

	_build_accessory_overlays()
	_refresh_accessories()
	_spawn_owner_beside(room_petal)

func _build_accessory_overlays() -> void:
	for id in ACCESSORY_ANCHORS:
		var icon := TextureRect.new()
		icon.name = "Accessory_%s" % id
		icon.texture = load("res://Sprites/%s.png" % id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		var a: Dictionary = ACCESSORY_ANCHORS[id]
		icon.anchor_left = a["l"]
		icon.anchor_top = a["t"]
		icon.anchor_right = a["r"]
		icon.anchor_bottom = a["b"]
		room_petal.add_child(icon)
		accessory_nodes[id] = icon

func _spawn_owner_beside(petal_node: TextureRect) -> void:
	var owner_node := TextureRect.new()
	owner_node.name = "Owner"
	owner_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	owner_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	owner_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_node.anchor_left = petal_node.anchor_left
	owner_node.anchor_top = petal_node.anchor_top
	owner_node.anchor_right = petal_node.anchor_right
	owner_node.anchor_bottom = petal_node.anchor_bottom
	owner_node.offset_left = petal_node.offset_right + 12.0
	owner_node.offset_right = owner_node.offset_left + 90.0
	owner_node.offset_top = petal_node.offset_bottom - 110.0
	owner_node.offset_bottom = petal_node.offset_bottom
	owner_node.grow_vertical = petal_node.grow_vertical
	petal_node.get_parent().add_child(owner_node)
	# Keep the owner drawn behind the cat, since her walk-in path
	# crosses through Petal's box and would otherwise cover her.
	petal_node.get_parent().move_child(owner_node, petal_node.get_index())
	_walk_in_owner(owner_node)

func _walk_in_owner(owner_node: TextureRect) -> void:
	var walk_frames: Array[Texture2D] = []
	for i in range(OWNER_WALK_FRAME_COUNT):
		walk_frames.append(load("res://Sprites/owner_walk/frame_%02d.png" % i))

	owner_node.pivot_offset = owner_node.size / 2.0
	var target_x := owner_node.position.x
	var start_x := target_x - 140.0
	owner_node.position.x = start_x

	var steps := 12
	for i in range(steps):
		if not is_instance_valid(owner_node):
			return
		owner_node.texture = walk_frames[i % walk_frames.size()]
		owner_node.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.06).timeout

	if not is_instance_valid(owner_node):
		return
	owner_node.texture = static_owner
	owner_node.position.x = target_x

func _on_room_pet_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		PetalState.pet_her()
		Feedback.pop(self, ["🥰 purr~", "💕", "😻"].pick_random(), room_petal.global_position + Vector2(60, 20))
		_bounce_pet()

func _bounce_pet() -> void:
	room_petal.pivot_offset = room_petal.size / 2.0
	var tween := create_tween()
	tween.tween_property(room_petal, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(room_petal, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

func _play_toy_animation() -> void:
	if not room_petal or is_playing:
		return
	is_playing = true
	for id in accessory_nodes:
		accessory_nodes[id].visible = false
	for i in range(play_frames.size()):
		if not is_instance_valid(room_petal):
			is_playing = false
			return
		room_petal.texture = play_frames[i]
		var last := i == play_frames.size() - 1
		await get_tree().create_timer(0.7 if last else 0.18).timeout
	is_playing = false
	if is_instance_valid(room_petal):
		room_petal.texture = load("res://Sprites/petal_cutout.png")
		_refresh_accessories()

func _refresh_stats() -> void:
	hunger_bar.value = PetalState.hunger
	happiness_bar.value = PetalState.happiness
	energy_bar.value = PetalState.energy
	clean_bar.value = PetalState.cleanliness
	mood_label.text = PetalState.mood()

func _refresh_accessories() -> void:
	if not room_petal or not is_instance_valid(room_petal):
		return
	var acc := PetalState.accessories
	for id in accessory_nodes:
		accessory_nodes[id].visible = acc[id]
