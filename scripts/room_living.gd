extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")
const Confetti = preload("res://scripts/confetti.gd")
const Sfx = preload("res://scripts/sfx.gd")

const TREAT_EMOJIS := ["🍬", "🍪", "🧁", "🍓", "🍩"]
const TREAT_GAME_SECONDS := 16.0
const TREAT_SPAWN_EVERY := 0.85
const TREAT_FALL_SPEED := 140.0

@onready var background: TextureRect = %Background

var friend_busy := false

var treat_overlay: Control = null
var treat_score := 0
var treat_time_left := 0.0
var treat_spawn_countdown := 0.0
var treat_game_active := false
var active_treats: Array[Label] = []

func _ready() -> void:
	background.texture = load("res://Sprites/backgrounds/living_room.jpg")
	PetCameo.spawn(%Petal)
	%FeedButton.pressed.connect(_on_feed)
	%PlayButton.pressed.connect(_on_play)
	%PlayButton.icon = load("res://Sprites/toy_wand.png")
	%PlayButton.expand_icon = true
	%PlayButton.add_theme_constant_override("icon_max_width", 36)
	%FeedButton.expand_icon = true
	%FeedButton.add_theme_constant_override("icon_max_width", 36)

	PetalState.stats_changed.connect(_update_food_icon)
	_update_food_icon()

	%Friend.mouse_filter = Control.MOUSE_FILTER_STOP
	%Friend.gui_input.connect(_on_friend_input)
	%InviteButton.pressed.connect(_on_invite)
	_setup_friend_buttons()
	_refresh_friend()

	var idle_timer := Timer.new()
	idle_timer.wait_time = 3.5
	idle_timer.autostart = true
	idle_timer.timeout.connect(_on_friend_idle_tick)
	add_child(idle_timer)

	%TricksButton.visible = PetalState.has_tricks()
	%TricksButton.pressed.connect(_on_tricks_pressed)
	%SitTrickButton.visible = PetalState.tricks().has("sit")
	%SitTrickButton.pressed.connect(_on_trick_chosen.bind("sit"))
	%ComeTrickButton.visible = PetalState.tricks().has("come")
	%ComeTrickButton.pressed.connect(_on_trick_chosen.bind("come"))
	%WaveTrickButton.visible = PetalState.tricks().has("wave")
	%WaveTrickButton.pressed.connect(_on_trick_chosen.bind("wave"))
	%SingTrickButton.visible = PetalState.tricks().has("sing")
	%SingTrickButton.pressed.connect(_on_trick_chosen.bind("sing"))

	%TreatCatchButton.pressed.connect(_start_treat_catch)

	%BellButton.visible = PetalState.has_bell_toy()
	%BellButton.pressed.connect(_on_bell)

func _process(delta: float) -> void:
	if not treat_game_active:
		return
	treat_time_left -= delta
	for treat in active_treats.duplicate():
		if not is_instance_valid(treat):
			active_treats.erase(treat)
			continue
		treat.position.y += TREAT_FALL_SPEED * delta
		if treat.position.y > size.y:
			active_treats.erase(treat)
			treat.queue_free()

	if treat_time_left > 0.0:
		treat_spawn_countdown -= delta
		if treat_spawn_countdown <= 0.0:
			treat_spawn_countdown = TREAT_SPAWN_EVERY
			_spawn_treat()
	elif active_treats.is_empty():
		_finish_treat_catch()

func _start_treat_catch() -> void:
	if treat_game_active:
		return
	treat_game_active = true
	treat_score = 0
	treat_time_left = TREAT_GAME_SECONDS
	treat_spawn_countdown = 0.0
	active_treats.clear()
	%TreatCatchButton.disabled = true

	treat_overlay = Control.new()
	treat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	treat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(treat_overlay)

	var title := Label.new()
	title.text = "🍬 Catch the treats!"
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(20, 70)
	treat_overlay.add_child(title)

	Feedback.pop(self, "🍬 tap the treats before they land!", %TreatCatchButton.global_position + Vector2(0, -20))

func _spawn_treat() -> void:
	if not is_instance_valid(treat_overlay):
		return
	var treat := Label.new()
	treat.text = TREAT_EMOJIS.pick_random()
	treat.add_theme_font_size_override("font_size", 40)
	treat.mouse_filter = Control.MOUSE_FILTER_STOP
	treat.position = Vector2(randf_range(20.0, maxf(40.0, size.x - 60.0)), -40.0)
	treat.gui_input.connect(_on_treat_input.bind(treat))
	treat_overlay.add_child(treat)
	active_treats.append(treat)

func _on_treat_input(event: InputEvent, treat: Label) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if not (is_click or is_touch) or not is_instance_valid(treat):
		return
	active_treats.erase(treat)
	treat_score += 1
	PetalState.catch_treat()
	Sfx.pop(self)
	Confetti.burst(treat_overlay, treat.position, 6)
	Feedback.pop(self, "✨ yum!", treat.position)
	treat.queue_free()

func _finish_treat_catch() -> void:
	treat_game_active = false
	%TreatCatchButton.disabled = false
	if not is_instance_valid(treat_overlay):
		return

	var result := Label.new()
	result.text = "🎉 You caught %d treat%s!" % [treat_score, "" if treat_score == 1 else "s"]
	result.add_theme_font_size_override("font_size", 26)
	result.position = Vector2(20, 130)
	treat_overlay.add_child(result)

	if treat_score >= 5:
		Sfx.fanfare(self)
		Confetti.burst(treat_overlay, Vector2(size.x / 2.0, size.y / 2.0), 24)

	var close_button := Button.new()
	close_button.text = "✅ Done"
	close_button.custom_minimum_size = Vector2(140, 60)
	close_button.position = Vector2(20, 180)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_close_treat_catch)
	treat_overlay.add_child(close_button)

