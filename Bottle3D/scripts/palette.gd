class_name Palette
extends RefCounted

## The colour system, in one place.
##
## One blue. An earlier pass gave each bolt its own discharge colour - violet,
## cyan, a rare amber - on the reasoning that real plasma is coloured by the gas
## it burns in. It was rejected, and rightly: a bottle of mixed colours is a
## palette on display, while a bottle of one colour is a single thing seen
## clearly. The restraint is the point.

const VOID := Color("070A12")
const DEEP_INDIGO := Color("131B2F")

## The hot filament. Always this, whatever the sheath is doing around it.
const CORE := Color("EAF2FF")

## The discharge itself.
const PLASMA := Color("4A7BF7")


static func gas() -> Color:
	return PLASMA


## A bolt held a long time cools toward the fog it hangs in. Still the same
## blue, just further into the dark: this is age, not a second colour.
static func cooled(gas_color: Color, age: float) -> Color:
	return gas_color.lerp(DEEP_INDIGO, age * 0.75)
