class_name RigNavigation
extends RefCounted

## Grid pathfinding over a RigMap.
##
## Officers need to route around the hull rather than walk into it, both while
## patrolling and while chasing. AStarGrid2D handles that, and building it from
## the same map data the collision comes from means the two cannot disagree.

var _astar: AStarGrid2D
var _map: RigMap


func _init(map: RigMap) -> void:
	_map = map
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, map.width, map.height)
	_astar.cell_size = Vector2(TileCatalog.TILE_SIZE)
	# Officers walk the deck, not through door frames diagonally.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	rebuild()


## Re-reads solidity from the map.
##
## Doors count as walkable even while shut. They open for whoever is entitled to
## walk through them, and treating them as walls here would leave the rig as a
## set of disconnected rooms with no route between them.
func rebuild() -> void:
	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, _map.is_solid(cell) and not _map.is_door(cell))


func set_cell_solid(cell: Vector2i, solid: bool) -> void:
	if _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, solid)


func is_walkable(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


## Cells from `from_cell` to `to_cell` inclusive, or empty when unreachable.
func path_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return result
	result.assign(_astar.get_id_path(from_cell, to_cell))
	return result


## World-space waypoints, centred on each tile.
func world_path_between(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in path_between(from_cell, to_cell):
		points.append(_map.cell_centre(cell))
	return points


## The nearest walkable cell to `cell`, searched outward. Used to recover when
## something is nudged into geometry.
func nearest_walkable(cell: Vector2i, max_radius: int = 6) -> Vector2i:
	if is_walkable(cell):
		return cell
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if is_walkable(candidate):
					return candidate
	return cell
