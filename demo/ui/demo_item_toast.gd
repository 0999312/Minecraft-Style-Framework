extends UIToast
class_name DemoItemToast
## 演示 Toast 通知

var _label: Label

func _ready() -> void:
	super._ready()
	_build_ui()

func _on_show(data: Dictionary = {}) -> void:
	if data.has("message"):
		_label.text = data["message"]
	else:
		_label.text = "Toast!"
	# 简单的出现动画：从右侧滑入
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_dismiss() -> void:
	# 淡出动画
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

func _build_ui() -> void:
	# 定位在右上角
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -320
	offset_top = 20
	offset_right = -20
	offset_bottom = 70
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(_label)
