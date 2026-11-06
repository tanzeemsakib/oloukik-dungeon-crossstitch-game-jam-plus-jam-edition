extends Control
## Fight prototype. Builds everything in code.
##
## One ring is active at a time (random, can repeat). After each hit or miss a
## random ring lights up.
##   ATTACK hit  -> damages the boss
##   DEFEND hit  -> nothing (you blocked it). Missing a DEFEND ring hurts you.
##   FOCUS hit   -> charges the bar; when full a pick screen pops up instantly:
##                  A = big damage, S = shield, D = heal
##   Shield only comes from the FOCUS payoff and soaks all damage you take.
##   Missing the other rings costs nothing, it just wastes time.
##
## The boss has no normal attack. Every so often it fires a SPECIAL: a string
## of 3-4 key prompts. Clear it for big damage to the boss, fail it and you
## take damage (shield soaks first).
##
## Keys: A / S / D for the rings, the focus pick screen and the upgrade screen.
## The boss randomly reverses the active ring's rotation (the "something's off"
## trick). There is no key for it.
##
## ONE MORE TIME (the run loop):
## - A run never ends until you die: each fight the boss has more HP and the timers speed up.
## - After each win you pick 1 of 3 upgrades (A / S / D).
## - Dying ends the run. Enter or Space starts the next one. Every death gives
##   +10 max hp for all later runs (carry-over), and the boss REMEMBERS what
##   killed you: it opens every fight in the next run with that move.

