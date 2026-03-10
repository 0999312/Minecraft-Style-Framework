extends Resource
class_name ResourceLocation

var namespace_id: String
var id: String

func _init(p_namespace: String, p_path: String) -> void:
	namespace_id = p_namespace
	id = p_path

static func from_string(location_str: String) -> ResourceLocation:
	var parts = location_str.split(":", true, 1)
	if parts.size() != 2:
		push_error("Invalid ResourceLocation format: " + location_str)
		return null
	return ResourceLocation.new(parts[0], parts[1])

func to_string() -> String:
	return "%s:%s" % [namespace_id, id]

func _to_string() -> String:
	return to_string()

func equals(other: ResourceLocation) -> bool:
	return namespace_id == other.namespace_id and id == other.id
