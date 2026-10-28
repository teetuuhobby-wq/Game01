extends RefCounted
## THE DAY CLOCK, as plain rules (no pictures, so tests can check it on its own).
## Which day it is and what time. A day runs from 7:00 to 19:00 in DAY_MINUTES real
## minutes (tuning.gd). At 19:00 the screen fades to dark, a "Day 1 done" card shows,
## and Day 2 starts at 7:00. T jumps an hour ahead. day_view.gd shows all of this.
## Also the town's timetable from town_data.gd, as questions anything can ask: is a
## place open, how full is the market, where is a resident heading at this hour.
## Hours are numbers: 8.5 = half past eight.

const T := preload("res://tuning.gd")
const Town := preload("res://town_data.gd")

const FIRST_HOUR := 7.0      # morning
const LAST_HOUR := 19.0      # evening: the day ends here
const BELL_HOUR := 18.0      # the evening bell
const FADE_SECONDS := 1.5    # the fade to dark at the end of the day, and back in
const CARD_SECONDS := 3.0    # how long the "Day 1 done" card shows

enum Phase { DAY, FADE_OUT, CARD, FADE_IN }

var day := 1
var hour := T.DAY_START_HOUR
var frozen := false          # tests stop the clock (T still works)
var phase := Phase.DAY
var phase_t := 0.0           # seconds into the fade or the card


## Game hours that pass per real second.
static func hours_per_second() -> float:
	return (LAST_HOUR - FIRST_HOUR) / (T.DAY_MINUTES * 60.0)


## Moves the clock on by delta real seconds. Gives back what happened, in order:
##   "evening_bell" - it just struck 18:00
##   "day_over"     - it's 19:00: the fade to dark begins
##   "new_day"      - the screen is dark: it's now the next day, 7:00 (the morning bell)
##   "awake"        - the picture has faded back in
func advance(delta: float) -> Array:
	var events := []
	match phase:
		Phase.DAY:
			if not frozen:
				events.append_array(_move_to(hour + delta * hours_per_second()))
		Phase.FADE_OUT:
			phase_t += delta
			if phase_t >= FADE_SECONDS:
				phase = Phase.CARD
				phase_t = 0.0
		Phase.CARD:
			phase_t += delta
			if phase_t >= CARD_SECONDS:
				day += 1
				hour = FIRST_HOUR
				phase = Phase.FADE_IN
				phase_t = 0.0
				events.append("new_day")
		Phase.FADE_IN:
			phase_t += delta
			if not frozen:
				hour = minf(hour + delta * hours_per_second(), LAST_HOUR)
			if phase_t >= FADE_SECONDS:
				phase = Phase.DAY
				phase_t = 0.0
				events.append("awake")
	return events


## T: jumps an hour ahead (not past 19:00, which ends the day). Only during the day.
func skip_hour() -> Array:
	if phase != Phase.DAY:
		return []
	return _move_to(hour + 1.0)


## Sets the time straight away (tests, screenshots, --hour, a replay's start).
func set_time(h: float, d := -1) -> void:
	hour = clampf(h, FIRST_HOUR, LAST_HOUR - 0.001)
	if d > 0:
		day = d
	phase = Phase.DAY
	phase_t = 0.0


func _move_to(h: float) -> Array:
	var events := []
	var was := hour
	hour = minf(h, LAST_HOUR)
	if was < BELL_HOUR and hour >= BELL_HOUR:
		events.append("evening_bell")
	if hour >= LAST_HOUR:
		phase = Phase.FADE_OUT
		phase_t = 0.0
		events.append("day_over")
	return events


## How dark the screen is (0 = clear, 1 = black), for the fade.
func darkness() -> float:
	match phase:
		Phase.FADE_OUT:
			return clampf(phase_t / FADE_SECONDS, 0.0, 1.0)
		Phase.CARD:
			return 1.0
		Phase.FADE_IN:
			return 1.0 - clampf(phase_t / FADE_SECONDS, 0.0, 1.0)
	return 0.0


## The time as a clock shows it, in 10-minute steps: "8:30".
static func clock_text(h: float) -> String:
	var m := floori(h * 6.0 + 0.0001) * 10   # minutes since midnight, in 10s
	return "%d:%02d" % [m / 60, m % 60]


# ---------- The city over the day ----------

## How fast the city walks (1 = normal, 0 = stopped): it slows to a stop from 18:00
## to 18:45, and starts again after it has stood up in the morning (7:15 to 7:30).
static func walk_rate_at(h: float) -> float:
	if h < 12.0:
		return smoothstep(7.25, 7.5, h)
	return 1.0 - smoothstep(18.0, 18.75, h)


## How far the city has knelt (0 = standing tall, 1 = knelt for the night): it kneels
## from 18:45 to 19:00 and stands up again from 7:00 to 7:15.
static func kneel_at(h: float) -> float:
	if h < 12.0:
		return 1.0 - smoothstep(7.0, 7.25, h)
	return smoothstep(18.75, 19.0, h)


## How lit-up the lanterns and windows are for the evening (0 = daytime, 1 = evening):
## from about 17:30.
static func evening_at(h: float) -> float:
	return smoothstep(17.4, 18.6, h)


# ---------- The town's timetable (town_data.gd) ----------

## True if the place has opening hours at all (the guild, the store...).
static func has_hours(place: String) -> bool:
	return Town.OPEN_HOURS.has(place)


static func is_open(place: String, h: float) -> bool:
	if not Town.OPEN_HOURS.has(place):
		return true
	var o: Dictionary = Town.OPEN_HOURS[place]
	return h >= float(o["open"]) and h < float(o["close"])


## True in a place's busiest hours (places without busy hours are never "busy").
static func is_busy(place: String, h: float) -> bool:
	var o: Dictionary = Town.OPEN_HOURS.get(place, {})
	if not o.has("busy"):
		return false
	return is_open(place, h) and h >= float(o["busy"][0]) and h < float(o["busy"][1])


static func has_busy_hours(place: String) -> bool:
	return Town.OPEN_HOURS.get(place, {}).has("busy")


## What a resident says, or a board shows, at a closed place.
static func closed_line(place: String, h: float) -> String:
	var lines: Dictionary = Town.CLOSED_LINES.get(place, Town.CLOSED_LINES["default"])
	var o: Dictionary = Town.OPEN_HOURS.get(place, {"open": 8.0})
	var opens := float(o["open"])
	var line: String = lines["before"] if h < opens else lines["after"]
	return line.replace("{open}", clock_text(opens))


## How full the market is at this hour (0..1), between the times in MARKET_CROWD.
static func crowd_share(h: float) -> float:
	var c: Array = Town.MARKET_CROWD
	if h <= c[0][0]:
		return c[0][1]
	for i in range(1, c.size()):
		if h <= c[i][0]:
			return lerpf(c[i - 1][1], c[i][1], (h - c[i - 1][0]) / (c[i][0] - c[i - 1][0]))
	return c[c.size() - 1][1]


## Where a resident is heading at this hour (their routine in town_data.gd), or their
## usual place if they have no routine.
static func heading(id: String, h: float) -> String:
	var r: Array = Town.ROUTINES.get(id, [])
	if r.is_empty():
		return Town.CAST.get(id, {}).get("where", "")
	var place: String = r[0][1]
	for step in r:
		if h >= float(step[0]):
			place = step[1]
	return place
