extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const SCENTS := {
	"rose": "🌹 rose-petal fresh!",
	"berry": "🍓 berry sweet & clean!",
	"lavender": "💜 lavender calm & clean!",
}

const SUDS_PER_PIXEL := 0.6
const DRY_PER_SECOND := 45.0

const DRYER_IDLE := "res://Sprites/blowdryer_idle.png"
const DRYER_BLOWING := "res://Sprites/blowdryer_blowing.png"
const GROOMING_BG := "res://Sprites/backgrounds/grooming_room.jpg"
const BATH_BG := "res://Sprites/backgrounds/bath_room.jpg"

enum Stage { IDLE, PICKING_SCENT, SCRUBBING, READY_TO_RINSE, DRYING, READY_TO_FINISH, DONE }

@onready var action_button: Button = %ActionButton
@onready var scrub_zone: Control = %ScrubZone
@onready var suds_bar: ProgressBar = %SudsBar
@onready var dry_bar: ProgressBar = %DryBar
@onready var dryer_sprite: TextureRect = %DryerSprite
@onready var petal: TextureRect = $Petal
@onready var background: TextureRect = %Background

var stage: Stage = Stage.IDLE
var chosen_scent := ""
var suds := 0.0
var is_scrubbing_drag := false
var last_scrub_pos := Vector2.ZERO
var is_drying_held := false

func _ready() -> void:
	background.texture = load(PetalState.room_bg("bath", BATH_BG))
	%BackButton.pressed.connect(_on_back)
	action_button.pressed.connect(_on_action)
	%RoseButton.pressed.connect(_on_scent_chosen.bind("rose"))
	%BerryButton.pressed.connect(_on_scent_chosen.bind("berry"))
	%LavenderButton.pressed.connect(_on_scent_chosen.bind("lavender"))

	scrub_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	scrub_zone.gui_input.connect(_on_scrub_input)

	petal.mouse_filter = Control.MOUSE_FILTER_STOP
	petal.gui_input.connect(_on_dryer_input)

func _process(delta: float) -> void:
	if stage == Stage.DRYING and is_drying_held:
		var dry: float = dry_bar.value + DRY_PER_SECOND * delta
		dry_bar.value = minf(100.0, dry)
		if dry_bar.value >= 100.0:
			_finish_drying()

func _on_back() -> void:
	PetalState.navigate_to_room.emit("grooming")

func _on_action() -> void:
	match stage:
		Stage.IDLE:
			stage = Stage.PICKING_SCENT
			%ScentPicker.visible = true
			action_button.visible = false
			Feedback.pop(self, "🧴 pick a scent!", action_button.global_position)
		Stage.READY_TO_RINSE:
			_do_rinse()
		Stage.READY_TO_FINISH:
			_on_back()
		_:
			pass

func _on_scent_chosen(scent: String) -> void:
	if stage != Stage.PICKING_SCENT:
		return
	chosen_scent = scent
	%ScentPicker.visible = false
	suds = 0.0
	suds_bar.value = 0.0
	suds_bar.visible = true
	stage = Stage.SCRUBBING
	Feedback.pop(self, "🫧 lather up - rub the tub!", scrub_zone.global_position)

func _on_scrub_input(event: InputEvent) -> void:
	if stage != Stage.SCRUBBING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_scrubbing_drag = event.pressed
		last_scrub_pos = event.position
	elif event is InputEventScreenTouch:
		is_scrubbing_drag = event.pressed
		last_scrub_pos = event.position
	elif event is InputEventMouseMotion and is_scrubbing_drag:
		_add_scrub(event.position)
	elif event is InputEventScreenDrag:
		_add_scrub(event.position)

func _add_scrub(pos: Vector2) -> void:
	suds = minf(100.0, suds + pos.distance_to(last_scrub_pos) * SUDS_PER_PIXEL)
	last_scrub_pos = pos
	suds_bar.value = suds
	if suds >= 100.0:
		_finish_scrub()

func _finish_scrub() -> void:
	stage = Stage.READY_TO_RINSE
	is_scrubbing_drag = false
	action_button.visible = true
	action_button.text = "💦 Rinse!"
	Feedback.pop(self, "🫧 all sudsy!", scrub_zone.global_position)

func _do_rinse() -> void:
	PetalState.bathe()
	Feedback.pop(self, SCENTS[chosen_scent], action_button.global_position)
	_start_blowdry()

func _start_blowdry() -> void:
	stage = Stage.DRYING
	suds_bar.visible = false
	action_button.visible = false
	background.texture = load(PetalState.room_bg("grooming", GROOMING_BG))
	%Title.text = "💨 Blow Dry"
	petal.texture = load(PetalState.cutout_path())
	petal.visible = true
	dryer_sprite.texture = load(DRYER_IDLE)
	dryer_sprite.visible = true
	dry_bar.value = 0.0
	dry_bar.visible = true
	Feedback.pop(self, "💨 hold to blow dry!", petal.global_position)

func _on_dryer_input(event: InputEvent) -> void:
	if stage != Stage.DRYING:
		return
	var is_press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch
	if is_press:
		is_drying_held = event.pressed
		dryer_sprite.texture = load(DRYER_BLOWING if is_drying_held else DRYER_IDLE)

func _finish_drying() -> void:
	stage = Stage.READY_TO_FINISH
	is_drying_held = false
	dryer_sprite.visible = false
	dry_bar.visible = false
	petal.texture = load(PetalState.static_pose("blowdried"))
	Feedback.pop(self, "✨ so fluffy!", petal.global_position)
	action_button.visible = true
	action_button.text = "✅ All Done"
