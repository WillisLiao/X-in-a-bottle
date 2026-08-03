extends RefCounted

## One identity registry keeps saved, roster, bot, and presentation facts in
## sync.  Frame data is cosmetic metadata and intentionally has no gameplay
## values, collision values, or authority behavior.

const DEFAULT_ID := "vane"
const ORDERED_IDS := ["vane", "cradle", "keel", "loom"]
const FACTS := {
	"vane": {"name": "VANE", "purpose": "ROUTE READER", "preference": "run_seed", "glyph": "V"},
	"cradle": {"name": "CRADLE", "purpose": "SIGNAL RECEIVER", "preference": "relay_support", "glyph": "C"},
	"keel": {"name": "KEEL", "purpose": "LINE HOLDER", "preference": "escort", "glyph": "K"},
	"loom": {"name": "LOOM", "purpose": "SIGHT KEEPER", "preference": "intercept_sighting", "glyph": "L"},
}

static func valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and FACTS.has(str(value).to_lower())

static func canonical_id(value: Variant) -> String:
	var candidate := str(value).to_lower()
	return candidate if FACTS.has(candidate) else DEFAULT_ID

static func facts(value: Variant) -> Dictionary:
	return (FACTS[canonical_id(value)] as Dictionary).duplicate(true)

static func bot_frame_for_slot(slot: int, team_size: int) -> String:
	if team_size <= 1:
		return DEFAULT_ID
	return ORDERED_IDS[mini(maxi(slot, 0), ORDERED_IDS.size() - 1)]

static func glyph(value: Variant) -> String:
	return str(facts(value).get("glyph", "V"))
