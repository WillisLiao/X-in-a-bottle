extends Node3D

## Hobbitle is a free focus app.
##
## Open it, leave it on the desk, and watch the hobbits and trolls build.
## There is no account, score, purchase, or productivity system to manage.
## The only useful state is the work the crew completes while this place is open.
## The older map and expedition code stays dormant behind `FOCUS_ONLY`; it is
## not part of the user's focus session.
##
## ## Zoom out is the map
##
## There used to be a picker: a screen with five islands on it that you chose
## between. It is gone, and what replaced it is not another screen.
##
## Keep pinching out past where the region used to stop and it keeps receding,
## until you are looking at the whole world and every place in it. Keep pinching
## in and you are back down among somebody's hands. One continuous gesture, no
## menu, and nothing to be dismissed - which is the whole of `MAP_FROM`,
## `_map_blend` and about forty lines below.
##
## The five biomes are five regions of one place now rather than five parallel
## saves, so the thing you pull back to see is a world rather than a menu of
## worlds. See `Region`, `Country`, and `handoffs/DESIGN-one-world.md`.

const TARGET_FPS := 30
const FOCUS_ONLY := true

enum ViewMode { FIELD, VILLAGE }

## Everything above this is a hand on the phone. Below it is a desk, a passing
## lorry, somebody walking past.
const ORBIT_RATE := 0.0022
const PITCH_RATE := 0.0016

## How far down the drag can push the camera's angle before it stops orbiting
## and starts looking up instead. See `_move_camera`.
const ORBIT_FLOOR := 0.06

## And how far past that it can keep going. A shade under ninety degrees of
## total travel, which is one unhurried drag up the screen.
const PITCH_MIN := -1.62
const ZOOM_MIN := 0.42

## Where the region stops being the subject and the world starts being it.
##
## Below this the camera is looking at a place and behaves exactly as it always
## did. Above it the aim slides off the region and onto the middle of the world,
## the haze thins out so forty metres of it does not swallow the far end, and
## tapping a region travels to it. The two states are never both true and are
## never switched between - it is one number, and the user is holding it.
const MAP_FROM := 1.9

## And where it stops. Past this the camera is out at the world and there is
## nothing further to pull back to.
##
## Note how small the number is against the hundred and seventy metres the
## camera actually ends up at. Distance is not `_zoom` times a constant any
## more - see `_move_camera`. If it were, a world this wide would need a zoom
## range of thirty to one, and a pinch only gets you about four to one in a
## gesture, so opening the map would have taken six of them in a row. The
## design asks for one continuous gesture, so the last stretch of the pinch
## carries the camera much further than the first, and the whole width of the
## world costs the same flick of two fingers whatever is in it.
const ZOOM_MAX := 3.0

## Nought inside a region, one out at the world. Smoothed by the same curve the
## camera uses, so nothing about the transition has an edge on it.
var _map := 0.0

## How much further over the world the camera leans once it is out at the map.
##
## Thirty-six degrees is the angle a region is composed at, and it is chosen to
## read faces - from much higher these stop being people and become hats. But
## the map has no faces in it and a different problem: the arc runs thirty units
## deep as well as seventy across, and seen from a face-reading angle that depth
## collapses into a diagonal stripe across the bottom of the frame with the top
## half empty. Leaning over as the camera pulls back trades the faces, which are
## no longer visible anyway, for the depth, which is the whole shape of the
## world.
##
## Not far, though. Past about fifteen degrees of extra lean the horizon leaves
## the top of the frame and takes the sky and the sun with it, and the map ends
## up read against a flat wall of haze. A map of a world should have that
## world's weather over it.
const MAP_PITCH := 0.22

## The lens the world is seen through, against the thirty-four degrees a region
## is seen through.
##
## Same argument `ElfWorld` already makes about framing one region, one scale
## up. A thirty-four degree lens on this viewport is sixty-six degrees across,
## and the arc fills nearly all of it - so the two end regions sit right out at
## the edge of the frame where rectilinear projection stretches hardest, and the
## Ice and the Dunes were being drawn about forty per cent larger than the
## Meadow in the middle despite being further away. Which reads as the world
## bulging at the ends rather than as a lens doing what lenses do.
##
## Twenty-two degrees from a hundred metres out is the same picture with the
## stretch taken out of it, and it costs nothing but a clip plane.
const MAP_LENS := 22.0

## Where the pinch is being carried to, when something other than a finger is
## doing the carrying. Negative means nothing is. Arriving at a region has to be
## a descent rather than a cut, or travelling reads as a screen change - which
## is the thing the picker was deleted for being.
var _zoom_to := -1.0

const VOID := Color("0B0906")

var _camera: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

## The two things in the sky you can actually point at. Drawn, not inferred -
## see `_build_bodies`.
var _sun_body: MeshInstance3D
var _moon_body: MeshInstance3D

## Zero in the working hour, one in the middle of a break. Everything about the
## sky - its colour, which body is up, how warm the low sun is - is driven off
## this one smoothed number rather than off `resting()` directly, so a break
## arrives as a sunset rather than as a cut.
var _night := 0.0

## The island's designed day sky, held so the night blend has something to
## interpolate away from every frame.
var _sky_day_top := Color("3E76C4")
var _sky_day_horizon := Color("E3D2AE")
var _sky_night_top := Color("10162E")
var _sky_night_horizon := Color("1E2740")

## Where the sun and moon are, held between frames rather than recomputed from
## scratch, so each can be frozen while it is invisible - see `_rest_light`.
var _sun_elev := 32.0
var _sun_azim := 0.0
var _moon_elev := 30.0
var _moon_azim := 0.0

## The last `_night` the sky material was written at. Writing a procedural sky's
## colours re-renders its radiance map, which is not something to do sixty times
## a second on a phone that has to stay cool for twenty-five minutes - and for
## all but a few seconds an hour this value does not move at all.
var _sky_written := -1.0

## What the lower hemisphere settles into, far below the horizon. The island's
## own haze colour, so distance and fog agree.
var _haze_floor := Color("2A2A44")

## The region's own fog, held so the map can thin it out and put it back without
## having to ask the biome again every frame.
var _fog_density := 0.016
var _key_energy := 1.0
var _fill_energy := 1.0
var _ambient_energy := 1.0
var _menu: Menu
var _focus_hud: FocusHud
var _field_marks: FieldMarks
var _expedition_marks: ExpeditionMarks
var _sleeping_hill: SleepingHillVisual
var _rooted_gate: RootedGateVisual
var _lost_lights: LostLightsVisual
var _migration: MigrationVisual
var _fable_state: FableState
var _fable_journey: FableJourney
var _fable_source: FableJourneySource
var _expedition_stage := "dormant"
var _act_fable := ""
var _act_stage := ""
var _act_marks: ActMarks
var _view_mode := ViewMode.VILLAGE

var _world: ElfWorld
var _island := 0

## The rest of the world - the four regions nobody is standing in. Scenery only;
## it has no tick and never will, because the rule that only what is being
## watched moves is what makes a bigger world affordable at all.
var _country: Country

var _tilt: Vector2 = Vector2.ZERO
var _has_sensors := false

# Where the camera is looking from, which is now the user's business.
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _drift := 0.0

## Whether a one-finger drag turns the region (false) or slides the camera
## over it (true). Reset whenever a region is entered, so nobody arrives at
## a fresh region already panned off to one side.
var _pan_mode := false
var _pan := Vector3.ZERO

