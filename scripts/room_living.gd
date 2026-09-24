extends Control

const Feedback = preload("res://scripts/room_feedback.gd")
const PetCameo = preload("res://scripts/pet_cameo.gd")

@onready var background: TextureRect = %Background

var friend_busy := false

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
	%MarigoldButton.pressed.connect(_on_friend_chosen.bind("marigold"))
	%BlossomButton.pressed.connect(_on_friend_chosen.bind("blossom"))
	%IrisButton.pressed.connect(_on_friend_chosen.bind("iris"))
	%LilyButton.pressed.connect(_on_friend_chosen.bind("lily"))
	_refresh_friend()

	var idle_timer := Timer.new()
	idle_timer.wait_time = 3.5
	idle_timer.autostart = true
	idle_timer.timeout.connect(_on_friend_idle_tick)
	add_child(idle_timer)

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

func _on_invite() -> void:
	if PetalState.visiting_friend != "":
		PetalState.say_bye_to_friend()
		_refresh_friend()
		Feedback.pop(self, "bye bye!", %InviteButton.global_position)
	else:
		%FriendPicker.visible = true
		%InviteButton.disabled = true

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
