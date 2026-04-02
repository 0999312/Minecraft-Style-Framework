## Schema — DFU 风格版本结构定义
##
## 对齐 Mojang DFU Schema 设计：
## - 每个 Schema 代表某一版本的数据结构定义
## - 版本号为整数，单调递增
## - 通过 Schema 链描述数据结构的版本演进
extends RefCounted
class_name Schema

## 版本号
var version: int

## 该版本的类型定义（type_name -> TypeTemplate）
var _types: Dictionary = {}  ## String -> Variant（描述结构）

func _init(p_version: int) -> void:
	version = p_version

## 注册一个类型的结构定义
func register_type(type_name: String, type_definition: Variant) -> void:
	_types[type_name] = type_definition

## 获取类型定义
func get_type(type_name: String) -> Variant:
	return _types.get(type_name)

## 获取所有已注册的类型名
func get_type_names() -> Array:
	return _types.keys()

## 是否包含指定类型
func has_type(type_name: String) -> bool:
	return _types.has(type_name)

func _to_string() -> String:
	return "Schema(v%d, types=%s)" % [version, str(_types.keys())]
