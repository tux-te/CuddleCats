extends RefCounted

# Shared "nice job!" popup used by every room so a 5-year-old gets
# instant, readable feedback with no numbers to read.

static func pop(parent: Control, text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.position = at
	label.z_index = 10
	parent.add_child(label)

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", at.y - 40.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)