var _touches := {}
var _pinch_from := 0.0
var _pinch_zoom := 1.0
var _press_at := Vector2.ZERO
var _press_time := 0.0
var _dragged := false

## The break used to be drawn as a light crossing the sky in a HUD overlay -
## a hairline arc with a dot travelling along it. The sun and moon now do that
## job for real: the sun sets as the hour ends, the moon rises and sets across
## the break tracking `rest_fraction()` exactly as the arc used to, and the
## hearth becomes the brightest thing on the island while it does. Two
## progress indicators for one event was worse than either alone, so this one
## was deleted rather than kept alongside the other.
var _rest_label: Label
var _dim := 1.0

var _capture_path: String = ""
var _capture_after: float = 0.0
var _capture_screen := "world"
var _force_rest := -1.0
var _arg_fire := -1
var _arg_yaw := NAN
var _arg_zoom := NAN
var _arg_pitch := NAN
var _arg_pan := Vector2(NAN, NAN)
var _arg_feed := NAN
var _arg_feast := false
var _arg_route := ""
var _arg_route_reset := false
var _arg_story := ""
var _arg_story_reset := false
var _arg_story_stage := ""
var _arg_act_reset := false
var _arg_fable := ""
var _arg_fable_stage := ""
var _capturing := false
var _elapsed: float = 0.0


