extends Event
class_name SignalEvent

var _source_ref: WeakRef
var signal_name: String

func _init(p_source: Node, p_signal: String) -> void:
	_source_ref = weakref(p_source)
	signal_name = p_signal

func get_source_node() -> Node:
	return _source_ref.get_ref() as Node

func is_source_valid() -> bool:
	var ref = _source_ref.get_ref()
	return ref != null and is_instance_valid(ref)
