## Codec — DFU 风格编解码器
##
## 受 Mojang DFU Codec 思路启发：
## - encode(value, ops) -> DataResult  将运行时对象编码到 DynamicOps 载体
## - decode(value, ops) -> DataResult  将载体数据解码为运行时对象
## - 支持组合式声明：field_of / optional_field_of / list_of / map_of / either / xmap / dispatch
## - 同一个 Codec 定义可用于多个 DynamicOps 实现（当前内置 JSON / Godot Resource）
extends RefCounted
class_name Codec

# ── 核心 API（子类实现） ──────────────────────────────

## 编码：将运行时值编码到 ops 载体格式
func encode(value: Variant, ops: DynamicOps) -> DataResult:
	return DataResult.error("Codec.encode() not implemented")

## 解码：从 ops 载体格式解码为运行时值
func decode(value: Variant, ops: DynamicOps) -> DataResult:
	return DataResult.error("Codec.decode() not implemented")

# ── 组合器 API ────────────────────────────────────────

## 将此 Codec 转为 MapCodec 中的必填字段
func field_of(name: String) -> MapCodec:
	return MapCodec.FieldCodec.new(name, self, false, null)

## 将此 Codec 转为 MapCodec 中的可选字段（带默认值）
func optional_field_of(name: String, default_value: Variant = null) -> MapCodec:
	return MapCodec.FieldCodec.new(name, self, true, default_value)

## 构造列表 Codec
func list_of() -> Codec:
	return ListCodec.new(self)

## xmap：同步变换编解码值
func xmap(decode_fn: Callable, encode_fn: Callable) -> Codec:
	return XmapCodec.new(self, decode_fn, encode_fn)

## flat_xmap：变换可能失败（返回 DataResult）
func flat_xmap(decode_fn: Callable, encode_fn: Callable) -> Codec:
	return FlatXmapCodec.new(self, decode_fn, encode_fn)

# ── 静态工厂 ──────────────────────────────────────────

## 基础类型 Codec

## bool
static func BOOL() -> Codec:
	return PrimitiveCodec.new(PrimitiveCodec.PrimitiveType.BOOL)

## int
static func INT() -> Codec:
	return PrimitiveCodec.new(PrimitiveCodec.PrimitiveType.INT)

## float
static func FLOAT() -> Codec:
	return PrimitiveCodec.new(PrimitiveCodec.PrimitiveType.FLOAT)

## String
static func STRING() -> Codec:
	return PrimitiveCodec.new(PrimitiveCodec.PrimitiveType.STRING)

## ResourceLocation codec
static func RESOURCE_LOCATION() -> Codec:
	return ResourceLocationCodec.new()

## 构造键值对 map Codec
static func map_of(key_codec: Codec, value_codec: Codec) -> Codec:
	return MapOfCodec.new(key_codec, value_codec)

## 构造 Either Codec（优先尝试 first，失败则尝试 second）
static func either(first: Codec, second: Codec) -> Codec:
	return EitherCodec.new(first, second)

## 构造 Dispatch Codec（根据类型字段分发到不同子 Codec）
static func dispatch(type_key: String, type_codec: Codec, dispatch_fn: Callable) -> Codec:
	return DispatchCodec.new(type_key, type_codec, dispatch_fn)

## 从 MapCodec 构建 Record 风格 Codec
static func record(map_codec: MapCodec) -> Codec:
	return RecordCodec.new(map_codec)

## 构造 unit Codec（始终返回固定值）
static func unit(value: Variant) -> Codec:
	return UnitCodec.new(value)

# ═══════════════════════════════════════════════════════
# 内部实现：基本类型 Codec
# ═══════════════════════════════════════════════════════

class PrimitiveCodec extends Codec:
	enum PrimitiveType { BOOL, INT, FLOAT, STRING }

	var _type: PrimitiveType

	func _init(type: PrimitiveType) -> void:
		_type = type

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		match _type:
			PrimitiveType.BOOL:
				return DataResult.success(ops.create_bool(value))
			PrimitiveType.INT:
				return DataResult.success(ops.create_int(value))
			PrimitiveType.FLOAT:
				return DataResult.success(ops.create_float(value))
			PrimitiveType.STRING:
				return DataResult.success(ops.create_string(value))
		return DataResult.error("Unknown primitive type")

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		match _type:
			PrimitiveType.BOOL:
				return ops.get_bool(value)
			PrimitiveType.INT:
				return ops.get_int(value)
			PrimitiveType.FLOAT:
				return ops.get_float(value)
			PrimitiveType.STRING:
				return ops.get_string(value)
		return DataResult.error("Unknown primitive type")

# ═══════════════════════════════════════════════════════
# 内部实现：ResourceLocation Codec
# ═══════════════════════════════════════════════════════