func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_has_sensors = OS.has_feature("mobile")

	_build_environment()
	_build_camera()
	_build_lights()
	_build_bodies()
	_build_finish()
	_build_sky()
	_build_back()
	_fable_state = FableState.load()
	if Progress.fable_state().is_empty():
		_fable_state.persist()
	_fable_journey = FableJourney.new()
	_fable_journey.completed.connect(_on_expedition_completed)
	_fable_source = FableJourneySource.new()
	_fable_source.step_reached.connect(_on_story_step)
	_sleeping_hill = SleepingHillVisual.new(_fable_state)
	add_child(_sleeping_hill)
	_sleeping_hill.rebuild()
	_expedition_marks.set_context(_camera, _sleeping_hill)
	_rooted_gate = RootedGateVisual.new(_fable_state)
	add_child(_rooted_gate)
	_rooted_gate.rebuild()
	_lost_lights = LostLightsVisual.new(_fable_state)
	add_child(_lost_lights)
	_lost_lights.rebuild()
	_act_marks.set_context(_camera, _rooted_gate, _lost_lights)
	_sync_act_state()

	_island = clampi(Progress.last_island(), 0, Biome.COUNT - 1)
	_country = Country.new()
	add_child(_country)
	_field_marks.set_context(_camera, _country)
	_apply_focus_mode()

	_menu = Menu.new()
	add_child(_menu)
	_menu.begin.connect(_on_begin)
	_menu.dismissed.connect(_on_dismissed)

	_read_capture_args()
	if _arg_route_reset or not _arg_route.is_empty():
		var routes := RouteBook.load()
		if _arg_route_reset:
			routes.clear()
		if not _arg_route.is_empty():
			routes.record_debug_route(_arg_route)
		routes.persist()
	if not _arg_story.is_empty():
		_apply_story_capture()
	if not _arg_fable.is_empty():
		_apply_act_capture()

	if FOCUS_ONLY or _capture_screen == "world":
		_enter_village(_island)
	elif _capture_screen == "map" or _capture_screen == "field":
		_enter_field(_island)
	else:
		_menu.show_title()

	# After _enter, which resets the camera to the region's default. Held apart
	# so a capture can ask for an angle and actually get it.
	if not is_nan(_arg_yaw):
		_yaw = _arg_yaw
	if not is_nan(_arg_zoom):
		_zoom = clampf(_arg_zoom, ZOOM_MIN, ZOOM_MAX)
		_zoom_to = -1.0
	if not is_nan(_arg_pitch):
		_pitch = _arg_pitch
	if not is_nan(_arg_pan.x):
		_pan = Vector3(_arg_pan.x, 0.0, _arg_pan.y)

	if _arg_fire >= 0 and _world != null:
		_world.send_fire(_arg_fire)

	# The map blend is smoothed toward its target, and a capture taken twenty
	# seconds in has plenty of time to get there - but one taken at zero would
	# photograph the world at the region's fog. Start it where it belongs.
	_map = clampf(inverse_lerp(MAP_FROM, ZOOM_MAX, _zoom), 0.0, 1.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_move_camera(delta)
	if _country:
		_country.set_map(_map)
	if _field_marks:
		_field_marks.set_map(_map)
	if _expedition_marks:
		_expedition_marks.queue_redraw()
	_fade_back(delta)
	_rest_light(delta)
	if _focus_hud and _world != null and not _menu.showing():
		_focus_hud.update_state(_world.focus_seconds(), _world.resting(),
			_world.rest_seconds_remaining(), _world.feed_ready(),
			_world.rally_ready())
	_maybe_capture()

	if _world == null or _menu.showing():
		return

	if _view_mode == ViewMode.VILLAGE:
		_world.advance(delta)
	if _migration and _migration.running():
		if _migration.advance(delta):
			_finish_migration()


# --- moving between places ---------------------------------------------------

func _on_food_requested() -> void:
	if _world != null and _world.call_feast():
		_focus_hud.show_feedback("FOOD IS FALLING")


func _on_rally_requested() -> void:
	if _world != null and _world.call_rally():
		_focus_hud.show_feedback("THE BELL IS RINGING")

func _on_begin() -> void:
	_enter_field(_island)


func _on_dismissed() -> void:
	if _world != null:
		_menu.hide_all()


## Go and live in a region.
##
## The camera keeps its angle across a move, and descends into the new place
## rather than arriving at it. That is the difference between travelling and
## changing screens, and it is most of what the picker was deleted for.
func _enter_field(region: int) -> void:
	if FOCUS_ONLY:
		_enter_village(region)
		return
	_prepare_region(region)
	_view_mode = ViewMode.FIELD
	_zoom = ZOOM_MAX
	_zoom_to = -1.0
	_menu.hide_all()


## A place is prepared once and then either viewed from the country or entered
## close enough to watch. Keeping these paths separate makes the field a real
## product mode rather than an accidental consequence of a zoom value.
func _prepare_region(region: int) -> void:
	var arriving := _world == null
	if not arriving and _island == region:
		return

	_leave()
	_island = clampi(region, 0, Biome.COUNT - 1)
	Progress.set_last_island(_island)
	Progress.flush()

	_world = ElfWorld.new(_island)
	_world.settled.connect(_on_settled)
	add_child(_world)
	_world.build()

	# The bottle is never empty, but bootstrap scenery must not earn time.
	for _i in ElfWorld.STARTING_OBJECTS:
		_world._grow()

	_country.show_from(_island)
	if FOCUS_ONLY:
		_country.visible = false
	_apply_lighting(_world)
	_camera.fov = _world.lens
	_pan = Vector3.ZERO
	if arriving:
		_yaw = 0.0
		_pitch = 0.0
		_zoom = 1.0
		_zoom_to = -1.0
	else:
		_zoom_to = 1.0
	if _force_rest >= 0.0:
		_world.force_rest(_force_rest)
	if not is_nan(_arg_feed):
		_world.force_feed(_arg_feed)
	if _arg_feast:
		_world.force_feed(1.0)
		_world.call_feast()
	_drift = 6.0


## Descending is the only path that makes the construction scene active.
func _enter_village(region: int) -> void:
	_prepare_region(region)
	_view_mode = ViewMode.VILLAGE
	_zoom_to = 1.0
	_menu.hide_all()
	if _focus_hud:
		_focus_hud.visible = true


func _enter(region: int) -> void:
	_enter_village(region)


## A lantern got where it was going. The world that sent it cannot draw the
## region it just settled - that is `Country`'s side of the fence - so the whole
## of the rest of the world is rebuilt around it, once, and a fire appears on a
## place that had none.
func _on_settled(_region: int) -> void:
	if _country:
		_country.show_from(_island, true)


func _leave() -> void:
	if _world == null:
		return
	_world.persist()
	_world.queue_free()
	_world = null


func _notification(what: int) -> void:
	# Losing twenty seconds of a week-long build because somebody took a call is
	# the one place autosave has to be exact.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST,
			NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if _world:
			_world.persist()


func _begin_expedition() -> void:
	if _expedition_stage != "dormant" or _fable_state.resolution("sleeping_hill") != FableState.UNRESOLVED:
		return
	_expedition_stage = "carrying"
	_fable_journey.begin()
	_sleeping_hill.set_route_step(-1)
	_expedition_marks.set_stage(_expedition_stage)

func _on_story_step(step: int) -> void:
	if _fable_journey.accept_step(step):
		_sleeping_hill.set_route_step(step)
		_expedition_marks.set_cairn_step(step + 1)

func _on_expedition_completed() -> void:
	_expedition_stage = "choosing"
	_sleeping_hill.raise_seed()
	_expedition_marks.set_stage(_expedition_stage)


func _apply_focus_mode() -> void:
	# The builder is the product surface. The map and story layers remain in the
	# project for their captures, but they do not interrupt a focus session.
	if not FOCUS_ONLY:
		return
	_country.visible = false
	_field_marks.visible = false
	_expedition_marks.visible = false
	_act_marks.visible = false
	_sleeping_hill.visible = false
	_rooted_gate.visible = false
	_lost_lights.visible = false


func _resolve_expedition(outcome: String) -> void:
	if _expedition_stage != "choosing" or not _fable_state.resolve("sleeping_hill", outcome):
		return
	_fable_state.persist()
	_expedition_marks.play_resolution_bloom()
	_expedition_stage = "resolved"
	_sleeping_hill.resolve(outcome)
	_expedition_marks.set_stage(_expedition_stage)
	if outcome == FableState.HOLLOW:
		_enter_village(_island)
	else:
		_view_mode = ViewMode.FIELD
	_sync_act_state()

func _sync_act_state() -> void:
	if FOCUS_ONLY:
		_act_fable = ""
		_act_stage = ""
		if _rooted_gate:
			_rooted_gate.visible = false
		if _lost_lights:
			_lost_lights.visible = false
		if _act_marks:
			_act_marks.visible = false
		return
	_act_fable = FableCatalog.available(_fable_state)
	_rooted_gate.visible = FableCatalog.unlocked(_fable_state, FableCatalog.ROOTED_GATE)
	_lost_lights.visible = FableCatalog.unlocked(_fable_state, FableCatalog.LOST_LIGHTS)
	if _act_fable == FableCatalog.ROOTED_GATE:
		_act_stage = "rooted_dormant"
		_act_marks.set_stage(_act_stage)
	elif _act_fable == FableCatalog.LOST_LIGHTS:
		_act_stage = "lost_dormant"
		_act_marks.set_stage(_act_stage)
	elif _act_fable == FableCatalog.MIGRATION:
		_act_stage = "migration_ready"
		_act_marks.set_stage(_act_stage)
	else:
		_act_stage = ""
		_act_marks.set_stage("")

func _begin_rooted_gate() -> void:
	if _act_fable != FableCatalog.ROOTED_GATE or _act_stage != "rooted_dormant":
		return
	_act_stage = "rooted_choosing"
	_act_marks.set_stage(_act_stage)

func _resolve_rooted_gate(species: String) -> void:
	if _act_stage != "rooted_choosing" or not _fable_state.resolve(FableCatalog.ROOTED_GATE, species):
		return
	_fable_state.persist()
	_rooted_gate.rebuild()
	_act_stage = "lost_dormant"
	_act_fable = FableCatalog.LOST_LIGHTS
	_act_marks.set_stage(_act_stage)
	_lost_lights.visible = true

func _begin_lost_lights() -> void:
	if _act_stage != "lost_dormant":
		return
	_act_stage = "lost_choosing"
	_act_marks.set_stage(_act_stage)

func _resolve_lost_lights(destination: String) -> void:
	if _act_stage != "lost_choosing" or not _fable_state.resolve(FableCatalog.LOST_LIGHTS, destination):
		return
	_fable_state.persist()
	_lost_lights.rebuild()
	if _fable_state.all_chapters_resolved():
		_act_fable = FableCatalog.MIGRATION
		_act_stage = "migration_ready"
		_act_marks.set_stage(_act_stage)

func _begin_migration() -> void:
	if _act_stage != "migration_ready" or _migration != null:
		return
	var people: Array[Dictionary] = []
	if _world:
		for person in _world.expedition_people():
			people.append(person)
	if people.is_empty():
		people = [
			{"seed": _fable_state.seed_for("rooted_gate"), "species": FableState.HOBBIT},
			{"seed": _fable_state.seed_for("lost_lights"), "species": FableState.TROLL},
			{"seed": _fable_state.world_seed, "species": FableState.HOBBIT},
		]
	_migration = MigrationVisual.new(people)
	add_child(_migration)
	_migration.begin()
	_act_stage = "migration_running"
	_act_marks.set_stage(_act_stage)

func _finish_migration() -> void:
	if not _fable_state.meadow_act_complete:
		if not _fable_state.complete_meadow_act():
			return
		_fable_state.persist()
	Progress.set_last_island(3)
	Progress.settle(3)
	Progress.flush()
	if _country:
		_country.show_from(_island, true)
	_rooted_gate.visible = true
	_lost_lights.visible = true
	_act_stage = ""
	_act_fable = ""
	_act_marks.set_stage("")
	_sync_act_state()

func _apply_act_capture() -> void:
	if _arg_act_reset:
		_fable_state = FableState.new(FableState.new_world_seed())
		_fable_state.persist()
		_sleeping_hill.set_state(_fable_state)
		_sleeping_hill.rebuild()
		_rooted_gate.set_state(_fable_state)
		_rooted_gate.rebuild()
		_lost_lights.set_state(_fable_state)
		_lost_lights.rebuild()
	if _arg_fable == FableCatalog.ROOTED_GATE and _fable_state.resolution(FableCatalog.SLEEPING_HILL) == FableState.UNRESOLVED:
		_fable_state.resolve(FableCatalog.SLEEPING_HILL, FableState.GROVE)
	if _arg_fable in [FableCatalog.LOST_LIGHTS, FableCatalog.MIGRATION] and _fable_state.resolution(FableCatalog.SLEEPING_HILL) == FableState.UNRESOLVED:
		_fable_state.resolve(FableCatalog.SLEEPING_HILL, FableState.GROVE)
	if _arg_fable == FableCatalog.MIGRATION and _fable_state.resolution(FableCatalog.ROOTED_GATE) == FableState.UNRESOLVED:
		_fable_state.resolve(FableCatalog.ROOTED_GATE, FableState.TROLL)
	if _arg_fable == FableCatalog.MIGRATION and _fable_state.resolution(FableCatalog.LOST_LIGHTS) == FableState.UNRESOLVED:
		_fable_state.resolve(FableCatalog.LOST_LIGHTS, FableState.OUTWARD)
	_fable_state.persist()
	_sync_act_state()
	match _arg_fable_stage:
		"choosing":
			if _arg_fable == FableCatalog.ROOTED_GATE:
				_begin_rooted_gate()
			elif _arg_fable == FableCatalog.LOST_LIGHTS:
				_begin_lost_lights()
		"troll", "hobbit":
			_begin_rooted_gate()
			_resolve_rooted_gate(_arg_fable_stage)
		"home", "outward":
			_begin_lost_lights()
			_resolve_lost_lights(_arg_fable_stage)
		"complete":
			_fable_state.resolve(FableCatalog.ROOTED_GATE, FableState.TROLL)
			_fable_state.resolve(FableCatalog.LOST_LIGHTS, FableState.OUTWARD)
			_fable_state.resolve(FableCatalog.SLEEPING_HILL, FableState.GROVE)
			_fable_state.complete_meadow_act()
			_fable_state.persist()
			_act_stage = "migration_ready"
			_begin_migration()

func _apply_story_capture() -> void:
	if _arg_story_reset:
		_fable_state = FableState.new(FableState.new_world_seed())
		_fable_state.persist()
		_sleeping_hill.set_state(_fable_state)
		_sleeping_hill.rebuild()
	if _arg_story_stage == "dormant" or _arg_story_stage.is_empty():
		return
	if _arg_story_stage == "carrying":
		_begin_expedition()
		for step in FableJourney.STEP_COUNT - 1:
			_on_story_step(step)
	elif _arg_story_stage == "choosing":
		_begin_expedition()
		for step in FableJourney.STEP_COUNT:
			_on_story_step(step)
		_on_expedition_completed()
	elif _arg_story_stage in ["hollow", "grove"]:
		_fable_state.resolve("sleeping_hill", _arg_story_stage)
		_fable_state.persist()
		_sleeping_hill.rebuild()
		_expedition_stage = "resolved"
		_expedition_marks.set_stage(_expedition_stage)



# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_at = event.position
				_press_time = _elapsed
				_dragged = false
				if _expedition_stage in ["carrying", "choosing"]:
					_expedition_marks.begin_drag(event.position)
				elif _act_stage in ["rooted_choosing", "lost_choosing"]:
					_act_marks.begin_drag(event.position)
			elif _touches.size() == 2:
				_pinch_from = _pinch_span()
				_pinch_zoom = _zoom
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				_finish_press(event.position)

	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _expedition_stage in ["carrying", "choosing"]:
			_expedition_marks.drag_to(event.position)
		elif _act_stage in ["rooted_choosing", "lost_choosing"]:
			_act_marks.drag_to(event.position)
		elif _touches.size() >= 2:
			_pinch(_pinch_span())
		elif _pan_mode:
			_pan_camera(event.relative)
		else:
			_orbit(event.relative)

	elif event is InputEventMouseButton:
		# An emulated pointer reports device -1 and would double every gesture.
		if event.device == -1:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_to = -1.0
			_zoom = clampf(_zoom * 0.92, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_to = -1.0
			_zoom = clampf(_zoom * 1.08, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_at = event.position
				_press_time = _elapsed
				_dragged = false
				if _expedition_stage in ["carrying", "choosing"]:
					_expedition_marks.begin_drag(event.position)
				elif _act_stage in ["rooted_choosing", "lost_choosing"]:
					_act_marks.begin_drag(event.position)
			else:
				_expedition_marks.end_drag()
				_act_marks.end_drag()
				_finish_press(event.position)

	elif event is InputEventMouseMotion and event.device != -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _expedition_stage in ["carrying", "choosing"]:
				_expedition_marks.drag_to(event.position)
			elif _act_stage in ["rooted_choosing", "lost_choosing"]:
				_act_marks.drag_to(event.position)
			elif _pan_mode:
				_pan_camera(event.relative)
			else:
				_orbit(event.relative)


func _pinch_span() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


## The one gesture that used to be a screen.
##
## Nothing here knows about a map. It is the same pinch it always was against a
## much longer range, and everywhere else that cares reads `_map` off the number
## it leaves behind - which is why there is no transition to get wrong, no state
## to be in, and nothing that can be halfway open.
func _pinch(span: float) -> void:
	if _pinch_from < 1.0 or span < 1.0:
		return
	_dragged = true
	_zoom_to = -1.0
	if FOCUS_ONLY:
		_zoom = clampf(_pinch_zoom * (_pinch_from / span), 0.72, 1.25)
		_view_mode = ViewMode.VILLAGE
		return
	_zoom = clampf(_pinch_zoom * (_pinch_from / span), ZOOM_MIN, ZOOM_MAX)
	if _view_mode == ViewMode.FIELD and _zoom < MAP_FROM:
		_view_mode = ViewMode.VILLAGE
	elif _view_mode == ViewMode.VILLAGE and _zoom >= MAP_FROM:
		_view_mode = ViewMode.FIELD


## Turning the island, and leaning over it.
##
## The top of the range is clamped well short of overhead: from directly above
## these stop being people and become hats.
##
## The bottom used to stop at -0.28, which sounds like a detail and was not.
## The island is framed from thirty-six degrees up through a thirty-four degree
## lens, so the horizon sits nineteen degrees above the top of the frame, and
## -0.28 was not enough to pull it down into view - which meant that at no
## angle the user could reach was any part of the actual sky on screen, and
## the sun and moon were unreachable rather than missing. Leaning back far
## enough to see the weather is now allowed, and is the only way to find
## either of them.
func _orbit(by: Vector2) -> void:
	if _menu.showing():
		return
	if by.length() > 2.0:
		_dragged = true
	_yaw = wrapf(_yaw - by.x * ORBIT_RATE, -PI, PI)
	_pitch = clampf(_pitch + by.y * PITCH_RATE, PITCH_MIN, 0.62)
	_drift = 14.0


## The other half of the toggle: sliding the camera over the island rather
## than turning it round. Grabs the ground plane rather than the yaw, so the
## content follows the finger the way it would with a real map.
func _pan_camera(by: Vector2) -> void:
	if _menu.showing() or _camera == null:
		return
	if by.length() > 2.0:
		_dragged = true

	var basis := _camera.global_transform.basis
	var right := _flat(basis.x)
	var forward := _flat(-basis.z)
	var rate := 0.0032 * _zoom

	_pan -= right * by.x * rate
	_pan += forward * by.y * rate
	_drift = 14.0


func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-10 else Vector3.ZERO


func _finish_press(at: Vector2) -> void:
	if _dragged or _elapsed - _press_time > 0.6:
		return
	if at.distance_to(_press_at) > 40.0:
		return
	if FOCUS_ONLY:
		if _focus_hud and _focus_hud.tap(at):
			return
		return

	if _menu.showing():
		_menu.tapped(at)
		return
	if _expedition_marks.tap(at):
		if _expedition_stage == "dormant":
			_begin_expedition()
		return
	if _act_marks.tap(at):
		if _act_stage == "rooted_dormant":
			_begin_rooted_gate()
		elif _act_stage == "lost_dormant":
			_begin_lost_lights()
		return

	# Bottom left corner: which way a one-finger drag turns.
	if at.x < 620.0 and at.y > 1000.0:
		_pan_mode = not _pan_mode
		return

	# A complete coastline makes the whole region the target.
	# This stays inside the close view because a map tap already has a place
	# travel meaning, and a food event must never steal that gesture.
	if _view_mode == ViewMode.VILLAGE and _map < 0.35 \
			and _world != null and _world.feed_ready():
		if _world.call_feast():
			return

	# Out on the map, a tap is somewhere to go.
	if _view_mode == ViewMode.FIELD and _country.claim_rumor(at, _camera):
		_field_marks.claim_feedback(at)
		return
	if _view_mode == ViewMode.FIELD and _map > 0.35 and _tap_region(at):
		return


## The region under a tap, from where it actually is on screen rather than from
## a hit rectangle kept in step by hand. Everything on the map is a real thing
## in the world at its real distance, so asking the camera where it landed is
## both the simplest way to do this and the only one that cannot drift.
func _tap_region(at: Vector2) -> bool:
	if _camera == null:
		return false

	var best := -1
	var nearest := 190.0
	for i in Biome.COUNT:
		var here := _country.where(i) + Vector3(0, 0.5, 0)
		if _camera.is_position_behind(here):
			continue
		var d := _camera.unproject_position(here).distance_to(at)
		if d < nearest:
			nearest = d
			best = i

	if best < 0:
		return false
	if best == _island:
		# Already living there. Go back down to it.
		_enter_village(_island)
		return true

	# Somewhere people already live. No save here: `_enter` leaves the region it
	# is in, and leaving persists.
	if Progress.settled(best):
		_enter(best)
		return true

	# Somewhere nobody lives yet, joined to here by a neck of land. Tapping it
	# does not take you there - it sends somebody, and then you watch them go.
	#
	# A region costs about eighty seconds of watching one person walk.
	# That watchable crossing remains the only way to settle an available region.
	if _world != null and Region.NEIGHBOURS.get(_island, []).has(best):
		if _world.journey() < 0:
			_world.send_fire(best)
		# Drawn back far enough to hold both regions in frame, not so far that
		# the person doing the walking is a speck.
		_zoom_to = lerpf(MAP_FROM, ZOOM_MAX, 0.45)
		return true

	# Not joined to here. Nothing happens, and nothing explains why - the necks
	# of land are on screen and the chain is its own explanation.
	return true


func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 105

	# Said once, at the start of the first break, and then never again. After
	# that a dozen figures lying down round a fire explains itself.
	_rest_label = Label.new()
	_rest_label.text = "They have stopped for a while."
	_rest_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rest_label.offset_top = 372.0
	_rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_label.add_theme_font_size_override("font_size", 42)
	_rest_label.add_theme_color_override("font_color", Color("EFE3CB"))
	_rest_label.modulate.a = 0.0
	_rest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_rest_label)

	add_child(layer)


## The sun's elevation follows the work hour and the moon's follows the break,
## so the light itself announces what is about to happen before anything on
## the ground does: it starts descending in the last few minutes before a
## break rather than the break simply arriving.
##
## The key comes down, the fill goes cold and the hearth is left doing most of
## the work, so a break looks like one from across a room. It is also the only
## time the fire is the brightest thing on the island, which is the correct
## thing for it to be when everybody has gone to sit round it.
func _rest_light(delta: float) -> void:
	if _world == null:
		return

	var want := 0.42 if _world.resting() else 1.0
	_dim = lerpf(_dim, want, clampf(delta * 0.55, 0.0, 1.0))
	_night = clampf(inverse_lerp(1.0, 0.42, _dim), 0.0, 1.0)

	_key.light_energy = _key_energy * _dim
	_fill.light_energy = _fill_energy * lerpf(1.45, 1.0, _dim)
	_env.ambient_light_energy = _ambient_energy * lerpf(0.72, 1.0, _dim)

	# The sky itself goes over to night, which it never used to - the same blue
	# stayed up through every break, and the lights coming down on an unchanged
	# sky read as a cloud passing rather than as an evening.
	if absf(_night - _sky_written) > 0.02:
		_sky_written = _night
		_write_sky(_sky_day_top.lerp(_sky_night_top, _night),
			_sky_day_horizon.lerp(_sky_night_horizon, _night))

	# The two bodies cross over rather than swapping. The sun is gone by the
	# time the night is three-fifths in, the moon is not there until it is
	# two-fifths, and in the overlap both are faint - which is what dusk is.
	var sun_up := clampf((1.0 - _night) * 2.4, 0.0, 1.0)
	var moon_up := clampf((_night - 0.42) * 2.4, 0.0, 1.0)

	# One slow arc across the whole working hour: low as they wake, high with
	# a gentle drift through the middle, low again as it announces the break
	# before anybody downs tools. Held where it was once it has faded out, so
	# that the reset of the hour - which throws the sun from the west back to
	# the east in a single frame - happens while nobody can see it.
	if sun_up > 0.0:
		var work_t := _world.work_fraction()
		_sun_elev = lerpf(14.0 + 40.0 * sin(work_t * PI), 2.5, _night)
		_sun_azim = lerpf(-58.0, 58.0, work_t)
	_key.rotation_degrees = Vector3(-_sun_elev, _sun_azim, 0)

	# Low sun, warm sun. The disc goes over to orange as it comes down, which
	# is the cheapest possible sunset and reads from across a room.
	var low := 1.0 - clampf(_sun_elev / 34.0, 0.0, 1.0)
	_place_body(_sun_body, _sun_elev, _sun_azim,
		Color(1.35, 1.30, 1.15).lerp(Color(1.50, 0.82, 0.44), low), sun_up)

	var fraction := _world.rest_fraction()
	if moon_up > 0.0 and fraction >= 0.0:
		_moon_elev = 8.0 + 38.0 * sin(fraction * PI)
		_moon_azim = lerpf(58.0, -58.0, fraction)
	_moon.visible = moon_up > 0.004
	if _moon.visible:
		_moon.rotation_degrees = Vector3(-_moon_elev, _moon_azim, 0)
		_moon.light_energy = 0.55 * moon_up * sin(deg_to_rad(_moon_elev))
	_place_body(_moon_body, _moon_elev, _moon_azim,
		Color(1.10, 1.14, 1.25), moon_up)

	var hint: float = _world.rest_hint() if fraction >= 0.0 else 0.0
	_rest_label.modulate.a = lerpf(_rest_label.modulate.a, hint * 0.55,
		clampf(delta * 1.6, 0.0, 1.0))


## The focus layer.
##
## The scene gets only the small timer/status overlay it needs to read as a
## focus app. Camera gestures stay available for looking around, but no map,
## story target, or control label competes with the build.
func _build_back() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110
	_field_marks = FieldMarks.new()
	layer.add_child(_field_marks)
	_expedition_marks = ExpeditionMarks.new()
	_expedition_marks.set_context(_camera, _sleeping_hill)
	_expedition_marks.lantern_tapped.connect(_begin_expedition)
	_expedition_marks.cairn_tapped.connect(_on_story_step)
	_expedition_marks.choice_tapped.connect(_resolve_expedition)
	layer.add_child(_expedition_marks)
	_act_marks = ActMarks.new()
	_act_marks.rooted_species_chosen.connect(_resolve_rooted_gate)
	_act_marks.lost_destination_chosen.connect(_resolve_lost_lights)
	_act_marks.migration_tapped.connect(_begin_migration)
	layer.add_child(_act_marks)
	_field_marks.visible = not FOCUS_ONLY
	_expedition_marks.visible = not FOCUS_ONLY
	_act_marks.visible = not FOCUS_ONLY

	_focus_hud = FocusHud.new()
	_focus_hud.food_requested.connect(_on_food_requested)
	_focus_hud.rally_requested.connect(_on_rally_requested)
	add_child(_focus_hud)
	add_child(layer)


## It stays on screen rather than being hidden behind a gesture, but it settles
## to almost nothing so it is not something you are looking at for twenty-five
## minutes. It never goes to zero: a control you cannot see is a control that is
## not there.
func _fade_back(delta: float) -> void:
	# Focus mode has no persistent camera control label competing with the scene.
	_drift = maxf(0.0, _drift - delta)


## How far back the camera has to stand for the whole arc of regions to fit
## across the frame, in metres.
##
## Derived rather than typed, from the width of the world, the lens the map is
## seen through and the shape of the viewport, so that moving a region in
## `Region.ORIGINS` cannot quietly leave one of them off the edge of the frame.
func _map_distance() -> float:
	var vp := get_viewport().get_visible_rect().size
	var aspect := maxf(vp.x, 1.0) / maxf(vp.y, 1.0)
	# `fov` is the vertical angle, and the arc runs across the frame. Measured
	# against the map's own lens rather than the region's, because by the time
	# the camera is out this far it is looking through the other one.
	var half := atan(tan(deg_to_rad(MAP_LENS) * 0.5) * aspect)

	# A tenth of headroom, so the two end regions sit in the world rather than
	# jammed against the bezel.
	return Region.reach() / maxf(tan(half), 0.05) * 1.10


func _move_camera(delta: float) -> void:
	if _world == null:
		return

	if _zoom_to >= 0.0:
		_zoom = lerpf(_zoom, _zoom_to, clampf(delta * 3.2, 0.0, 1.0))
		if absf(_zoom - _zoom_to) < 0.01:
			_zoom = _zoom_to
			_zoom_to = -1.0

	_map_blend(delta)

	var nominal: float = _world.distance
	# Out on the map the camera stops looking at the region and starts looking
	# at the middle of everything, so pulling back walks the world into frame
	# rather than leaving the place you were in stuck under the thumb.
	var focal: Vector3 = _world.focus.lerp(
		Region.centre(_island) + Vector3(0, 0.4, 0), _map) + _pan
	var base_pitch: float = atan2(_world.rise, nominal)

	# Inside a region, distance is the pinch times the region's own framing, as
	# it always was. Out past `MAP_FROM` it stops being proportional and heads
	# for wherever the whole world happens to fit - which is a hundred and
	# seventy metres for five regions and would be further for eight, without
	# the gesture changing at all. The two agree at the join, because `_map` is
	# nought there and the lerp collapses onto the first term.
	var unit := sqrt(nominal * nominal + _world.rise * _world.rise)
	var away := lerpf(unit * _zoom, _map_distance(), _map)

	var yaw := _yaw

	# Dragging down used to walk the camera round and under the island, which
	# is the one direction there is nothing to see in - and, because the camera
	# always aims at the island, it never turned the view toward the sky no
	# matter how far it went. That is why the sun and the moon were unfindable:
	# not missing, but behind the top edge of the frame at every angle a thumb
	# could reach.
	#
	# So the orbit stops just above level, and everything past that tilts the
	# aim upward from where the camera already is. Keep dragging and the island
	# slides off the bottom of the frame and you are looking at the weather.
	var want := base_pitch + _pitch + MAP_PITCH * _map
	var pitch := clampf(want, ORBIT_FLOOR, 1.18)
	var aim_up := maxf(0.0, ORBIT_FLOOR - want)

	if _has_sensors:
		# Tilt still adds a little parallax on top of wherever the user has put
		# the camera. It is the difference between looking at a screen and
		# looking into something, and it is deliberately separate from work.
		var g := Input.get_gravity()
		if g.length() > 0.1:
			g = g.normalized()
			# Gravity is reported in the device's own frame, which does not turn
			# when the screen does. Held the other way up in landscape, the same
			# lean produces the opposite x.
			var flipped := DisplayServer.screen_get_orientation() \
				== DisplayServer.SCREEN_REVERSE_LANDSCAPE
			var lean := Vector2(g.x, g.z)
			if flipped:
				lean.x = -lean.x
			_tilt = _tilt.lerp(lean, clampf(delta * 2.2, 0.0, 1.0))
		yaw += _tilt.x * _world.orbit_gain
		pitch = clampf(pitch + _tilt.y * 0.12, 0.10, 1.18)

	_camera.position = focal + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * away
	_camera.look_at(focal, Vector3.UP)
	if aim_up > 0.0:
		_camera.rotate_object_local(Vector3.RIGHT, aim_up)


## What being out at the world rather than in a region changes, other than the
## distance.
##
## Only one thing, and it is the haze. The fog was tuned against thirteen metres
## of island and there are eighty metres of world; left alone it swallows both
## ends of the arc and the map becomes one region and some weather. Thinned as
## the camera pulls back, it does the job it was there for - saying how far away
## the far end is - instead of hiding it.
##
## Everything else about the map is the same scene from further off. There is no
## second camera, no orthographic switch, no icons and no labels: the reason to
## build the map out of the world was so that there would be nothing to keep in
## step with it.
func _map_blend(delta: float) -> void:
	var want := clampf(inverse_lerp(MAP_FROM, ZOOM_MAX, _zoom), 0.0, 1.0)
	# Smoothed, so the haze does not step when a pinch does.
	_map = lerpf(_map, want * want * (3.0 - 2.0 * want),
		clampf(delta * 6.0, 0.0, 1.0))

	if _env != null:
		_env.fog_density = lerpf(_fog_density, _fog_density * 0.12, _map)
	if _camera != null and _world != null:
		_camera.fov = lerpf(_world.lens, MAP_LENS, _map)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()

	# A sky, not a void. The palette here was tuned for glowing objects against
	# black back when this was Lightning in a Bottle, and it stayed unexamined
	# through a daylight building site with nothing overhead to say where the
	# light was coming from. A sky is not a vessel, so nothing about the
	# phone-is-the-bottle rule objects to having one.
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2E3A5C")
	sky_mat.sky_horizon_color = Color("8C8FA0")
	sky_mat.sky_curve = 0.14
	sky_mat.ground_bottom_color = Color("463E38")
	sky_mat.ground_horizon_color = Color("8C8FA0")
	# The lower hemisphere is not a strip along the bottom of the frame in this
	# app, it is nearly all of the background: the camera looks down from
	# thirty-six degrees up through a thirty-four degree lens, so everything
	# behind the land sits between nineteen and fifty-three degrees below the
	# horizon, and every pixel of it is the ground half of the sky.
	#
	# At 0.32 that whole band came out as one flat pale wall. It holds the
	# horizon colour nearly the entire way down, which means `ground_bottom_color`
	# was being carefully chosen for a part of the sphere nobody has ever seen,
	# and the background - two thirds of every frame - read as paper.
	#
	# The number goes the opposite way from how it reads: **lower is a faster
	# fall to the bottom colour.** That was settled by rendering the two ends in
	# flat red and blue and looking, which took two captures, and it is written
	# down here so nobody has to do it again. At 0.02 the band is entirely the
	# bottom colour and at 1.7 entirely the horizon colour. This puts the
	# transition inside the band, so the background graduates from the warm glow
	# near the horizon down into the region's own haze, which is what air with
	# distance in it looks like.
	#
	# Worth knowing before touching it: ambient is 78 per cent sky, so these two
	# colours light the island as well as sitting behind it.
	sky_mat.ground_curve = 0.13
	# No sun from the sky material. Every directional light in the scene gets
	# one and none of them is controllable enough to be the sun this app wants -
	# see `_build_lights`.
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	_sky_mat = sky_mat

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("463E5E")
	env.ambient_light_energy = 0.80
	# Mostly the sky, which is why brightening the sky brightens the island as
	# well as the background. Not entirely, though: without this the per-island
	# ambient colour that `_apply_lighting` sets is dead code, because ambient
	# taken purely from the sky ignores it, and five islands that each chose an
	# ambient tint would all have been getting the same one.
	env.ambient_light_sky_contribution = 0.78

	# Bloom is what turns a lit window into something worth walking toward.
	# Threshold sits below the white point so the hot cores clip into glow.
	env.glow_enabled = true
	env.glow_intensity = 1.20
	env.glow_hdr_threshold = 0.80
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# `glow_bloom` is not the glow. It is a floor added underneath the
	# threshold, so a fraction of *every* pixel gets blurred and added back
	# over the frame whether it is a hearth or a patch of grass. At 0.40 that
	# is a forty percent full-screen haze, which was invisible when this was
	# glowing objects against a black void and turns a daylight scene into
	# milk - which is what "the sky is not bright enough" actually looked
	# like. The sky was never dark. It was washed colourless.
	env.glow_bloom = 0.05

	# Aerial perspective from cheap distance fog, not the volumetric kind. The
	# mobile renderer has none, and it was the most expensive thing in the scene
	# by a distance.
	env.fog_enabled = true
	env.fog_light_color = Color("2A2A44")
	env.fog_light_energy = 0.6
	env.fog_density = 0.016
	# Aerial perspective belongs on the island, not on the sky behind it. At
	# 0.35 a third of every sky pixel was the fog's dark blue-grey, which is a
	# fast way to grey out a colour that was chosen carefully.
	env.fog_sky_affect = 0.10

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	_env = env
	world.environment = env
	add_child(world)


## The three lights, and the reason none of them draws itself.
##
## `ProceduralSkyMaterial` does put a sun in the sky for each of the first four
## `DirectionalLight3D`s in the scene, so the previous session's assumption was
## not wrong exactly - but it was never checked, and what it actually produces
## is a wide soft halo rather than a disc, because the size of that halo comes
## from the light's `light_angular_distance`, which defaults to zero. Worse,
## every directional light gets one: the fill was quietly painting a second sun
## into the sky from behind, at 152 degrees, which is most of why nobody could
## find the real one.
##
## The property last session reached for was `light_angular_size`, which does
## not exist; the real name is `light_angular_distance`. Setting it correctly
## does produce a disc. It is still the wrong mechanism for this app, because
## the disc's brightness is the light's brightness - so the moon, which is dim
## on purpose, would be invisible on purpose too, and a sun that has to dim at
## dusk would shrink out of the sky instead of going orange.
##
## So all three are `SKY_MODE_LIGHT_ONLY` and the sun and moon are drawn as
## real objects in `_build_bodies`, where their size, colour and glow are ours.
func _build_lights() -> void:
	_key = DirectionalLight3D.new()
	_key.shadow_enabled = false
	_key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_key)

	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-14, 152, 0)
	_fill.shadow_enabled = false
	_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_fill)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("AEC4E6")
	_moon.light_energy = 0.0
	_moon.visible = false
	_moon.shadow_enabled = false
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)


