extends SceneTree

## The first real-world loop has to survive a restart before it is worth
## rendering. This is intentionally pure domain coverage: location permission,
## native sampling, and server trust all sit outside RouteBook.

func _init() -> void:
	var book := RouteBook.new()
	var walked := book.record(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(12.0, 0.0), Vector2(12.0, 8.0),
	]))
	assert(walked == 5)
	assert(book.segments().size() == 5)
	assert(book.sites().size() == 1)

	var restored := RouteBook.new()
	restored.deserialize(book.serialize())
	restored.deserialize_sites(book.serialize_sites())
	restored.deserialize_claims(book.serialize_claims())
	assert(restored.segments().size() == 5)
	var site: Dictionary = restored.sites()[0]
	assert(restored.claim_site(String(site["id"])))
	assert(not restored.claim_site(String(site["id"])))
	var claimed := RouteBook.new()
	claimed.deserialize(book.serialize())
	claimed.deserialize_sites(book.serialize_sites())
	claimed.deserialize_claims(restored.serialize_claims())
	assert(bool(claimed.sites()[0]["claimed"]))

	print("route_book_test passed")
	quit()
