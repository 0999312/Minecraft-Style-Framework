## DataResult — DFU 风格结果对象
##
## 受 Mojang DFU DataResult 思路启发：
## - 支持 success / error / partial_success 三种状态
## - 携带 Diagnostic 路径与错误/警告信息
## - 支持 map / flat_map / apply 等函数式组合
## - 支持部分成功（保留已解码字段，附带诊断信息）
extends RefCounted
class_name DataResult

## 结果状态枚举
enum Status {
	SUCCESS,       ## 完全成功
	ERROR,         ## 无法继续解码
	PARTIAL,       ## 部分成功（使用默认值继续）
}

## 诊断级别
enum DiagnosticLevel {
	FATAL,         ## 无法继续
	RECOVERABLE,   ## 使用默认值继续
	WARNING,       ## 结构合法但存在潜在问题
}

var _status: Status = Status.SUCCESS
var _value: Variant = null
var _partial_value: Variant = null
var _error_message: String = ""
var _diagnostics: Array = []  # Array[Diagnostic]

# ── 构造 ──────────────────────────────────────────────

## 创建成功结果
static func success(value: Variant) -> DataResult:
	var r := DataResult.new()
	r._status = Status.SUCCESS
	r._value = value
	return r

## 创建错误结果
static func error(message: String) -> DataResult:
	var r := DataResult.new()
	r._status = Status.ERROR
	r._error_message = message
	r._diagnostics.append(Diagnostic.new(DiagnosticLevel.FATAL, message, ""))
	return r

## 创建部分成功结果（保留部分值 + 诊断信息）
static func partial(partial_value: Variant, message: String) -> DataResult:
	var r := DataResult.new()
	r._status = Status.PARTIAL
	r._partial_value = partial_value
	r._value = partial_value
	r._error_message = message
	r._diagnostics.append(Diagnostic.new(DiagnosticLevel.RECOVERABLE, message, ""))
	return r

# ── 查询 ──────────────────────────────────────────────

func is_success() -> bool:
	return _status == Status.SUCCESS

func is_error() -> bool:
	return _status == Status.ERROR

func is_partial() -> bool:
	return _status == Status.PARTIAL

func get_status() -> Status:
	return _status

## 获取结果值（成功或部分成功时有效）
func get_value() -> Variant:
	return _value

## 获取结果值，若无值则使用默认值
func get_or_default(default: Variant) -> Variant:
	if _value != null:
		return _value
	return default

## 获取错误信息
func get_error() -> String:
	return _error_message

## 获取所有诊断信息
func get_diagnostics() -> Array:
	return _diagnostics

## 获取部分值（仅 PARTIAL 状态有效）
func get_partial_value() -> Variant:
	return _partial_value

# ── 函数式组合 ─────────────────────────────────────────

## map：对成功值施加变换
func map(transform: Callable) -> DataResult:
	if _status == Status.ERROR:
		return self
	var new_result := DataResult.new()
	new_result._status = _status
	new_result._error_message = _error_message
	new_result._diagnostics = _diagnostics.duplicate()
	new_result._value = transform.call(_value)
	new_result._partial_value = _partial_value
	return new_result

## flat_map：对成功值施加返回 DataResult 的变换
func flat_map(transform: Callable) -> DataResult:
	if _status == Status.ERROR:
		return self
	var inner: DataResult = transform.call(_value)
	if inner == null:
		return DataResult.error("flat_map returned null")
	# 合并诊断
	var merged := DataResult.new()
	merged._status = inner._status
	merged._value = inner._value
	merged._partial_value = inner._partial_value
	merged._error_message = inner._error_message
	merged._diagnostics = _diagnostics.duplicate()
	merged._diagnostics.append_array(inner._diagnostics)
	# 如果原结果是 PARTIAL，降级
	if _status == Status.PARTIAL and merged._status == Status.SUCCESS:
		merged._status = Status.PARTIAL
	return merged

## apply：将另一个 DataResult<Callable> 应用到当前值
func apply(func_result: DataResult) -> DataResult:
	if func_result.is_error():
		return func_result
	if is_error():
		return self
	var fn: Callable = func_result.get_value()
	return map(fn)

## 添加诊断信息
func add_diagnostic(level: DiagnosticLevel, message: String, path: String = "") -> DataResult:
	_diagnostics.append(Diagnostic.new(level, message, path))
	if level == DiagnosticLevel.FATAL and _status != Status.ERROR:
		_status = Status.ERROR
	elif level == DiagnosticLevel.RECOVERABLE and _status == Status.SUCCESS:
		_status = Status.PARTIAL
	return self

## 设置路径前缀（用于嵌套字段的错误定位）
func set_path_prefix(prefix: String) -> DataResult:
	for d: Diagnostic in _diagnostics:
		if d.path.is_empty():
			d.path = prefix
		else:
			d.path = prefix + "." + d.path
	return self

func _to_string() -> String:
	match _status:
		Status.SUCCESS:
			return "DataResult.success(%s)" % str(_value)
		Status.ERROR:
			return "DataResult.error(%s)" % _error_message
		Status.PARTIAL:
			return "DataResult.partial(%s, %s)" % [str(_value), _error_message]
	return "DataResult.unknown"

# ═══════════════════════════════════════════════════════
# Diagnostic 内部类
# ═══════════════════════════════════════════════════════

## 诊断信息条目
class Diagnostic extends RefCounted:
	var level: DataResult.DiagnosticLevel
	var message: String
	var path: String  ## 字段路径，例如 "inventory.items[3].count"

	func _init(p_level: DataResult.DiagnosticLevel = DataResult.DiagnosticLevel.WARNING, p_message: String = "", p_path: String = "") -> void:
		level = p_level
		message = p_message
		path = p_path

	func _to_string() -> String:
		var level_str := "WARNING"
		match level:
			DataResult.DiagnosticLevel.FATAL:
				level_str = "FATAL"
			DataResult.DiagnosticLevel.RECOVERABLE:
				level_str = "RECOVERABLE"
		if path.is_empty():
			return "[%s] %s" % [level_str, message]
		return "[%s] %s: %s" % [level_str, path, message]
