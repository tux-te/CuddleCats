extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var celebrate_button: Button = %CelebrateButton

func _ready() -> void:
	PetCameo.spawn(%Petal)
	celebrate_button.pressed.connect(_on_celebrate)

func _on_celebrate() -> void:
	PetalState.celebrate_party()
	PetCameo.jump_for_joy(%Petal)
	for offset in [Vector2(-60, -30), Vector2(60, -60), Vector2(0, -90), Vector2(-100, -80)]:
		Feedback.pop(self, ["🎈", "🎊", "🎉", "✨"].pick_random(), celebrate_button.global_position + offset)
