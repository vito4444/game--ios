class_name ItemCatalog
extends RefCounted

## Every item definition, loaded from data/items/items.json.

const DEFAULT_PATH := "res://data/items/items.json"


class Item:
	var id: StringName
	var name: String
	var description: String
	var icon: StringName
	var contraband: bool
	var value: int
	var size: int

	func _init(data: Dictionary) -> void:
		id = StringName(data.get("id", ""))
		name = data.get("name", "")
		description = data.get("description", "")
		icon = StringName(data.get("icon", ""))
		contraband = bool(data.get("contraband", false))
		value = int(data.get("value", 0))
		size = int(data.get("size", 1))


var items: Array[Item] = []
var errors: PackedStringArray = PackedStringArray()

var _by_id: Dictionary = {}


static func load_from(path: String = DEFAULT_PATH) -> ItemCatalog:
	var catalog := ItemCatalog.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		catalog.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return catalog

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		catalog.errors.append("%s is not a JSON object" % path)
		return catalog

	for entry in (parsed as Dictionary).get("items", []) as Array:
		catalog._add(Item.new(entry as Dictionary))
	catalog._validate()
	return catalog


func is_valid() -> bool:
	return errors.is_empty()


func has(id: StringName) -> bool:
	return _by_id.has(id)


func get_item(id: StringName) -> Item:
	return _by_id.get(id)


func is_contraband(id: StringName) -> bool:
	var item := get_item(id)
	return item != null and item.contraband


func size_of(id: StringName) -> int:
	var item := get_item(id)
	return item.size if item != null else 1


func display_name(id: StringName) -> String:
	var item := get_item(id)
	return item.name if item != null else String(id)


func contraband_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for item in items:
		if item.contraband:
			found.append(item.id)
	return found


func _add(item: Item) -> void:
	if _by_id.has(item.id):
		errors.append("duplicate item id: %s" % item.id)
		return
	items.append(item)
	_by_id[item.id] = item


func _validate() -> void:
	if items.is_empty():
		errors.append("catalog has no items")
	for item in items:
		if item.id == &"":
			errors.append("an item has no id")
		if item.name.is_empty():
			errors.append("%s has no display name" % item.id)
		if item.size <= 0:
			errors.append("%s must take at least one slot" % item.id)
		if item.value < 0:
			errors.append("%s has a negative value" % item.id)
