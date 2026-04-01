extends UIPanel
class_name DemoConfirmDialog
## 演示确认弹窗（POPUP 层级，支持弹窗队列）

var _message_label: Label
var _btn_confirm: Button
var _btn_cancel: Button

func _on_init() -> void:
	_build_ui()

func _on_open(data: Dictionary = {}) -> void:
	_refresh_i18n()
	if data.has("message"):
		_message_label.text = data["message"]

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.text = ""
	vbox.add_child(title)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_message_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	_btn_confirm = Button.new()
	_btn_confirm.custom_minimum_size = Vector2(120, 40)
	_btn_confirm.pressed.connect(_on_confirm_pressed)
	hbox.add_child(_btn_confirm)

	_btn_cancel = Button.new()
	_btn_cancel.custom_minimum_size = Vector2(120, 40)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(_btn_cancel)

func _refresh_i18n() -> void:
	_btn_confirm.text = I18NManager.get_text("ui.common.confirm")
	_btn_cancel.text = I18NManager.get_text("ui.common.cancel")

func _on_confirm_pressed() -> void:
	print("[DemoConfirmDialog] 确认")
	UIManager.back(UILayer.POPUP)

func _on_cancel_pressed() -> void:
	print("[DemoConfirmDialog] 取消")
	UIManager.back(UILayer.POPUP)
