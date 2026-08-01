class_name Biome
extends RefCounted

## The five islands.
##
## One world, five places, and each one keeps its own build. You pick which to
## focus on, and the one you are not looking at does not advance - there is no
## idle income here and there never will be, because the only currency in this
## app is a phone somebody has put down and left alone.
##
## What actually differs between them is not decoration. Each island has a
## different bottleneck, because each has different amounts of the six things
## that come out of the ground:
##
##   Meadow    even. Nothing is scarce and nothing is free. The one to learn on.
##   Arctic    everything is slow and timber is nearly absent. The hard one.
##   Desert    sand for nothing, so glass and concrete race ahead of the frame.
##   Coast     sand and reed are cheap, iron is a long way off.
##   Jungle    timber and fibre pour in, stone and ore are a fight.
##
## Because the house needs all of it, that changes the shape of a week rather
## than its length: on the desert island the elves are stuck waiting for lumber
## with a yard full of glass, and on the jungle island the reverse. Same
## blueprint, five different arguments about what to do next.

const COUNT := 5

## Half-extents of every island. Big enough that the walk to the reedbed passes
## behind a ridge and out of sight, small enough to compose in a phone frame
## once the camera is pulled back and the horizon is doing some of the work.
const LAND_X := 6.5
const LAND_Z := 4.2


## Where everything stands. Shared across the islands, because the layout is
## tuned - shortest errand two and a half metres, longest nearly nine, nothing
## overlapping - and re-tuning it five times would produce five worse versions of
## it. The islands differ in what the ground looks like and what it will give
## you, which is where the difference belongs.
const LAYOUT := {
	"site": Vector3(0.3, 0, -0.5),
	"survey": Vector3(0.3, 0, 1.15),
	"crane": Vector3(1.75, 0, -0.35),
	"skip": Vector3(-1.9, 0, 1.45),
	"dredge": Vector3(1.45, 0, 0.85),

	"hearth": Vector3(3.0, 0, 2.5),
	"quarry": Vector3(-4.9, 0, 0.2),
	"mine": Vector3(-5.3, 0, -1.9),
	"grove": Vector3(4.9, 0, -1.7),
	"reedbed": Vector3(-2.6, 0, -3.2),
	"claypit": Vector3(-1.5, 0, 3.0),
	"sandbank": Vector3(1.9, 0, 3.5),
	"pool": Vector3(-4.1, 0, -3.0),
	"crest": Vector3(5.4, 0, 1.6),

	"kiln": Vector3(-3.3, 0, 1.6),
	"smelter": Vector3(-4.3, 0, 2.4),
	"sawmill": Vector3(3.6, 0, 0.2),
	"press": Vector3(4.7, 0, 1.5),
	"mixer": Vector3(-1.9, 0, 0.2),
	"glassworks": Vector3(0.8, 0, 2.9),
	"pipeworks": Vector3(-3.0, 0, -1.2),
	"drawbench": Vector3(-2.2, 0, -2.1),
	"loom": Vector3(2.9, 0, -3.0),
	"plastermill": Vector3(-0.9, 0, 1.8),
}

## Which place yields which raw material, and what the thing being worked is.
## The shapes differ per island - a grove is palms on the coast and stunted
## pines in the arctic - but a tree is where timber comes from everywhere.
const SOURCES := {
	"quarry": Plan.Kind.STONE,
	"grove": Plan.Kind.TIMBER,
	"mine": Plan.Kind.ORE,
	"claypit": Plan.Kind.CLAY,
	"sandbank": Plan.Kind.SAND,
	"reedbed": Plan.Kind.FIBRE,
}


static func name_of(index: int) -> String:
	return [
		"The Meadow", "The Ice", "The Dunes", "The Shore", "The Green",
	][clampi(index, 0, COUNT - 1)]


static func blurb_of(index: int) -> String:
	return [
		"Even ground. Nothing scarce, nothing free.",
		"Everything is slow here, and there is barely any wood.",
		"Sand for nothing. The glass runs ahead of the frame.",
		"Reed and sand are cheap. The iron is a long walk.",
		"Timber pours in. Stone is a fight.",
	][clampi(index, 0, COUNT - 1)]