const Pal = preload("res://scripts/palette.gd")
const TauntPanel = preload("res://scripts/taunt_panel.gd")
const Ring = preload("res://scripts/ring.gd")
const Qte = preload("res://scripts/qte_special.gd")
const Pick = preload("res://scripts/focus_pick.gd")
const UpgradePick = preload("res://scripts/upgrade_pick.gd")
const Ransom = preload("res://scripts/ransom_text.gd")
const Backdrop = preload("res://scripts/backdrop.gd")
const Lobby = preload("res://scripts/lobby.gd")
const Sfx = preload("res://scripts/sfx.gd")
const EndPanel = preload("res://scripts/end_panel.gd")
const TipPanel = preload("res://scripts/tip_panel.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const Wipe = preload("res://scripts/wipe.gd")

# Looping background music. Put your files here (rename them, or change the paths).
const MUSIC_PATH := "res://assets/battle-theme.ogg"       # fights and the tutorial
const MENU_MUSIC_PATH := "res://assets/menu-theme.ogg"    # title and menu screens
const TAUNT_MUSIC_PATH := "res://assets/taunt-theme.ogg"  # the boss's speech after a death
const MUSIC_VOLUME_DB := -6.0           # lower = quieter, 0 = full volume

# Each player has three keys: [attack ring, defend ring, focus ring].
const PLAYER_KEYS := [
	[KEY_A, KEY_S, KEY_D],
	[KEY_J, KEY_K, KEY_L],
	[KEY_LEFT, KEY_DOWN, KEY_RIGHT],
]
# Boss hp multiplier by player count (1, 2, 3). Co-op has more hands on the rings.
const COOP_BOSS_HP_MULT := [1.0, 1.8, 2.5]

# Survives scene reloads, so it carries over between runs (resets when the game closes).
static var music_player: AudioStreamPlayer = null   # one player for the whole launch
static var music_current := ""         # which track it is playing, so reloads never restart it
static var seen_title := false         # the title screen shows once per launch
static var players := 0                # 0 = show the lobby, otherwise 1, 2 or 3
static var roles: Array = []           # roles[p] = ring index player p picked (co-op)
static var deaths := 0
static var boss_art := 1                # which drawing is on screen (1 = boss-1.png ..., -1 = boss-tutorial.png)
static var mask_cache := {}             # art index -> fill mask texture (built once per launch)
static var last_taunt := -1             # which one-liner the boss used last, so it never repeats back to back
static var boss_tint := 0               # which entry of BOSS_TINTS
static var art_bag: Array = []          # shuffled bags: no repeats until all have appeared
static var tint_bag: Array = []
static var last_death_cause := ""   # "SPECIAL" or "DEFEND" or "" - what the boss remembers

const DEFS := [
	{"name": "ATTACK", "key": KEY_A, "color": Pal.RED},
	{"name": "DEFEND", "key": KEY_S, "color": Pal.GREEN},
	{"name": "FOCUS", "key": KEY_D, "color": Pal.BLUE},
]

# Layout
const NAME_FONT_SIZE := 34              # ATTACK / DEFEND / FOCUS under each ring
const RING_SIZE := 190.0
const RING_TOP := 372.0                 # rings sit low so the boss has room
const MISS_Y := RING_TOP - 60.0         # where the MISS text appears
const BOSS_PATH := "res://assets/boss-%d.png"          # fight bosses: boss-1.png, boss-2.png, boss-3.png ...
const BOSS_TUTORIAL_PATH := "res://assets/boss-tutorial.png"   # tutorial boss and the one who taunts you after a death

# What the tutorial boss says after you die. He never lets on at first. Death number
# REVEAL_DEATHS gets the reveal line instead.
const TAUNTS := [
	"Back so soon? You always are.",
	"Same place. Same ending. Funny, that.",
	"Count them, if you like. I do.",
	"This is where I find you. Every time.",
]
const TAUNT_REVEAL := "Ten times. Did you really think this was luck?\nI am the one who put you in this loop. And I am not letting you out."
const REVEAL_DEATHS := 10
# Every fight picks a random drawing (boss.png, boss-1.png ... whichever exist) and a
# random fill color from this pool, as shuffled bags so nothing repeats back to back.
# Remove an entry to take that color out of the pool, or add more.
const MAX_BOSS_ARTS := 12               # looks for boss-1.png up to boss-11.png
const BOSS_TINTS := [Pal.VIOLET, Pal.AMBER, Pal.TEAL, Pal.ORCHID, Pal.LIME]   # fill colors (none of them used by the UI)
const BOSS_GRAIN := 0.16                # noise over the boss color: 0 = smooth, 0.3 = rough
const BOSS_GRAIN_PX := 2.0              # size of each speck, in screen pixels
const BOSS_BORDER_PX := 7.0             # white border around the boss, in screen pixels
const FILL_SCALE := 6                   # the fill mask is built at 1/6 size (fast)
const FILL_GAP := 3                     # outline gaps up to about 2x this many mask pixels count as closed
# Draws, back to front: a white border, the color fill, then your outline untouched.
const BOSS_SHADER := """
shader_type canvas_item;
uniform sampler2D fill_mask : filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(0.94, 0.92, 0.88, 1.0);
uniform float border = 14.0;   // border width in texture pixels
uniform float flash = 0.0;     // 1 = white hit flash
uniform float grain = 0.16;    // noise strength on the color fill (0 = smooth)
uniform float grain_size = 4.0;   // noise speck size in texture pixels

float ink_of(vec4 t) {
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	return t.a * (1.0 - smoothstep(0.35, 0.8, lum));
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
float fill_at(vec2 uv) {
	return smoothstep(0.35, 0.65, texture(fill_mask, uv).r);
}
vec4 over(vec4 d, vec4 s) {
	float a = s.a + d.a * (1.0 - s.a);
	vec3 rgb = (s.rgb * s.a + d.rgb * d.a * (1.0 - s.a)) / max(a, 0.00001);
	return vec4(rgb, a);
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float ink = ink_of(t);
	float fill = fill_at(UV);
	float edge = max(ink, fill);
	for (int r = 1; r <= 3; r++) {
		vec2 px = TEXTURE_PIXEL_SIZE * border * (float(r) / 3.0);
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5235988;
			vec2 p = UV + vec2(cos(ang), sin(ang)) * px;   // (built-ins like TEXTURE only work in here, not in helpers)
			edge = max(edge, max(ink_of(texture(TEXTURE, p)), fill_at(p)));
		}
	}
	// Grain: fine specks plus a coarser blotch layer, over the fill (and a little on the border).
	vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE / grain_size);
	float g = ((hash(cell) - 0.5) * 0.8 + (hash(floor(cell / 5.0)) - 0.5) * 0.5) * grain;
	vec4 c = vec4(border_color.rgb * (1.0 + g * 0.5), edge);
	c = over(c, vec4(tint.rgb * (1.0 + g), fill));
	c = over(c, vec4(t.rgb, ink));
	c.rgb = mix(c.rgb, vec3(1.0), flash * 0.75);
	COLOR = c;
}
"""
const SCREEN_H := 720.0
const BOSS_TOP := 76.0                  # small gap under the boss HP text at the top
const BOSS_HEIGHT := SCREEN_H - BOSS_TOP   # boss stands on the bottom edge
const BOSS_SIZE := Vector2(760.0, BOSS_HEIGHT)   # art is fitted inside this box, aspect kept
const HOVER_RISE := 12.0                # how far the boss floats up (px); 0 = still
const HOVER_DRIFT := 3.0                # sideways sway (px)
const BOSS_FONT_SIZE := 44             # boss "100 hp" readout, top center
const BAR_W := 260.0                   # health and focus bars share these
const BAR_H := 22.0
const STAT_FONT_SIZE := 40              # "60 hp" and "20 fp" readouts
const STAT_Y := 646.0
const STAT_W := 180.0                   # width of each "hp" / "sp" readout
const HP_TEXT_X := 60.0                 # hp sits left of the left ring's center line
const SP_TEXT_X := 240.0                # sp sits right of it, same height
const LEFT_BAR_X := 110.0               # lines up under the left ring
const RIGHT_BAR_X := 910.0              # lines up under the right ring
const BOSS_POP_AREA := Rect2(360.0, 85.0, 560.0, 40.0)    # damage you deal pops up here
const PLAYER_POP_AREA := Rect2(40.0, 85.0, 260.0, 40.0)   # damage you take pops up here
const FOCUS_POP_AREA := Rect2(980.0, 85.0, 260.0, 40.0)    # focus points you gain pop up here
const BUBBLE_POPUPS := true             # false = plain outlined text (the previous look)
const POPUP_RISE := 36.0               # how far pop-ups float up
const POPUP_HOLD := 0.9                 # seconds fully visible before fading
const POPUP_FADE := 0.6                 # seconds to fade out
const SHAKE_TIME := 0.25
const SHAKE_STRENGTH := 10.0
const BIG_HIT := 20                     # damage at or above this gets the heavy hit feel

# Balance (tune these)
const BOSS_MAX_HP := 50 
const PLAYER_MAX_HP := 60
const ATTACK_DAMAGE := 4                # per Attack hit
const DEFEND_MISS_DAMAGE := 5           # you take this when a Defend ring is missed
const MAX_SHIELD := 40
const FOCUS_MAX := 30                   # focus points (fp) to fill the bar
const FOCUS_PER_HIT := 10               # 3 hits fill the bar
const HEAL_AMOUNT := 20
const BIG_DAMAGE := 25
const SHIELD_PAYOFF := 25
const REVERSE_MIN_WAIT := 3.0           # seconds between boss rotation flips (random)
const REVERSE_MAX_WAIT := 7.0
const SPECIAL_MIN_WAIT := 12.0          # seconds between specials (random)
const SPECIAL_MAX_WAIT := 20.0
const SPECIAL_REWARD := 30              # boss damage when you clear the QTE
const SPECIAL_DAMAGE := 20              # your damage when you fail it

# Run loop (tune these)
const PACE_MIN := 0.45                  # timers never get faster than this (x the starting speed)
const POSITION_MIN_WAIT := 9.0          # seconds between the boss swapping ring positions (random)
const POSITION_MAX_WAIT := 16.0
const BOSS_HP_GROWTH := 1.0             # each later fight: boss hp +100% of the base (+50 hp at the 50 hp start)
const DIFFICULTY_STEP := 0.85           # each later fight: special / reverse timers x0.85
const FIGHT_HEAL := 20                  # hp restored between fights
const CARRY_HP_PER_DEATH := 10          # max hp gained for every death, all later runs
const CARRY_HP_MAX := 40
const UPGRADES := [
	{"id": "HP", "label": "TOUGH", "desc": "+15 max hp"},
	{"id": "ATK", "label": "SHARP", "desc": "+2 attack damage"},
	{"id": "FOCUS", "label": "FOCUSED", "desc": "+5 fp per focus hit"},
	{"id": "ZONE", "label": "STEADY", "desc": "wider target zones"},
	{"id": "SLOW", "label": "CALM", "desc": "rings spin slower"},
	{"id": "WARD", "label": "WARDED", "desc": "+10 shield from focus"},
]

var rings := {}
var info := {}
var miss_labels := {}
var miss_tweens := {}
var stats := {}
var active_name := ""
var focus_charge := 0
var bar_texts := {}           # text labels drawn on the bars
var in_menu := false          # true while the focus pick screen is open
var shake_left := 0.0
var shake_power := 1.0        # screen shake multiplier, bigger for big hits
var boss_base := Vector2.ZERO # where the boss rests, so shaking returns to it
var boss_shake := 0.0         # current boss shake strength (decays to 0)

var boss: Control
var boss_tween: Tween
var qte   # instance of qte_special.gd (left untyped so start() resolves)
var pick  # instance of focus_pick.gd (untyped for the same reason)
var upick  # instance of upgrade_pick.gd
var end_screen: EndPanel
var tip: TipPanel              # tutorial hint box
var taunt: TauntPanel          # the tutorial boss's line after a death
var pause_menu: PauseMenu      # Esc menu: resume / main menu / quit
var trans: Wipe                # screen wipe between screens
var tutorial := false          # true while the scripted tutorial fight runs

signal tut_step                # the tutorial script waits on this
signal never                   # never emitted: parks the script after leaving

var coop := false             # true for 2 or 3 players: all three rings spin at once
var lobby                     # instance of lobby.gd
var ring_tags := {}           # ring name -> owner text shown under the ring in co-op
var run_fight := 1
var boss_max_hp := BOSS_MAX_HP
var max_hp := PLAYER_MAX_HP
var boss_hp := BOSS_MAX_HP
var player_hp := PLAYER_MAX_HP
var shield := 0
var up_atk := 0               # run upgrades (reset when the scene reloads)
var up_focus := 0
var up_shield := 0
var offered: Array = []       # the 3 upgrades currently on screen
var pace := 1.0               # timer multiplier, shrinks each fight
var death_cause := ""
var transitioning := false    # true between a boss dying and the next fight
var special_timer := 0.0
var reverse_timer := 0.0
var shuffle_timer := 0.0
var reloading := false        # true once a reload wipe has started
var slot_of := {"ATTACK": 0, "DEFEND": 1, "FOCUS": 2}   # which screen slot (0 left .. 2 right) each ring sits in
var in_special := false
var over := false


func _ready() -> void:
	Engine.time_scale = 1.0   # in case a hit-stop was interrupted by a reload
	randomize()
	var bg := Backdrop.new()   # dark halftone background, behind everything
	bg.size = Vector2(1280, 720)
	add_child(bg)
	_build_boss()
	_apply_boss()
	_build_hud()
	_build_rings()

	qte = Qte.new()
	qte.size = Vector2(1280, 720)
	qte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte.visible = false
	add_child(qte)
	qte.finished.connect(_on_special_finished)

	pick = Pick.new()
	pick.size = Vector2(1280, 720)
	pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pick.visible = false
	add_child(pick)
	pick.chosen.connect(_on_focus_chosen)

	upick = UpgradePick.new()
	upick.size = Vector2(1280, 720)
	upick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upick.visible = false
	add_child(upick)
	upick.chosen.connect(_on_upgrade_chosen)

	_build_end_screen()

	lobby = Lobby.new()
	lobby.size = Vector2(1280, 720)
	lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lobby.visible = false
	add_child(lobby)
	lobby.started.connect(_on_lobby_started)

	tip = TipPanel.new()
	tip.size = Vector2(1280, 720)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	add_child(tip)

	taunt = TauntPanel.new()
	taunt.size = Vector2(1280, 720)
	taunt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	taunt.visible = false
	add_child(taunt)

	pause_menu = PauseMenu.new()
	pause_menu.size = Vector2(1280, 720)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.visible = false
	add_child(pause_menu)
	pause_menu.chose.connect(_on_pause_chose)
	pause_menu.toggled.connect(_on_pause_toggled)

	trans = Wipe.new()          # last child = drawn on top of everything
	trans.size = Vector2(1280, 720)
	trans.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trans.visible = false
	add_child(trans)
	lobby.trans = trans

	# Carry-over from earlier runs: every death made you a bit tougher.
	max_hp = PLAYER_MAX_HP + mini(CARRY_HP_MAX, deaths * CARRY_HP_PER_DEATH)
	player_hp = max_hp
	_refresh_labels()

	if players == 0:
		_show_battle(false)     # no boss, rings or readouts on the menu screens
		_play_music(MENU_MUSIC_PATH)
		in_menu = true         # pauses every timer until the lobby is done
		lobby.start(PLAYER_KEYS, not seen_title)   # title screen only on first launch
		seen_title = true
	else:
		_play_music(MUSIC_PATH)   # back from the taunt screen: fight music again
		_configure_players()
		_start_fight()

	if Wipe.start_covered:
		# Came here through a wipe (retry, back to menu): start covered, then reveal.
		Wipe.start_covered = false
		trans.hold()
		await get_tree().process_frame
		await trans.uncover()


func _play_music(path: String) -> void:
	# The player lives on the scene root, not in this scene, so reloading the
	# scene ("one more time") does not restart a song that is already playing.
	# Asking for a different track swaps it. Missing files are skipped silently.
	if music_current == path or not ResourceLoader.exists(path):
		return
	music_current = path
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true   # loops even if the Import tab's Loop box was not ticked
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.name = "Music"
		music_player.volume_db = MUSIC_VOLUME_DB
		music_player.stream = stream
		music_player.autoplay = true
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing under the pause menu
		get_tree().root.add_child.call_deferred(music_player)
	else:
		music_player.stream = stream
		if music_player.is_inside_tree():
			music_player.play()
		else:
			music_player.autoplay = true


func _show_battle(on: bool) -> void:
	# Boss, rings, ring names and the hp / sp / fp readouts, all at once.
	boss.visible = on
	for n in rings:
		rings[n].visible = on
	for n in info:
		info[n].visible = on
	for k in bar_texts:
		bar_texts[k].visible = on


func _on_lobby_started(count: int, picked: Array) -> void:
	players = count       # 0 = the tutorial (the menu shows again afterwards)
	roles = picked
	in_menu = false
	_show_battle(true)
	_play_music(MUSIC_PATH)   # the fight song starts once the menu is done
	_configure_players()
	if count == 0:
		_run_tutorial()
		return
	_start_fight()


# ---------------------------------------------------------------- tutorial
# A short scripted fight. The game freezes behind a hint box at every new
# mechanic; ENTER continues, ESC leaves. Nothing here touches deaths or the
# boss's memory.

func _run_tutorial() -> void:
	tutorial = true
	boss_art = -1      # the tutorial boss, in the UI red
	boss_tint = -1
	_apply_boss()
	boss_max_hp = 200
	boss_hp = 200
	special_timer = 9999.0
	reverse_timer = 9999.0
	await get_tree().process_frame

	_activate("ATTACK")   # lit first so the player sees the ring the hint talks about
	await _tip("ATTACK", "Press A while the needle is inside the zone.\nA hit hurts the boss.")
	await tut_step

	_activate("DEFEND")
	await _tip("DEFEND", "Press S the same way.\nMiss it and you get hurt.")
	await tut_step

	# The boss flips a ring's spin. The ring ignores keys for a moment so the
	# player can watch it happen, then has to hit it to go on.
	_activate("ATTACK")
	rings["ATTACK"].set_process_unhandled_input(false)
	await get_tree().create_timer(0.9).timeout
	_boss_reverse()
	await get_tree().create_timer(0.2).timeout
	await _tip("SOMETHING'S OFF", "The boss can flip a ring's spin.\nWatch the needle, then hit it.")
	rings["ATTACK"].set_process_unhandled_input(true)
	await tut_step

	# The boss swaps the rings around. Keys stay with their ring.
	_boss_shuffle_rings(true)
	await get_tree().create_timer(0.7).timeout
	await _tip("SOMETHING'S OFF", "He can also swap the rings around.\nA ring keeps its key: ATTACK is still A.")

	_activate("FOCUS")
	await _tip("FOCUS", "Press D. Three hits fill the bar.")
	await tut_step   # fires when the bar is full and the pick screen opens
	await _tip("FOCUS FULL", "A: big damage     S: shield     D: heal", true)
	await tut_step   # fires when one is picked

	_start_special()
	await _tip("SOMETHING'S OFF", "The boss fires a special.\nPress the keys shown, in order.", true)
	await tut_step

	var pool: Array = UPGRADES.duplicate()
	pool.shuffle()
	offered = pool.slice(0, 3)
	in_menu = true
	upick.start(offered, _key_sets())
	await _tip("BOSS DOWN", "Beat a boss to pick an upgrade.\nIt lasts the whole run.", true)
	await tut_step

	await _tip("THAT'S IT", "There is no last fight. Go as far as you can.\nDie, and the boss remembers how.")
	_exit_tutorial()


func _tip(title: String, body: String, at_bottom: bool = false) -> void:
	# Freezes the rings and pick screens, shows the hint, and waits for ENTER.
	var frozen: Array = rings.values()
	frozen.append_array([qte, pick, upick])
	var modes: Array = []
	for n in frozen:
		modes.append(n.process_mode)
		n.process_mode = Node.PROCESS_MODE_DISABLED
	tip.show_tip(title, body, at_bottom)
	var skipped: bool = await tip.closed
	for i in frozen.size():
		frozen[i].process_mode = modes[i]
	if skipped:
		_exit_tutorial()
		await never   # the scene is reloading; park here


func _exit_tutorial() -> void:
	players = 0
	roles = []
	_reload_scene()


func _reload_scene() -> void:
	# Wipe to black, then reload; the new scene starts covered and wipes away.
	if reloading:
		return   # a second key during the wipe
	reloading = true
	await trans.cover()
	Wipe.start_covered = true
	get_tree().reload_current_scene()


func _tutorial_ring_resolved(hit: bool, ring) -> void:
	if in_menu:
		tut_step.emit()   # the focus bar just filled and the pick screen opened
		return
	if hit and ring.ring_name != "FOCUS":
		ring.set_active(false)
		active_name = ""
		tut_step.emit()
		return
	ring.set_active(true)   # a miss, or a focus hit that has not filled the bar yet: same ring again


func _configure_players() -> void:
	# Decides which keys press which ring, and who owns each ring.
	coop = players >= 2
	for i in DEFS.size():
		var ring_name: String = DEFS[i]["name"]
		var ks: Array = []
		var tags: Array = []
		if not coop:
			ks.append(PLAYER_KEYS[0][i])
		else:
			for p in players:
				var owns: bool = roles[p] == i
				# With 2 players the role nobody picked is shared by both.
				var shared: bool = players == 2 and not (i in roles)
				if owns or shared:
					ks.append(PLAYER_KEYS[p][i])
					tags.append("P%d" % (p + 1))
		var parts: Array = []
		for k in ks:
			parts.append(OS.get_keycode_string(k))
		rings[ring_name].keys = ks
		rings[ring_name].key_label = "/".join(parts)
		ring_tags[ring_name] = "+".join(tags)


func _key_sets() -> Array:
	# For the pick screens: option i can be chosen by every player's i-th key.
	var sets: Array = []
	for i in 3:
		var ks: Array = []
		if not coop:
			ks.append(PLAYER_KEYS[0][i])
		else:
			for p in players:
				ks.append(PLAYER_KEYS[p][i])
		sets.append(ks)
	return sets


func _resume_rings(only: String = "") -> void:
	# Solo: light one random ring. Co-op: every ring runs at the same time, and a
	# ring that just resolved restarts on its own.
	if coop:
		if only != "":
			rings[only].set_active(true)
		else:
			for n in rings:
				rings[n].set_active(true)
	else:
		_activate_next("")


func _start_fight() -> void:
	_apply_boss(true)
	var coop_mult: float = COOP_BOSS_HP_MULT[clampi(players, 1, 3) - 1]
	boss_max_hp = int(BOSS_MAX_HP * (1.0 + BOSS_HP_GROWTH * (run_fight - 1)) * coop_mult)
	boss_hp = boss_max_hp
	shield = 0
	focus_charge = 0
	in_menu = false
	in_special = false
	transitioning = false
	pace = maxf(PACE_MIN, pow(DIFFICULTY_STEP, run_fight - 1))
	special_timer = _special_wait()
	reverse_timer = _reverse_wait()
	shuffle_timer = _shuffle_wait()

	var title := "FIGHT %d" % run_fight
	_banner(title, 200.0, Pal.PAPER, 72)

	# The boss remembers how you died last time and opens with that move.
	var first := ""
	match last_death_cause:
		"SPECIAL":
			special_timer = 3.0
			if run_fight == 1:
				_banner("THE BOSS REMEMBERS: SPECIAL", 290.0, Pal.RED, 40)
		"DEFEND":
			first = "DEFEND"
			if run_fight == 1:
				_banner("THE BOSS REMEMBERS: DEFEND", 290.0, Pal.RED, 40)
	if coop:
		_resume_rings()
	elif first != "":
		_activate(first)
	else:
		_activate_next("")


func _special_wait() -> float:
	return randf_range(SPECIAL_MIN_WAIT, SPECIAL_MAX_WAIT) * pace


func _reverse_wait() -> float:
	return randf_range(REVERSE_MIN_WAIT, REVERSE_MAX_WAIT) * pace


func _shuffle_wait() -> float:
	return randf_range(POSITION_MIN_WAIT, POSITION_MAX_WAIT) * pace


func _banner(text: String, y: float, col: Color, font_size: int) -> void:
	# Big centered text that fades in, holds, fades out.
	var lbl := _ransom(font_size, col, 0.45)
	lbl.text = text
	lbl.size = Vector2(1280.0, font_size * 1.5)
	lbl.position = Vector2(0.0, y)
	lbl.modulate.a = 0.0
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _boss_path(index: int) -> String:
	# -1 = the tutorial boss, 1.. = fight bosses. Returns "" if nothing usable exists.
	var want := BOSS_TUTORIAL_PATH if index < 0 else BOSS_PATH % index
	if ResourceLoader.exists(want):
		return want
	# Missing file: fall back to the tutorial boss, then to any fight boss.
	if ResourceLoader.exists(BOSS_TUTORIAL_PATH):
		return BOSS_TUTORIAL_PATH
	for i in range(1, MAX_BOSS_ARTS):
		if ResourceLoader.exists(BOSS_PATH % i):
			return BOSS_PATH % i
	return ""


func _next_from_bag(bag: Array, refill: Array, last: int) -> int:
	# Shuffled-bag pick: every option comes up once before any repeats, and the
	# first pick of a fresh bag is never the one used last.
	if bag.is_empty():
		bag.append_array(refill)
		bag.shuffle()
		if bag.size() > 1 and bag[bag.size() - 1] == last:
			bag.reverse()
	return bag.pop_back()


func _pick_boss() -> void:
	# Random boss art and a random color from the pool, for this fight.
	var arts: Array = []
	for i in range(1, MAX_BOSS_ARTS):
		if ResourceLoader.exists(BOSS_PATH % i):
			arts.append(i)
	if arts.is_empty():
		return
	var tints: Array = []
	for i in BOSS_TINTS.size():
		tints.append(i)
	boss_art = _next_from_bag(art_bag, arts, boss_art)
	boss_tint = _next_from_bag(tint_bag, tints, boss_tint)


func _apply_boss(pick_new: bool = false) -> void:
	# Shows the current boss art and color. Does nothing for the orange placeholder block.
	var img := boss as TextureRect
	if img == null:
		return
	if pick_new:
		_pick_boss()
	var path := _boss_path(boss_art)
	if path == "":
		return
	var tex: Texture2D = load(path)
	img.texture = tex
	if img.material == null:
		var sh := Shader.new()
		sh.code = BOSS_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		img.material = mat
	var mat2 := img.material as ShaderMaterial
	# Texture pixels per screen pixel (the art is shrunk to fit the boss box).
	var shown := minf(BOSS_SIZE.x / tex.get_width(), BOSS_SIZE.y / tex.get_height())
	mat2.set_shader_parameter("fill_mask", _fill_mask_for(boss_art, tex))
	mat2.set_shader_parameter("tint", Pal.RED if boss_tint < 0 else BOSS_TINTS[boss_tint])   # -1 = the tutorial boss, in the UI red
	mat2.set_shader_parameter("border", BOSS_BORDER_PX / shown)
	mat2.set_shader_parameter("flash", 0.0)
	mat2.set_shader_parameter("grain", BOSS_GRAIN)
	mat2.set_shader_parameter("grain_size", BOSS_GRAIN_PX / shown)


func _fill_mask_for(art_index: int, tex: Texture2D) -> Texture2D:
	# Finds the space "inside" the outline so it can be colored. Works on a small
	# copy of the art: ink pixels are grown a little to close tiny gaps, everything
	# the outside can reach is background, the rest is the body. Cached per drawing.
	if mask_cache.has(art_index):
		return mask_cache[art_index]
	var img := tex.get_image()
	if img == null:
		return ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_L8))   # empty: no fill
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := maxi(8, ceili(img.get_width() / float(FILL_SCALE)))
	var h := maxi(8, ceili(img.get_height() / float(FILL_SCALE)))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var n := w * h
	var data := img.get_data()

	# 1 = outline. Transparent PNGs use alpha; a flat white background uses darkness.
	var clear := 0
	for i in n:
		if data[i * 4 + 3] < 25:
			clear += 1
	var use_alpha := clear > n * 0.2
	var ink := PackedByteArray()
	ink.resize(n)
	for i in n:
		var a: int = data[i * 4 + 3]
		if use_alpha:
			ink[i] = 1 if a > 60 else 0
		else:
			var lum: float = data[i * 4] * 0.299 + data[i * 4 + 1] * 0.587 + data[i * 4 + 2] * 0.114
			ink[i] = 1 if (lum < 128.0 and a > 128) else 0

	# Grow the outline, then flood the background in from the image edge.
	var blocked := _grow(ink, w, h, FILL_GAP)
	var outside := PackedByteArray()
	outside.resize(n)
	var stack: Array[int] = []
	for x in w:
		for y in [0, h - 1]:
			var i: int = y * w + x
			if blocked[i] == 0 and outside[i] == 0:
				outside[i] = 1
				stack.append(i)
	for y in h:
		for x in [0, w - 1]:
			var i: int = y * w + x
			if blocked[i] == 0 and outside[i] == 0:
				outside[i] = 1
				stack.append(i)
	while not stack.is_empty():
		var i: int = stack.pop_back()
		var x := i % w
		var y := i / w
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var j: int = ny * w + nx
			if outside[j] == 0 and blocked[j] == 0:
				outside[j] = 1
				stack.append(j)

	# Take back the growth: let the background creep back in over plain (non-outline) pixels.
	for _round in FILL_GAP:
		var grown := outside.duplicate()
		for y in h:
			for x in w:
				var i := y * w + x
				if outside[i] == 1:
					continue
				if ink[i] == 1:
					continue
				if (x > 0 and outside[i - 1] == 1) or (x < w - 1 and outside[i + 1] == 1) \
						or (y > 0 and outside[i - w] == 1) or (y < h - 1 and outside[i + w] == 1):
					grown[i] = 1
		outside = grown

	# Body = not background. Shrink it one pixel so the color never pokes past the outline.
	var out := PackedByteArray()
	out.resize(n)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if outside[i] == 0 and outside[i - 1] == 0 and outside[i + 1] == 0 \
					and outside[i - w] == 0 and outside[i + w] == 0:
				out[i] = 255
	var mask := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, out))
	mask_cache[art_index] = mask
	return mask


