extends Control

# The Garden's weather is fetched live from Open-Meteo for Washington, DC
# each time the room opens. If it's rainy (or stormy), Princess Petal
# doesn't want to go outside and the Stroll button is disabled.

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

const SUNNY_BG := "res://Sprites/backgrounds/garden_sunny.jpg"
const RAIN_BG := "res://Sprites/backgrounds/garden_rain.jpg"
const SNOW_BG := "res://Sprites/backgrounds/garden_snow.jpg"

const WEATHER_URL := "https://api.open-meteo.com/v1/forecast?latitude=38.9072&longitude=-77.0369&current_weather=true&temperature_unit=fahrenheit"

const RAIN_CODES := [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
const SNOW_CODES := [71, 73, 75, 77, 85, 86]

const WALK_LEFT_X := 200.0
const WALK_RIGHT_X := 1000.0

@onready var background: TextureRect = %Background
@onready var status_label: Label = %StatusLabel
@onready var stroll_button: Button = %StrollButton
@onready var fish_button: Button = %FishButton
@onready var fish_display: Label = %FishDisplay
@onready var rod_sprite: TextureRect = %RodSprite
@onready var http: HTTPRequest = %WeatherRequest

const FISH_MIN_WAIT := 1.5
const FISH_MAX_WAIT := 3.5
const FISH_BITE_WINDOW := 1.0

const FISH_COLORS := [
	{"name": "Blue", "color": Color(0.35, 0.6, 1.0)},
	{"name": "Orange", "color": Color(1.0, 0.55, 0.15)},
	{"name": "Golden", "color": Color(1.0, 0.85, 0.2)},
	{"name": "Purple", "color": Color(0.7, 0.4, 0.95)},
	{"name": "Green", "color": Color(0.35, 0.85, 0.5)},
	{"name": "Pink", "color": Color(1.0, 0.55, 0.75)},
]

enum FishState { IDLE, WAITING, BITING, SHOWING, READY_TO_RELEASE }

var walk_frames: Array[Texture2D] = []
var rod_frames: Array[Texture2D] = []
var is_raining := false
var is_strolling := false
var fish_state: FishState = FishState.IDLE

func _ready() -> void:
	for i in range(10):
		walk_frames.append(load("res://Sprites/petal_walk/frame_%02d.png" % i))
	for i in range(10):
		rod_frames.append(load("res://Sprites/fishing_rod/frame_%02d.png" % i))

	background.texture = load(SUNNY_BG)
	PetCameo.spawn(%Petal)
	stroll_button.pressed.connect(_on_stroll)
	stroll_button.disabled = true
	status_label.text = "🌤️ Checking today's weather in Washington, DC..."

	fish_button.pressed.connect(_on_fish)

	http.request_completed.connect(_on_weather_response)
	var err := http.request(WEATHER_URL)
	if err != OK:
		_use_fallback()

	_apply_season_tint()

func _apply_season_tint() -> void:
	var month: int = Time.get_datetime_dict_from_system()["month"]
	var tint := Color(1, 1, 1)
	if month in [3, 4, 5]:
		tint = Color(0.95, 1.0, 0.93) # spring
	elif month in [6, 7, 8]:
		tint = Color(1.0, 0.98, 0.9) # summer
	elif month in [9, 10, 11]:
		tint = Color(1.0, 0.9, 0.78) # fall
	else:
		tint = Color(0.9, 0.95, 1.0) # winter
	background.modulate = tint

func _on_weather_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not is_instance_valid(self):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_use_fallback()
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("current_weather"):
		_use_fallback()
		return
	var current: Dictionary = parsed["current_weather"]
	var code := int(current.get("weathercode", 0))
	var temp = current.get("temperature", null)
	_apply_weather(code, temp)

func _apply_weather(code: int, temp) -> void:
	var temp_text := "%d°F" % int(round(temp)) if temp != null else ""
	if RAIN_CODES.has(code):
		is_raining = true
		background.texture = load(RAIN_BG)
		status_label.text = "🌧️ It's rainy in Washington, DC right now (%s)." % temp_text
	elif SNOW_CODES.has(code):
		is_raining = false
		background.texture = load(SNOW_BG)
		status_label.text = "❄️ It's snowing in Washington, DC right now (%s)." % temp_text
	else:
		is_raining = false
		background.texture = load(SUNNY_BG)
		status_label.text = "☀️ It's lovely in Washington, DC right now (%s)." % temp_text
	_refresh_stroll_button()

func _use_fallback() -> void:
	if not is_instance_valid(self):
		return
	is_raining = false
	background.texture = load(SUNNY_BG)
	status_label.text = "🌤️ Couldn't check today's weather - let's assume it's nice!"
	_refresh_stroll_button()

func _refresh_stroll_button() -> void:
	if is_raining:
		stroll_button.disabled = true
		stroll_button.text = "🌧️ Stay Inside"
		Feedback.pop(self, "🌧️ doesn't want wet paws!", %Petal.global_position + Vector2(20, -20))
	else:
		stroll_button.disabled = false
		stroll_button.text = "🌷 Stroll"

func _on_stroll() -> void:
	if is_raining or is_strolling:
		return
	is_strolling = true
	stroll_button.disabled = true

	await _walk_to(WALK_RIGHT_X)
	await _walk_to(WALK_LEFT_X)

	if not is_instance_valid(self):
		return
	PetalState.stroll()
	Feedback.pop(self, "🌼 lovely stroll!", stroll_button.global_position)
	stroll_button.disabled = is_raining
	is_strolling = false

func _on_fish() -> void:
	match fish_state:
		FishState.IDLE:
			_start_fishing()
		FishState.WAITING:
			Feedback.pop(self, "🎣 not yet...", fish_button.global_position)
		FishState.BITING:
			_catch_fish()
		FishState.SHOWING:
			_take_photo_with_fish()
		FishState.READY_TO_RELEASE:
			_release_fish()

func _play_rod_frames(frame_indices: Array, delay: float) -> void:
	for index in frame_indices:
		if not is_instance_valid(self):
			return
		rod_sprite.texture = rod_frames[index]
		await get_tree().create_timer(delay).timeout

func _start_fishing() -> void:
	fish_state = FishState.WAITING
	fish_button.disabled = true
	fish_button.text = "🎣 casting..."
	await _play_rod_frames([1, 2, 3, 4, 5], 0.08)
	if not is_instance_valid(self) or fish_state != FishState.WAITING:
		return
	fish_button.disabled = false
	fish_button.text = "🎣 waiting for a bite..."
	var wait_time := randf_range(FISH_MIN_WAIT, FISH_MAX_WAIT)
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(self) or fish_state != FishState.WAITING:
		return
	fish_state = FishState.BITING
	fish_button.text = "🐟 PULL BACK!"
	rod_sprite.texture = rod_frames[6]
	Feedback.pop(self, "🐟 bite!", fish_button.global_position)
	await get_tree().create_timer(FISH_BITE_WINDOW).timeout
	if not is_instance_valid(self) or fish_state != FishState.BITING:
		return
	fish_state = FishState.IDLE
	fish_button.text = "🎣 Fish"
	rod_sprite.texture = rod_frames[0]
	Feedback.pop(self, "the fish got away...", fish_button.global_position)

func _catch_fish() -> void:
	var caught: Dictionary = FISH_COLORS[randi() % FISH_COLORS.size()]
	fish_state = FishState.SHOWING
	fish_button.disabled = true
	fish_button.text = "🎣 reeling in..."
	await _play_rod_frames([7, 8, 9], 0.1)
	if not is_instance_valid(self):
		return
	rod_sprite.texture = rod_frames[0]
	fish_display.modulate = caught["color"]
	fish_display.visible = true
	fish_button.disabled = false
	fish_button.text = "📸 Take a Photo"
	PetalState.catch_fish()
	PetCameo.jump_for_joy(%Petal)
	Feedback.pop(self, "👀 a %s fish!" % caught["name"], fish_display.global_position)

func _take_photo_with_fish() -> void:
	fish_state = FishState.READY_TO_RELEASE
	fish_button.text = "🌊 Let It Go"
	PetalState.take_photo()
	Feedback.pop(self, "📸 say cheese!", fish_display.global_position)

func _release_fish() -> void:
	fish_state = FishState.IDLE
	fish_display.visible = false
	fish_button.text = "🎣 Fish"
	Feedback.pop(self, "🌊 back you go!", fish_button.global_position)

func _walk_to(target_x: float) -> void:
	var start_x: float = %Petal.position.x
	var steps := 14
	for i in range(steps):
		%Petal.texture = walk_frames[i % walk_frames.size()]
		%Petal.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		if start_x > target_x:
			%Petal.scale.x = -1.0
		else:
			%Petal.scale.x = 1.0
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(self):
			return
