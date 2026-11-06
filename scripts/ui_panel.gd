extends RefCounted
## Persona-style drawing helpers for overlays. Call these from inside a
## Control's _draw():
##
##   const UiPanel = preload("res://scripts/ui_panel.gd")
##   UiPanel.panel(self, Rect2(x, y, w, h), accent_color)
##   UiPanel.tag(self, Vector2(x, y), "TITLE", 32, Pal.PAPER, Pal.INK)
##
## panel: a jagged black shape with a thick white edge and a colored shadow.
## tag:   a slanted bar (white by default) with text, sat on the panel's top edge.

const Pal = preload("res://scripts/palette.gd")
const BLACK := Pal.INK
const TILT := -0.025   # about -1.4 degrees: the slight Persona lean


static func tilt(ci: Control, pivot: Vector2, angle: float = TILT) -> void:
	# Call first thing in _draw(). Everything drawn afterwards (panel, tag, text)
	# leans by `angle` around `pivot`.
	ci.draw_set_transform(pivot - pivot.rotated(angle), angle, Vector2.ONE)


static func panel(ci: Control, rect: Rect2, accent: Color = Pal.RED) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	# Skewed corners so it never looks like a plain rectangle.
	var shape := PackedVector2Array([
		Vector2(x + 30.0, y),
		Vector2(x + w, y + 18.0),
		Vector2(x + w - 30.0, y + h),
		Vector2(x, y + h - 18.0),
	])

	# Colored shadow, offset down and to the right.
	var shadow := PackedVector2Array()
	for p in shape:
		shadow.append(p + Vector2(16.0, 14.0))
	ci.draw_colored_polygon(shadow, accent)

	# White edge: the same shape grown outward, then the black fill on top.
	var edges := Geometry2D.offset_polygon(shape, 7.0, Geometry2D.JOIN_MITER)
	if not edges.is_empty():
		ci.draw_colored_polygon(edges[0], Pal.PAPER)
	ci.draw_colored_polygon(shape, BLACK)


static func tag(ci: Control, pos: Vector2, text: String, font_size: int, fill: Color = Pal.PAPER, ink: Color = Pal.INK) -> void:
	var font := ci.get_theme_default_font()
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pad := 34.0
	var w := text_w + pad * 2.0
	var h := font_size * 1.35
	var shape := PackedVector2Array([
		Vector2(pos.x + 16.0, pos.y),
		Vector2(pos.x + w, pos.y - 7.0),
		Vector2(pos.x + w - 16.0, pos.y + h),
		Vector2(pos.x, pos.y + h + 7.0),
	])
	var rim := Geometry2D.offset_polygon(shape, 4.0, Geometry2D.JOIN_MITER)
	if not rim.is_empty():
		ci.draw_colored_polygon(rim[0], BLACK)
	ci.draw_colored_polygon(shape, fill)
	var baseline := pos.y + h * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	ci.draw_string(font, Vector2(pos.x + pad, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
