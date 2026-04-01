extends UIPanel
class_name DemoInventory
## 演示背包面板（使用 CACHE 模式）

var _title_label: Label
var _btn_back: Button
var _item_list: VBoxContainer

func _on_init() -> void:
	_build_ui()

func _on_open(_data: Dictionary = {}) -> void:
	_refresh_i18n()
	_refresh_items()

func _on_resume() -> void:
	_refresh_i18n()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(450, 400)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_item_list)

	_btn_back = Button.new()
	_btn_back.custom_minimum_size = Vector2(200, 48)
	_btn_back.pressed.connect(_on_back_pressed)
	vbox.add_child(_btn_back)

func _refresh_i18n() -> void:
	_title_label.text = I18NManager.get_text("ui.inventory.title")
	_btn_back.text = I18NManager.get_text("ui.common.back")

func _refresh_items() -> void:
	# 清空旧列表
	for child in _item_list.get_children():
		child.queue_free()

	# 模拟背包物品
	var items := ["item.iron_sword", "item.bow", "item.arrow"]
	for key in items:
		var label := Label.new()
		label.text = "• " + I18NManager.get_text(key)
		_item_list.add_child(label)

func _on_back_pressed() -> void:
	UIManager.back(ui_layer)
