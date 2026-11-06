# OLOUKIK DUNGEON

*You die. You wake up. You fight again. Someone is making sure of it.*

A **Persona-styled boss battler** built around timing rings, with local co-op and a story told through your deaths. Every fight is a timing duel against a boss who gets stronger each round, and a run only ends when you fall. Made in 48 hours by team **CrossStitch** for **Game Jam Plus 26/27**, using the themes **One more time**, **Something's off** and **Better together**.

> **Status:** in the Incubation stage of Game Jam Plus, being improved for the Continental Semifinals. Boss art, music and sound effects are still being added, so some files listed below may be placeholders.

**Play it in the browser (no download):** https://tanzeem-ahmed-sakib.itch.io/oloukik-dungeon

---

## Contents

- [How it plays](#how-it-plays)
- [Controls](#controls)
- [The three themes](#the-three-themes)
- [Visual design](#visual-design)
- [File structure](#file-structure)
- [Setup (Godot 4.x)](#setup-godot-4x)
- [Exporting for the web](#exporting-for-the-web)
- [Known gotchas](#known-gotchas)
- [Audio files](#audio-files)
- [Credits](#credits)
- [Roadmap](#roadmap)
- [Contact](#contact)

---

## How it plays

1. The title screen shows once per launch. Press any key to reach the menu: **Tutorial**, **1 Player**, **2 Players**, **3 Players** or **Quit**.
2. In co-op, each player picks a role (**Attack**, **Defend** or **Focus**) with their own keys. With 2 players the unpicked role is shared, and with 3 players the last player gets the role left. A solo player handles all three rings.
3. In a fight, **one ring is active at a time**. A needle rotates around the ring, and the player presses that ring's key while the needle is inside the target zone.
   - **Attack** hit: damages the boss.
   - **Defend** hit: blocks. Missing a Defend ring hurts you.
   - **Focus** hit: charges a bar. When it is full, a pick screen opens: **big damage**, **shield** or **heal**.
   - Shield comes only from Focus and soaks all damage you take.
4. The boss has no normal attack. Every so often it fires a **special**: a string of 3 or 4 key prompts under a timer. Clear it for big damage to the boss. Fail it and you take damage.
5. Mid-fight, the boss can **reverse a ring's spin** and **swap where the rings sit on screen**. The muscle memory you just built turns against you.
6. After each win you pick **1 of 3 upgrades**, then the next boss arrives with more health and faster timers.
7. When you die, the run ends. A **wipe transition** leads to the taunt screen, where the tutorial boss speaks a one-liner. Press Enter or Space for **one more time**.
8. Between runs, every death gives **+10 max HP** for all later runs, and the boss **remembers what killed you** and opens the next run with that move.
9. On the **10th death** the boss drops the act and reveals that he is the one who trapped you in this loop.

### Balance numbers

| Setting | Value |
| --- | --- |
| Boss HP, first fight | 50 |
| Boss HP growth | +50 per fight |
| Boss HP multiplier, 1 / 2 / 3 players | 1.0 / 1.8 / 2.5 |
| Death carry-over | +10 max HP per death |
| Boss reveal | on death 10 |

These live as constants at the top of `scripts/main.gd` (`BOSS_MAX_HP`, `BOSS_HP_GROWTH`, `COOP_BOSS_HP_MULT`, `REVEAL_DEATHS`).

---

## Controls

Keyboard only.

| Player | Attack ring | Defend ring | Focus ring |
| --- | --- | --- | --- |
| Player 1 | A | S | D |
| Player 2 | J | K | L |
| Player 3 | Left arrow | Down arrow | Right arrow |

| Key | Action |
| --- | --- |
| Up / Down (or W / S) | Move in menus |
| Enter or Space | Confirm, skip text, start the next run |
| 1, 2, 3 | Pick the player count in the lobby |
| A / S / D (any player's keys) | Choose on the Focus and upgrade screens |
| Esc | Pause menu (Resume, Main Menu, Quit). Also pauses the music |
| Esc on the end screen | Back to player selection |

---

## The three themes

| Theme | In the game |
| --- | --- |
| **One more time** | Runs never end in a win, only in a death. The retry prompt, the carry-over HP and the boss who remembers how you died all push you to go again. |
| **Something's off** | The boss reverses a ring's spin, swaps where the rings sit on screen, and fires specials, so rhythm you learned stops working. |
| **Better together** | Local co-op splits the rings between two or three players and scales the boss up to match. |

---

## Visual design

The look borrows from **Persona** and **Shin Megami Tensei**: tilted panels, slanted wipes, sharp type and a strict red, white and black base. Everything is built in code with `Control` nodes and `_draw()`, so there are no UI image assets.

| Role | Hex | In `palette.gd` |
| --- | --- | --- |
| Black (panels, outlines) | `#1C1A21` | `INK` |
| Deep black (screen background) | `#120F17` | `DEEP` |
| White (text, edges) | `#F0EBE0` | `PAPER` |
| Red (attack, boss, danger) | `#D94F4A` | `RED` |
| Green (defend, health, heal) | `#66C480` | `GREEN` |
| Blue (focus) | `#5E94E0` | `BLUE` |
| Sky (shield) | `#8CCCE6` | `SKY` |
| Yellow (reversal flash) | `#F0D66B` | `YELLOW` |

**Boss tints.** Each fight picks a random boss drawing and a random fill color from a pool of hues the UI never uses, so a boss is never mistaken for a button or a ring. The pool is `VIOLET #9E75DB`, `AMBER #EB9442`, `TEAL #52ADA8`, `ORCHID #CC7AC7` and `LIME #ADC25C`. The tutorial boss is always UI red. Picks come from shuffled bags, so nothing repeats back to back.

Hex values are rounded from the Godot `Color` values in `scripts/palette.gd`. That file is the single place to change a color.

**Boss rendering.** A small `canvas_item` shader draws the boss in layers: a white border, a color fill inside the outline, your ink lines untouched on top, plus grain and a white hit flash. The fill area is found in GDScript by flood-filling a low-resolution copy of the drawing from its edges, and the result is cached per drawing.

---

## File structure

```
res://
├── project.godot
├── scenes/
│   └── main.tscn                # the only scene; everything else is built in code
├── assets/
│   ├── boss-1.png ...           # fight bosses (boss-1 to boss-11 are looked for)
│   ├── boss-tutorial.png        # tutorial boss, and the one who taunts you after a death
│   ├── battle-theme.ogg         # fights and the tutorial
│   ├── menu-theme.ogg           # title and menu screens
│   ├── taunt-theme.ogg          # the taunt screen after a death
│   └── sfx/                     # optional sound effects, one file per name
└── scripts/
    ├── main.gd                  # fight flow, bosses, tutorial, wipes, music, pause
    ├── lobby.gd                 # title screen, menu, player count, role selection
    ├── ring.gd                  # one timing ring (needle, target zone, reverse)
    ├── qte_special.gd           # the boss's special: key prompts under a timer
    ├── focus_pick.gd            # big damage / shield / heal pick screen
    ├── upgrade_pick.gd          # pick 1 of 3 upgrades between fights
    ├── taunt_panel.gd           # typed-out boss dialogue box
    ├── tip_panel.gd             # tutorial hint boxes
    ├── end_panel.gd             # game over screen
    ├── pause_menu.gd            # Esc menu
    ├── wipe.gd                  # red / white / black slanted transition
    ├── backdrop.gd              # halftone background
    ├── ransom_text.gd           # cut-out lettering for the title
    ├── ui_panel.gd              # tilted panel and tag drawing helpers
    ├── palette.gd               # every color in one place
    └── sfx.gd                   # one-shot sound player
```

### What each script owns

| Script | Role |
| --- | --- |
| `main.gd` | The biggest file. Builds the fight scene, runs the tutorial as a script of waits and hint boxes, picks and draws bosses, handles the run loop, death and taunt flow, music, pausing and scene reloads. |
| `lobby.gd` | Title and menu screens, player count, role selection. Emits `started(player_count, roles)`. |
| `ring.gd` | One QTE ring. Only the active ring runs. A press while the needle is outside the zone is a miss with a short lockout. |
| `qte_special.gd` | The "Something's off" special. Press the keys in order. A wrong key or running out of time fails it. |
| `focus_pick.gd`, `upgrade_pick.gd` | The two pick screens. Input is ignored for a split second after opening so a mashed ring key does not pick by accident. |
| `wipe.gd` | The transition. `cover()` and `uncover()` sweep the screen. After a scene reload, `Wipe.start_covered` makes the new scene start covered and wipe away. |
| `sfx.gd` | Plays one-shot sounds with a little random pitch. A missing file is skipped silently. |
| `palette.gd` | The color constants listed above. |

---

## Setup (Godot 4.x)

1. Install [Godot 4.7](https://godotengine.org/download).
2. Clone this repository.
3. In Godot choose **Import** and pick `project.godot`.
4. Run the project. The main scene is `scenes/main.tscn`.

There are no plugins, no autoloads and no external libraries. The project uses the **Compatibility** renderer so it also runs in browsers. Window size is 1280 x 720.

To add a boss, drop `boss-3.png`, `boss-4.png` and so on into `assets/`. The game finds them by name and adds them to the random pool with no code change.

---

## Exporting for the web

1. Install the Web export templates and add a **Web** preset (*Project, Export*).
2. **Turn Thread Support off.** itch.io and plain static hosts cannot send the headers a threaded build needs.
3. Export to a folder as **`index.html`**. The file must have exactly that name.
4. Zip the **contents** of the folder so `index.html` sits at the top level of the zip.
5. On itch.io set *Kind of project* to **HTML**, upload the zip, tick **"This file will be played in the browser"** and set the viewport to **1280 x 720**.

Web notes:

- Remove or hide **Quit** on web, because it does nothing in a browser tab.
- Browser fullscreen takes the **Esc** key, so pausing may not work there.
- The player has to click the game once before it receives key presses.
- The game needs a keyboard, so it does not work on phones.

---

## Known gotchas

- **State survives scene reloads.** Retrying reloads the scene, so run data lives in `static var`s in `main.gd` (deaths, player count, roles, last death cause, boss art and tint, the music player, the mask cache). These reset only when the game closes.
- **The first appearance of each boss builds its fill mask in GDScript.** In a browser, where GDScript runs slower, this can cause a brief hitch the first time a boss appears. It is cached after that.
- **Pausing.** The game pauses with `get_tree().paused`. The pause menu, the wipe and the music player use `PROCESS_MODE_ALWAYS` so they keep working. The tutorial freezes the rings and pick screens separately with `PROCESS_MODE_DISABLED`.
- **Missing audio is not an error.** Sound effects and the extra music tracks are skipped if the files are absent, so you can add them one at a time.
- **The window title still says "Ringfall".** That is the project's old working name in `project.godot`. Change it under *Project Settings, Application, Config, Name*.
- **No mouse support, by design.** Menus, pick screens and the pause menu are keyboard only.

---

## Audio files

The game looks for three music tracks in `assets/` and sound effects in `assets/sfx/` (`.ogg`, `.wav` or `.mp3`, tried in that order).

**Sound effect names** (all optional): `block`, `boss_down`, `boss_hit_big`, `charge`, `die`, `focus_full`, `heal`, `key_fail`, `key_ok`, `miss`, `player_hurt`, `reverse`, `select`, `shield_up`, `shuffle`, `special_clear`, `special_fail`, `special_warn`, `strike`, `talk`, `transition_in`, `transition_out`, `upgrade_pick`, `win`.

Per-sound volume tweaks and the random pitch range are at the top of `scripts/sfx.gd`.

---

## Credits

**Team CrossStitch**

- [Tanzeem Ahmed](https://tanzeem-ahmed-sakib.itch.io/): Game Director
- [Fatima Mahzabin](https://itch.io/profile/tonton03): Art Director

**Music** by Jens Vide:

- [Showtime](https://jens-vide.itch.io/showtime)
- [Town Square](https://jens-vide.itch.io/town-square)
- [Tokyo Map](https://jens-vide.itch.io/tokyo-map)

**Sound effects** from [Pixabay](https://pixabay.com/).

**Inspired by** Persona and Shin Megami Tensei (style and music), Hades (storytelling through death) and Balatro (making simple actions feel rewarding).

---

## Roadmap

- [x] Core fight: rings, specials, Focus and upgrade picks
- [x] Endless runs with carry-over HP and a boss who remembers how you died
- [x] Local co-op for 1 to 3 players
- [x] Tutorial boss, taunt screen and the death-ten reveal
- [x] Ring spin reversal and ring position swaps, both shown in the tutorial
- [x] Wipe transitions between screens
- [ ] Boss art for more bosses, each with its own signature rule
- [ ] Original soundtrack and the full sound effect set
- [ ] Controller support
- [ ] Fix web lag by building all boss fill masks ahead of time
- [ ] Hit feedback: screen shake, hit-stop, timing grades
- [ ] Persistent progress that survives closing the tab
- [ ] Accessibility: wider timing option, shape-coded rings, rebindable keys
- [ ] Dungeon exploration between fights, inspired by Persona and Darkest Dungeon
- [ ] Update the design document

---

## Contact

- itch.io: https://tanzeem-ahmed-sakib.itch.io/
- Email: tasakib69@gmail.com
