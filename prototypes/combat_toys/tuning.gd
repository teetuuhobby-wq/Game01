extends RefCounted
## TUNING for both combat toys. Change a number, save, and run the toy again.

# ---------- Toy A: action ----------
# Every red warning mark is drawn from the same number its hit uses, so the red is exactly
# where you get hurt: if your feet are on the red when it strikes, you're hit; off it, you're safe.
const A_PLAYER_HEARTS := 5
const A_PLAYER_SPEED := 6.5          # metres per second
const A_DODGE_SPEED := 13.0          # how fast the dodge roll moves you
const A_DODGE_TIME := 0.32           # seconds the roll lasts
const A_DODGE_SAFE := 0.28           # seconds of the roll where nothing can hit you
const A_DODGE_COOLDOWN := 0.45
const A_SWING_TIME := 0.32           # one sword swing, start to end
const A_REACH := 1.9                 # how far the sword reaches past the beetle's shell (metres)
const A_COMBO_DAMAGE := [1, 1, 2]    # damage of the 1st, 2nd and 3rd swing in a row
const A_STUCK_MULTIPLIER := 2        # damage is multiplied by this while the beetle is stuck
const A_HURT_SAFE := 1.0             # seconds you can't be hit again after getting hurt
const A_INPUT_BUFFER := 0.2          # a click or roll pressed a moment too early is remembered this long
                                     # (and through the whole hit-freeze or stagger), then used as soon as you can

const A_BEETLE_HEALTH := 50
const A_BEETLE_SPEED := 3.2          # walking speed (enraged: x1.2)
const A_LUNGE_WINDUP := 0.9          # seconds of warning before it charges (enraged: x0.8)
const A_LUNGE_SPEED := 15.0
const A_LUNGE_TIME := 0.6
const A_LUNGE_HALF_WIDTH := 1.4      # the red strip reaches this far to each side of the charge line,
                                     # and you're hit only if you stand on it (your feet, not your elbows)
const A_STUCK_TIME := 1.4            # seconds it's stuck after a charge (your chance!)
const A_SNAP_WINDUP := 0.55          # warning before a close bite
const A_SNAP_RANGE := 3.4           # how far the red bite fan reaches (from just in front of its head)
const A_SNAP_ANGLE := 55.0           # the fan's width: degrees to each side of straight ahead
const A_BURROW_EVERY := 9.0          # once enraged: seconds between burrow attacks
const A_ERUPT_WARNING := 0.9         # how long the red circle shows before it bursts out
const A_ERUPT_RADIUS := 2.6          # size of that red circle: stand inside it when it bursts and you're hit
const A_ENRAGE_AT := 0.5             # enraged below this share of its health

# ---------- Toy B: turn-based ----------
const B_ENERGY := 3                  # energy each turn
const B_HAND := 5                    # cards drawn each turn
const B_YOU_HEALTH := 24
const B_BRAM_HEALTH := 30
const B_BEETLE_HEALTH := 80
const B_BEETLE_SHELL := 6            # shell it starts with (soaks up damage first)
# The beetle's attacks (damage, when they happen) and the cards are listed at the top of turns_rules.gd.
