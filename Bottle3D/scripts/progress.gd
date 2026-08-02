class_name Progress
extends RefCounted

## What survives being put down.
##
## A house takes a week. Nobody focuses for a week without stopping, so the
## build has to outlive the session or the whole premise collapses into a
## fifteen-minute toy. Closing the app costs nothing.
##
## The records are still one per region, and that is not a leftover from the
## five islands - a region has its own site, its own queue and its own hours,
## and it always will. What changed on 2026-08-02 is that the regions are places
## in one world rather than five parallel saves, so there is now a world-level
## record on top of them: which regions have been settled. See `Region` and
## `handoffs/DESIGN-one-world.md`.
##
## What is deliberately *not* saved is any notion of time passing while you were
## away. There is no offline progress and there will not be. The only thing that
## moves this app forward is an app-open region, and a hobbit who laid a joist
## while you were asleep would be a lie about what you did.
##
## Six things are kept per region.
##
## **The queue.** Which works are finished. The house is rebuilt from this on
## load, instantly and silently, so opening an island on the fourth day shows you
## the fourth day.
##
## **The stock.** How much of each material is lying about. Redistributed to
## sensible heaps rather than restored heap-by-heap: an elf's beliefs about where
## things are should not survive a restart, because that ignorance is cheap to
## recreate and expensive to store.
##
## **The residents.** Every elf is generated from one integer, so keeping the
## integers brings back the same people - the tall one with the crooked hat, the
## one that always ends up at the kiln. Their formed affinities come back with
## them, so the specialisms they grew into on Tuesday are still theirs on
## Saturday. This is the cheapest interiority in the whole app and it is
## possibly the most effective: recognising somebody is most of believing in
## them.
##
## **The hours.** How much app-open time this region has had, plus where it is
## in the work-and-rest cycle.
##
## **The feed.** Its two-hour coastline charge and any remaining meal haste.
## The food itself is a transient scene, so restarting does not leave a meal
## hanging in the air or a hobbit holding an object whose owner is gone.
##
## **The paths.** Where they have walked, a byte per patch of ground. The one
## record in here that is a picture rather than a number, and the only one the
## user ever sees directly - it is the ground itself. See `Wear`.
##
## The hours are the one number the app shows, and it is deliberately a *spent*
## number rather than a remaining one. A countdown invites you to wait it out; a
## clock that only moves while you are working is a record of what you did.

const PATH := "user://hobbitle.cfg"

## What the save was called before the rename. Read once, if the new one is not
## there yet, and written back under the new name at the next flush. On iOS this
## does nothing - a new bundle identifier means a new container and an empty
## one - but on desktop it means a week of building does not evaporate over a
## change of filename.
const OLD_PATH := "user://elvle.cfg"

static var _cfg: ConfigFile = null


static func _open() -> ConfigFile:
	if _cfg != null:
		return _cfg
	_cfg = ConfigFile.new()
	# A missing file is the normal first-run case, not an error.
	if _cfg.load(PATH) != OK:
		_cfg.load(OLD_PATH)
	return _cfg


static func flush() -> void:
	if _cfg != null:
		_cfg.save(PATH)


static func _key(island: int) -> String:
	return "island%d" % island


static func read(island: int) -> Dictionary:
	var cfg := _open()
	var k := _key(island)
	return {
		"done": PackedInt32Array(cfg.get_value(k, "done", PackedInt32Array())),
		"stock": PackedInt32Array(cfg.get_value(k, "stock",
			_zeroes(Plan.KIND_COUNT))),
		"focus": float(cfg.get_value(k, "focus", 0.0)),
		"cycle": float(cfg.get_value(k, "cycle", 0.0)),
		"rest": float(cfg.get_value(k, "rest", 0.0)),
		"feed": float(cfg.get_value(k, "feed", 0.0)),
		"haste": float(cfg.get_value(k, "haste", 0.0)),
		"seeds": PackedInt32Array(cfg.get_value(k, "seeds", PackedInt32Array())),
		"affinity": cfg.get_value(k, "affinity", {}),
		"wear": cfg.get_value(k, "wear", ""),
		"journey": int(cfg.get_value(k, "journey", -1)),
	}


static func write(island: int, state: Dictionary) -> void:
	var cfg := _open()
	var k := _key(island)
	cfg.set_value(k, "done", state["done"])
	cfg.set_value(k, "stock", state["stock"])
	cfg.set_value(k, "focus", state["focus"])
	cfg.set_value(k, "cycle", state["cycle"])
	cfg.set_value(k, "rest", state["rest"])
	cfg.set_value(k, "feed", state["feed"])
	cfg.set_value(k, "haste", state["haste"])
	cfg.set_value(k, "seeds", state["seeds"])
	cfg.set_value(k, "affinity", state["affinity"])
	cfg.set_value(k, "wear", state["wear"])
	cfg.set_value(k, "journey", state["journey"])


