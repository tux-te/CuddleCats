extends Node

# Care stats for Princess Petal. All stats are 0-100; 100 is best.
# Decay is slow and mood language stays gentle - this is a game for a
# 5-year-old, so nothing here should ever feel like "failing".

signal stats_changed
signal accessories_changed
signal play_animation_requested
signal bell_animation_requested
signal friend_changed
signal sticker_earned
signal navigate_to_room(room_id: String)
signal photo_taken
signal pet_changed
signal coins_changed
signal milestone_reached(total: int)

const MAX_STAT := 100.0
const DECAY_PER_SEC := 0.15

# Every playable pet: display name, sit pose, optional frame-based
# animations (walk/jump/sleep/dance/play - omitted if the pet doesn't have
# art for it yet, in which case PetCameo falls back to simple tweens), and
# her dress-up accessories (icon + overlay anchor, proportional to her
# TextureRect so it lands right no matter which room-sized box she's in).
# "exclusive_groups" lists accessory ids that can't be worn together (e.g.
# only one collar at a time) - toggling one off clears the rest.
const PETS := {
	"petal": {
		"name": "Princess Petal",
		"cutout": "res://Sprites/petal_cutout.png",
		"walk": {"path": "res://Sprites/petal_walk/frame_%02d.png", "count": 10},
		"jump": {"path": "res://Sprites/petal_jump/frame_%02d.png", "count": 5},
		"sleep": {"path": "res://Sprites/petal_sleep/frame_%02d.png", "count": 11},
		"dance": {"path": "res://Sprites/petal_dance/frame_%02d.png", "count": 10},
		"play": {"path": "res://Sprites/petal_play/frame_%02d.png", "count": 10},
		"blowdried": "res://Sprites/petal_blowdried.png",
		"accessories": {
			"bow": {"icon": "res://Sprites/bow.png", "anchor": {"l": 0.327, "t": 0.025, "r": 0.427, "b": 0.196}},
			"flower": {"icon": "res://Sprites/flower.png", "anchor": {"l": 0.573, "t": 0.025, "r": 0.673, "b": 0.196}},
			"sunglasses": {"icon": "res://Sprites/sunglasses.png", "anchor": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.491}},
			"scarf": {"icon": "res://Sprites/scarf.png", "anchor": {"l": 0.333, "t": 0.515, "r": 0.667, "b": 0.699}},
			"blush": {"icon": "res://Sprites/blush.png", "anchor": {"l": 0.28, "t": 0.32, "r": 0.72, "b": 0.5}},
			"mascara": {"icon": "res://Sprites/mascara.png", "anchor": {"l": 0.373, "t": 0.294, "r": 0.633, "b": 0.44}},
			"lipstick": {"icon": "res://Sprites/lipstick.png", "anchor": {"l": 0.40, "t": 0.44, "r": 0.60, "b": 0.52}},
		},
		"exclusive_groups": [],
	},
	"pompom": {
		"name": "Pompom",
		"cutout": "res://Sprites/pompom_cutout.png",
		"walk": {"path": "res://Sprites/pompom_walk/frame_%02d.png", "count": 11},
		"jump": {"path": "res://Sprites/pompom_jump/frame_%02d.png", "count": 7},
		"sleep": {"path": "res://Sprites/pompom_sleep/frame_%02d.png", "count": 10},
		"trick_come": {"path": "res://Sprites/pompom_come_trick/frame_%02d.png", "count": 9},
		"trick_wave": {"path": "res://Sprites/pompom_wave_trick/frame_%02d.png", "count": 6},
		"brush": {"path": "res://Sprites/pompom_brush/frame_%02d.png", "count": 10},
		"dance": {"path": "res://Sprites/pompom_dance/frame_%02d.png", "count": 12},
		"swim": {"path": "res://Sprites/pompom_swim/frame_%02d.png", "count": 16},
		"bath_comic": {"path": "res://Sprites/pompom_bath_comic/frame_%02d.png", "count": 14},
		"wave": "res://Sprites/pompom_wave.png",
		"sleep_still": "res://Sprites/pompom_sleep_pose.png",
		"come_still": "res://Sprites/pompom_come_pose.png",
		"accessories": {
			"blush": {"icon": "res://Sprites/blush.png", "anchor": {"l": 0.03, "t": 0.28, "r": 0.50, "b": 0.52}},
			"mascara": {"icon": "res://Sprites/mascara.png", "anchor": {"l": 0.06, "t": 0.26, "r": 0.40, "b": 0.38}},
			"lipstick": {"icon": "res://Sprites/lipstick.png", "anchor": {"l": 0.12, "t": 0.42, "r": 0.35, "b": 0.53}},
		},
		"exclusive_groups": [],
		"tricks": ["sit", "come", "wave"],
		"friends": ["coco", "biscuit"],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
		},
	},
	"sheila": {
		"name": "Sheila",
		"cutout": "res://Sprites/sheila_cutout.png",
		# Sheila shares Pompom's dog-themed rooms and collar wardrobe, but has
		# her own full set of frame animations (and a bath background just
		# for her - the tub art was drawn with her specifically in it).
		"walk": {"path": "res://Sprites/sheila_walk/frame_%02d.png", "count": 7},
		"jump": {"path": "res://Sprites/sheila_jump/frame_%02d.png", "count": 5},
		"sleep": {"path": "res://Sprites/sheila_sleep/frame_%02d.png", "count": 6},
		"dance": {"path": "res://Sprites/sheila_dance/frame_%02d.png", "count": 9},
		"trick_sit": {"path": "res://Sprites/sheila_sit_trick/frame_%02d.png", "count": 5},
		"trick_wave": {"path": "res://Sprites/sheila_wave_trick/frame_%02d.png", "count": 7},
		"swim": {"path": "res://Sprites/sheila_swim/frame_%02d.png", "count": 16},
		"brush": {"path": "res://Sprites/sheila_brush/frame_%02d.png", "count": 5},
		"accessories": {
			"collar_pink": {"icon": "res://Sprites/pompom_collars/pink.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}},
			"collar_lavender": {"icon": "res://Sprites/pompom_collars/lavender.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}},
			"collar_blue": {"icon": "res://Sprites/pompom_collars/blue.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}},
			"collar_green": {"icon": "res://Sprites/pompom_collars/green.png", "anchor": {"l": 0.15, "t": 0.56, "r": 0.85, "b": 0.82}},
		},
		"exclusive_groups": [["collar_pink", "collar_lavender", "collar_blue", "collar_green"]],
		"rooms": {
			"bedroom": "res://Sprites/backgrounds/pompom_bedroom.jpg",
			"bath": "res://Sprites/backgrounds/sheila_bath.jpg",
		},
		"tricks": ["sit", "come", "wave"],
		"friends": ["coco", "biscuit"],
	},
	"kiwi": {
		"name": "Kiwi",
		"cutout": "res://Sprites/kiwi_cutout.png",
		# Kiwi flies in instead of walking, and has a single flying hero
		# pose she strikes for Jump for Joy (no frames needed - see
		# PetCameo._bounce_tween, which checks for "jump_still").
		"walk": {"path": "res://Sprites/kiwi_walk/frame_%02d.png", "count": 5},
		"jump_still": "res://Sprites/kiwi_jump_pose.png",
		"trick_sing": {"path": "res://Sprites/kiwi_sing_trick/frame_%02d.png", "count": 6},
		"toy_bell": {"path": "res://Sprites/kiwi_bell_toy/frame_%02d.png", "count": 6},
		"play_still": "res://Sprites/lucy_and_kiwi.png",
		# A little illustrated comic of Lucy brushing her, shown instead of
		# the generic disembodied-hand brush animation (see room_grooming.gd).
		"brush": {"path": "res://Sprites/kiwi_brush/frame_%02d.png", "count": 8},
		"accessories": {},
		"exclusive_groups": [],
		"rooms": {
			"grooming": "res://Sprites/backgrounds/bird_grooming.jpg",
			"dressup": "res://Sprites/backgrounds/bird_dressup.jpg",
		},
		"tricks": ["sing"],
		"friends": ["raspberry"],
	},
}

var active_pet := "petal"

var pet_records := {}

func _init_pet_records() -> void:
	for id in PETS:
		var acc := {}
		for acc_id in PETS[id]["accessories"]:
			acc[acc_id] = false
		pet_records[id] = {
			"hunger": 80.0,
			"happiness": 80.0,
			"energy": 80.0,
			"cleanliness": 80.0,
			"accessories": acc,
		}

var pet_name: String:
	get: return PETS[active_pet]["name"]

func switch_pet(id: String) -> void:
	if not PETS.has(id) or id == active_pet:
		return
	active_pet = id
	pet_changed.emit()
	stats_changed.emit()
	accessories_changed.emit()

func has_anim(kind: String) -> bool:
	return PETS[active_pet].has(kind)

func anim_frames(kind: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not has_anim(kind):
		return frames
	var info: Dictionary = PETS[active_pet][kind]
	for i in range(int(info["count"])):
		frames.append(load(String(info["path"]) % i))
	return frames

func cutout_path() -> String:
	return String(PETS[active_pet]["cutout"])

func static_pose(key: String) -> String:
	return String(PETS[active_pet].get(key, PETS[active_pet]["cutout"]))

# Returns the active pet's background for this room if she has one
# generated, otherwise the room's own default (usually Petal's art).
func room_bg(room_id: String, default_path: String) -> String:
	var rooms: Dictionary = PETS[active_pet].get("rooms", {})
	return String(rooms.get(room_id, default_path))

const TRICK_INFO := {
	"sit": {"label": "Sit", "emoji": "🐾"},
	"come": {"label": "Come", "emoji": "👋"},
	"wave": {"label": "Wave", "emoji": "🖐️"},
	"sing": {"label": "Sing", "emoji": "🎵"},
}

func has_tricks() -> bool:
	return not tricks().is_empty()

func tricks() -> Array:
	return PETS[active_pet].get("tricks", [])

func do_trick(trick_id: String) -> void:
	if not tricks().has(trick_id):
		return
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("tricks")
	add_coins(3)

const FRIENDS := {
	"marigold": {"name": "Princess Marigold", "cutout": "res://Sprites/friend_cutout.png"},
	"blossom": {"name": "Princess Blossom", "cutout": "res://Sprites/friend_blossom.png"},
	"iris": {"name": "Princess Iris", "cutout": "res://Sprites/friend_iris.png"},
	"lily": {"name": "Princess Lily", "cutout": "res://Sprites/friend_lily.png"},
	"biscuit": {"name": "Biscuit", "cutout": "res://Sprites/friend_biscuit.png"},
	"coco": {"name": "Coco", "cutout": "res://Sprites/friend_coco.png"},
	"raspberry": {"name": "Raspberry", "cutout": "res://Sprites/friend_raspberry.png"},
}
const DEFAULT_FRIEND_OPTIONS: Array[String] = ["marigold", "blossom", "iris", "lily"]
var visiting_friend := ""

# The active pet's own circle of friends (dogs only know other dogs, etc.) -
# falls back to the default princess friends for pets that don't set one.
func friend_options() -> Array[String]:
	var options: Array = PETS[active_pet].get("friends", DEFAULT_FRIEND_OPTIONS)
	var typed: Array[String] = []
	for id in options:
		typed.append(String(id))
	return typed

var hunger: float:
	get: return pet_records[active_pet]["hunger"]
	set(value): pet_records[active_pet]["hunger"] = value

var happiness: float:
	get: return pet_records[active_pet]["happiness"]
	set(value): pet_records[active_pet]["happiness"] = value

var energy: float:
	get: return pet_records[active_pet]["energy"]
	set(value): pet_records[active_pet]["energy"] = value

var cleanliness: float:
	get: return pet_records[active_pet]["cleanliness"]
	set(value): pet_records[active_pet]["cleanliness"] = value

# Dress-up accessories the active pet can wear, toggled from the Dress-Up
# Room. This returns the live per-pet dictionary (Dictionaries are
# reference types in GDScript), so existing code that mutates
# PetalState.accessories[id] directly keeps working unchanged.
var accessories: Dictionary:
	get: return pet_records[active_pet]["accessories"]

# Sticker Book: id -> {emoji, label}. Earned the first time you do the
# matching activity; "earned" tracks which ids have been unlocked.
const STICKERS := {
	"feed": {"emoji": "🍓", "label": "Snack Time"},
	"play": {"emoji": "🧶", "label": "Playtime"},
	"pet": {"emoji": "🥰", "label": "Best Friends"},
	"cuddle": {"emoji": "💞", "label": "Cozy Cuddles"},
	"bathe": {"emoji": "🛁", "label": "Bath Time"},
	"brush": {"emoji": "✨", "label": "Brushed & Fluffy"},
	"nap": {"emoji": "😴", "label": "Sweet Dreams"},
	"stroll": {"emoji": "🌷", "label": "Garden Stroll"},
	"obstacle": {"emoji": "🏆", "label": "Champion"},
	"friend": {"emoji": "🐾", "label": "Good Friends"},
	"photo": {"emoji": "📸", "label": "Say Cheese"},
	"party": {"emoji": "🎉", "label": "Party Time"},
	"fish": {"emoji": "🐟", "label": "Fisher"},
	"tricks": {"emoji": "🎾", "label": "Good Trick!"},
	"catch": {"emoji": "🍬", "label": "Treat Catcher"},
	"bell": {"emoji": "🔔", "label": "Jingle Bells"},
	"swim": {"emoji": "🏊", "label": "Splash Time"},
}
var earned_stickers := {}

# Photo Book: snapshots taken in the Photo Booth, newest last. Capped so
# the game doesn't hoard an unbounded number of full-screen textures.
const MAX_PHOTOS := 12
var photos: Array[Texture2D] = []

func award_sticker(id: String) -> void:
	if not STICKERS.has(id) or earned_stickers.get(id, false):
		return
	earned_stickers[id] = true
	sticker_earned.emit(id)
	add_coins(10)

# Treat Coins: a simple, gentle reward currency. Every bit of care earns a
# few, with a bigger crate every MILESTONE_STEP coins - just a fun "ding!"
# moment, never anything a 5-year-old could fail to reach.
const MILESTONE_STEP := 50
var coins := 0

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	var before := coins
	coins += amount
	coins_changed.emit()
	if coins / MILESTONE_STEP > before / MILESTONE_STEP:
		milestone_reached.emit(coins)

func _ready() -> void:
	_init_pet_records()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)

	# Web export has no OS font fallback for emoji glyphs used throughout the
	# UI, so append a dedicated emoji font to the default font's fallback
	# chain rather than replacing it (replacing it broke normal text).
	var emoji_font: Font = load("res://fonts/TwemojiMozilla.ttf")
	ThemeDB.fallback_font.fallbacks = [emoji_font]

func _on_tick() -> void:
	hunger = maxf(0.0, hunger - DECAY_PER_SEC)
	happiness = maxf(0.0, happiness - DECAY_PER_SEC * 0.7)
	energy = maxf(0.0, energy - DECAY_PER_SEC * 0.5)
	cleanliness = maxf(0.0, cleanliness - DECAY_PER_SEC * 0.3)
	stats_changed.emit()

func feed() -> void:
	hunger = minf(MAX_STAT, hunger + 25.0)
	happiness = minf(MAX_STAT, happiness + 5.0)
	stats_changed.emit()
	award_sticker("feed")
	add_coins(3)

func play() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	cleanliness = maxf(0.0, cleanliness - 5.0)
	stats_changed.emit()
	award_sticker("play")
	add_coins(4)

func pet_her() -> void:
	happiness = minf(MAX_STAT, happiness + 12.0)
	stats_changed.emit()
	award_sticker("pet")
	add_coins(1)

func pet_friend() -> void:
	happiness = minf(MAX_STAT, happiness + 8.0)
	stats_changed.emit()
	add_coins(1)

func cuddle() -> void:
	happiness = minf(MAX_STAT, happiness + 18.0)
	energy = minf(MAX_STAT, energy + 5.0)
	stats_changed.emit()
	award_sticker("cuddle")
	add_coins(3)

func bathe() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 30.0)
	happiness = minf(MAX_STAT, happiness + 5.0)
	stats_changed.emit()
	award_sticker("bathe")
	add_coins(5)

func brush() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 15.0)
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("brush")
	add_coins(4)