## How far out the sun and moon are hung. Inside the camera's far plane with
## room to spare, and far enough past the island that no amount of orbiting or
## panning gets near them.
const BODY_DIST := 44.0

## Apparent diameter, in degrees. The real sun is half of one degree, which on
## a phone held at arm's length is four pixels and not worth drawing. These are
## the size the sun is remembered as rather than the size it is.
const SUN_ANGLE := 5.4
const MOON_ANGLE := 4.6


## The sun and the moon, as two billboards hung a long way off.
##
## Unshaded, so nothing lights them and they are exactly the colour they are
## told to be; fog disabled, so forty metres of aerial perspective does not
## grey out the one thing in the frame that is meant to be the brightest; and
## an albedo pushed past white, so both clip through the glow threshold in
## `_build_environment` and bloom rather than sitting flat.
func _build_bodies() -> void:
	_sun_body = _sky_body(_disc(Color("FFF6DC"), Color("FFC55E"), 0), SUN_ANGLE)
	_moon_body = _sky_body(_disc(Color("F2F5FF"), Color("A8BEE4"), 3), MOON_ANGLE)
	_moon_body.visible = false


func _sky_body(tex: ImageTexture, angle_deg: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	# Values above white. A Color is not clamped on its way to the shader, and
	# the glow threshold is 0.80, so this is what makes a sun bloom instead of
	# being a pale sticker.
	mat.albedo_color = Color(1.35, 1.30, 1.15)

	var quad := QuadMesh.new()
	var span := 2.0 * BODY_DIST * tan(deg_to_rad(angle_deg) * 0.5)
	# The texture is mostly halo, so the mesh has to be several times the
	# diameter of the disc it contains.
	quad.size = Vector2(span * DISC_SPAN, span * DISC_SPAN)

	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


const DISC_TEX := 96
## How much wider the whole billboard is than the solid disc at its centre.
const DISC_SPAN := 2.6


## A body and the air around it, drawn once into a texture.
##
## The disc itself is a flat core with a slightly warmer rim, which is what
## stops it reading as a sticker; outside it the alpha falls away as a cube,
## which is a close enough approximation of atmospheric scatter and, more to
## the point, is what makes the thing look like it is giving off light rather
## than being a circle.
##
## `blotches` puts a few darker patches on the face. Three of them turn a pale
## disc into the moon, which is a startling amount of recognition for nine
## lines of code.
func _disc(core: Color, rim: Color, blotches: int) -> ImageTexture:
	var img := Image.create(DISC_TEX, DISC_TEX, false, Image.FORMAT_RGBA8)
	var half := float(DISC_TEX) * 0.5
	var edge := 1.0 / DISC_SPAN            ## Where the solid disc ends.
	var feather := 1.6 / half

	var seeds: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EA
	for _i in blotches:
		seeds.append(Vector3(rng.randf_range(-0.5, 0.5),
			rng.randf_range(-0.5, 0.5), rng.randf_range(0.16, 0.30)))

	for y in DISC_TEX:
		for x in DISC_TEX:
			var p := Vector2((float(x) + 0.5) / half - 1.0,
				(float(y) + 0.5) / half - 1.0)
			var r := p.length()

			var solid := clampf((edge - r) / feather + 0.5, 0.0, 1.0)
			var halo := pow(clampf(1.0 - (r - edge) / maxf(1.0 - edge, 1e-5),
				0.0, 1.0), 3.0)

			var c := core.lerp(rim, clampf(r / edge, 0.0, 1.0) * 0.85)
			for s in seeds:
				c = c.lerp(c.darkened(0.30), clampf(
					1.0 - Vector2(p.x - s.x, p.y - s.y).length() / s.z, 0.0, 1.0))

			c.a = maxf(solid, halo * 0.42)
			img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


## Hangs a body along a light's direction, at the far end of it. The light
## shines *from* the body, so the body sits opposite the way the light points.
func _place_body(node: MeshInstance3D, elevation: float, azimuth: float,
		tint: Color, up: float) -> void:
	if node == null or _camera == null:
		return
	node.visible = up > 0.004
	if not node.visible:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(-elevation),
		deg_to_rad(azimuth), 0.0))
	node.position = _camera.position + basis.z * BODY_DIST
	var mat := node.material_override as StandardMaterial3D
	mat.albedo_color = Color(tint.r, tint.g, tint.b, up)


