extends Control
## Death / win screen: a tilted black panel with a white edge, a tag and a big
## title, drawn over the fight (no full-screen dim).
## Set title / note / win, then show it.

const Pal = preload("res://scripts/palette.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

var title := ""
var note := ""
var win := false
var _t := 0.0


func show_result(is_win: bool, title_text: String, note_text: String) -> void:
	win = is_win
	title = title_text
	note = note_text
	_t = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var accent := Pal.GREEN if win else Pal.RED
	var cx := size.x * 0.5
	var panel_rect := Rect2(cx - 460.0, 170.0, 920.0, 380.0)
	UiPanel.tilt(self, panel_rect.get_center())
	UiPanel.panel(self, panel_rect, accent)
	UiPanel.tag(self, Vector2(panel_rect.position.x + 24.0, panel_rect.position.y - 34.0),
			"RUN CLEARED" if win else "GAME OVER", 32,
			accent if win else Pal.PAPER, Pal.INK)

	# Big title, with a tiny shake on a death.
	var shake := Vector2.ZERO if win else Vector2(sin(_t * 47.0), cos(_t * 39.0)) * 1.5
	var font := get_theme_default_font()
	var fs := 110
	_text(font, Vector2(cx, 270.0) + shake + Vector2(5.0, 5.0), title, fs, accent)
	_text(font, Vector2(cx, 270.0) + shake, title, fs, Pal.PAPER)

	if note != "":
		var y := 360.0
		for line in note.split("\n"):
			_text(font, Vector2(cx, y), line, 28, Color(Pal.PAPER, 0.9))
			y += 40.0

	# Prompts at the bottom edge of the panel.
	_text(font, Vector2(cx, 495.0), "ONE MORE TIME  [ENTER]", 38, Pal.PAPER)
	_text(font, Vector2(cx, 535.0 - 2.0), "CHANGE PLAYERS  [ESC]", 24, Color(Pal.PAPER, 0.6))


func _text(font: Font, center: Vector2, text: String, fs: int, col: Color) -> void:
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - 450.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, 900.0, fs, col)
