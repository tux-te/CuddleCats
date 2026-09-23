extends Node

# Care stats for Princess Petal. All stats are 0-100; 100 is best.
# Decay is slow and mood language stays gentle - this is a game for a
# 5-year-old, so nothing here should ever feel like "failing".

signal stats_changed
signal accessories_changed
signal play_animation_requested
signal friend_changed
signal sticker_earned

const MAX_STAT := 100.0
const DECAY_PER_SEC := 0.15

var pet_name := "Princess Petal"
var friend_name := "Princess Marigold"
var friend_visiting := false
var hunger := 80.0
var happiness := 80.0
var energy := 80.0
var cleanliness := 80.0

# Dress-up accessories Petal can wear, toggled from the Dress-Up Room.
var accessories := {
	"bow": false,
	"flower": false,
	"sunglasses": false,
	"scarf": false,
}

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
}
var earned_stickers := {}

func award_sticker(id: String) -> void:
	if not STICKERS.has(id) or earned_stickers.get(id, false):
		return
	earned_stickers[id] = true
	sticker_earned.emit(id)

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)

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

func play() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	cleanliness = maxf(0.0, cleanliness - 5.0)
	stats_changed.emit()
	award_sticker("play")

func pet_her() -> void:
	happiness = minf(MAX_STAT, happiness + 12.0)
	stats_changed.emit()
	award_sticker("pet")

func cuddle() -> void:
	happiness = minf(MAX_STAT, happiness + 18.0)
	energy = minf(MAX_STAT, energy + 5.0)
	stats_changed.emit()
	award_sticker("cuddle")

func bathe() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 30.0)
	happiness = minf(MAX_STAT, happiness + 5.0)
	stats_changed.emit()
	award_sticker("bathe")

func brush() -> void:
	cleanliness = minf(MAX_STAT, cleanliness + 15.0)
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("brush")

func nap() -> void:
	energy = minf(MAX_STAT, energy + 35.0)
	stats_changed.emit()
	award_sticker("nap")

func stroll() -> void:
	happiness = minf(MAX_STAT, happiness + 20.0)
	energy = maxf(0.0, energy - 10.0)
	stats_changed.emit()
	award_sticker("stroll")

func obstacle_course() -> void:
	happiness = minf(MAX_STAT, happiness + 25.0)
	energy = maxf(0.0, energy - 15.0)
	cleanliness = maxf(0.0, cleanliness - 8.0)
	stats_changed.emit()
	award_sticker("obstacle")

func take_photo() -> void:
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("photo")

func celebrate_party() -> void:
	happiness = MAX_STAT
	stats_changed.emit()
	award_sticker("party")

func catch_fish() -> void:
	happiness = minf(MAX_STAT, happiness + 10.0)
	stats_changed.emit()
	award_sticker("fish")

func toggle_friend_visit() -> void:
	friend_visiting = not friend_visiting
	if friend_visiting:
		happiness = minf(MAX_STAT, happiness + 20.0)
		award_sticker("friend")
	stats_changed.emit()
	friend_changed.emit()

func toggle_accessory(id: String) -> void:
	if not accessories.has(id):
		return
	accessories[id] = not accessories[id]
	happiness = minf(MAX_STAT, happiness + 3.0)
	accessories_changed.emit()
	stats_changed.emit()

func mood() -> String:
	var avg := (hunger + happiness + energy + cleanliness) / 4.0
	if avg >= 80.0:
		return "Princess Petal feels radiant!"
	elif avg >= 55.0:
		return "Princess Petal is doing okay."
	elif avg >= 30.0:
		return "Princess Petal could use some care."
	else:
		return "Princess Petal really needs you!"
