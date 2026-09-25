extends RefCounted

# Procedural confetti burst - no art assets needed, just a handful of
# colored squares that pop outward and tumble down before fading. Used
# for stickers, coin milestones, and other "yay!" moments.

const COLORS := [
	Color(1.0, 0.55, 0.7),
	Color(1.0, 0.8, 0.3),
	Color(0.55, 0.85, 1.0),
	Color(0.7, 1.0, 0.6),
	Color(0.85, 0.6, 1.0),
]

static func burst(parent: Control, at: Vector2, count: int = 18) -> void:
	if not is_instance_valid(parent):
		return
	for _i in range(count):
		var piece := ColorRect.new()
		piece.color = COLORS[randi() % COLORS.size()]
		piece.size = Vector2(randf_range(6.0, 12.0), randf_range(6.0, 12.0))
		piece.position = at - piece.size / 2.0
		piece.z_index = 20
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.pivot_offset = piece.size / 2.0
		parent.add_child(piece)

		var angle := randf_range(0.0, TAU)
		var dist := randf_range(60.0, 160.0)
		var target := at + Vector2(cos(angle), sin(angle) * 0.6 - 0.4) * dist

		var tween := parent.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", target - piece.size / 2.0, randf_range(0.5, 0.8)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "rotation_degrees", randf_range(-360.0, 360.0), randf_range(0.5, 0.8))
		tween.chain().tween_property(piece, "position:y", target.y - piece.size.y / 2.0 + 90.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(piece, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(piece.queue_free)
