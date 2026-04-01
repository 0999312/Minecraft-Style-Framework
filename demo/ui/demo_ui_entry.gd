extends Node
## UI 框架演示入口
## 注册所有 UI 面板/Toast 到 UIRegistry，加载多语言翻译，打开主菜单
## 演示：栈式导航、覆盖层、Toast、弹窗队列、背景遮罩、本地化切换

func _ready() -> void:
	# ─── 注册 UIRegistry ───
	if not RegistryManager.has_registry("ui"):
		RegistryManager.register_registry("ui", UIRegistry.new())
	var ui_reg: UIRegistry = RegistryManager.get_registry("ui")

	# 注册面板
	ui_reg.register_panel(
		ResourceLocation.from_string("demo:main_menu"),
		preload("res://demo/ui/demo_main_menu.tscn"),
		UILayer.NORMAL,
		UIPanel.CacheMode.CACHE
	)
	ui_reg.register_panel(
		ResourceLocation.from_string("demo:settings"),
		preload("res://demo/ui/demo_settings.tscn"),
		UILayer.NORMAL
	)
	ui_reg.register_panel(
		ResourceLocation.from_string("demo:inventory"),
		preload("res://demo/ui/demo_inventory.tscn"),
		UILayer.NORMAL,
		UIPanel.CacheMode.CACHE
	)
	ui_reg.register_panel(
		ResourceLocation.from_string("demo:confirm_dialog"),
		preload("res://demo/ui/demo_confirm_dialog.tscn"),
		UILayer.POPUP
	)

	# 注册 Toast
	ui_reg.register_toast(
		ResourceLocation.from_string("demo:item_toast"),
		preload("res://demo/ui/demo_item_toast.tscn")
	)

	# ─── 加载翻译 ───
	I18NManager.load_translation("en", "res://demo/lang/en.json")
	I18NManager.load_translation("zh_CN", "res://demo/lang/zh_CN.json")
	I18NManager.set_language("en")

	# ─── 添加 HUD 覆盖层（持久显示） ───
	var hud := _create_hud_overlay()
	UIManager.add_overlay(ResourceLocation.from_string("demo:hud"), hud, UILayer.SCENE)

	# ─── 订阅 UI 事件（用于日志输出） ───
	EventBus.subscribe("UIOpenEvent", _on_ui_open)
	EventBus.subscribe("UICloseEvent", _on_ui_close)
	EventBus.subscribe("UIPauseEvent", _on_ui_pause)
	EventBus.subscribe("UIResumeEvent", _on_ui_resume)
	EventBus.subscribe("LanguageChangedEvent", _on_language_changed)

	# ─── 打开主菜单 ───
	UIManager.open_panel(ResourceLocation.from_string("demo:main_menu"))

	print("[UIDemoEntry] UI Demo started")

## 创建 HUD 覆盖层（显示当前时间和语言）
func _create_hud_overlay() -> Control:
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.name = "HUDLabel"
	label.text = "HUD Overlay"
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 10
	label.offset_top = -30
	label.offset_bottom = -10
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)

	return hud

# ─── 事件回调（输出日志） ───

func _on_ui_open(event: UIOpenEvent) -> void:
	print("[UIEvent] 打开: %s (layer=%d)" % [event.panel_id.to_string(), event.layer])

func _on_ui_close(event: UICloseEvent) -> void:
	print("[UIEvent] 关闭: %s (layer=%d)" % [event.panel_id.to_string(), event.layer])

func _on_ui_pause(event: UIPauseEvent) -> void:
	print("[UIEvent] 暂停: %s (layer=%d)" % [event.panel_id.to_string(), event.layer])

func _on_ui_resume(event: UIResumeEvent) -> void:
	print("[UIEvent] 恢复: %s (layer=%d)" % [event.panel_id.to_string(), event.layer])

func _on_language_changed(event: LanguageChangedEvent) -> void:
	print("[UIEvent] 语言切换: %s" % event.lang_code)
	# 更新 HUD 覆盖层文本
	var hud := UIManager.get_overlay(ResourceLocation.from_string("demo:hud"))
	if hud:
		var label := hud.get_node_or_null("HUDLabel") as Label
		if label:
			label.text = I18NManager.get_text("ui.hud.overlay_text")
