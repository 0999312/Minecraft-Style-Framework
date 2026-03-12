extends Node

var _listeners: Dictionary = {}
var _bound_signals: Dictionary = {}  # Signal hash -> Callable (bridge callable)

func subscribe(event_type: StringName, listener: Callable) -> void:
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	var arr: Array = _listeners[event_type]
	if arr.has(listener):
		return
	arr.append(listener)

func unsubscribe(event_type: StringName, listener: Callable) -> void:
	if _listeners.has(event_type):
		var arr = _listeners[event_type]
		var index = arr.find(listener)
		if index >= 0:
			arr.remove_at(index)

func publish(event: Event) -> void:
	var event_type = event.get_event_type()
	if _listeners.has(event_type):
		var listeners_copy = _listeners[event_type].duplicate()
		var stale: Array = []
		for listener in listeners_copy:
			# 清理已销毁对象的 Callable
			var obj = listener.get_object()
			if obj != null and not is_instance_valid(obj):
				stale.append(listener)
				continue
			# 如果事件已被取消，停止派发后续监听器
			if event.is_cancelled():
				break
			listener.call(event)
		# 移除失效的监听器
		for s in stale:
			var arr: Array = _listeners[event_type]
			var idx = arr.find(s)
			if idx >= 0:
				arr.remove_at(idx)

func bind_signal(signal_target: Signal, event_factory: Callable) -> Signal:
	var source_obj = signal_target.get_object()
	if source_obj == null or not is_instance_valid(source_obj):
		push_error("EventBus.bind_signal: signal source object is invalid")
		return signal_target
	var sig_id = str(source_obj.get_instance_id()) + "::" + signal_target.get_name()
	if _bound_signals.has(sig_id):
		push_warning("EventBus.bind_signal: signal already bound: ", sig_id)
		return signal_target
	var callable = func(...args):
		var event = event_factory.callv(args)
		if event is Event:
			publish(event)
		else:
			push_error("Event factory must return an Event instance")
	_bound_signals[sig_id] = callable
	signal_target.connect(callable)
	return signal_target

func unbind_signal(signal_target: Signal) -> void:
	var source_obj = signal_target.get_object()
	if source_obj == null or not is_instance_valid(source_obj):
		return
	var sig_id = str(source_obj.get_instance_id()) + "::" + signal_target.get_name()
	if _bound_signals.has(sig_id):
		var callable = _bound_signals[sig_id]
		if signal_target.is_connected(callable):
			signal_target.disconnect(callable)
		_bound_signals.erase(sig_id)

func clear_listeners(event_type: StringName) -> void:
	if _listeners.has(event_type):
		_listeners[event_type].clear()

func clear_all_listeners() -> void:
	_listeners.clear()
