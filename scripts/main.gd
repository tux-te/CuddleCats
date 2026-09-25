extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

const IDLE_REACTION_SECONDS := 9.0
const IDLE_REACTIONS := ["😽 blink", "🐾 stretch~", "💤 yawn~", "😊 happy sigh"]

const ROOMS := {
	"bedroom": preload("res://scenes/rooms/bedroom.tscn"),
	"living": preload("res://scenes/rooms/living_room.tscn"),
	"dressup": preload("res://scenes/rooms/dress_up_room.tscn"),
	"grooming": preload("res://scenes/rooms/grooming_room.tscn"),
	"bath": preload("res://scenes/rooms/bath_room.tscn"),
	"obstacle": preload("res://scenes/rooms/obstacle_course.tscn"),
	"garden": preload("res://scenes/rooms/garden.tscn"),
	"fishing": preload("res://scenes/rooms/fishing_pond.tscn"),
	"photo": preload("res://scenes/rooms/photo_booth.tscn"),
	"photobook": preload("res://scenes/rooms/photo_book.tscn"),
	"party": preload("res://scenes/rooms/party.tscn"),
	"stickers": preload("res://scenes/rooms/sticker_book.tscn"),
}

const OWNER_WALK_FRAME_COUNT := 5

@onready var room_slot: Control = %RoomSlot
@onready var name_label: Label = %NameLabel
@onready var mood_label: Label = %MoodLabel
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var clean_bar: ProgressBar = %CleanBar
@onready var pets_button: Button = %PetsButton
@onready var pet_picker: Control = %PetPicker
@onready var pet_list: HBoxContainer = %PetList
@onready var coins_label: Label = %CoinsLabel

var current_room: Control = null
var current_room_id := "bedroom"
var room_petal: TextureRect = null
var accessory_nodes := {}
var static_owner: Texture2D
var is_playing := false
var seconds_since_interaction := 0.0

func _ready() -> void:
	static_owner = load("res://Sprites/owner.png")
	name_label.text = PetalState.pet_name

	PetalState.stats_changed.connect(_refresh_stats)
	PetalState.accessories_changed.connect(_refresh_accessories)
	PetalState.play_animation_requested.connect(_play_toy_animation)
	PetalState.navigate_to_room.connect(_show_room)
	PetalState.pet_changed.connect(_on_pet_changed)
	PetalState.coins_changed.connect(_refresh_coins)
	PetalState.sticker_earned.connect(_on_sticker_earned)
	PetalState.milestone_reached.connect(_on_milestone_reached)
	_refresh_stats()
	_refresh_coins()

	%BedroomButton.pressed.connect(_show_room.bind("bedroom"))
	%LivingButton.pressed.connect(_show_room.bind("living"))
	%DressUpButton.pressed.connect(_show_room.bind("dressup"))
	%GroomingButton.pressed.connect(_show_room.bind("grooming"))
	%ObstacleButton.pressed.connect(_show_room.bind("obstacle"))
	%GardenButton.pressed.connect(_show_room.bind("garden"))
	%PhotoButton.pressed.connect(_show_room.bind("photo"))
	%PartyButton.pressed.connect(_show_room.bind("party"))
	%StickersButton.pressed.connect(_show_room.bind("stickers"))

	pets_button.pressed.connect(_open_pet_picker)
	%ClosePetPickerButton.pressed.connect(_close_pet_picker)

	_show_room("bedroom")

	var idle_timer := Timer.new()
	idle_timer.wait_time = 1.0
	idle_timer.autostart = true
	idle_timer.timeout.connect(_on_idle_tick)
	add_child(idle_timer)

func _refresh_coins() -> void:
	coins_label.text = "🪙 %d Treat Coin%s" % [PetalState.coins, "" if PetalState.coins == 1 else "s"]

func _on_sticker_earned(_id: String) -> void:
	Sfx.chime(self)
	if room_petal and is_instance_valid(room_petal):
		Confetti.burst(current_room, room_petal.global_position + room_petal.size / 2.0, 14)

func _on_milestone_reached(total: int) -> void:
	Sfx.fanfare(self)
	var at: Vector2 = room_petal.global_position + room_petal.size / 2.0 if room_petal and is_instance_valid(room_petal) else get_viewport_rect().size / 2.0
	Confetti.burst(self, at, 30)
	Feedback.pop(self, "🪙 %d Treat Coins! Yay!" % total, at + Vector2(-60, -60))

# A little life in the room: if nobody has interacted for a while, the
# pet gives a small cute reaction so the screen never feels frozen.
# Resets whenever petting happens (see _on_room_pet_input).
func _on_idle_tick() -> void:
	seconds_since_interaction += 1.0
	if seconds_since_interaction < IDLE_REACTION_SECONDS:
		return
	seconds_since_interaction = 0.0
	if not room_petal or not is_instance_valid(room_petal) or is_playing:
		return
	_bounce_pet()
	Feedback.pop(self, IDLE_REACTIONS.pick_random(), room_petal.global_position + Vector2(60, 0))

func _show_room(id: String) -> void:
	current_room_id = id
	if current_room:
		current_room.queue_free()
	room_petal = null
	accessory_nodes.clear()
	current_room = ROOMS[id].instantiate()
	room_slot.add_child(current_room)
	_wire_room_pet()

func _open_pet_picker() -> void:
	for child in pet_list.get_children():
		child.queue_free()
	for id in PetalState.PETS:
		var btn := TextureButton.new()
		btn.texture_normal = load(String(PetalState.PETS[id]["cutout"]))
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(160, 220)
		btn.pressed.connect(_on_pet_picked.bind(id))
		pet_list.add_child(btn)
	pet_picker.visible = true

func _close_pet_picker() -> void:
	pet_picker.visible = false

func _on_pet_picked(id: String) -> void:
	PetalState.switch_pet(id)
	_close_pet_picker()

func _on_pet_changed() -> void:
	name_label.text = PetalState.pet_name
	_show_room(current_room_id)

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
	var pet_accessories: Dictionary = PetalState.PETS[PetalState.active_pet]["accessories"]
	for id in pet_accessories:
		var icon := TextureRect.new()
		icon.name = "Accessory_%s" % id
		icon.texture = load(String(pet_accessories[id]["icon"]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		var a: Dictionary = pet_accessories[id]["anchor"]
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
		seconds_since_interaction = 0.0
		PetalState.pet_her()
		Sfx.pop(self)
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

	if not PetalState.has_anim("play"):
		await PetCameo.jump_for_joy(room_petal)
		is_playing = false
		if is_instance_valid(room_petal):
			_refresh_accessories()
		return

	var frames := PetalState.anim_frames("play")
	for i in range(frames.size()):
		if not is_instance_valid(room_petal):
			is_playing = false
			return
		room_petal.texture = frames[i]
		var last := i == frames.size() - 1
		await get_tree().create_timer(0.7 if last else 0.18).timeout
	is_playing = false
	if is_instance_valid(room_petal):
		room_petal.texture = load(PetalState.cutout_path())
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
