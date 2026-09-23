extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

func _ready() -> void:
	background.texture = load("res://Sprites/backgrounds/living_room.jpg")
	PetCameo.spawn(%Petal)
	%FeedButton.pressed.connect(_on_feed)
	%PlayButton.pressed.connect(_on_play)
	%PlayButton.icon = load("res://Sprites/toy_wand.png")
	%PlayButton.expand_icon = true
	%PlayButton.add_theme_constant_override("icon_max_width", 36)
	%FeedButton.expand_icon = true
	%FeedButton.add_theme_constant_override("icon_max_width", 36)

	PetalState.stats_changed.connect(_update_food_icon)
	_update_food_icon()

func _update_food_icon() -> void:
	var level := _hunger_level()
	%FeedButton.icon = load("res://Sprites/food_bowl/level_%d.png" % level)

func _hunger_level() -> int:
	var h := PetalState.hunger
	if h >= 80.0:
		return 1
	elif h >= 60.0:
		return 2
	elif h >= 40.0:
		return 3
	elif h >= 20.0:
		return 4
	else:
		return 5

func _on_feed() -> void:
	PetalState.feed()
	Feedback.pop(self, "🍓 yum!", %FeedButton.global_position)

func _on_play() -> void:
	PetalState.play()
	PetalState.play_animation_requested.emit()
	Feedback.pop(self, "🎉 wheee!", %PlayButton.global_position)
