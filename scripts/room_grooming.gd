extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const BRUSH_FRAME_COUNT := 5

@onready var background: TextureRect = %Background

var is_brushing := false
var is_bathing := false

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
	# The bath_room scene's tub art has Princess Petal's cat baked right
	# into it - fine for Petal and Sheila (who has her own bath background),
	# but for pets whose whole bath is an illustrated comic, skip that room
	# entirely so they're never shown bathing in Petal's tub.
	if PetalState.has_anim("bath_comic"):
		_play_bath_comic_inline()
	else:
		PetalState.navigate_to_room.emit("bath")

func _play_bath_comic_inline() -> void:
	if is_bathing:
		return
	is_bathing = true
	%Petal.visible = false
	Feedback.pop(self, "🛁 bath time!", %BatheButton.global_position)
	PetalState.bathe()

	var anim: TextureRect = %BrushAnim
	var orig_anchors := Vector4(anim.anchor_left, anim.anchor_top, anim.anchor_right, anim.anchor_bottom)
	var orig_offsets := Vector4(anim.offset_left, anim.offset_top, anim.offset_right, anim.offset_bottom)
	anim.anchor_left = 0.0
	anim.anchor_top = 0.0
	anim.anchor_right = 1.0
	anim.anchor_bottom = 1.0
	anim.offset_left = 0.0
	anim.offset_top = 0.0
	anim.offset_right = 0.0
	anim.offset_bottom = 0.0
	anim.visible = true

	var frames := PetalState.anim_frames("bath_comic")
	for frame in frames:
		if not is_instance_valid(self):
			return
		anim.texture = frame
		await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(self):
		return

	anim.anchor_left = orig_anchors.x
	anim.anchor_top = orig_anchors.y
	anim.anchor_right = orig_anchors.z
	anim.anchor_bottom = orig_anchors.w
	anim.offset_left = orig_offsets.x
	anim.offset_top = orig_offsets.y
	anim.offset_right = orig_offsets.z
	anim.offset_bottom = orig_offsets.w
	anim.visible = false
	%Petal.visible = true
	is_bathing = false
