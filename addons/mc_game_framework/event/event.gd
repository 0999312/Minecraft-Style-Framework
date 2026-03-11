extends RefCounted
class_name Event

var _cancelled := false

# 取消事件，阻止后续监听器处理
func cancel() -> void:
	_cancelled = true

# 检查事件是否已被取消
func is_cancelled() -> bool:
	return _cancelled

# 返回事件类型（默认使用类名）
func get_event_type() -> StringName:
	return StringName(get_script().get_global_name())
