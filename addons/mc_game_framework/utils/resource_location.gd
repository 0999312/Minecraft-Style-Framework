## ResourceLocation — Minecraft 风格资源标识符
##
## 参考 Mojang 原版设计：
## - 格式: namespace:path
## - namespace 和 path 均使用小写
## - 合法字符: 小写字母(a-z)、数字(0-9)、下划线(_)、连字符(-)、点(.)
## - path 中额外允许斜杠(/)用于层级分隔
## - 路径层级含义由开发者自行约定，框架只做格式合法性校验
extends RefCounted
class_name ResourceLocation

## namespace 合法字符正则：小写字母、数字、_、-、.
const NAMESPACE_PATTERN := "^[a-z0-9_\\-.]+$"
## path 合法字符正则：小写字母、数字、_、-、.、/
const PATH_PATTERN := "^[a-z0-9_\\-./]+$"

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

## 从字符串解析（保留向后兼容，不强制校验）
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

## 严格模式解析（带 Mojang 风格合法性校验，返回 DataResult）
static func parse(location_str: String) -> DataResult:
	if location_str.is_empty():
		return DataResult.error("ResourceLocation: empty string")
	var parts = location_str.split(":", true, 1)
	if parts.size() != 2:
		return DataResult.error("Invalid ResourceLocation format (missing ':'): %s" % location_str)
	if parts[0].is_empty() or parts[1].is_empty():
		return DataResult.error("ResourceLocation namespace and path must not be empty: %s" % location_str)
	var ns_result := validate_namespace(parts[0])
	if ns_result.is_error():
		return ns_result
	var path_result := validate_path(parts[1])
	if path_result.is_error():
		return path_result
	return DataResult.success(ResourceLocation.new(parts[0], parts[1]))

## 校验完整字符串格式（返回 DataResult）
static func validate(location_str: String) -> DataResult:
	return parse(location_str).map(func(_v): return true)

## 校验 namespace 合法性
static func validate_namespace(ns: String) -> DataResult:
	if ns.is_empty():
		return DataResult.error("ResourceLocation namespace must not be empty")
	var regex := RegEx.new()
	regex.compile(NAMESPACE_PATTERN)
	if not regex.search(ns):
		return DataResult.error(
			"Invalid ResourceLocation namespace '%s': only lowercase letters (a-z), digits (0-9), '_', '-', '.' are allowed" % ns)
	return DataResult.success(ns)

## 校验 path 合法性
static func validate_path(path: String) -> DataResult:
	if path.is_empty():
		return DataResult.error("ResourceLocation path must not be empty")
	var regex := RegEx.new()
	regex.compile(PATH_PATTERN)
	if not regex.search(path):
		return DataResult.error(
			"Invalid ResourceLocation path '%s': only lowercase letters (a-z), digits (0-9), '_', '-', '.', '/' are allowed" % path)
	return DataResult.success(path)

## 判断给定字符串是否为合法的 ResourceLocation 格式
static func is_valid(location_str: String) -> bool:
	var result := parse(location_str)
	return result.is_success()

func _to_string() -> String:
	return _str_cache

func equals(other: ResourceLocation) -> bool:
	if other == null:
		return false
	return namespace_id == other.namespace_id and id == other.id
