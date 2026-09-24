extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const BACKDROPS := {
	"bedroom": "res://Sprites/backgrounds/bedroom.jpg",
	"living": "res://Sprites/backgrounds/living_room.jpg",
	"garden": "res://Sprites/backgrounds/garden_sunny.jpg",
	"dressup": "res://Sprites/backgrounds/dress_up_room.jpg",
}

@onready var background: TextureRect = %Background
@onready var flash: ColorRect = %Flash
@onready var snap_button: Button = %SnapButton

func _ready() -> void:
	background.texture = load(BACKDROPS["bedroom"])
	PetCameo.spawn(%Petal)

	%BedroomBackdrop.pressed.connect(_set_backdrop.bind("bedroom"))
	%LivingBackdrop.pressed.connect(_set_backdrop.bind("living"))
	%GardenBackdrop.pressed.connect(_set_backdrop.bind("garden"))
	%DressupBackdrop.pressed.connect(_set_backdrop.bind("dressup"))
	snap_button.pressed.connect(_on_snap)

func _set_backdrop(id: String) -> void:
	background.texture = load(BACKDROPS[id])

func _on_snap() -> void:
	var image := get_viewport().get_texture().get_image()
	PetalState.take_photo(ImageTexture.create_from_image(image))
	Feedback.pop(self, "📸 cheese!", snap_button.global_position)
	var tween := create_tween()
	flash.modulate.a = 1.0
	flash.visible = true
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): flash.visible = false)