static func last_island() -> int:
	return int(_open().get_value("app", "island", Region.HOME))


static func set_last_island(island: int) -> void:
	_open().set_value("app", "island", island)


# --- the world ---------------------------------------------------------------

## Which regions somebody lives in.
##
## The only genuinely new state the one-world pivot adds. Everything else it
## needs was already being kept per island; this is the one fact that belongs to
## the world rather than to a place in it.
##
## Stored as the list rather than as a count, because the order of settlement is
## the shape of a particular world - west first is a different game from east
## first - and a count would throw that away for no saving worth having.
static func settled_regions() -> PackedInt32Array:
	var cfg := _open()
	if cfg.has_section_key("world", "settled"):
		return PackedInt32Array(cfg.get_value("world", "settled"))

	# No world record yet, which means either a fresh install or a save from
	# before the pivot. A save from before it has up to five separate builds in
	# it, and every one of them is somewhere a person spent hours: those are
	# settled regions now, and taking them away because the data model changed
	# under them would be the single worst thing this file could do.
	var found := PackedInt32Array([Region.HOME])
	for i in Biome.COUNT:
		if i != Region.HOME and started(i):
			found.append(i)
	cfg.set_value("world", "settled", found)
	return found


static func settled(region: int) -> bool:
	return settled_regions().has(region)


static func settle(region: int) -> void:
	if settled(region):
		return
	var found := settled_regions()
	found.append(region)
	_open().set_value("world", "settled", found)


## Coarse fantasy-world crossings, not a record of the phone's locations.
## `RouteBook` owns their binary shape so a future server can provide the same
## data without teaching this persistence layer about location sampling.
static func community_roads() -> PackedInt32Array:
	return PackedInt32Array(_open().get_value("world", "community_roads",
		PackedInt32Array()))


static func set_community_roads(words: PackedInt32Array) -> void:
	_open().set_value("world", "community_roads", words)


static func community_sites() -> PackedInt32Array:
	return PackedInt32Array(_open().get_value("world", "community_sites",
		PackedInt32Array()))


static func set_community_sites(words: PackedInt32Array) -> void:
	_open().set_value("world", "community_sites", words)


static func claimed_rumors() -> PackedStringArray:
	return PackedStringArray(_open().get_value("world", "claimed_rumors",
		PackedStringArray()))


static func set_claimed_rumors(ids: PackedStringArray) -> void:
	_open().set_value("world", "claimed_rumors", ids)


## Whether the start screen has ever been got past. Used only to decide whether
## the first thing shown is the title or the island you were last on.
static func seen_title() -> bool:
	return bool(_open().get_value("app", "seen", false))


static func mark_seen() -> void:
	_open().set_value("app", "seen", true)


# --- how far along a region is -----------------------------------------------
#
# Nothing reads these at the moment. They were the picker's language and the
# picker is gone; they are kept rather than deleted because they are not code so
# much as three product decisions written down as functions - no percentage, the
# language of a building site, and time spent rather than time remaining - and
# the map is going to want to say what is happening in a settled region before
# very long. If it turns out not to, delete them then.

## How far along an island is, zero to one. Shown as a ring, never as a
## percentage: a number invites optimisation and the point of this app is that
## there is nothing to optimise except leaving it alone.
static func fraction(island: int) -> float:
	var done: PackedInt32Array = read(island)["done"]
	return clampf(float(done.size()) / maxf(float(Plan.count()), 1.0), 0.0, 1.0)


## The name of what is happening there now. This is the only progress language
## in the app, and it is deliberately the language of a building site rather than
## of a game: "Storey 2", "Services", "Lining".
static func phase(island: int) -> String:
	var done: PackedInt32Array = read(island)["done"]
	if done.size() >= Plan.count():
		return "Finished"
	if done.is_empty():
		return "Not started"

	# The furthest thing finished, not the count, because works complete a few at
	# a time and out of order within the open window.
	var furthest := 0
	for i in done:
		furthest = maxi(furthest, int(i))
	return Plan.phase_of(mini(furthest + 1, Plan.count() - 1))


## How long this island has actually had somebody working on it.
##
## Counted only while the world is open on this region.
## It excludes the menu and the other four regions, but includes the quarter
## hour the crew spends resting.
## It is the honest answer to "how much of this did I do", which over a week is
## the only number worth keeping.
static func build_time(island: int) -> String:
	var s := int(read(island)["focus"])
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func started(island: int) -> bool:
	return not read(island)["done"].is_empty()


static func _zeroes(n: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(n)
	return a
