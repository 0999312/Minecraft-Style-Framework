## GodotResourceOps — Godot Resource 格式的 DynamicOps 实现
##
## 支持 Godot Resource (.tres/.res) 落盘：
## - 使用 Dictionary 作为中间表示（与 JsonOps 共享结构）
## - 额外支持 Resource 对象的属性反射读写
## - 支持 CodecResource 的 save/load 流程
extends DynamicOps
class_name GodotResourceOps

## 全局单例
static var INSTANCE := GodotResourceOps.new()

# ── 基本类型创建（与 JsonOps 相同） ──────────────────

func empty() -> Variant:
	return null

func create_int(value: int) -> Variant:
	return value

func create_float(value: float) -> Variant:
	return value

func create_bool(value: bool) -> Variant:
	return value

func create_string(value: String) -> Variant:
	return value

func create_list(values: Array) -> Variant:
	return values

func create_map(entries: Dictionary) -> Variant:
	return entries

# ── 基本类型读取 ──────────────────────────────────────

func get_int(value: Variant) -> DataResult:
	if value is int:
		return DataResult.success(value)
	if value is float:
		return DataResult.success(int(value))
	return DataResult.error("GodotResourceOps: expected int, got: %s" % type_string(typeof(value)))

func get_float(value: Variant) -> DataResult:
	if value is float:
		return DataResult.success(value)
	if value is int:
		return DataResult.success(float(value))
	return DataResult.error("GodotResourceOps: expected float, got: %s" % type_string(typeof(value)))

func get_bool(value: Variant) -> DataResult:
	if value is bool:
		return DataResult.success(value)
	return DataResult.error("GodotResourceOps: expected bool, got: %s" % type_string(typeof(value)))

func get_string(value: Variant) -> DataResult:
	if value is String:
		return DataResult.success(value)
	return DataResult.error("GodotResourceOps: expected String, got: %s" % type_string(typeof(value)))

# ── 复合类型操作 ──────────────────────────────────────

func get_map_value(map_value: Variant, key: String) -> DataResult:
	# 支持 Dictionary 和 Resource 两种来源
	if map_value is Dictionary:
		if not map_value.has(key):
			return DataResult.error("Key '%s' not found in map" % key)
		return DataResult.success(map_value[key])
	if map_value is Resource:
		var props := _get_resource_properties(map_value)
		if props.has(key):
			return DataResult.success(map_value.get(key))
		return DataResult.error("Property '%s' not found on Resource" % key)
	return DataResult.error("GodotResourceOps: expected Dictionary or Resource, got: %s" % type_string(typeof(map_value)))

func set_map_value(map_value: Variant, key: String, value: Variant) -> Variant:
	var dict: Dictionary
	if map_value is Dictionary:
		dict = map_value.duplicate()
	elif map_value is Resource:
		dict = resource_to_dict(map_value)
	else:
		dict = {}
	dict[key] = value
	return dict

func remove_map_value(map_value: Variant, key: String) -> Variant:
	if map_value is Dictionary:
		var dict := (map_value as Dictionary).duplicate()
		dict.erase(key)
		return dict
	return map_value

func get_map_keys(map_value: Variant) -> DataResult:
	if map_value is Dictionary:
		return DataResult.success(map_value.keys())
	if map_value is Resource:
		return DataResult.success(_get_resource_properties(map_value).keys())
	return DataResult.error("GodotResourceOps: expected Dictionary or Resource for map keys")

func get_map_entries(map_value: Variant) -> DataResult:
	if map_value is Dictionary:
		return DataResult.success(map_value)
	if map_value is Resource:
		return DataResult.success(resource_to_dict(map_value))
	return DataResult.error("GodotResourceOps: expected Dictionary or Resource for map entries")

func get_list(value: Variant) -> DataResult:
	if value is Array:
		return DataResult.success(value)
	return DataResult.error("GodotResourceOps: expected Array, got: %s" % type_string(typeof(value)))

func merge_maps(first: Variant, second: Variant) -> Variant:
	var result: Dictionary = {}
	if first is Dictionary:
		result.merge(first)
	if second is Dictionary:
		result.merge(second, true)
	return result

# ── 类型判断 ──────────────────────────────────────────

func is_map(value: Variant) -> bool:
	return value is Dictionary or value is Resource

func is_list(value: Variant) -> bool:
	return value is Array

func is_number(value: Variant) -> bool:
	return value is int or value is float

func is_string(value: Variant) -> bool:
	return value is String

func get_name() -> String:
	return "GodotResourceOps"

# ── Resource 辅助方法 ─────────────────────────────────

## 将 Resource 对象的 @export 属性转为 Dictionary
static func resource_to_dict(res: Resource) -> Dictionary:
	var dict := {}
	for prop in res.get_property_list():
		# 只导出用户声明的属性（PROPERTY_USAGE_STORAGE）
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			dict[prop["name"]] = res.get(prop["name"])
	return dict

## 将 Dictionary 值写回 Resource 对象的属性
static func dict_to_resource(dict: Dictionary, res: Resource) -> DataResult:
	var props := _get_resource_properties_static(res)
	var diagnostics: Array = []
	for key in dict:
		if props.has(key):
			res.set(key, dict[key])
		else:
			diagnostics.append(DataResult.Diagnostic.new(
				DataResult.DiagnosticLevel.WARNING,
				"Unknown property '%s' ignored when writing to Resource" % key, key))
	var result := DataResult.success(res)
	result._diagnostics = diagnostics
	return result

## 保存 Resource 到文件
static func save_resource(res: Resource, path: String) -> DataResult:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		return DataResult.error("Failed to save Resource to '%s': error %d" % [path, err])
	return DataResult.success(path)

## 从文件加载 Resource
static func load_resource(path: String) -> DataResult:
	if not ResourceLoader.exists(path):
		return DataResult.error("Resource file not found: '%s'" % path)
	var res := ResourceLoader.load(path)
	if res == null:
		return DataResult.error("Failed to load Resource from: '%s'" % path)
	return DataResult.success(res)

# ── 内部辅助 ──────────────────────────────────────────

func _get_resource_properties(res: Resource) -> Dictionary:
	return _get_resource_properties_static(res)

static func _get_resource_properties_static(res: Resource) -> Dictionary:
	var props := {}
	for prop in res.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_STORAGE and prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[prop["name"]] = prop
	return props
