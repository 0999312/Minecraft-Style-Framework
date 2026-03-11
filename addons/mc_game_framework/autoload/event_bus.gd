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
			listener.call(event)

func bind_signal(signal_target: Signal, event_factory: Callable) -> Signal:
	# 使用可变参数收集信号的所有参数
	var callable = func(...args):
		var event = event_factory.callv(args)
		if event is Event:
			publish(event)
		else:
			push_error("Event factory must return an Event instance")
	signal_target.connect(callable)
	return signal_target  # 返回原始信号，但注意断开需使用相同的 callable
