## TypeRewriteRule — DFU 风格类型重写规则
##
## 对齐 Mojang DFU TypeRewriteRule 设计：
## - 描述单条迁移操作：字段改名、字段拆分、嵌套重组、枚举映射等
## - 每条规则可限定作用范围（type_name）
## - 通过 apply(data, ops) 执行迁移
extends RefCounted
class_name TypeRewriteRule

## 规则适用的类型名称（空字符串表示适用于所有类型）
var target_type: String = ""

func _init(p_target_type: String = "") -> void:
	target_type = p_target_type

## 判断此规则是否适用于指定类型
func applies_to(type_name: String) -> bool:
	return target_type.is_empty() or target_type == type_name

## 执行规则（子类实现）
func apply(data: Variant, ops: DynamicOps) -> DataResult:
	return DataResult.error("TypeRewriteRule.apply() not implemented")

# ═══════════════════════════════════════════════════════
# 预置规则：字段改名
# ═══════════════════════════════════════════════════════

class RenameField extends TypeRewriteRule:
	var _old_name: String
	var _new_name: String

	func _init(target: String, old_name: String, new_name: String) -> void:
		super(target)
		_old_name = old_name
		_new_name = new_name

	func apply(data: Variant, ops: DynamicOps) -> DataResult:
		if not ops.is_map(data):
			return DataResult.success(data)
		var old_result := ops.get_map_value(data, _old_name)
		if old_result.is_error():
			# 字段不存在，跳过
			return DataResult.success(data)
		var value = old_result.get_value()
		var result = ops.remove_map_value(data, _old_name)
		result = ops.set_map_value(result, _new_name, value)
		return DataResult.success(result)

# ═══════════════════════════════════════════════════════
# 预置规则：添加带默认值的字段
# ═══════════════════════════════════════════════════════

class AddField extends TypeRewriteRule:
	var _field_name: String
	var _default_value: Variant

	func _init(target: String, field_name: String, default_value: Variant) -> void:
		super(target)
		_field_name = field_name
		_default_value = default_value

	func apply(data: Variant, ops: DynamicOps) -> DataResult:
		if not ops.is_map(data):
			return DataResult.success(data)
		var existing := ops.get_map_value(data, _field_name)
		if not existing.is_error():
			# 字段已存在，跳过
			return DataResult.success(data)
		var result = ops.set_map_value(data, _field_name, _default_value)
		return DataResult.success(result)

# ═══════════════════════════════════════════════════════
# 预置规则：移除字段
# ═══════════════════════════════════════════════════════

class RemoveField extends TypeRewriteRule:
	var _field_name: String

	func _init(target: String, field_name: String) -> void:
		super(target)
		_field_name = field_name

	func apply(data: Variant, ops: DynamicOps) -> DataResult:
		if not ops.is_map(data):
			return DataResult.success(data)
		return DataResult.success(ops.remove_map_value(data, _field_name))

# ═══════════════════════════════════════════════════════
# 预置规则：值映射（枚举/ID 重命名）
# ═══════════════════════════════════════════════════════

class MapFieldValue extends TypeRewriteRule:
	var _field_name: String
	var _value_map: Dictionary  ## old_value -> new_value

	func _init(target: String, field_name: String, value_map: Dictionary) -> void:
		super(target)
		_field_name = field_name
		_value_map = value_map

	func apply(data: Variant, ops: DynamicOps) -> DataResult:
		if not ops.is_map(data):
			return DataResult.success(data)
		var field_result := ops.get_map_value(data, _field_name)
		if field_result.is_error():
			return DataResult.success(data)
		var old_value = field_result.get_value()
		if _value_map.has(old_value):
			return DataResult.success(ops.set_map_value(data, _field_name, _value_map[old_value]))
		return DataResult.success(data)

# ═══════════════════════════════════════════════════════
# 预置规则：自定义 Callable 迁移
# ═══════════════════════════════════════════════════════

class CustomRule extends TypeRewriteRule:
	var _transform: Callable  ## (data: Variant, ops: DynamicOps) -> DataResult

	func _init(target: String, transform: Callable) -> void:
		super(target)
		_transform = transform

	func apply(data: Variant, ops: DynamicOps) -> DataResult:
		return _transform.call(data, ops)