func _grow(src: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	# Square dilation: every 1 spreads r pixels in all directions.
	var tmp := PackedByteArray()
	tmp.resize(w * h)
	for y in h:
		for x in w:
			if src[y * w + x] == 1:
				for xx in range(maxi(0, x - r), mini(w, x + r + 1)):
					tmp[y * w + xx] = 1
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			if tmp[y * w + x] == 1:
				for yy in range(maxi(0, y - r), mini(h, y + r + 1)):
					out[yy * w + x] = 1
	return out


func _build_boss() -> void:
	# Boss art lives in assets/ (boss-1.png, boss-2.png ..., boss-tutorial.png).
	# If none of them exist, an orange block is used instead.
	if _boss_path(boss_art) != "":
		var img := TextureRect.new()
		img.texture = load(_boss_path(boss_art))
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		img.size = BOSS_SIZE
		img.position = Vector2(640.0 - BOSS_SIZE.x * 0.5, BOSS_TOP)
		boss = img
		boss_base = img.position
		add_child(boss)
		return

	var block := ColorRect.new()
	block.color = Pal.RED
	block.size = Vector2(300.0, BOSS_HEIGHT)
	block.position = Vector2(640.0 - 150.0, BOSS_TOP)
	boss = block
	boss_base = block.position
	add_child(boss)
	var tag := Label.new()
	tag.text = "BOSS"
	tag.size = block.size
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 48)
	boss.add_child(tag)


