extends Control

@onready var grid: GridContainer = %Grid
@onready var sub_label: Label = %SubLabel

var slots := {}

func _ready() -> void:
	for id in PetalState.STICKERS:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(150, 150)
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		panel.add_child(label)
		grid.add_child(panel)
		slots[id] = label

	PetalState.sticker_earned.connect(func(_id): _refresh())
	_refresh()

func _refresh() -> void:
	var count := 0
	for id in PetalState.STICKERS:
		var data: Dictionary = PetalState.STICKERS[id]
		var label: Label = slots[id]
		if PetalState.earned_stickers.get(id, false):
			label.text = "%s\n%s" % [data["emoji"], data["label"]]
			label.modulate = Color(1, 1, 1, 1)
			count += 1
		else:
			label.text = "❔\n???"
			label.modulate = Color(0.6, 0.6, 0.6, 1)
	sub_label.text = "%d / %d collected" % [count, PetalState.STICKERS.size()]
