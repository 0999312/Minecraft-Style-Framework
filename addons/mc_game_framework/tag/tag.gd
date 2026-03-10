extends Resource
class_name Tag

var registry_type: ResourceLocation  # 指向注册表的 ResourceLocation，如 "registry:item"
var _entries: Dictionary = {}  # 条目ID字符串 -> true

func _init(p_registry_type: ResourceLocation) -> void:
	registry_type = p_registry_type

func add_entry(entry_id: ResourceLocation) -> void:
	var key = entry_id.to_string()
	_entries[key] = true

func remove_entry(entry_id: ResourceLocation) -> bool:
	var key = entry_id.to_string()
	if _entries.has(key):
		_entries.erase(key)
		return true
	return false

func has_entry(entry_id: ResourceLocation) -> bool:
	return _entries.has(entry_id.to_string())

func get_all_entries() -> Array[ResourceLocation]:
	var result: Array[ResourceLocation] = []
	for key in _entries.keys():
		result.append(ResourceLocation.from_string(key))
	return result

func get_entry_count() -> int:
	return _entries.size()

func clear_entries() -> void:
	_entries.clear()