func _ransom(font_px: int, col: Color, share: float = 0.4) -> Ransom:
	# Ransom-note text node. `col` is the accent block color, `share` how often
	# a letter uses it (0 = only white and black blocks).
	var t := Ransom.new()
	t.font_size = font_px
	t.accent = col
	t.accent_share = share
	return t


func _stat_text(x: float, col: Color, width: float = BAR_W) -> Ransom:
	# Large readout (e.g. "60 hp", "20 fp") in ransom-note lettering.
	var lbl := _ransom(STAT_FONT_SIZE, col, 0.55)
	lbl.size = Vector2(width, STAT_FONT_SIZE + 24.0)
	lbl.position = Vector2(x, STAT_Y - 6.0)
	add_child(lbl)
	return lbl


func _bar_text(bar: ProgressBar, font_size: int) -> Label:
	# White outlined text centered on a bar, e.g. "20 hp".
	var lbl := Label.new()
	lbl.size = bar.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Pal.PAPER)
	lbl.add_theme_color_override("font_outline_color", Pal.INK)
	lbl.add_theme_constant_override("outline_size", 6)
	bar.add_child(lbl)
	return lbl


func _style_bar(bar: ProgressBar, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	bar.add_theme_stylebox_override("fill", sb)


func _build_hud() -> void:
	# Boss HP: red text only, top center.
	var boss_text := _ransom(BOSS_FONT_SIZE, Pal.RED, 0.6)
	boss_text.size = Vector2(640.0, 70.0)
	boss_text.position = Vector2(320.0, 0.0)
	add_child(boss_text)
	bar_texts["boss"] = boss_text

	# Bottom left: "60 hp" and "20 sp" side by side, same size and baseline.
	# Together they are centered under the left ring.
	bar_texts["player"] = _stat_text(HP_TEXT_X, Pal.GREEN, STAT_W)
	bar_texts["shield"] = _stat_text(SP_TEXT_X, Pal.SKY, STAT_W)


	bar_texts["focus"] = _stat_text(RIGHT_BAR_X, Pal.BLUE)



func _build_rings() -> void:
	for i in DEFS.size():
		var d: Dictionary = DEFS[i]
		var cx := 240.0 + 400.0 * i

		var ring := Ring.new()
		ring.ring_name = d["name"]
		ring.keys = [d["key"]]
		ring.key_label = OS.get_keycode_string(d["key"])
		ring.shrinks_over_time = true
		ring.accent = d["color"]
		ring.size = Vector2(RING_SIZE, RING_SIZE)
		ring.position = Vector2(cx - RING_SIZE * 0.5, RING_TOP)
		add_child(ring)
		ring.resolved.connect(_on_ring_resolved.bind(ring))
		rings[d["name"]] = ring
		stats[d["name"]] = {"hit": 0, "miss": 0}

		var lbl := _ransom(NAME_FONT_SIZE, d["color"], 0.55)
		lbl.size = Vector2(260, 58)
		lbl.position = Vector2(cx - 130.0, RING_TOP + RING_SIZE + 4.0)
		add_child(lbl)
		info[d["name"]] = lbl

		var miss := _ransom(40, d["color"], 0.6)
		miss.bubble = BUBBLE_POPUPS
		miss.text = "MISS"
		miss.size = Vector2(RING_SIZE, 56)
		miss.position = Vector2(cx - RING_SIZE * 0.5, MISS_Y)
		miss.modulate.a = 0.0
		add_child(miss)
		miss_labels[d["name"]] = miss


func _build_end_screen() -> void:
	end_screen = EndPanel.new()
	end_screen.size = Vector2(1280, 720)
	end_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_screen.visible = false
	add_child(end_screen)


func _activate_next(exclude: String) -> void:
	var options: Array = []
	for d in DEFS:
		if d["name"] != exclude:
			options.append(d["name"])
	_activate(options[randi() % options.size()])


func _activate(ring_name: String) -> void:
	active_name = ring_name
	for n in rings:
		rings[n].set_active(n == active_name)


func _process(delta: float) -> void:
	_refresh_labels()

	if shake_left > 0.0:
		shake_left = maxf(0.0, shake_left - delta)
		var k := minf(shake_left / SHAKE_TIME, 1.5)
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * k * shake_power
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
		shake_power = 1.0

	# The boss shakes on its own, harder the bigger the hit.
	# The boss hovers: a slow rise and fall (up only, so it never sinks past the
	# bottom edge) with a hint of sideways drift.
	var t := Time.get_ticks_msec() / 1000.0
	var hover := Vector2(sin(t * 0.8) * HOVER_DRIFT, -(0.5 + 0.5 * sin(t * 1.6)) * HOVER_RISE)
	if boss_shake > 0.5:
		boss.position = boss_base + hover + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * boss_shake
		boss_shake = maxf(0.0, boss_shake - delta * 70.0)
	else:
		boss.position = boss_base + hover
		boss_shake = 0.0

	if not over and not in_special and not in_menu and not tutorial:
		special_timer -= delta
		if special_timer <= 0.0:
			_start_special()
		reverse_timer -= delta
		if reverse_timer <= 0.0:
			reverse_timer = _reverse_wait()
			_boss_reverse()
		shuffle_timer -= delta
		if shuffle_timer <= 0.0:
			shuffle_timer = _shuffle_wait()
			_boss_shuffle_rings()


func _boss_shuffle_rings(force: bool = false) -> void:
	# The boss swaps the rings around: each keeps its own color, name and key, but
	# they trade places on screen, so the left ring may be DEFEND (S) and so on.
	if (in_special or in_menu) and not force:
		return
	var slots := [0, 1, 2]
	for _try in 20:
		slots.shuffle()
		var changed := false
		for i in DEFS.size():
			if slots[i] != slot_of[DEFS[i]["name"]]:
				changed = true
		if changed:
			break
	for i in DEFS.size():
		slot_of[DEFS[i]["name"]] = slots[i]
	for n in rings:
		var cx: float = 240.0 + 400.0 * slot_of[n]
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(rings[n], "position:x", cx - RING_SIZE * 0.5, 0.4)
		tw.tween_property(info[n], "position:x", cx - 130.0, 0.4)
		tw.tween_property(miss_labels[n], "position:x", cx - RING_SIZE * 0.5, 0.4)
		rings[n]._flash(Pal.YELLOW)
	Sfx.play("shuffle")
	_flash_boss()


func _boss_reverse() -> void:
	# The boss flips one live ring's spin mid-turn (solo: the lit ring; co-op: a
	# random one of the three). The ring flashes yellow and the boss flashes
	# white so the player can see who did it.
	if in_special or in_menu:
		return
	var live: Array = []
	for n in rings:
		if rings[n].active:
			live.append(n)
	if live.is_empty():
		return
	rings[live[randi() % live.size()]].reverse()
	Sfx.play("reverse")
	_flash_boss()


func _refresh_labels() -> void:
	for d in DEFS:
		var n: String = d["name"]
		if coop and ring_tags.has(n):
			info[n].text = "%s %s" % [n, ring_tags[n]]
		else:
			info[n].text = n
		info[n].modulate.a = 1.0 if rings[n].active else 0.35
	bar_texts["focus"].text = "%d fp" % focus_charge
	bar_texts["boss"].text = "%d hp" % boss_hp
	bar_texts["player"].text = "%d hp" % player_hp
	bar_texts["shield"].text = "%d sp" % shield


func _show_miss(ring_name: String) -> void:
	_show_ring_text(ring_name, "MISS")


func _show_ring_text(ring_name: String, text: String) -> void:
	# Floats a word above a ring, in that ring's color (MISS, BLOCKED).
	var lbl: Ransom = miss_labels[ring_name]
	lbl.text = text
	if miss_tweens.has(ring_name) and miss_tweens[ring_name]:
		miss_tweens[ring_name].kill()
	lbl.position.y = MISS_Y
	lbl.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", MISS_Y - POPUP_RISE, POPUP_HOLD + POPUP_FADE)
	tw.tween_property(lbl, "modulate:a", 0.0, POPUP_FADE).set_delay(POPUP_HOLD)
	miss_tweens[ring_name] = tw


func _popup(text: String, area: Rect2) -> void:
	# White text at a random point inside `area`, floats up and fades.
	var lbl := _ransom(48, Pal.PAPER, 0.0)  # white text
	lbl.bubble = BUBBLE_POPUPS
	lbl.text = text
	lbl.size = Vector2(360.0, 64.0)
	lbl.position = Vector2(
		randf_range(area.position.x, area.end.x) - lbl.size.x * 0.5,
		randf_range(area.position.y, area.end.y)
	)
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - POPUP_RISE, POPUP_HOLD + POPUP_FADE)
	tw.tween_property(lbl, "modulate:a", 0.0, POPUP_FADE).set_delay(POPUP_HOLD)
	tw.chain().tween_callback(lbl.queue_free)