## The whole palette was tuned for glowing objects against a black void, back
## when this was Lightning in a Bottle, and it stayed that way through a
## daylight building site with a sky now overhead to make the dimness obvious.
## Raised here rather than by editing every energy on every island, so the
## five stay in the same relation to each other they were tuned in.
const LIGHT_BOOST := 1.35

## Each island sets the light it wants to be seen in. An arctic key on a jungle
## floor is the fastest way to make five places look like one place recoloured.
func _apply_lighting(world: World) -> void:
	_key.light_color = world.key_color
	_key_energy = world.key_energy * LIGHT_BOOST
	_fill.light_color = world.fill_color
	_fill_energy = world.fill_energy * LIGHT_BOOST
	_env.ambient_light_color = world.ambient_color
	_ambient_energy = world.ambient_energy * LIGHT_BOOST

	var b := Biome.of(_island)
	_env.fog_light_color = b["fog"]
	_fog_density = b["fog_density"]
	_env.fog_density = _fog_density

	# The sky used to be derived from this same palette - a ten percent lerp
	# from the ambient colour toward the key, then darkened again. That was the
	# mistake behind "the sky is not bright enough": the ambient colour is a
	# dark violet-grey chosen to sit under a scene, and no small nudge toward a
	# cream key light turns it into a daytime sky. Deriving one number from
	# another is only worth doing when the two actually want to agree, and a
	# sky and a fill light do not.
	#
	# So each island now designs its own, and they differ in the shape of the
	# gradient as well as its colour - the arctic's is flat and pale from top
	# to bottom, the desert's holds deep blue until a hard band of glare at the
	# horizon. See `Biome`.
	_sky_day_top = b["sky_top"]
	_sky_day_horizon = b["sky_horizon"]
	_sky_mat.sky_curve = b["sky_curve"]

	# Night is the island's own, tinted into its haze so the five nights are as
	# different as the five days, if less so - which is true of real nights.
	_sky_night_top = b["sky_night"]
	_sky_night_horizon = Color(b["sky_night"]).lerp(b["fog"], 0.55).lightened(0.05)

	_haze_floor = b["fog"]
	_sky_written = -1.0
	_write_sky(_sky_day_top, _sky_day_horizon)