class ResourceLocationCodec extends Codec:

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		if value is ResourceLocation:
			return DataResult.success(ops.create_string(value.to_string()))
		return DataResult.error("Expected ResourceLocation, got: %s" % type_string(typeof(value)))

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var str_result := ops.get_string(value)
		if str_result.is_error():
			return str_result
		var s: String = str_result.get_value()
		var validate_result := ResourceLocation.validate(s)
		if validate_result.is_error():
			return validate_result
		var loc := ResourceLocation.from_string(s)
		if loc == null:
			return DataResult.error("Failed to parse ResourceLocation: %s" % s)
		return DataResult.success(loc)

# ═══════════════════════════════════════════════════════
# 内部实现：List Codec
# ═══════════════════════════════════════════════════════

class ListCodec extends Codec:
	var _element_codec: Codec

	func _init(element_codec: Codec) -> void:
		_element_codec = element_codec

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		if not (value is Array):
			return DataResult.error("Expected Array for list codec, got: %s" % type_string(typeof(value)))
		var encoded_items: Array = []
		var diagnostics: Array = []
		for i in range(value.size()):
			var item_result := _element_codec.encode(value[i], ops)
			if item_result.is_error():
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.FATAL,
					"Failed to encode list element [%d]: %s" % [i, item_result.get_error()],
					"[%d]" % i
				))
			else:
				encoded_items.append(item_result.get_value())
				diagnostics.append_array(item_result.get_diagnostics())
		var result := DataResult.success(ops.create_list(encoded_items))
		result._diagnostics = diagnostics
		return result

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var list_result := ops.get_list(value)
		if list_result.is_error():
			return list_result
		var raw_list: Array = list_result.get_value()
		var decoded_items: Array = []
		var diagnostics: Array = []
		var has_errors := false
		for i in range(raw_list.size()):
			var item_result := _element_codec.decode(raw_list[i], ops)
			if item_result.is_error():
				has_errors = true
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.RECOVERABLE,
					"Failed to decode list element [%d]: %s" % [i, item_result.get_error()],
					"[%d]" % i
				))
			else:
				decoded_items.append(item_result.get_value())
				diagnostics.append_array(item_result.get_diagnostics())
		var result: DataResult
		if has_errors:
			result = DataResult.partial(decoded_items, "Some list elements failed to decode")
		else:
			result = DataResult.success(decoded_items)
		result._diagnostics = diagnostics
		return result

# ═══════════════════════════════════════════════════════
# 内部实现：Map-of Codec（键值对字典）
# ═══════════════════════════════════════════════════════

class MapOfCodec extends Codec:
	var _key_codec: Codec
	var _value_codec: Codec

	func _init(key_codec: Codec, value_codec: Codec) -> void:
		_key_codec = key_codec
		_value_codec = value_codec

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		if not (value is Dictionary):
			return DataResult.error("Expected Dictionary for map codec, got: %s" % type_string(typeof(value)))
		var encoded: Dictionary = {}
		var diagnostics: Array = []
		for k in value:
			var key_result := _key_codec.encode(k, ops)
			if key_result.is_error():
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.FATAL,
					"Failed to encode map key: %s" % key_result.get_error(), ""))
				continue
			var val_result := _value_codec.encode(value[k], ops)
			if val_result.is_error():
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.FATAL,
					"Failed to encode map value for key '%s': %s" % [str(k), val_result.get_error()], ""))
				continue
			encoded[key_result.get_value()] = val_result.get_value()
		var result := DataResult.success(ops.create_map(encoded))
		result._diagnostics = diagnostics
		return result

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var entries_result := ops.get_map_entries(value)
		if entries_result.is_error():
			return entries_result
		var raw_entries: Dictionary = entries_result.get_value()
		var decoded: Dictionary = {}
		var diagnostics: Array = []
		var has_errors := false
		for raw_k in raw_entries:
			var key_result := _key_codec.decode(raw_k, ops)
			if key_result.is_error():
				has_errors = true
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.RECOVERABLE,
					"Failed to decode map key: %s" % key_result.get_error(), ""))
				continue
			var val_result := _value_codec.decode(raw_entries[raw_k], ops)
			if val_result.is_error():
				has_errors = true
				diagnostics.append(DataResult.Diagnostic.new(
					DataResult.DiagnosticLevel.RECOVERABLE,
					"Failed to decode map value for key '%s': %s" % [str(raw_k), val_result.get_error()], ""))
				continue
			decoded[key_result.get_value()] = val_result.get_value()
			diagnostics.append_array(val_result.get_diagnostics())
		var result: DataResult
		if has_errors:
			result = DataResult.partial(decoded, "Some map entries failed to decode")
		else:
			result = DataResult.success(decoded)
		result._diagnostics = diagnostics
		return result