func _flash_boss() -> void:
	if boss_tween:
		boss_tween.kill()
	var mat := boss.material as ShaderMaterial
	if mat != null:
		# The shader draws the boss, so the flash is a shader value, not modulate.
		mat.set_shader_parameter("flash", 1.0)
		boss_tween = create_tween()
		boss_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.2)
		return
	boss.modulate = Color(1.8, 1.8, 1.8)
	boss_tween = create_tween()
	boss_tween.tween_property(boss, "modulate", Color.WHITE, 0.2)


func _damage_boss(amount: int) -> void:
	boss_hp = maxi(0, boss_hp - amount)
	_popup("+%.1f atk" % amount, BOSS_POP_AREA)
	_flash_boss()
	boss_shake = maxf(boss_shake, clampf(amount * 1.2, 4.0, 30.0))
	if amount >= BIG_HIT:
		# Big hits (focus big damage, cleared special) shake the whole screen harder.
		shake_left = 0.4
		shake_power = 2.2
		Sfx.play("boss_hit_big")
		_hit_stop(0.09)
	if boss_hp <= 0:
		Sfx.play("boss_down")
		boss_shake = 40.0
		shake_left = 0.5
		shake_power = 2.6
		_hit_stop(0.2)
	_check_end()


func _hit_stop(duration: float) -> void:
	# Freezes the game for a split second so hits feel heavy. The timer ignores
	# time scale, so it always ends on time.
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _check_end() -> void:
	if over or transitioning or tutorial:
		return
	if boss_hp <= 0:
		_boss_down()
	elif player_hp <= 0:
		_end(false)