## Everything the world reads to build itself.
static func of(index: int) -> Dictionary:
	match clampi(index, 0, COUNT - 1):
		1: return _arctic()
		2: return _desert()
		3: return _coast()
		4: return _jungle()
	return _meadow()


# --- the islands -------------------------------------------------------------

static func _meadow() -> Dictionary:
	return {
		"id": 0,
		"name": "The Meadow",

		"ground": Color("46583B"),
		"ground_lit": Color("5E7449"),
		"patch": Color("6E7A47"),
		"rocky": Color("6A6459"),
		"shore": Color("7C6B4E"),
		"earth": Color("6B5A42"),
		"water": Color("1E4257"),
		"grass": [Color("5A7040"), Color("74794A")],
		"scrub": Color("3E5B3C"),
		"canopy": Color("39633F"),
		"canopy_glow": Color("6FA86B"),
		"bark": Color("523D2E"),
		"reed": Color("7A7440"),

		"key": Color("FFE3B8"), "key_energy": 1.15,
		"fill": Color("9E93BE"), "fill_energy": 0.30,
		"ambient": Color("463E5E"), "ambient_energy": 0.80,
		"fog": Color("2A2A44"), "fog_density": 0.016,

		# A temperate afternoon, with the warmth already coming into the bottom
		# of it. The gradient sits about a third of the way up.
		"sky_top": Color("3E76C4"), "sky_horizon": Color("E3D2AE"),
		"sky_curve": 0.18, "sky_night": Color("10162E"),

		"siding": Color("A88A5E"), "tile": Color("8C4F3E"),
		"tree": "broadleaf",
		"cover": 1.0,
		"pace": {},
		"pastimes": ["fish", "sit", "swim"],
	}


static func _arctic() -> Dictionary:
	return {
		"id": 1,
		"name": "The Ice",

		# Snow is not white. Under a low sun at this latitude it is a pale blue
		# that goes violet in shadow, and painting it white is the single fastest
		# way to make an arctic scene look like a plastic model of one.
		"ground": Color("9FB0C4"),
		"ground_lit": Color("CBD8E6"),
		"patch": Color("8CA0B8"),
		"rocky": Color("5A6068"),
		"shore": Color("6E7686"),
		"earth": Color("6A6E78"),
		"water": Color("15384E"),
		"grass": [Color("8FA2B4"), Color("A6B6C6")],
		"scrub": Color("4C5A52"),
		"canopy": Color("2E4A42"),
		"canopy_glow": Color("4E7A66"),
		"bark": Color("3E3A36"),
		"reed": Color("7E8478"),

		"key": Color("DCE9FF"), "key_energy": 0.92,
		"fill": Color("7F93C8"), "fill_energy": 0.34,
		"ambient": Color("35405E"), "ambient_energy": 0.86,
		"fog": Color("36415C"), "fog_density": 0.030,

		# Pale the whole way up and barely graded at all. An arctic sky has no
		# depth in it - that flatness is the thing that reads as cold, more than
		# the colour does, so the curve is nearly twice the meadow's.
		"sky_top": Color("6E93C4"), "sky_horizon": Color("DCE8F4"),
		"sky_curve": 0.34, "sky_night": Color("0E1730"),

		"siding": Color("6E5B45"), "tile": Color("4A5560"),
		"tree": "conifer",
		"cover": 0.45,

		# Frozen ground, stunted wood, and a quarry that is half scree. Nothing
		# here is quick, and the wood is nearly not there at all - the arctic
		# build is the one that teaches you what the sawmill is worth.
		"pace": {
			Plan.Kind.TIMBER: 2.10, Plan.Kind.CLAY: 1.55, Plan.Kind.SAND: 1.40,
			Plan.Kind.FIBRE: 1.65, Plan.Kind.STONE: 0.90, Plan.Kind.ORE: 1.05,
		},
		"pastimes": ["fish", "sit"],
	}


