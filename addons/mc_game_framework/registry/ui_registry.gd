extends RegistryBase
class_name UIRegistry
## UI 面板注册表
## 注册面板场景及其默认参数，供 UIManager 实例化使用

## 注册一个面板
func register_panel(id: ResourceLocation, scene: PackedScene,
					default_layer: int = UILayer.NORMAL,
					cache_mode: int = UIPanel.CacheMode.NONE) -> void:
	register(id, {
		"scene": scene,
		"default_layer": default_layer,
		"cache_mode": cache_mode
	})

## 注册一个 Toast
func register_toast(id: ResourceLocation, scene: PackedScene) -> void:
	register(id, {
		"scene": scene,
		"default_layer": UILayer.TOAST,
		"is_toast": true
	})

## 实例化面板，返回 UIPanel 或 null
func instantiate_panel(id: ResourceLocation) -> UIPanel:
	var info = get_entry(id)
	if info == null:
		push_error("UIRegistry: panel not found: %s" % id.to_string())
		return null
	var scene: PackedScene = info.get("scene")
	if scene == null:
		push_error("UIRegistry: no scene for panel: %s" % id.to_string())
		return null
	var instance = scene.instantiate()
	if not instance is UIPanel:
		push_error("UIRegistry: scene root must extend UIPanel: %s" % id.to_string())
		instance.queue_free()
		return null
	var panel := instance as UIPanel
	panel.panel_id = id
	panel.ui_layer = info.get("default_layer", UILayer.NORMAL)
	panel.cache_mode = info.get("cache_mode", UIPanel.CacheMode.NONE)
	return panel

## 实例化 Toast，返回 UIToast 或 null
func instantiate_toast(id: ResourceLocation) -> UIToast:
	var info = get_entry(id)
	if info == null:
		push_error("UIRegistry: toast not found: %s" % id.to_string())
		return null
	var scene: PackedScene = info.get("scene")
	if scene == null:
		push_error("UIRegistry: no scene for toast: %s" % id.to_string())
		return null
	var instance = scene.instantiate()
	if not instance is UIToast:
		push_error("UIRegistry: scene root must extend UIToast: %s" % id.to_string())
		instance.queue_free()
		return null
	var toast := instance as UIToast
	toast.toast_id = id
	return toast

## 校验条目必须为 Dictionary 类型
func _validate_entry(entry: Variant) -> bool:
	return entry is Dictionary

func _get_expected_type_name() -> String:
	return "Dictionary{scene, default_layer, ...}"
