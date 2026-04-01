extends Event
class_name UIOpenEvent
## 面板打开事件

var panel_id: ResourceLocation
var layer: int

func _init(p_panel_id: ResourceLocation, p_layer: int) -> void:
	panel_id = p_panel_id
	layer = p_layer
