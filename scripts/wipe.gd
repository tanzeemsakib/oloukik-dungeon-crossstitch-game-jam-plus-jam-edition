extends Control
## Persona-style screen transition: a red, a white and a black slanted wipe
## sweep across the screen. Swap the screen while it is fully covered.
##
##   await wipe.cover()        # screen is now fully black
##   ... change what is on screen ...
##   await wipe.uncover()      # wipes away again
##
## After a scene reload, set Wipe.start_covered = true first; the new scene then
## starts covered and uncovers itself (see main.gd).
## SFX (optional files): transition_in, transition_out.

const Pal = preload("res://scripts/palette.gd")
const Sfx = preload("res://scripts/sfx.gd")

static var start_covered := false

const DURATION := 0.34        # seconds for the cover, and again for the uncover
const SLANT := 170.0
const LAYERS := [
	Pal.RED,    # red leads
	Pal.PAPER,     # white follows
	Pal.INK,  # black finishes and fills the screen
]

var p := 0.0:
	set(v):
		p = v
		queue_redraw()
var busy := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # still runs while the game is paused


func cover() -> void:
	busy = true
	visible = true
	Sfx.play("transition_in")
	var tw := create_tween()
	tw.tween_property(self, "p", 1.0, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func uncover() -> void:
	Sfx.play("transition_out")
	var tw := create_tween()
	tw.tween_property(self, "p", 0.0, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	visible = false
	busy = false


func hold() -> void:
	# Start fully covered (used right after a scene reload).
	busy = true
	visible = true
	p = 1.0


func _input(event: InputEvent) -> void:
	# No key gets through while a wipe is running.
	if busy and event is InputEventKey:
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var w := size.x
	var h := size.y
	for k in LAYERS.size():
		var pk := clampf((p - k * 0.18) / (1.0 - 0.36), 0.0, 1.0)
		if pk <= 0.0:
			continue
		var xe := lerpf(-SLANT, w + SLANT, pk)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-400.0, 0.0), Vector2(xe + SLANT, 0.0),
			Vector2(xe - SLANT, h), Vector2(-400.0, h)]), LAYERS[k])
