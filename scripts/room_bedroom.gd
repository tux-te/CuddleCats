extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

func _ready() -> void:
	background.texture = load(PetalState.room_bg("bedroom", "res://Sprites/backgrounds/bedroom.jpg"))
	PetCameo.spawn(%Petal)
	%CuddleButton.pressed.connect(_on_cuddle)
	%NapButton.pressed.connect(_on_nap)
	%PhotoBookButton.pressed.connect(_on_photo_book)

func _on_cuddle() -> void:
	PetalState.cuddle()
	PetCameo.jump_for_joy(%Petal)
	Feedback.pop(self, "🥰 +hugs", %CuddleButton.global_position)

func _on_nap() -> void:
	PetalState.nap()
	PetCameo.sleep(%Petal)
	Feedback.pop(self, "💤 zzz", %NapButton.global_position)

func _on_photo_book() -> void:
	PetalState.navigate_to_room.emit("photobook")
