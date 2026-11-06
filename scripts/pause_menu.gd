extends Control
## Esc menu during a fight or the tutorial: RESUME, MAIN MENU, QUIT.
## Pauses the whole game while it is open. Esc again resumes.
## Emits chose(index) when MAIN MENU (1) or QUIT (2) is picked; main.gd reacts.

const Pal = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal chose(index: int)
signal toggled(paused: bool)   # main.gd pauses / resumes the music with this

const ITEMS := ["RESUME", "MAIN MENU", "QUIT"]

var index := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused


func open() -> void:
	index = 0
	visible = true
	get_tree().paused = true
	toggled.emit(true)
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	toggled.emit(false)


func _activate(i: int) -> void:
	Sfx.play("select")
	if i == 0:
		close()
	else:
		chose.emit(i)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		close()
	elif k == KEY_UP or k == KEY_W:
		index = (index + ITEMS.size() - 1) % ITEMS.size()
		Sfx.play("select")
	elif k == KEY_DOWN or k == KEY_S:
		index = (index + 1) % ITEMS.size()
		Sfx.play("select")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_activate(index)
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	var rect := Rect2(cx - 280.0, 170.0, 560.0, 380.0)
	UiPanel.tilt(self, rect.get_center())
	UiPanel.panel(self, rect, Pal.RED)
	UiPanel.tag(self, Vector2(rect.position.x + 24.0, rect.position.y - 34.0), "PAUSED", 34)
	var font := get_theme_default_font()
	for i in ITEMS.size():
		var cy := 260.0 + i * 96.0
		var selected := i == index
		if selected:
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 220.0, cy - 36.0), Vector2(cx + 230.0, cy - 42.0),
				Vector2(cx + 210.0, cy + 36.0), Vector2(cx - 240.0, cy + 42.0)]), Pal.PAPER)
		var ink := Pal.INK if selected else Pal.PAPER
		var fs := 50
		var baseline := cy + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(cx - 250.0, baseline), ITEMS[i], HORIZONTAL_ALIGNMENT_CENTER, 500.0, fs, ink)
