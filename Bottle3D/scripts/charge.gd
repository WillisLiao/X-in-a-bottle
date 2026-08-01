class_name Charge
extends RefCounted

## How many of them are on the island.
##
## Stillness brings them; moving the phone sends them away, and sends them away
## much faster than stillness brings them. That asymmetry is the whole
## mechanism: a ten second glance at a notification has to cost real progress,
## or there is no reason to leave the phone alone.
##
## Touching the screen is deliberately *not* a disturbance. It used to be, and
## that punished turning the island round to see what was happening on the far
## side - it charged you for paying attention, which is the opposite of the
## point. What breaks a stretch of work is picking the phone up, and that is
## what the accelerometer measures.

## Perfect stillness needed for a full crew.
const FILL_SECONDS := 15.0 * 60.0

## Disturbance drains this many times faster than stillness fills.
const DRAIN_MULTIPLIER := 12.0

## Movement below this is a desk, a passing lorry, someone walking past. Above
## it is a hand. In G, matching the native build.
const AGITATION_THRESHOLD := 0.035

## After a disturbance ends, the bottle waits before rebuilding. Without this it
## starts refilling the instant the phone lands, which makes putting it down
## feel like it undoes picking it up.
const SETTLE_SECONDS := 2.5

## The island is never empty. Somebody is there when it opens, so the first
## thing seen is the place itself rather than a black screen to be earned.
const STARTING_OBJECTS := 2

var level := 0.0
var is_disturbed := false

var _settling := 0.0


func update(delta: float, agitation: float, touched: bool) -> void:
	var disturbed := touched or agitation > AGITATION_THRESHOLD
	is_disturbed = disturbed

	if disturbed:
		_settling = SETTLE_SECONDS
		level = maxf(0.0, level - delta * DRAIN_MULTIPLIER / FILL_SECONDS)
		return

	if _settling > 0.0:
		_settling = maxf(0.0, _settling - delta)
		return

	level = minf(1.0, level + delta / FILL_SECONDS)


## How many of them are here right now, out of `capacity`.
##
## Front-loaded hard. A linear count needs over a minute of stillness before
## anything appears at all, which is indistinguishable from the app being
## broken.
##
## The exponent was 0.45 first, which put the third object at 52 seconds and the
## fourth at nearly two minutes - working, but slow enough that it read as
## nothing happening. At 0.30 the early arrivals land at roughly 13s, 39s and
## 89s, so the bottle is visibly alive in the first minute, while a full one
## still costs the entire fifteen. The point of the curve is that early feedback
## is cheap and the last few are expensive.
const CURVE := 0.30

func population(capacity: int) -> int:
	var grown := 0
	if level > 0.0:
		grown = int(round(float(capacity) * pow(level, CURVE)))
	return maxi(STARTING_OBJECTS, grown)
