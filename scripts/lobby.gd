extends Control
## Start screen. Step 1: how many players (press 1, 2 or 3).
## Step 2 (2 or 3 players): each player in turn picks a role with their own keys.
##   - With 2 players the role nobody picked is SHARED: either player can play it.
##   - With 3 players the last player gets the one role left.
## Emits started(player_count, roles). roles[p] = ring index (0 Attack, 1 Defend,
## 2 Focus) chosen by player p. For 1 player roles is empty (solo plays all rings).

const Pal = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx.gd")
const UiPanel = preload("res://scripts/ui_panel.gd")

signal started(player_count: int, roles: Array)

const ROLES := [
	{"name": "ARCHER", "ring": "ATTACK", "color": Pal.RED},
	{"name": "PALADIN", "ring": "DEFEND", "color": Pal.GREEN},
	{"name": "BARD", "ring": "FOCUS", "color": Pal.BLUE},
]
const COUNT_KEYS := [[KEY_1, KEY_KP_1], [KEY_2, KEY_KP_2], [KEY_3, KEY_KP_3]]
const MENU_ITEMS := ["TUTORIAL", "1 PLAYER", "2 PLAYERS", "3 PLAYERS", "QUIT"]
const TITLE_LINES := ["OLOUKIK", "DUNGEON"]   # the game name, one entry per line
const BOX_W := 260.0
const BOX_H := 170.0
const GAP := 40.0

var player_keys: Array = []   # player_keys[p][ring] = keycode, set by start()
var stage := 0                # -1 = title, 0 = player count, 1 = roles
var count := 1
var menu_index := 0           # highlighted row of the main menu
var picking := 0              # which player is choosing a role
var chosen: Array = []        # chosen[p] = ring index
var open := false
var grace := 0.0
var trans    # the screen wipe (wipe.gd), set by main.gd


func start(keys: Array, with_title: bool = false) -> void:
	player_keys = keys
	stage = -1 if with_title else 0
	count = 1
	picking = 0
	chosen = []
	open = true
	grace = 0.3
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	grace = maxf(0.0, grace - delta)
	queue_redraw()


func _finish() -> void:
	open = false
	if trans:
		await trans.cover()
	visible = false
	started.emit(count, chosen.duplicate())   # main swaps to the fight while covered
	if trans:
		await trans.uncover()


func _go(mid: Callable) -> void:
	# Runs `mid` while the screen is covered by the wipe.
	if trans == null:
		mid.call()
		return
	await trans.cover()
	mid.call()
	await trans.uncover()


func _enter_menu() -> void:
	stage = 0
	grace = 0.25


func _enter_roles() -> void:
	stage = 1
	picking = 0
	chosen = []
	grace = 0.25


func _pick_menu(index: int) -> void:
	Sfx.play("select")
	if index == MENU_ITEMS.size() - 1:
		get_tree().quit()
		return
	if index == 0:
		count = 0           # 0 players = the tutorial
		_finish()
		return
	count = index
	if count == 1:
		_finish()
	else:
		_go(_enter_roles)


func _choose_role(ring: int) -> void:
	chosen.append(ring)
	Sfx.play("select")
	picking += 1
	grace = 0.2
	if count == 3 and chosen.size() == 2:
		# The last player gets the remaining role automatically.
		for r in 3:
			if not (r in chosen):
				chosen.append(r)
		_finish()
	elif picking >= count:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not open or grace > 0.0:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()

	if stage == -1:
		Sfx.play("select")   # any key leaves the title screen
		grace = 0.25
		_go(_enter_menu)
		return

	if stage == 0:
		var k: int = event.keycode
		if k == KEY_UP or k == KEY_W:
			menu_index = (menu_index + MENU_ITEMS.size() - 1) % MENU_ITEMS.size()
			Sfx.play("select")
		elif k == KEY_DOWN or k == KEY_S:
			menu_index = (menu_index + 1) % MENU_ITEMS.size()
			Sfx.play("select")
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_pick_menu(menu_index)
		else:
			for i in COUNT_KEYS.size():   # 1 / 2 / 3 jump straight to that player count
				if k in COUNT_KEYS[i]:
					menu_index = i + 1
					_pick_menu(menu_index)
		return

	# Stage 1: the current player picks a free role with their own key.
	for ring in 3:
		if event.keycode == player_keys[picking][ring] and not (ring in chosen):
			_choose_role(ring)
			return


