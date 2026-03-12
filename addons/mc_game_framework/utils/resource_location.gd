extends RefCounted
class_name ResourceLocation

var namespace_id: String:
	set(v):
		namespace_id = v
		_str_cache = "%s:%s" % [namespace_id, id]
var id: String:
	set(v):
		id = v
		_str_cache = "%s:%s" % [namespace_id, id]
var _str_cache: String

func _init(p_namespace: String = "", p_path: String = "") -> void:
	namespace_id = p_namespace
	id = p_path
	_str_cache = "%s:%s" % [namespace_id, id]

static func from_string(location_str: String) -> ResourceLocation:
	if location_str.is_empty():
		push_error("ResourceLocation.from_string: empty string")
		return null
	var parts = location_str.split(":", true, 1)
	if parts.size() != 2:
		push_error("Invalid ResourceLocation format: " + location_str)
		return null
	if parts[0].is_empty() or parts[1].is_empty():
		push_error("ResourceLocation namespace and id must not be empty: " + location_str)
		return null
	return ResourceLocation.new(parts[0], parts[1])

func _to_string() -> String:
	return _str_cache

func equals(other: ResourceLocation) -> bool:
	if other == null:
		return false
	return namespace_id == other.namespace_id and id == other.id
