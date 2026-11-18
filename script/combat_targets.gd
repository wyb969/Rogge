extends Node


class Entry:
	extends RefCounted
	var actor: Node2D
	var health_field: StringName
	var death_field: StringName
var _entries: Array[Entry] = []
var _slots: = {}
var queries: = 0
var candidates_examined: = 0

func _ready() -> void :
	get_tree().node_added.connect(_added)
	get_tree().node_removed.connect(_removed)

func _added(node: Node) -> void :
	if not node is Node2D or not (node.has_method("apply_hit") or node.has_method("get_hit")): return
	var entry: = Entry.new()
	entry.actor = node
	entry.health_field = &"boss_current_health" if "boss_current_health" in node else (&"health" if "health" in node else &"")
	for flag in [&"_death_started", &"is_dying", &"is_dead", &"is_death"]:
		if flag in node:
			entry.death_field = flag
			break
	_slots[node.get_instance_id()] = _entries.size()
	_entries.append(entry)

func _removed(node: Node) -> void :
	var id: = node.get_instance_id()
	if not _slots.has(id): return
	var index: int = _slots[id]
	var last: Entry = _entries.back()
	_entries[index] = last
	_slots[last.actor.get_instance_id()] = index
	_entries.pop_back()
	_slots.erase(id)

func _live(entry: Entry, group: StringName) -> bool:
	var actor: = entry.actor
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group(group): return false
	if entry.death_field != &"" and actor.get(entry.death_field): return false
	return entry.health_field == &"" or float(actor.get(entry.health_field)) > 0

func nearest(origin: Vector2, distance_squared: float = INF, excluded: Dictionary = {}, group: StringName = &"EnemyGroup") -> Node2D:
	queries += 1
	candidates_examined += _entries.size()
	var best: Node2D
	for entry in _entries:
		if not _live(entry, group) or excluded.has(entry.actor): continue
		var distance: = origin.distance_squared_to(entry.actor.global_position)
		if distance < distance_squared:
			distance_squared = distance
			best = entry.actor
	return best

func nearest_visible(origin: Vector2, radius_squared: float, limit: int, owner: Node, rect: Rect2, canvas: Transform2D) -> Array[Node2D]:
	queries += 1
	candidates_examined += _entries.size()
	var result: Array[Node2D] = []
	var distances: = PackedFloat64Array()
	if limit <= 0: return result
	for entry in _entries:
		var actor: = entry.actor
		if not _live(entry, &"EnemyGroup") or not owner.is_ancestor_of(actor) or not actor.has_method("apply_hit"): continue
		var distance: = origin.distance_squared_to(actor.global_position)
		if distance > radius_squared or not rect.has_point(canvas * actor.global_position): continue

		var at: = 0
		while at < distances.size() and distances[at] <= distance: at += 1
		if at >= limit: continue
		result.insert(at, actor)
		distances.insert(at, distance)
		if result.size() > limit:
			result.pop_back()
			distances.resize(limit)
	return result

func tracked_count() -> int:
	return _entries.size()

func in_radius(origin: Vector2, radius_squared: float, owner: Node) -> Array[Node2D]:
	queries += 1
	candidates_examined += _entries.size()
	var result: Array[Node2D] = []
	for entry in _entries:
		if _live(entry, &"EnemyGroup") and owner.is_ancestor_of(entry.actor) and entry.actor.has_method("apply_hit") and origin.distance_squared_to(entry.actor.global_position) <= radius_squared:
			result.append(entry.actor)
	return result

func fill_in_bounds(bounds: Rect2, owner: Node, result: Array[Node2D]) -> void :
	queries += 1
	candidates_examined += _entries.size()
	for entry in _entries:
		if _live(entry, &"EnemyGroup") and owner.is_ancestor_of(entry.actor) and entry.actor.has_method("apply_hit") and bounds.has_point(entry.actor.global_position): result.append(entry.actor)

func fill_in_radius(origin: Vector2, radius_squared: float, owner: Node, result: Array[Node2D]) -> void :
	queries += 1
	candidates_examined += _entries.size()
	for entry in _entries:
		if not _live(entry, &"EnemyGroup"): continue
		var actor: = entry.actor
		if owner != null and not owner.is_ancestor_of(actor): continue
		if origin.distance_squared_to(actor.global_position) <= radius_squared: result.append(actor)
