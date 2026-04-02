## JsonOps — JSON 格式的 DynamicOps 实现
##
## 对齐 DFU JsonOps：
## - Variant 作为 JSON 中间表示（Dictionary / Array / String / int / float / bool / null）
## - encode 产生 Godot JSON 兼容的 Variant 结构
## - decode 接受 JSON.parse_string 返回的 Variant 结构
extends DynamicOps
class_name JsonOps

## 全局单例（避免反复创建）
static var INSTANCE := JsonOps.new()

# ── 基本类型创建 ──────────────────────────────────────

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
	return DataResult.error("Expected int, got: %s (%s)" % [str(value), type_string(typeof(value))])

func get_float(value: Variant) -> DataResult:
	if value is float:
		return DataResult.success(value)
	if value is int:
		return DataResult.success(float(value))
	return DataResult.error("Expected float, got: %s (%s)" % [str(value), type_string(typeof(value))])

func get_bool(value: Variant) -> DataResult:
	if value is bool:
		return DataResult.success(value)
	return DataResult.error("Expected bool, got: %s (%s)" % [str(value), type_string(typeof(value))])

func get_string(value: Variant) -> DataResult:
	if value is String:
		return DataResult.success(value)
	return DataResult.error("Expected String, got: %s (%s)" % [str(value), type_string(typeof(value))])

# ── 复合类型操作 ──────────────────────────────────────

func get_map_value(map_value: Variant, key: String) -> DataResult:
	if not (map_value is Dictionary):
		return DataResult.error("Expected Dictionary, got: %s" % type_string(typeof(map_value)))
	var dict: Dictionary = map_value
	if not dict.has(key):
		return DataResult.error("Key '%s' not found in map" % key)
	return DataResult.success(dict[key])

func set_map_value(map_value: Variant, key: String, value: Variant) -> Variant:
	var dict: Dictionary
	if map_value is Dictionary:
		dict = map_value.duplicate()
	else:
		dict = {}
	dict[key] = value
	return dict

func remove_map_value(map_value: Variant, key: String) -> Variant:
	if not (map_value is Dictionary):
		return map_value
	var dict: Dictionary = map_value.duplicate()
	dict.erase(key)
	return dict

func get_map_keys(map_value: Variant) -> DataResult:
	if not (map_value is Dictionary):
		return DataResult.error("Expected Dictionary for map keys, got: %s" % type_string(typeof(map_value)))
	return DataResult.success(map_value.keys())

func get_map_entries(map_value: Variant) -> DataResult:
	if not (map_value is Dictionary):
		return DataResult.error("Expected Dictionary for map entries, got: %s" % type_string(typeof(map_value)))
	return DataResult.success(map_value)

func get_list(value: Variant) -> DataResult:
	if value is Array:
		return DataResult.success(value)
	return DataResult.error("Expected Array, got: %s" % type_string(typeof(value)))

func merge_maps(first: Variant, second: Variant) -> Variant:
	var result: Dictionary = {}
	if first is Dictionary:
		result.merge(first)
	if second is Dictionary:
		result.merge(second, true)
	return result

# ── 类型判断 ──────────────────────────────────────────

func is_map(value: Variant) -> bool:
	return value is Dictionary

func is_list(value: Variant) -> bool:
	return value is Array

func is_number(value: Variant) -> bool:
	return value is int or value is float

func is_string(value: Variant) -> bool:
	return value is String

func get_name() -> String:
	return "JsonOps"

# ── JSON 辅助方法 ─────────────────────────────────────

## 将 Variant 结构序列化为 JSON 字符串
static func to_json_string(value: Variant, indent: String = "\t") -> String:
	return JSON.stringify(value, indent)

## 将 JSON 字符串解析为 Variant 结构
static func from_json_string(json_str: String) -> DataResult:
	var parsed = JSON.parse_string(json_str)
	if parsed == null and json_str != "null":
		return DataResult.error("JSON parse error")
	return DataResult.success(parsed)