func _boss_down() -> void:
	# Pause everything and offer three upgrades.
	transitioning = true
	in_menu = true
	for n in rings:
		rings[n].set_active(false)
	active_name = ""
	var pool: Array = UPGRADES.duplicate()
	pool.shuffle()
	offered = pool.slice(0, 3)
	upick.start(offered, _key_sets())


func _on_upgrade_chosen(index: int) -> void:
	Sfx.play("upgrade_pick")
	if tutorial:
		tut_step.emit()
		return
	await trans.cover()   # wipe to the next fight
	match offered[index]["id"]:
		"HP":
			max_hp += 15
			player_hp += 15
		"ATK":
			up_atk += 2
		"FOCUS":
			up_focus += 5
		"ZONE":
			for n in rings:
				rings[n].base_zone_width = minf(1.6, rings[n].base_zone_width + 0.1)
		"SLOW":
			for n in rings:
				rings[n].speed = maxf(1.8, rings[n].speed * 0.9)
		"WARD":
			up_shield += 10
	var before := player_hp
	player_hp = mini(max_hp, player_hp + FIGHT_HEAL)
	if player_hp > before:
		_popup("+%.1f hp" % (player_hp - before), PLAYER_POP_AREA)
	run_fight += 1
	_start_fight()
	await trans.uncover()