func _close_treat_catch() -> void:
	if is_instance_valid(treat_overlay):
		treat_overlay.queue_free()
	treat_overlay = null
	active_treats.clear()

func _update_food_icon() -> void:
	var level := _hunger_level()
	var bowl_texture := load("res://Sprites/food_bowl/level_%d.png" % level)
	%FeedButton.icon = bowl_texture
	%FoodBowl.texture = bowl_texture

func _hunger_level() -> int:
	var h := PetalState.hunger
	if h >= 80.0:
		return 1
	elif h >= 60.0:
		return 2
	elif h >= 40.0:
		return 3
	elif h >= 20.0:
		return 4
	else:
		return 5

func _on_feed() -> void:
	PetalState.feed()
	Feedback.pop(self, "🍓 yum!", %FeedButton.global_position)

func _on_play() -> void:
	PetalState.play()
	PetalState.play_animation_requested.emit()
	Feedback.pop(self, "🎉 wheee!", %PlayButton.global_position)
	if PetalState.visiting_friend != "":
		_play_with_friend()

func _on_bell() -> void:
	PetalState.ring_bell()
	Feedback.pop(self, "🔔 jingle jingle!", %BellButton.global_position)

func _on_invite() -> void:
	if PetalState.visiting_friend != "":
		PetalState.say_bye_to_friend()
		_refresh_friend()
		Feedback.pop(self, "bye bye!", %InviteButton.global_position)
	else:
		%FriendPicker.visible = true
		%InviteButton.disabled = true

func _setup_friend_buttons() -> void:
	var buttons: Array[TextureButton] = [%MarigoldButton, %BlossomButton, %IrisButton, %LilyButton]
	var options := PetalState.friend_options()
	for i in range(buttons.size()):
		var btn := buttons[i]
		if i < options.size():
			var id := options[i]
			btn.visible = true
			btn.texture_normal = load(PetalState.FRIENDS[id]["cutout"])
			btn.pressed.connect(_on_friend_chosen.bind(id))
		else:
			btn.visible = false

func _on_friend_chosen(id: String) -> void:
	%FriendPicker.visible = false
	%InviteButton.disabled = false
	PetalState.invite_friend(id)
	_refresh_friend()
	Feedback.pop(self, "🐾 %s is here!" % PetalState.FRIENDS[id]["name"], %InviteButton.global_position)

func _refresh_friend() -> void:
	var visiting: String = PetalState.visiting_friend
	%InviteButton.text = "👋 Say Bye" if visiting != "" else "🐾 Invite Over"
	if visiting == "":
		%Friend.visible = false
		return
	%Friend.texture = load(PetalState.FRIENDS[visiting]["cutout"])
	_walk_in_friend()

func _walk_in_friend() -> void:
	%Friend.visible = true
	%Friend.modulate.a = 1.0
	%Friend.scale = Vector2.ONE
	%Friend.pivot_offset = %Friend.size / 2.0

	var target_x: float = %Friend.position.x
	var start_x: float = target_x + 160.0
	%Friend.position.x = start_x

	friend_busy = true
	var steps := 16
	for i in range(steps):
		if not is_instance_valid(%Friend):
			return
		%Friend.position.x = lerp(start_x, target_x, float(i + 1) / float(steps))
		await get_tree().create_timer(0.05).timeout
	if is_instance_valid(%Friend):
		%Friend.position.x = target_x
	friend_busy = false

func _on_friend_input(event: InputEvent) -> void:
	if friend_busy:
		return
	var is_click: bool = event is InputEventMouseButton and event.pressed
	var is_touch: bool = event is InputEventScreenTouch and event.pressed
	if is_click or is_touch:
		PetalState.pet_friend()
		Feedback.pop(self, ["💕", "🥰 purr~", "😻"].pick_random(), %Friend.global_position + Vector2(60, 20))
		_bounce_friend()

func _bounce_friend() -> void:
	%Friend.pivot_offset = %Friend.size / 2.0
	var tween := create_tween()
	tween.tween_property(%Friend, "scale", Vector2(1.12, 0.9), 0.08)
	tween.tween_property(%Friend, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC)

# Small periodic hop so the friend doesn't just stand frozen between
# interactions - skipped while she's mid walk-in or mid play-together.
func _on_friend_idle_tick() -> void:
	if not %Friend.visible or friend_busy:
		return
	_hop(%Friend, 1, 14.0)

func _play_with_friend() -> void:
	if friend_busy:
		return
	friend_busy = true
	PetalState.pet_friend()
	Feedback.pop(self, "🐾 playing together!", %Friend.global_position + Vector2(20, -20))
	await _hop(%Friend, 3, 24.0)
	friend_busy = false

# Bounces a node up and back down `times`, returning once finished.
func _hop(node: TextureRect, times: int, height: float) -> void:
	node.pivot_offset = node.size / 2.0
	var base_y: float = node.position.y
	for _i in range(times):
		if not is_instance_valid(node):
			return
		var tween := create_tween()
		tween.tween_property(node, "position:y", base_y - height, 0.15).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "position:y", base_y, 0.15).set_trans(Tween.TRANS_BOUNCE)
		await tween.finished

func _on_tricks_pressed() -> void:
	%TrickPicker.visible = not %TrickPicker.visible

func _on_trick_chosen(trick_id: String) -> void:
	%TrickPicker.visible = false
	PetalState.do_trick(trick_id)
	var info: Dictionary = PetalState.TRICK_INFO[trick_id]
	Feedback.pop(self, "%s good %s!" % [info["emoji"], info["label"].to_lower()], %TricksButton.global_position)
	await PetCameo.perform_trick(%Petal, trick_id)