static func _desert() -> Dictionary:
	return {
		"id": 2,
		"name": "The Dunes",

		"ground": Color("B8935E"),
		"ground_lit": Color("D9B47A"),
		"patch": Color("A8834F"),
		"rocky": Color("8A6A4C"),
		"shore": Color("C4A878"),
		"earth": Color("8E6A44"),
		"water": Color("2A6A6E"),
		"grass": [Color("8E8248"), Color("A08F52")],
		"scrub": Color("6E7A44"),
		"canopy": Color("5A7444"),
		"canopy_glow": Color("8FAE60"),
		"bark": Color("6A5238"),
		"reed": Color("A08C50"),

		"key": Color("FFDCA0"), "key_energy": 1.12,
		"fill": Color("C08A6E"), "fill_energy": 0.26,
		"ambient": Color("5A4438"), "ambient_energy": 0.74,
		"fog": Color("4A3A32"), "fog_density": 0.012,

		# The opposite shape to the arctic's: deep blue nearly all the way down
		# and then a hard bleached band of glare at the horizon. Dry air holds
		# its colour until the dust starts, and the low curve is what draws that.
		"sky_top": Color("2F6FC6"), "sky_horizon": Color("EFD7A6"),
		"sky_curve": 0.08, "sky_night": Color("140F26"),

		"siding": Color("C9A87E"), "tile": Color("B06A44"),
		"tree": "palm",
		"cover": 0.35,

		# Sand for the taking, so glass and concrete arrive early and the yard
		# fills with things nobody can use yet, because there is no wood to frame
		# with. The most frustrating island, on purpose.
		"pace": {
			Plan.Kind.SAND: 0.45, Plan.Kind.CLAY: 0.80, Plan.Kind.STONE: 0.90,
			Plan.Kind.TIMBER: 2.30, Plan.Kind.FIBRE: 1.30, Plan.Kind.ORE: 1.15,
		},
		"pastimes": ["sit", "shade"],
	}


static func _coast() -> Dictionary:
	return {
		"id": 3,
		"name": "The Shore",

		"ground": Color("8C9A5E"),
		"ground_lit": Color("A8B472"),
		"patch": Color("9E9A5C"),
		"rocky": Color("9E9484"),
		"shore": Color("D6C69A"),
		"earth": Color("A08C64"),
		"water": Color("1C6478"),
		"grass": [Color("8AA05A"), Color("A2AE66")],
		"scrub": Color("5E7A4E"),
		"canopy": Color("4A7A4E"),
		"canopy_glow": Color("77B278"),
		"bark": Color("6E5940"),
		"reed": Color("948E52"),

		"key": Color("FFF0D2"), "key_energy": 1.22,
		"fill": Color("7FB6C8"), "fill_energy": 0.36,
		"ambient": Color("3E5468"), "ambient_energy": 0.86,
		"fog": Color("31485C"), "fog_density": 0.020,

		# The brightest of the five, and the only one that goes green-blue.
		# Sea haze takes the horizon almost to white.
		"sky_top": Color("4C90DE"), "sky_horizon": Color("D8ECEE"),
		"sky_curve": 0.24, "sky_night": Color("0B1A2A"),

		"siding": Color("BEB090"), "tile": Color("6E8C94"),
		"tree": "palm",
		"cover": 0.7,

		# A beach has sand and reed and very little metal. The smelter is the
		# whole game here, and everything downstream of iron waits on it.
		"pace": {
			Plan.Kind.SAND: 0.50, Plan.Kind.FIBRE: 0.85, Plan.Kind.TIMBER: 1.20,
			Plan.Kind.STONE: 1.40, Plan.Kind.ORE: 1.75, Plan.Kind.CLAY: 1.15,
		},
		"pastimes": ["fish", "swim", "sit"],
	}


