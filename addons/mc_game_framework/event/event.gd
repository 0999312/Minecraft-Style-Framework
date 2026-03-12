extends RefCounted
class_name Event

var _cancelled := false

# 取消事件，阻止后续监听器处理
func cancel() -> void:
	_cancelled = true

# 检查事件是否已被取消
func is_cancelled() -> bool:
	return _cancelled

# 返回事件类型（默认使用类名，无类名时回退到脚本路径）
func get_event_type() -> StringName:
	var s = get_script()
	if s == null:
		push_warning("Event.get_event_type(): no script attached, returning 'UnknownEvent'")
		return &"UnknownEvent"
	var global_name = s.get_global_name()
	if not global_name.is_empty():
		return StringName(global_name)
	var path = s.resource_path
	if not path.is_empty():
		return StringName(path)
	return &"UnknownEvent"
