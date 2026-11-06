extends RefCounted
## One-shot sound effects. Usage from any script:
##   const Sfx = preload("res://scripts/sfx.gd")
##   Sfx.play("strike")
##
## Looks for res://assets/sfx/<name>.ogg, .wav or .mp3 (in that order). If no
## file exists the call does nothing, so the game runs fine with missing sounds
## and you can drop files in one at a time.

const DIR := "res://assets/sfx/"
const EXTENSIONS := ["ogg", "wav", "mp3"]

# Per-sound volume tweaks in dB (0 = as recorded). Missing names play at 0.
const VOLUMES := {
	"miss": -4.0,
	"key_ok": -6.0,
	"strike": -2.0,
}
# Pitch is randomized by +/- this much so repeated sounds do not feel robotic.
const PITCH_VARIATION := 0.06

static var _cache := {}


static func play(sfx_name: String) -> void:
	var stream = _load(sfx_name)
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = VOLUMES.get(sfx_name, 0.0)
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.play()


static func _load(sfx_name: String):
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [DIR, sfx_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	_cache[sfx_name] = stream   # cache misses too, so missing files cost nothing
	return stream