static func _jungle() -> Dictionary:
	return {
		"id": 4,
		"name": "The Green",

		"ground": Color("2E4A2C"),
		"ground_lit": Color("40643A"),
		"patch": Color("3A5A32"),
		"rocky": Color("4E4E46"),
		"shore": Color("5E5236"),
		"earth": Color("4A3C28"),
		"water": Color("1A4A3E"),
		"grass": [Color("3A6034"), Color("4E7040")],
		"scrub": Color("2A4C30"),
		"canopy": Color("2C5834"),
		"canopy_glow": Color("62A05E"),
		"bark": Color("3E3226"),
		"reed": Color("5E7038"),

		"key": Color("E8F0C0"), "key_energy": 0.98,
		"fill": Color("6EA07E"), "fill_energy": 0.34,
		"ambient": Color("2A4038"), "ambient_energy": 0.92,
		"fog": Color("22382E"), "fog_density": 0.034,

		# Humid and milky, with the green of the canopy bounced back up into it.
		# The flattest gradient of the five and the least blue - a jungle sky is
		# mostly water, and you are looking at it through a day's evaporation.
		"sky_top": Color("5E8FB0"), "sky_horizon": Color("CBD8B8"),
		"sky_curve": 0.42, "sky_night": Color("0C1A18"),

		"siding": Color("7E6A46"), "tile": Color("4E6A44"),
		"tree": "giant",
		"cover": 1.45,

		# Wood and fibre everywhere, and a floor of leaf litter over basalt.
		# Quarrying and mining are the bottleneck, which makes every iron
		# fastener feel like a decision.
		"pace": {
			Plan.Kind.TIMBER: 0.55, Plan.Kind.FIBRE: 0.60, Plan.Kind.CLAY: 0.85,
			Plan.Kind.STONE: 1.35, Plan.Kind.ORE: 1.45, Plan.Kind.SAND: 1.55,
		},
		"pastimes": ["fish", "sit", "swim"],
	}


## The relief. One entry matters more than the rest: a ridge across the back
## left, between the yard and the reedbed, so an elf sent for reed walks out of
## sight and comes back. Without somewhere to be hidden, nobody can be wrong
## about anywhere, and every belief in the world below becomes decoration.
static func relief(index: int) -> Array:
	var l := LAYOUT
	var base := [
		{"at": Vector3(-1.6, 0, -1.5), "amount": 1.25, "rx": 2.5, "rz": 0.75},
		{"at": l["quarry"], "amount": 0.95, "rx": 1.5, "rz": 1.25},
		{"at": l["mine"], "amount": 1.15, "rx": 1.2, "rz": 1.1},
		{"at": l["grove"], "amount": 0.40, "rx": 1.9, "rz": 1.45},
		{"at": l["crest"], "amount": 0.90, "rx": 1.6, "rz": 1.3},
		{"at": l["pool"], "amount": -0.85, "rx": 1.45, "rz": 1.25},
		{"at": l["site"], "amount": 0.16, "rx": 1.8, "rz": 1.3},
		{"at": l["sandbank"], "amount": -0.22, "rx": 1.6, "rz": 0.9},
	]

	match index:
		1:
			# Ice is flatter, with one hard scarp. Snow fills hollows in.
			base[0]["amount"] = 1.05
			base[3]["amount"] = 0.20
			base[2]["amount"] = 1.45
		2:
			# Dunes: long, soft, and more of them.
			base[0]["amount"] = 1.05
			base[0]["rx"] = 3.2
			base.append({"at": Vector3(2.6, 0, -2.6), "amount": 0.75,
				"rx": 2.4, "rz": 1.1})
			base.append({"at": Vector3(-3.4, 0, 3.2), "amount": 0.60,
				"rx": 2.0, "rz": 1.0})
		3:
			# A shore shelves. Everything tips gently toward the water.
			base[7]["amount"] = -0.40
			base[7]["rx"] = 2.6
			base[5]["amount"] = -0.60
		4:
			# Jungle is broken ground: more bumps, none of them large.
			base[0]["amount"] = 1.15
			for i in 5:
				base.append({
					"at": Vector3(randf_range(-4.5, 4.5), 0, randf_range(-3.0, 3.0)),
					"amount": randf_range(0.28, 0.55), "rx": randf_range(0.8, 1.5),
					"rz": randf_range(0.7, 1.2)})
	return base
