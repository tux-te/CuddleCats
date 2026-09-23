extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

var buttons := {}

func _ready() -> void:
	background.texture = load("res://Sprites/backgrounds/dress_up_room.jpg")
	PetCameo.spawn(%Petal)

	buttons = {
		"bow": %BowButton,
		"flower": %FlowerButton,
		"sunglasses": %SunglassesButton,
		"scarf": %ScarfButton,
	}
	for id in buttons:
		var btn: Button = buttons[id]
		btn.icon = load("res://Sprites/%s.png" % id)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 48)
		btn.set_pressed_no_signal(PetalState.accessories[id])
		btn.pressed.connect(_on_toggle.bind(id))

func _on_toggle(id: String) -> void:
	PetalState.toggle_accessory(id)
	buttons[id].set_pressed_no_signal(PetalState.accessories[id])
	var text := "✨ pretty!" if PetalState.accessories[id] else "took it off"
	Feedback.pop(self, text, buttons[id].global_position)
