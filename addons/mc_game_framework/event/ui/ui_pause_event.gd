extends Event
class_name UIPauseEvent
## 面板暂停事件（被新面板覆盖）

var panel_id: ResourceLocation
var layer: int

func _init(p_panel_id: ResourceLocation, p_layer: int) -> void:
	panel_id = p_panel_id
	layer = p_layer