## The island floats, so the half of the background below the horizon is not
## ground - it is distance.
##
## This is the part that was actually wrong, and it took a capture to see it.
## The camera looks thirty-six degrees down through a thirty-four degree lens,
## which puts the horizon nineteen degrees above the top of the frame: at the
## default angle, and at every angle the user could reach, *none* of what is
## visible behind the island is the sky half of the sky material. All of it is
## the ground half, and the ground half was `earth` darkened by a third - mud.
## Every hour spent tuning `sky_top_color` was spent on a colour nobody had
## ever seen.
##
## So the lower hemisphere carries the horizon colour straight down, settling
## into the island's own haze. The gradient is continuous through the horizon
## line, which is what makes the island read as sitting in luminous air rather
## than as a plate pasted on a backdrop.
func _write_sky(top: Color, horizon: Color) -> void:
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.lerp(_haze_floor, 0.62)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.position = Vector3(0, 4, 8)
	# Far enough to hold the whole arc of regions with the camera pulled back to
	# the map, and then some. It was sixty, which was ample for one island and
	# would have clipped the far half of the world in two.
	_camera.far = 400.0
	# No depth of field. It is a per-pixel blur pass for a scene that reads
	# perfectly well without one, and heat is the constraint here.
	add_child(_camera)
	_camera.current = true