func _end(win: bool) -> void:
	over = true
	_show_battle(false)    # the end panel sits on the bare backdrop
	for n in rings:
		rings[n].set_active(false)
	active_name = ""
	if win:
		Sfx.play("win")
		last_death_cause = ""
		end_screen.show_result(true, "VICTORY", "")
		return

	Sfx.play("die")
	last_death_cause = death_cause
	deaths += 1
	var bonus := mini(CARRY_HP_MAX, deaths * CARRY_HP_PER_DEATH)
	# Let the killing blow land, wipe to the tutorial boss in red with a line for
	# you, then wipe again to the usual "you died" panel.
	await get_tree().create_timer(0.7).timeout
	await trans.cover()
	boss_art = -1
	boss_tint = -1
	_apply_boss()
	boss.visible = true
	_play_music(TAUNT_MUSIC_PATH)
	taunt.show_line(_taunt_line())
	trans.uncover()
	await taunt.finished
	await trans.cover()
	boss.visible = false
	end_screen.show_result(false, "YOU DIED", "YOU REACHED FIGHT %d\nTHE BOSS REMEMBERS: %s\nNEXT RUN: +%d max hp" % [run_fight, death_cause, bonus])
	trans.uncover()


func _taunt_line() -> String:
	if deaths == REVEAL_DEATHS:
		return TAUNT_REVEAL
	var i := randi() % TAUNTS.size()
	if TAUNTS.size() > 1 and i == last_taunt:
		i = (i + 1 + randi() % (TAUNTS.size() - 1)) % TAUNTS.size()
	last_taunt = i
	return TAUNTS[i]


