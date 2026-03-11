extends Node
class_name RegistryBase

var _entries: Dictionary = {}  # 键为 ResourceLocation 的字符串形式，值为任意类型

func register(id: ResourceLocation, entry: Variant) -> void:
	var key = id.to_string()
	if _entries.has(key):
		push_warning("Overwriting registry entry: ", key)
	print(id.to_string() + " registered")
	_entries[key] = entry

func unregister(id: ResourceLocation) -> bool:
	var key = id.to_string()
	if _entries.has(key):
		_entries.erase(key)
		print(id.to_string() + " unregistered")
		return true
	return false

func get_entry(id: ResourceLocation) -> Variant:
	return _entries.get(id.to_string())

func has_entry(id: ResourceLocation) -> bool:
	return _entries.has(id.to_string())

func get_all_entries() -> Dictionary:
	return _entries.duplicate()

func get_all_keys() -> Array:
	return _entries.keys()

func clear() -> void:
	_entries.clear()
