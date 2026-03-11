extends Event
class_name SignalEvent

var source_node: Node
var signal_name: String

func _init(p_source: Node, p_signal: String) -> void:
	source_node = p_source
	signal_name = p_signal
