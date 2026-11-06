extends RefCounted
## The game's colors in one place. Softer than pure black / white / primaries so
## nothing glares. Change a value here and it changes everywhere.

const INK := Color(0.11, 0.10, 0.13)       # panels, text outlines (the "black")
const DEEP := Color(0.07, 0.06, 0.09)      # screen background, a bit darker than panels
const PAPER := Color(0.94, 0.92, 0.88)     # the "white": text, edges, tags
const RED := Color(0.85, 0.31, 0.29)       # attack, boss, danger
const GREEN := Color(0.40, 0.77, 0.50)     # defend, hp, heal
const BLUE := Color(0.37, 0.58, 0.88)      # focus
const SKY := Color(0.55, 0.80, 0.90)       # shield
const YELLOW := Color(0.94, 0.84, 0.42)    # reversal flash

# Boss tints. Hues the UI never uses, so a recolored boss is never mistaken for
# a button, a bar or a ring. (Boss art itself should avoid the UI colors above.)
const VIOLET := Color(0.62, 0.46, 0.86)
const TEAL := Color(0.32, 0.68, 0.66)
const ORCHID := Color(0.80, 0.48, 0.78)
const LIME := Color(0.68, 0.76, 0.36)
const AMBER := Color(0.92, 0.58, 0.26)