func _draw() -> void:
	var cx := size.x * 0.5
	var red := Pal.RED

	if stage == -1:
		# Title: tilted panel, the name stacked on two lines in white over a red
		# shadow copy, and a blinking prompt. Each line shrinks to fit the panel.
		var pr := Rect2(cx - 480.0, 150.0, 960.0, 400.0)
		UiPanel.tilt(self, pr.get_center())
		UiPanel.panel(self, pr, red)
		var font := get_theme_default_font()
		for i in TITLE_LINES.size():
			var line: String = TITLE_LINES[i]
			var fs := 150
			while fs > 40 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 820.0:
				fs -= 4
			var y := 250.0 + i * 130.0
			_text(Vector2(cx + 6.0, y + 6.0), line, fs, red, 900.0)
			_text(Vector2(cx, y), line, fs, Pal.PAPER, 900.0)
		if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0:
			_text(Vector2(cx, 490.0), "PRESS ANY KEY", 38, Pal.PAPER, 800.0)
		return

	if stage == 0:
		# Vertical menu: TUTORIAL, then 1 / 2 / 3 players. The picked row is a
		# white slanted bar with black text.
		var pr0 := Rect2(cx - 330.0, 100.0, 660.0, 500.0)
		UiPanel.tilt(self, pr0.get_center())
		UiPanel.panel(self, pr0, red)
		UiPanel.tag(self, Vector2(pr0.position.x + 24.0, pr0.position.y - 34.0), "MAIN MENU", 34)
		for i in MENU_ITEMS.size():
			var cy := 176.0 + i * 80.0
			var selected := i == menu_index
			if selected:
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - 250.0, cy - 34.0), Vector2(cx + 260.0, cy - 40.0),
					Vector2(cx + 240.0, cy + 34.0), Vector2(cx - 270.0, cy + 40.0)]), Pal.PAPER)
			var ink := Pal.INK if selected else Pal.PAPER
			_text(Vector2(cx, cy), MENU_ITEMS[i], 50, ink, 500.0)
		_text(Vector2(cx, 566.0), "UP / DOWN    ENTER", 22, Color(Pal.PAPER, 0.55), 600.0)
		return

	var pr1 := Rect2(cx - 480.0, 130.0, 960.0, 400.0)
	UiPanel.tilt(self, pr1.get_center())
	UiPanel.panel(self, pr1, red)
	UiPanel.tag(self, Vector2(pr1.position.x + 24.0, pr1.position.y - 34.0), "PLAYER %d: PICK A ROLE" % (picking + 1), 34)
	var x1 := cx - (3.0 * BOX_W + 2.0 * GAP) * 0.5
	for ring in 3:
		var rect := Rect2(x1 + ring * (BOX_W + GAP), 180.0, BOX_W, BOX_H)
		var role: Dictionary = ROLES[ring]
		var col: Color = role["color"]
		var taken_by := chosen.find(ring)
		if taken_by >= 0:
			draw_rect(rect, Color(col, 0.25), true)
			draw_rect(rect, Color(col, 0.5), false, 3.0)
			_text(rect.get_center(), "PLAYER %d" % (taken_by + 1), 34, Color(Pal.PAPER, 0.8), BOX_W)
			continue
		draw_rect(rect, col, false, 5.0)
		var key_text := OS.get_keycode_string(player_keys[picking][ring])
		_text(Vector2(rect.get_center().x, rect.position.y + 45.0), key_text, 56, Pal.PAPER, BOX_W)
		_text(Vector2(rect.get_center().x, rect.position.y + 105.0), role["name"], 34, col, BOX_W)
		_text(Vector2(rect.get_center().x, rect.position.y + 142.0), role["ring"], 22, Color(Pal.PAPER, 0.75), BOX_W)

	if count == 2:
		_text(Vector2(cx, 440.0), "THE ROLE LEFT OVER IS SHARED: EITHER PLAYER CAN PLAY IT", 26, Color(Pal.PAPER, 0.8), 900.0)
	elif count == 3:
		_text(Vector2(cx, 440.0), "THE LAST PLAYER GETS THE ROLE LEFT", 26, Color(Pal.PAPER, 0.8), 900.0)


func _outlined(center: Vector2, text: String, fs: int, col: Color, width: float) -> void:
	var font := get_theme_default_font()
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	var origin := Vector2(center.x - width * 0.5, baseline)
	draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, 12, Pal.INK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)


func _text(center: Vector2, text: String, fs: int, col: Color, width: float) -> void:
	var font := get_theme_default_font()
	var baseline := center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(center.x - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