func nap() -> void:
	energy = minf(MAX_STAT, energy + 35.0)
	stats_changed.emit()
	award_sticker("nap")
	add_coins(3)

func stroll() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	stats_changed.emit()
	award_sticker("stroll")
	add_coins(4)

func obstacle_course() -> void:
	happiness = minf(MAX_STAT, happiness + 25.0)
	energy = maxf(0.0, energy - 15.0)
	cleanliness = maxf(0.0, cleanliness - 8.0)
	stats_changed.emit()
	award_sticker("obstacle")
	add_coins(5)

func take_photo(snapshot: Texture2D) -> void:
	photos.append(snapshot)
	if photos.size() > MAX_PHOTOS:
		photos.pop_front()
	photo_taken.emit()
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("photo")
	add_coins(3)

func celebrate_party() -> void:
	happiness = MAX_STAT
	stats_changed.emit()
	award_sticker("party")
	add_coins(6)

func catch_fish() -> void:
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("fish")
	add_coins(5)

func catch_treat() -> void:
	happiness = minf(MAX_STAT, happiness + 3.0)
	stats_changed.emit()
	award_sticker("catch")
	add_coins(2)

func has_bell_toy() -> bool:
	return PETS[active_pet].has("toy_bell")

func go_swimming() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	cleanliness = maxf(0.0, cleanliness - 10.0)
	stats_changed.emit()
	award_sticker("swim")
	add_coins(5)

