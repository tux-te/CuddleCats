extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var celebrate_button: Button = %CelebrateButton
@onready var dance_button: Button = %DanceButton

var is_dancing := false

func _ready() -> void:
	%Background.texture = load(PetalState.room_bg("party", "res://Sprites/backgrounds/party_room.jpg"))
	PetCameo.spawn(%Petal)
	celebrate_button.pressed.connect(_on_celebrate)
	dance_button.pressed.connect(_on_dance)

func _on_celebrate() -> void:
	PetalState.celebrate_party()
	PetCameo.jump_for_joy(%Petal)
	for offset in [Vector2(-60, -30), Vector2(60, -60), Vector2(0, -90), Vector2(-100, -80)]:
		Feedback.pop(self, ["🎈", "🎊", "🎉", "✨"].pick_random(), celebrate_button.global_position + offset)

func _on_dance() -> void:
	if is_dancing:
		return
	is_dancing = true
	dance_button.disabled = true
	PetalState.celebrate_party()
	Feedback.pop(self, "💃 dance party!", dance_button.global_position)
	await PetCameo.dance(%Petal)
	if not is_instance_valid(self):
		return
	dance_button.disabled = false
	is_dancing = false
