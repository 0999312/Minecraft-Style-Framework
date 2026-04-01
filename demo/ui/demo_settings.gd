extends UIPanel
class_name DemoSettings
## 演示设置面板

var _title_label: Label
var _btn_back: Button
var _volume_label: Label
var _volume_slider: HSlider

func _on_init() -> void:
	_build_ui()

func _on_open(_data: Dictionary = {}) -> void:
	_refresh_i18n()

func _on_resume() -> void:
	_refresh_i18n()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size.x = 400
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	# 音量设置
	_volume_label = Label.new()
	vbox.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.value = 80
	_volume_slider.custom_minimum_size = Vector2(300, 30)
	vbox.add_child(_volume_slider)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	vbox.add_child(spacer2)

	_btn_back = Button.new()
	_btn_back.custom_minimum_size = Vector2(200, 48)
	_btn_back.pressed.connect(_on_back_pressed)
	vbox.add_child(_btn_back)

func _refresh_i18n() -> void:
	_title_label.text = I18NManager.get_text("ui.settings.title")
	_volume_label.text = I18NManager.get_text("ui.settings.volume")
	_btn_back.text = I18NManager.get_text("ui.common.back")

func _on_back_pressed() -> void:
	UIManager.back(ui_layer)
