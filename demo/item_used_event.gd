extends Event
class_name ItemUsedEvent

var item_id: ResourceLocation
var user: Node

func _init(p_item_id: ResourceLocation, p_user: Node) -> void:
	item_id = p_item_id
	user = p_user
