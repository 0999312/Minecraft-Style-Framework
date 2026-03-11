extends Node

var _listeners: Dictionary = {}

func subscribe(event_type: StringName, listener: Callable) -> void:
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	_listeners[event_type].append(listener)

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
		for listener in listeners_copy:
			# 如果事件已被取消，停止派发后续监听器
			if event.is_cancelled():
				break
			listener.call(event)

func bind_signal(signal_target: Signal, event_factory: Callable) -> Signal:
	var callable = func(...args):
		var event = event_factory.callv(args)
		if event is Event:
			publish(event)
		else:
			push_error("Event factory must return an Event instance")
	signal_target.connect(callable)
	return signal_target
