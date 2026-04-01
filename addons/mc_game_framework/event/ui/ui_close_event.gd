extends Event
class_name UICloseEvent
## 面板关闭事件

var panel_id: ResourceLocation
var layer: int

func _init(p_panel_id: ResourceLocation, p_layer: int) -> void:
	panel_id = p_panel_id
	layer = p_layer
