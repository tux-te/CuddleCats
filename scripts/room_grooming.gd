extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const BRUSH_FRAME_COUNT := 5

@onready var background: TextureRect = %Background

var is_brushing := false

func _ready() -> void:
	background.texture = load(PetalState.room_bg("grooming", "res://Sprites/backgrounds/grooming_room.jpg"))
	PetCameo.spawn(%Petal)
	%BrushButton.pressed.connect(_on_brush)
	%BatheButton.pressed.connect(_on_bathe)

func _on_brush() -> void:
	PetalState.brush()
	Feedback.pop(self, "✨ so soft", %BrushButton.global_position)
	_play_brush_anim()

func _play_brush_anim() -> void:
	if is_brushing:
		return
	is_brushing = true
	%Petal.visible = false
	%BrushAnim.visible = true

	if PetalState.has_anim("brush"):
		# A pet-specific illustrated sequence (e.g. Kiwi's comic of Lucy
		# brushing her) - slower per frame so there's time to read it.
		var frames := PetalState.anim_frames("brush")
		for frame in frames:
			%BrushAnim.texture = frame
			await get_tree().create_timer(0.9).timeout
			if not is_instance_valid(self):
				return
	else:
		for i in range(BRUSH_FRAME_COUNT):
			%BrushAnim.texture = load("res://Sprites/owner_brush/frame_%02d.png" % i)
			await get_tree().create_timer(0.25).timeout
			if not is_instance_valid(self):
				return

	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self):
		return
	%BrushAnim.visible = false
	%Petal.visible = true
	is_brushing = false

func _on_bathe() -> void:
	PetalState.navigate_to_room.emit("bath")
