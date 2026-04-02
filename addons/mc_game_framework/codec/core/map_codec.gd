## MapCodec — DFU 风格字段级结构编解码器
##
## 受 Mojang DFU MapCodec 思路启发：
## - 负责对象/字段级结构编解码（encode_to_map / decode_from_map）
## - 支持 field_of / optional_field_of 组合
## - 支持多字段 Record 组合（RecordCodecBuilder 风格）
## - 每个 MapCodec 可通过 codec() 转为 Codec
extends RefCounted
class_name MapCodec

# ── 核心 API（子类实现） ──────────────────────────────

## 从 Map 数据解码为运行时对象
func decode_from_map(map_value: Variant, ops: DynamicOps) -> DataResult:
	return DataResult.error("MapCodec.decode_from_map() not implemented")

## 将运行时对象编码为 Map 数据
func encode_to_map(value: Variant, ops: DynamicOps) -> DataResult:
	return DataResult.error("MapCodec.encode_to_map() not implemented")

## 转为 Codec
func codec() -> Codec:
	return Codec.record(self)

# ── 组合器 ────────────────────────────────────────────

## 为解码结果施加变换（getter: 从大对象中提取本字段值用于 encode）
func for_getter(getter: Callable) -> MapCodec:
	return GetterMapCodec.new(self, getter)

# ── 静态工厂：RecordCodecBuilder 风格 ──────────────────

## 组合多个 MapCodec 字段，创建 Record 结构
## fields: Array[MapCodec] — 各字段的 MapCodec（必须通过 for_getter 设置了 getter）
## constructor: Callable — 接受各字段解码值，返回完整对象
## 返回: MapCodec
static func build(fields: Array, constructor: Callable) -> MapCodec:
	return RecordMapCodec.new(fields, constructor)

# ═══════════════════════════════════════════════════════
# 内部实现：FieldCodec（单字段 MapCodec）
# ═══════════════════════════════════════════════════════

class FieldCodec extends MapCodec:
	var _name: String
	var _codec: Codec
	var _optional: bool
	var _default_value: Variant

	func _init(name: String, codec: Codec, optional: bool, default_value: Variant) -> void:
		_name = name
		_codec = codec
		_optional = optional
		_default_value = default_value

	func decode_from_map(map_value: Variant, ops: DynamicOps) -> DataResult:
		var field_result := ops.get_map_value(map_value, _name)
		if field_result.is_error():
			if _optional:
				return DataResult.success(_default_value)
			return DataResult.error("Missing required field '%s'" % _name).set_path_prefix(_name)
		var decode_result := _codec.decode(field_result.get_value(), ops)
		if decode_result.is_error():
			if _optional:
				return DataResult.partial(_default_value,
					"Failed to decode field '%s', using default: %s" % [_name, decode_result.get_error()])
			return decode_result.set_path_prefix(_name)
		return decode_result

	func encode_to_map(value: Variant, ops: DynamicOps) -> DataResult:
		# value 是该字段的值（不是整个对象）
		if _optional and _is_default(value):
			# 可选字段且为默认值时裁剪（不写入）
			return DataResult.success(ops.create_map({}))
		var encode_result := _codec.encode(value, ops)
		if encode_result.is_error():
			return encode_result.set_path_prefix(_name)
		return DataResult.success(ops.create_map({_name: encode_result.get_value()}))

	func _is_default(value: Variant) -> bool:
		if _default_value == null and value == null:
			return true
		if _default_value != null and value != null:
			# Use type-safe comparison
			if typeof(_default_value) == typeof(value):
				return _default_value == value
		return false

# ═══════════════════════════════════════════════════════
# 内部实现：GetterMapCodec（附加 getter 的 MapCodec 包装）
# ═══════════════════════════════════════════════════════

class GetterMapCodec extends MapCodec:
	var _inner: MapCodec
	var _getter: Callable  ## (object) -> field_value

	func _init(inner: MapCodec, getter: Callable) -> void:
		_inner = inner
		_getter = getter

	func decode_from_map(map_value: Variant, ops: DynamicOps) -> DataResult:
		return _inner.decode_from_map(map_value, ops)

	func encode_to_map(value: Variant, ops: DynamicOps) -> DataResult:
		# value 是完整对象，通过 getter 提取字段值
		var field_value = _getter.call(value)
		return _inner.encode_to_map(field_value, ops)

# ═══════════════════════════════════════════════════════
# 内部实现：RecordMapCodec（多字段组合 MapCodec）
# ═══════════════════════════════════════════════════════

class RecordMapCodec extends MapCodec:
	var _fields: Array  ## Array[MapCodec] — 每个都应通过 for_getter() 设置了 getter
	var _constructor: Callable  ## (...field_values) -> object

	func _init(fields: Array, constructor: Callable) -> void:
		_fields = fields
		_constructor = constructor

	func decode_from_map(map_value: Variant, ops: DynamicOps) -> DataResult:
		var field_values: Array = []
		var diagnostics: Array = []
		var has_fatal := false
		var has_partial := false

		for field: MapCodec in _fields:
			var result := field.decode_from_map(map_value, ops)
			if result.is_error():
				has_fatal = true
				diagnostics.append_array(result.get_diagnostics())
				field_values.append(null)
			else:
				if result.is_partial():
					has_partial = true
				field_values.append(result.get_value())
				diagnostics.append_array(result.get_diagnostics())

		if has_fatal:
			var r := DataResult.error("Failed to decode record: missing or invalid required fields")
			r._diagnostics = diagnostics
			return r

		# 调用构造函数
		var obj = _constructor.callv(field_values)
		var r: DataResult
		if has_partial:
			r = DataResult.partial(obj, "Record decoded with partial fields")
		else:
			r = DataResult.success(obj)
		r._diagnostics = diagnostics
		return r

	func encode_to_map(value: Variant, ops: DynamicOps) -> DataResult:
		var merged: Variant = ops.create_map({})
		var diagnostics: Array = []

		for field: MapCodec in _fields:
			var result := field.encode_to_map(value, ops)
			if result.is_error():
				diagnostics.append_array(result.get_diagnostics())
				continue
			diagnostics.append_array(result.get_diagnostics())
			merged = ops.merge_maps(merged, result.get_value())

		var r := DataResult.success(merged)
		r._diagnostics = diagnostics
		return r
