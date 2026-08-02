class_name FableCatalog
extends RefCounted

## Small data-only unlock table for the three Meadow myths.

const SLEEPING_HILL := "sleeping_hill"
const ROOTED_GATE := "rooted_gate"
const LOST_LIGHTS := "lost_lights"
const MIGRATION := "migration"

static func available(state: FableState) -> String:
	if state.resolution(SLEEPING_HILL) == FableState.UNRESOLVED:
		return SLEEPING_HILL
	if state.resolution(ROOTED_GATE) == FableState.UNRESOLVED:
		return ROOTED_GATE
	if state.resolution(LOST_LIGHTS) == FableState.UNRESOLVED:
		return LOST_LIGHTS
	if not state.meadow_act_complete:
		return MIGRATION
	return ""

static func unlocked(state: FableState, id: String) -> bool:
	if id == SLEEPING_HILL:
		return true
	if id == ROOTED_GATE:
		return state.resolution(SLEEPING_HILL) != FableState.UNRESOLVED
	if id == LOST_LIGHTS:
		return state.resolution(ROOTED_GATE) != FableState.UNRESOLVED
	if id == MIGRATION:
		return state.all_chapters_resolved()
	return false
