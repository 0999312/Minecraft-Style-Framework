extends UIPanel
class_name DemoMainMenu
## 演示主菜单面板

var _title_label: Label
var _btn_settings: Button
var _btn_inventory: Button
var _btn_toast: Button
var _btn_popup: Button
var _btn_lang: Button
var _lang_label: Label

func _on_init() -> void:
	_build_ui()

func _on_open(_data: Dictionary = {}) -> void:
	_refresh_i18n()

func _on_resume() -> void:
	_refresh_i18n()

func _build_ui() -> void:
	# 全屏面板
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	_btn_settings = Button.new()
	_btn_settings.custom_minimum_size = Vector2(260, 48)
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)

	_btn_inventory = Button.new()
	_btn_inventory.custom_minimum_size = Vector2(260, 48)
	_btn_inventory.pressed.connect(_on_inventory_pressed)
	vbox.add_child(_btn_inventory)

	_btn_toast = Button.new()
	_btn_toast.custom_minimum_size = Vector2(260, 48)
	_btn_toast.pressed.connect(_on_toast_pressed)
	vbox.add_child(_btn_toast)

	_btn_popup = Button.new()
	_btn_popup.custom_minimum_size = Vector2(260, 48)
	_btn_popup.pressed.connect(_on_popup_pressed)
	vbox.add_child(_btn_popup)

	# 语言切换区域
	var lang_hbox := HBoxContainer.new()
	lang_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(lang_hbox)

	_lang_label = Label.new()
	lang_hbox.add_child(_lang_label)

	_btn_lang = Button.new()
	_btn_lang.pressed.connect(_on_lang_toggle)
	lang_hbox.add_child(_btn_lang)

func _refresh_i18n() -> void:
	_title_label.text = I18NManager.get_text("ui.main_menu.title")
	_btn_settings.text = I18NManager.get_text("ui.main_menu.settings")
	_btn_inventory.text = I18NManager.get_text("ui.main_menu.inventory")
	_btn_toast.text = I18NManager.get_text("ui.main_menu.show_toast")
	_btn_popup.text = I18NManager.get_text("ui.main_menu.show_popup")
	var lang := I18NManager.get_current_language()
	_lang_label.text = I18NManager.get_text("ui.main_menu.current_lang", [lang])
	_btn_lang.text = I18NManager.get_text("ui.main_menu.switch_lang")

func _on_settings_pressed() -> void:
	UIManager.open_panel(ResourceLocation.from_string("demo:settings"))

func _on_inventory_pressed() -> void:
	UIManager.open_panel(ResourceLocation.from_string("demo:inventory"))

func _on_toast_pressed() -> void:
	UIManager.show_toast(
		ResourceLocation.from_string("demo:item_toast"),
		{"message": I18NManager.get_text("ui.toast.item_obtained")},
		3.0
	)

func _on_popup_pressed() -> void:
	UIManager.queue_popup(
		ResourceLocation.from_string("demo:confirm_dialog"),
		{"message": I18NManager.get_text("ui.popup.confirm_message")}
	)

func _on_lang_toggle() -> void:
	var lang := I18NManager.get_current_language()
	if lang == "en":
		I18NManager.set_language("zh_CN")
	else:
		I18NManager.set_language("en")
	_refresh_i18n()
