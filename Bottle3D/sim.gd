extends SceneTree

## Runs an island headless at thirty ticks a second, far faster than real time,
## and reports what the elves actually spent the day doing and what is in every
## heap.
##
##   Godot --path . --headless --script sim.gd -- --minutes=90 --island=0
##
## Not part of the app, and the only sane way to work on the economy.
##
## The alternative is watching a three minute screen capture and guessing, which
## is how a workforce that never leaves the campfire goes unnoticed - and worse,
## how a bug that stopped every single delivery from completing survived several
## rounds of looking at the thing and thinking it seemed fine. An island can be
## fully animated, fully populated, and achieving absolutely nothing, and there
## is no camera angle from which that is obvious.

const NAMES := ["none", "gather", "craft", "haul", "deliver", "fit", "look",
	"rest", "idle", "own", "play", "carry fire", "eat", "cook"]


func _process(_delta: float) -> bool:
	# Run from the first frame rather than from _initialize, so the world is
	# genuinely inside the tree and global transforms exist.
	_run()
	return true


func _run() -> void:
	var minutes := 20.0
	var island := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			minutes = float(arg.trim_prefix("--minutes="))
		elif arg.begins_with("--island="):
			island = int(arg.trim_prefix("--island="))

	var world := ElfWorld.new(island)
	root.add_child(world)
	world.build()

	var dt := 1.0 / 30.0
	var steps := int(minutes * 60.0 / dt)
	var spent := {}

	for i in steps:
		world.advance(dt)
		if i % 15 == 0:
			for e in world._elves:
				spent[e.task] = int(spent.get(e.task, 0)) + 1

	var total := 0
	for k in spent:
		total += int(spent[k])

	print("--- %.0f minutes on island %d ---" % [minutes, island])
	print("elves: ", world._elves.size(), "  stations: ", world._stations.size())
	print("resting: ", world.resting(), "  through the break: %.2f"
		% world.rest_fraction())
	if world.resting():
		var doing := {}
		for e in world._elves:
			doing[e.pastime] = int(doing.get(e.pastime, 0)) + 1
		print("  ", doing)

	var order := spent.keys()
	order.sort_custom(func(a, b): return int(spent[a]) > int(spent[b]))
	for k in order:
		print("  %-9s %5.1f%%" % [NAMES[int(k)],
			100.0 * float(spent[k]) / maxf(float(total), 1.0)])

	var done := 0
	for w in world._works:
		if w.done:
			done += 1
	print("works done: ", done, " of ", world._works.size())
	if done < world._works.size():
		var open_now = world._open()
		for w in open_now:
			var short := []
			for k in w.spec["cost"]:
				if w.needs(int(k)) > 0:
					short.append("%s x%d" % [Plan.KIND_NAME[int(k)], w.needs(int(k))])
			print("  open: %-14s wants %s" % [w.spec["id"], ", ".join(short)])

	for st in world._stations:
		var ins := []
		if st.in_pile:
			for k in st.inputs:
				ins.append("%s %d/%d" % [Plan.KIND_NAME[int(k)],
					st.in_pile.of(int(k)), int(st.inputs[k])])
		print("  %-11s out %s %d/%d   in %s" % [st.id,
			Plan.KIND_NAME[st.out_kind], st.out_pile.count(), st.out_pile.limit,
			", ".join(ins) if ins else "-"])

	var stock := {}
	for p in world._piles:
		for it in p.items:
			var k := int(it.get_meta("kind"))
			stock[k] = int(stock.get(k, 0)) + 1
	var held := []
	for k in stock:
		held.append("%s %d" % [Plan.KIND_NAME[int(k)], stock[k]])
	print("on the island: ", ", ".join(held) if held else "nothing")

	quit()
