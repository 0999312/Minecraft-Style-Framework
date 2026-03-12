extends RefCounted
class_name RegistryBase

var _entries: Dictionary = {}  # 键为 ResourceLocation 的字符串形式，值为任意类型

func register(id: ResourceLocation, entry: Variant) -> void:
	if not _validate_entry(entry):
		push_error("Registry entry validation failed for '%s': expected type %s" % [id.to_string(), _get_expected_type_name()])
		return
	var key = id.to_string()
	if _entries.has(key):
		push_warning("Overwriting registry entry: ", key)
	_entries[key] = entry

func unregister(id: ResourceLocation) -> bool:
	var key = id.to_string()
	if _entries.has(key):
		_entries.erase(key)
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

# 虚方法：子类可覆写以限制条目类型，校验失败时 register() 将拒绝注册
func _validate_entry(_entry: Variant) -> bool:
	return true

# 虚方法：校验失败时在错误信息中显示期望的类型名称
func _get_expected_type_name() -> String:
	return "Variant"
