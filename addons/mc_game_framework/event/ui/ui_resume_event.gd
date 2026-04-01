extends Event
class_name UIResumeEvent
## 面板恢复事件（上方面板关闭后恢复）

var panel_id: ResourceLocation
var layer: int

func _init(p_panel_id: ResourceLocation, p_layer: int) -> void:
	panel_id = p_panel_id
	layer = p_layer
