extends Control
## One QTE ring: a needle rotates around a circle, a target zone sits at a
## random angle. Press the ring's key while the needle is inside the zone.
##
## - Only the ACTIVE ring runs. Inactive rings are dimmed and frozen.
##   The active ring gets a glowing outline in its color (Guitar Hero style).
## - Needle passes through the zone without a press  -> miss
## - Key pressed while the needle is outside the zone -> miss (short lockout)
## - If shrinks_over_time is true, each zone starts at full width and shrinks
##   steadily over shrink_duration seconds. Every new zone starts full size
##   again, so zones are not cumulatively smaller.
## - reverse() flips the rotation (the "something's off" enemy trick).

const Pal = preload("res://scripts/palette.gd")
signal resolved(hit: bool)

@export var ring_name := "ATTACK"
var keys: Array = [KEY_A]            # every key that presses this ring (set by main.gd)
var key_label := "A"                 # text shown in the middle of the ring, e.g. "A" or "D/L"
@export var speed := 3.2             # radians per second
@export var zone_width := 0.75       # radians (full size)
@export var shrinks_over_time := true
@export var shrink_duration := 4.0   # seconds for a zone to reach min size
@export var min_zone_width := 0.14
@export var accent := Pal.RED

var base_zone_width := 0.0
var active := false
var angle := 0.0
var dir := 1.0
var zone_center := 0.0
var zone_age := 0.0
var was_inside := false
var lockout := 0.0
var flash := 0.0
var flash_color := Pal.PAPER


func _ready() -> void:
	base_zone_width = zone_width
	dir = _random_dir()
	angle = randf() * TAU
	_place_zone()


func _random_dir() -> float:
	return 1.0 if randf() < 0.5 else -1.0


func set_active(on: bool) -> void:
	active = on
	lockout = 0.0
	if on:
		# Fresh start each time a ring lights up.
		angle = randf() * TAU
		dir = _random_dir()
		_place_zone()


func _place_zone() -> void:
	# New zone: full size, somewhere ahead of the needle, never right under it.
	zone_center = wrapf(angle + dir * randf_range(1.5, TAU - 1.5), 0.0, TAU)
	zone_age = 0.0
	zone_width = base_zone_width
	was_inside = false


func _inside() -> bool:
	return absf(angle_difference(angle, zone_center)) <= zone_width * 0.5


func reverse() -> void:
	if not active:
		return
	dir = -dir
	_flash(Pal.YELLOW)


func _flash(c: Color) -> void:
	flash_color = c
	flash = 1.0


func _hit() -> void:
	_flash(Pal.PAPER)
	dir = _random_dir()
	_place_zone()
	resolved.emit(true)


func _miss(passed_through: bool) -> void:
	_flash(Pal.RED)
	if shrinks_over_time and passed_through:
		_place_zone()  # fresh full-size zone after a missed rotation
	resolved.emit(false)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.0)
	if not active:
		queue_redraw()
		return
	angle = wrapf(angle + dir * speed * delta, 0.0, TAU)
	lockout = maxf(0.0, lockout - delta)
	zone_age += delta
	if shrinks_over_time:
		var t := clampf(zone_age / shrink_duration, 0.0, 1.0)
		zone_width = lerpf(base_zone_width, min_zone_width, t)
	var inside := _inside()
	if was_inside and not inside:
		_miss(true)  # needle left the zone with no press
	was_inside = inside
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in keys:
		if lockout > 0.0:
			return
		if _inside():
			_hit()
		else:
			lockout = 0.25
			_miss(false)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.4

	if not active:
		# Dim, frozen, no zone or needle.
		draw_circle(c, r + 18.0, Color(0, 0, 0, 0.4))
		draw_arc(c, r, 0.0, TAU, 96, Color(accent, 0.25), 6.0, true)
		_draw_key(c, Color(accent, 0.45))
		return

	draw_circle(c, r + 18.0, Color(0, 0, 0, 0.6))
	draw_arc(c, r, 0.0, TAU, 96, Color(Pal.PAPER, 0.25), 6.0, true)
	var half := zone_width * 0.5
	draw_arc(c, r, zone_center - half, zone_center + half, 32, accent, 22.0, true)
	var tip := c + Vector2.from_angle(angle) * (r + 16.0)
	var base := c + Vector2.from_angle(angle) * 34.0  # start outside the key letter
	draw_line(base, tip, Pal.PAPER, 5.0, true)
	_draw_key(c, Pal.PAPER)

	# Highlight outline: soft glow plus a thin bright line, gently pulsing.
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	draw_arc(c, r + 32.0, 0.0, TAU, 96, Color(accent, 0.25 * pulse), 14.0, true)
	draw_arc(c, r + 32.0, 0.0, TAU, 96, Color(accent, pulse), 5.0, true)

	if flash > 0.0:
		draw_arc(c, r + 22.0, 0.0, TAU, 96, Color(flash_color, flash), 8.0, true)


func _draw_key(c: Vector2, col: Color) -> void:
	# The ring's button, drawn in the center. Uses the project's default font.
	var font := get_theme_default_font()
	# One key is shown big; two or three keys (co-op) shrink to fit the ring.
	var fs := 44
	if key_label.length() > 2:
		fs = 30
	if key_label.length() > 5:
		fs = 22
	var baseline := c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(c.x - 60.0, baseline), key_label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, fs, col)