func ring_bell() -> void:
	happiness = minf(MAX_STAT, happiness + 15.0)
	stats_changed.emit()
	award_sticker("bell")
	add_coins(3)
	bell_animation_requested.emit()

func invite_friend(id: String) -> void:
	visiting_friend = id
	happiness = minf(MAX_STAT, happiness + 20.0)
	award_sticker("friend")
	add_coins(4)
	stats_changed.emit()
	friend_changed.emit()

func say_bye_to_friend() -> void:
	visiting_friend = ""
	friend_changed.emit()

func toggle_accessory(id: String) -> void:
	if not accessories.has(id):
		return
	var turning_on: bool = not accessories[id]
	if turning_on:
		for group in PETS[active_pet]["exclusive_groups"]:
			if group.has(id):
				for sibling in group:
					accessories[sibling] = false
	accessories[id] = turning_on
	happiness = minf(MAX_STAT, happiness + 3.0)
	accessories_changed.emit()
	stats_changed.emit()

const MAKEUP_IDS := ["blush", "mascara", "lipstick"]

func remove_all_makeup() -> void:
	for id in MAKEUP_IDS:
		if accessories.has(id):
			accessories[id] = false
	accessories_changed.emit()

func mood() -> String:
	var avg := (hunger + happiness + energy + cleanliness) / 4.0
	if avg >= 80.0:
		return "%s feels radiant!" % pet_name
	elif avg >= 55.0:
		return "%s is doing okay." % pet_name
	elif avg >= 30.0:
		return "%s could use some care." % pet_name
	else:
		return "%s really needs you!" % pet_name
