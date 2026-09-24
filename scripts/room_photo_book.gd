extends Control

@onready var grid: GridContainer = %Grid
@onready var sub_label: Label = %SubLabel
@onready var empty_label: Label = %EmptyLabel

func _ready() -> void:
	PetalState.photo_taken.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	for photo in PetalState.photos:
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(270, 170)
		rect.texture = photo
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		grid.add_child(rect)

	sub_label.text = "%d photo%s" % [PetalState.photos.size(), "" if PetalState.photos.size() == 1 else "s"]
	empty_label.visible = PetalState.photos.is_empty()