func _on_ring_resolved(hit: bool, ring) -> void:
	var s: Dictionary = stats[ring.ring_name]
	if hit:
		s["hit"] += 1
		shake_left = SHAKE_TIME  # screen shake rewards good timing
		match ring.ring_name:
			"ATTACK":
				Sfx.play("strike")
				_show_ring_text("ATTACK", "STRIKED")
				_damage_boss(ATTACK_DAMAGE + up_atk)
			"DEFEND":
				Sfx.play("block")
				_show_ring_text("DEFEND", "BLOCKED")  # no other reward: not getting hurt is the reward
			"FOCUS":
				Sfx.play("charge")
				_show_ring_text("FOCUS", "CHARGED")
				_charge_focus()
	else:
		s["miss"] += 1
		Sfx.play("miss")
		_show_miss(ring.ring_name)
		if ring.ring_name == "DEFEND":
			_hurt_player(DEFEND_MISS_DAMAGE, "DEFEND")

	if tutorial:
		_tutorial_ring_resolved(hit, ring)
		return
	if not over and not in_menu and not in_special:
		_resume_rings(ring.ring_name)  # solo: random ring (can repeat). Co-op: this ring restarts.


func _charge_focus() -> void:
	if in_menu:
		return
	var fp_before := focus_charge
	focus_charge = mini(FOCUS_MAX, focus_charge + FOCUS_PER_HIT + up_focus)
	_popup("+%.1f fp" % (focus_charge - fp_before), FOCUS_POP_AREA)
	if focus_charge >= FOCUS_MAX:
		_open_focus_menu()


func _open_focus_menu() -> void:
	# Pops up instantly, like the QTE screen. Rings pause until you pick.
	in_menu = true
	Sfx.play("focus_full")
	for n in rings:
		rings[n].set_active(false)
	active_name = ""
	pick.start(_key_sets())


func _on_focus_chosen(choice: String) -> void:
	in_menu = false
	_spend_focus(choice)
	if tutorial:
		tut_step.emit()
		return
	if not over and not in_menu:
		_resume_rings()


func _spend_focus(choice: String) -> void:
	focus_charge = 0
	match choice:
		"HEAL":
			Sfx.play("heal")
			var hp_before := player_hp
			player_hp = mini(max_hp, player_hp + HEAL_AMOUNT)
			_popup("+%.1f hp" % (player_hp - hp_before), PLAYER_POP_AREA)
		"BIG DAMAGE":
			_damage_boss(BIG_DAMAGE)
		"SHIELD":
			Sfx.play("shield_up")
			var before := shield
			shield = mini(MAX_SHIELD, shield + SHIELD_PAYOFF + up_shield)
			_popup("+%.1f sp" % (shield - before), PLAYER_POP_AREA)


func _hurt_player(amount: int, cause: String) -> int:
	# Shield soaks damage first. Returns how much the shield absorbed.
	# `cause` is remembered: it is what the boss opens with next run if you die.
	var absorbed := mini(shield, amount)
	shield -= absorbed
	var lost := amount - absorbed
	player_hp = maxi(0, player_hp - lost)
	if lost > 0:
		if not tutorial:
			death_cause = cause   # the tutorial must not teach the boss anything
		Sfx.play("player_hurt")
	if absorbed > 0:
		_popup("-%.1f sp" % absorbed, PLAYER_POP_AREA)
	if lost > 0:
		_popup("-%.1f hp" % lost, PLAYER_POP_AREA)
	_check_end()
	return absorbed


func _start_special() -> void:
	in_special = true
	Sfx.play("special_warn")
	for n in rings:
		rings[n].set_active(false)
	active_name = ""
	shake_left = 0.4
	var length := randi_range(3, 4)
	qte.start(length, length * 1.2 + 0.8)


func _on_special_finished(success: bool) -> void:
	in_special = false
	if success:
		Sfx.play("special_clear")
		shake_left = 0.4
		_damage_boss(SPECIAL_REWARD)
	else:
		Sfx.play("special_fail")
		_hurt_player(SPECIAL_DAMAGE, "SPECIAL")
	special_timer = _special_wait()
	if tutorial:
		tut_step.emit()
		return
	if not over and not in_menu:
		_resume_rings()


func _input(event: InputEvent) -> void:
	# Esc opens the pause menu mid-fight or mid-tutorial. This runs before the
	# special / pick screens see the key, so it works even while they are open.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if over or lobby.visible or pause_menu.visible:
			return
		get_viewport().set_input_as_handled()
		pause_menu.open()


func _on_pause_toggled(paused: bool) -> void:
	# Esc pauses the music too, and Resume picks it up where it stopped.
	if is_instance_valid(music_player):
		music_player.stream_paused = paused


func _on_pause_chose(index: int) -> void:
	if index == 1:
		pause_menu.close()
		_exit_tutorial()   # also the way back to the main menu from a normal fight
	else:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if over:
		if not end_screen.visible:
			return   # still in the boss's speech
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_reload_scene()
		elif event.keycode == KEY_ESCAPE:
			players = 0   # back to the lobby: change player count and roles
			roles = []
			_reload_scene()
		return
