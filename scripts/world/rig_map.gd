class_name RigMap
extends RefCounted

## Parser for the plain-text rig layouts in data/maps/.
##
## The format is deliberately editable by hand: two character grids plus a few
## key/value sections. Storing the layout as text rather than packed TileMap
## data means a level change is a readable diff.

class Zone:
	var id: StringName
	var kind: StringName
	var rect: Rect2i

	func _init(zone_id: StringName, zone_kind: StringName, zone_rect: Rect2i) -> void:
		id = zone_id
		kind = zone_kind
		rect = zone_rect

	func contains(cell: Vector2i) -> bool:
		return rect.has_point(cell)


var map_name: String = ""
var width: int = 0
var height: int = 0
var spawn: Vector2i = Vector2i.ZERO
var ground: PackedStringArray = PackedStringArray()
var props: PackedStringArray = PackedStringArray()
var zones: Array[Zone] = []
var errors: PackedStringArray = PackedStringArray()


static func load_from(path: String) -> RigMap:
	var map := RigMap.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		map.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return map
	map._parse(file.get_as_text())
	return map


func is_valid() -> bool:
	return errors.is_empty()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func ground_symbol(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return "#"
	return ground[cell.y][cell.x]


func prop_symbol(cell: Vector2i) -> String:
	if not in_bounds(cell):
		return TileCatalog.EMPTY_SYMBOL
	return props[cell.y][cell.x]


func is_solid(cell: Vector2i) -> bool:
	## Out of bounds counts as solid so the player cannot leave the hull.
	if not in_bounds(cell):
		return true
	var ground_entry := TileCatalog.ground_entry(ground_symbol(cell))
	if ground_entry.get("solid", false):
		return true
	return TileCatalog.prop_entry(prop_symbol(cell)).get("solid", false)


func zone_at(cell: Vector2i) -> Zone:
	for zone in zones:
		if zone.contains(cell):
			return zone
	return null


func zone_by_id(id: StringName) -> Zone:
	for zone in zones:
		if zone.id == id:
			return zone
	return null


func zones_of_kind(kind: StringName) -> Array[Zone]:
	var found: Array[Zone] = []
	for zone in zones:
		if zone.kind == kind:
			found.append(zone)
	return found


func pixel_size() -> Vector2i:
	return Vector2i(width, height) * TileCatalog.TILE_SIZE


func cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(TileCatalog.TILE_SIZE)


func _parse(text: String) -> void:
	var section := ""
	for raw_line in text.split("\n"):
		var line := raw_line.trim_suffix("\r")
		if line.strip_edges().is_empty():
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
			continue
		# '#' is a wall tile, so comments are only comments outside the grids.
		if line.begins_with("#") and section != "ground" and section != "props":
			continue

		match section:
			"":
				_parse_header(line)
			"ground":
				ground.append(line)
			"props":
				props.append(line)
			"spawn":
				_parse_spawn(line)
			"zones":
				_parse_zone(line)
			_:
				errors.append("unknown section: %s" % section)

	_validate()


func _parse_header(line: String) -> void:
	var parts := line.split("=", true, 1)
	if parts.size() != 2:
		errors.append("malformed header line: %s" % line)
		return
	var key := parts[0].strip_edges()
	var value := parts[1].strip_edges()
	match key:
		"name":
			map_name = value
		"width":
			width = value.to_int()
		"height":
			height = value.to_int()
		_:
			errors.append("unknown header key: %s" % key)


func _parse_spawn(line: String) -> void:
	var parts := line.split("=", true, 1)
	if parts.size() != 2:
		errors.append("malformed spawn line: %s" % line)
		return
	var coords := parts[1].strip_edges().split(",")
	if coords.size() != 2:
		errors.append("spawn needs x,y: %s" % line)
		return
	if parts[0].strip_edges() == "player":
		spawn = Vector2i(coords[0].to_int(), coords[1].to_int())


func _parse_zone(line: String) -> void:
	var parts := line.split("=", true, 1)
	if parts.size() != 2:
		errors.append("malformed zone line: %s" % line)
		return
	var fields := parts[1].strip_edges().split(",")
	if fields.size() != 5:
		errors.append("zone needs x,y,w,h,kind: %s" % line)
		return
	zones.append(
		Zone.new(
			StringName(parts[0].strip_edges()),
			StringName(fields[4].strip_edges()),
			Rect2i(
				fields[0].to_int(), fields[1].to_int(), fields[2].to_int(), fields[3].to_int()
			)
		)
	)


func _validate() -> void:
	if width <= 0 or height <= 0:
		errors.append("width and height must be positive")
		return
	for label in [["ground", ground], ["props", props]]:
		var rows: PackedStringArray = label[1]
		if rows.size() != height:
			errors.append("%s has %d rows, expected %d" % [label[0], rows.size(), height])
			continue
		for y in rows.size():
			if rows[y].length() != width:
				errors.append(
					"%s row %d is %d wide, expected %d" % [label[0], y, rows[y].length(), width]
				)

	for y in mini(ground.size(), height):
		for x in mini(ground[y].length(), width):
			if not TileCatalog.GROUND_SYMBOLS.has(ground[y][x]):
				errors.append("unknown ground symbol '%s' at %d,%d" % [ground[y][x], x, y])
	for y in mini(props.size(), height):
		for x in mini(props[y].length(), width):
			var symbol := props[y][x]
			if symbol == TileCatalog.EMPTY_SYMBOL:
				continue
			if not TileCatalog.PROP_SYMBOLS.has(symbol):
				errors.append("unknown prop symbol '%s' at %d,%d" % [symbol, x, y])

	if not in_bounds(spawn):
		errors.append("spawn %s is outside the map" % spawn)
	elif is_solid(spawn):
		errors.append("spawn %s is inside a solid tile" % spawn)