func _build_finish() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/finish.gdshader")
	rect.material = mat

	layer.add_child(rect)
	add_child(layer)


func _read_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--after="):
			_capture_after = float(arg.trim_prefix("--after="))
		elif arg.begins_with("--island=") or arg.begins_with("--region="):
			# `--island` is what every script and note in the repo says. The
			# places are regions now; the flag answers to both.
			_island = clampi(int(arg.get_slice("=", 1)), 0, Biome.COUNT - 1)
		elif arg.begins_with("--screen="):
			_capture_screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--yaw="):
			_arg_yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
		elif arg.begins_with("--zoom="):
			_arg_zoom = maxf(float(arg.trim_prefix("--zoom=")), ZOOM_MIN)
		elif arg.begins_with("--pitch="):
			# In the same units the drag produces, so a capture can be taken
			# from an angle a thumb could actually have reached. Without this
			# there was no way to check the sky from the command line at all,
			# which is most of why nobody noticed it was never on screen.
			_arg_pitch = clampf(deg_to_rad(float(arg.trim_prefix("--pitch="))),
				PITCH_MIN, 0.62)
		elif arg.begins_with("--pan="):
			var parts := arg.trim_prefix("--pan=").split(",", false)
			if parts.size() == 2:
				_arg_pan = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--feed="):
			# The coastline takes two hours in real play.
			# Captures need to inspect its whole loop in seconds, not hours.
			_arg_feed = clampf(float(arg.trim_prefix("--feed=")), 0.0, 1.0)
		elif arg == "--feast":
			# Starts a complete feed at launch, so the rain and meal can be
			# checked without synthesising a screen tap in headless captures.
			_arg_feast = true
		elif arg.begins_with("--route="):
			# A deterministic local route for proving the imagined world loop.
			_arg_route = arg.trim_prefix("--route=")
		elif arg == "--route-reset":
			# Capture-only cleanup for a repeatable empty-neighborhood look.
			# This is deliberately not a player-facing way to erase a walk.
			_arg_route_reset = true
		elif arg.begins_with("--story="):
			_arg_story = arg.trim_prefix("--story=")
		elif arg == "--story-reset":
			_arg_story_reset = true
		elif arg.begins_with("--story-stage="):
			_arg_story_stage = arg.trim_prefix("--story-stage=")
		elif arg == "--act-reset":
			_arg_act_reset = true
		elif arg.begins_with("--fable="):
			_arg_fable = arg.trim_prefix("--fable=").replace("-", "_")
		elif arg.begins_with("--fable-stage="):
			_arg_fable_stage = arg.trim_prefix("--fable-stage=")
		elif arg.begins_with("--fire="):
			# Sends the lantern to a region at launch, so eighty seconds of
			# somebody walking can be looked at without tapping anything.
			_arg_fire = clampi(int(arg.trim_prefix("--fire=")), 0, Biome.COUNT - 1)
		elif arg.begins_with("--rest="):
			# Drops straight into a break, a given fraction of the way through
			# it, so fifteen minutes of it can be looked at without waiting an
			# hour for it to start.
			_force_rest = clampf(float(arg.trim_prefix("--rest=")), 0.0, 1.0)


func _maybe_capture() -> void:
	if _capture_path.is_empty() or _elapsed < _capture_after or _capturing:
		return

	# Awaiting the draw returns to _process, which calls this again on the next
	# frame while the first call is still suspended. Without the guard every
	# subsequent frame tries to save to a path the first one has already cleared.
	_capturing = true

	# Printed with every capture, because the last session's sun was assumed to
	# be working from a screenshot that could not have contained it either way.
	# Now a capture says where both bodies are and whether they are drawn, so
	# "I cannot see the sun" and "there is no sun" stay distinguishable.
	print("[capture] sun %.0f deg up, %.0f across, drawn=%s"
		% [_sun_elev, _sun_azim, _sun_body.visible],
		" | moon %.0f deg up, %.0f across, drawn=%s"
		% [_moon_elev, _moon_azim, _moon_body.visible],
		" | night=%.2f" % _night)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	_capture_path = ""
	get_tree().quit()