# ═══════════════════════════════════════════════════════
# 内部实现：Xmap Codec
# ═══════════════════════════════════════════════════════

class XmapCodec extends Codec:
	var _inner: Codec
	var _decode_fn: Callable
	var _encode_fn: Callable

	func _init(inner: Codec, decode_fn: Callable, encode_fn: Callable) -> void:
		_inner = inner
		_decode_fn = decode_fn
		_encode_fn = encode_fn

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		var transformed = _encode_fn.call(value)
		return _inner.encode(transformed, ops)

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var result := _inner.decode(value, ops)
		if result.is_error():
			return result
		return result.map(_decode_fn)

# ═══════════════════════════════════════════════════════
# 内部实现：FlatXmap Codec
# ═══════════════════════════════════════════════════════

class FlatXmapCodec extends Codec:
	var _inner: Codec
	var _decode_fn: Callable  ## 返回 DataResult
	var _encode_fn: Callable  ## 返回 DataResult

	func _init(inner: Codec, decode_fn: Callable, encode_fn: Callable) -> void:
		_inner = inner
		_decode_fn = decode_fn
		_encode_fn = encode_fn

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		var transform_result: DataResult = _encode_fn.call(value)
		if transform_result.is_error():
			return transform_result
		return _inner.encode(transform_result.get_value(), ops)

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var result := _inner.decode(value, ops)
		if result.is_error():
			return result
		return result.flat_map(_decode_fn)

# ═══════════════════════════════════════════════════════
# 内部实现：Either Codec
# ═══════════════════════════════════════════════════════

class EitherCodec extends Codec:
	var _first: Codec
	var _second: Codec

	func _init(first: Codec, second: Codec) -> void:
		_first = first
		_second = second

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		# 优先尝试 first
		var result := _first.encode(value, ops)
		if not result.is_error():
			return result
		return _second.encode(value, ops)

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var result := _first.decode(value, ops)
		if not result.is_error():
			return result
		return _second.decode(value, ops)

# ═══════════════════════════════════════════════════════
# 内部实现：Dispatch Codec
# ═══════════════════════════════════════════════════════

class DispatchCodec extends Codec:
	var _type_key: String
	var _type_codec: Codec
	var _dispatch_fn: Callable  ## (type_value) -> Codec

	func _init(type_key: String, type_codec: Codec, dispatch_fn: Callable) -> void:
		_type_key = type_key
		_type_codec = type_codec
		_dispatch_fn = dispatch_fn

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		# value 应该是 Dictionary，包含类型字段
		if not (value is Dictionary):
			return DataResult.error("Dispatch encode expects Dictionary, got: %s" % type_string(typeof(value)))
		if not value.has(_type_key):
			return DataResult.error("Dispatch encode: missing type key '%s'" % _type_key)
		var type_val = value[_type_key]
		var sub_codec: Codec = _dispatch_fn.call(type_val)
		if sub_codec == null:
			return DataResult.error("Dispatch: no codec found for type '%s'" % str(type_val))
		return sub_codec.encode(value, ops)

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		var type_field_result := ops.get_map_value(value, _type_key)
		if type_field_result.is_error():
			return DataResult.error("Dispatch decode: missing type key '%s'" % _type_key)
		var type_val_result := _type_codec.decode(type_field_result.get_value(), ops)
		if type_val_result.is_error():
			return type_val_result
		var type_val = type_val_result.get_value()
		var sub_codec: Codec = _dispatch_fn.call(type_val)
		if sub_codec == null:
			return DataResult.error("Dispatch: no codec found for type '%s'" % str(type_val))
		return sub_codec.decode(value, ops)

# ═══════════════════════════════════════════════════════
# 内部实现：Unit Codec
# ═══════════════════════════════════════════════════════

class UnitCodec extends Codec:
	var _value: Variant

	func _init(value: Variant) -> void:
		_value = value

	func encode(_value_unused: Variant, ops: DynamicOps) -> DataResult:
		return DataResult.success(ops.empty())

	func decode(_value_unused: Variant, _ops: DynamicOps) -> DataResult:
		return DataResult.success(_value)

# ═══════════════════════════════════════════════════════
# 内部实现：Record Codec（从 MapCodec 构建）
# ═══════════════════════════════════════════════════════

class RecordCodec extends Codec:
	var _map_codec: MapCodec

	func _init(map_codec: MapCodec) -> void:
		_map_codec = map_codec

	func encode(value: Variant, ops: DynamicOps) -> DataResult:
		return _map_codec.encode_to_map(value, ops)

	func decode(value: Variant, ops: DynamicOps) -> DataResult:
		return _map_codec.decode_from_map(value, ops)
