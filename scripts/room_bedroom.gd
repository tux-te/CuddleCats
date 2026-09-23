extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

func _ready() -> void:
	background.texture = load("res://Sprites/backgrounds/bedroom.jpg")
	PetCameo.spawn(%Petal)
	%CuddleButton.pressed.connect(_on_cuddle)
	%NapButton.pressed.connect(_on_nap)

func _on_cuddle() -> void:
	PetalState.cuddle()
	PetCameo.jump_for_joy(%Petal)
	Feedback.pop(self, "🥰 +hugs", %CuddleButton.global_position)

func _on_nap() -> void:
	PetalState.nap()
	Feedback.pop(self, "💤 zzz", %NapButton.global_position)
