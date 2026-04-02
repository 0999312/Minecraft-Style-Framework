## DynamicOps — DFU 风格数据载体抽象
##
## 受 Mojang DFU DynamicOps 思路启发：
## - 将底层数据格式（当前内置 JSON / Godot Resource）统一抽象
## - 上层 Codec 不关心载体，只关心读写语义
## - 同一个 Codec 可以对接任意 DynamicOps 实现
extends RefCounted
class_name DynamicOps

# ── 基本类型创建 ──────────────────────────────────────

## 创建空值
func empty() -> Variant:
	return null

## 从 int 创建值
func create_int(value: int) -> Variant:
	push_error("DynamicOps.create_int() not implemented")
	return null

## 从 float 创建值
func create_float(value: float) -> Variant:
	push_error("DynamicOps.create_float() not implemented")
	return null

## 从 bool 创建值
func create_bool(value: bool) -> Variant:
	push_error("DynamicOps.create_bool() not implemented")
	return null

## 从 String 创建值
func create_string(value: String) -> Variant:
	push_error("DynamicOps.create_string() not implemented")
	return null

## 创建列表
func create_list(values: Array) -> Variant:
	push_error("DynamicOps.create_list() not implemented")
	return null

## 创建 Map（键值对结构）
func create_map(entries: Dictionary) -> Variant:
	push_error("DynamicOps.create_map() not implemented")
	return null

# ── 基本类型读取 ──────────────────────────────────────

## 读取为 int
func get_int(value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_int() not implemented")

## 读取为 float
func get_float(value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_float() not implemented")

## 读取为 bool
func get_bool(value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_bool() not implemented")

## 读取为 String
func get_string(value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_string() not implemented")

# ── 复合类型操作 ──────────────────────────────────────

## 从 Map 中获取指定 key 的值
func get_map_value(map_value: Variant, key: String) -> DataResult:
	return DataResult.error("DynamicOps.get_map_value() not implemented")

## 设置 Map 中指定 key 的值（返回新 Map）
func set_map_value(map_value: Variant, key: String, value: Variant) -> Variant:
	push_error("DynamicOps.set_map_value() not implemented")
	return null

## 移除 Map 中指定 key（返回新 Map）
func remove_map_value(map_value: Variant, key: String) -> Variant:
	push_error("DynamicOps.remove_map_value() not implemented")
	return null

## 获取 Map 所有键
func get_map_keys(map_value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_map_keys() not implemented")

## 获取 Map 所有键值对
func get_map_entries(map_value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_map_entries() not implemented")

## 将值解读为列表
func get_list(value: Variant) -> DataResult:
	return DataResult.error("DynamicOps.get_list() not implemented")

## 合并两个 Map
func merge_maps(first: Variant, second: Variant) -> Variant:
	push_error("DynamicOps.merge_maps() not implemented")
	return null

# ── 类型判断 ──────────────────────────────────────────

## 是否是 Map 类型
func is_map(value: Variant) -> bool:
	return false

## 是否是 List 类型
func is_list(value: Variant) -> bool:
	return false

## 是否是数值类型
func is_number(value: Variant) -> bool:
	return false

## 是否是字符串类型
func is_string(value: Variant) -> bool:
	return false

## 获取 Ops 的名称标识
func get_name() -> String:
	return "DynamicOps"
