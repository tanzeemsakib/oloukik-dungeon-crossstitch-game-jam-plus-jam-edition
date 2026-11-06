extends Control
## Static background: dark, with thin slanted white bars down the screen edges. Drawn once (no per-frame
## cost). Sits behind everything.

const Pal = preload("res://scripts/palette.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Pal.DEEP, true)

	# Slanted white bars along both edges.
	var white := Color(Pal.PAPER, 0.9)
	draw_colored_polygon(PackedVector2Array([
		Vector2(46, 0), Vector2(62, 0), Vector2(16, size.y), Vector2(0, size.y)]), white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x - 46, 0), Vector2(size.x - 62, 0), Vector2(size.x - 16, size.y), Vector2(size.x, size.y)]), white)
