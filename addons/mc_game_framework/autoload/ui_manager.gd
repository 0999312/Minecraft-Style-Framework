extends Node
## 栈式 UI 管理器（Autoload 单例）
## 管理四类 UI 元素：面板栈、覆盖层、Toast、弹窗队列
## 内置循环导航保护、背景遮罩、性能优化（O(1)面板索引、LRU缓存淘汰）

# ─── 常量 ───
const MAX_OPEN_DEPTH := 8       # 单帧最大连续 open_panel 深度（防循环导航）
const MAX_CACHED_PANELS := 10   # 缓存面板上限（LRU 淘汰）

# ─── 内部状态 ───

## 每个层级对应一个面板栈 Array[UIPanel]
var _panel_stacks: Dictionary = {}  # int(layer) → Array[UIPanel]

## 活跃面板索引：panel_id 字符串 → 所在层级（O(1) 查找）
var _active_panel_ids: Dictionary = {}  # String → int

## 缓存面板池：panel_id 字符串 → UIPanel 实例
var _cached_panels: Dictionary = {}  # String → UIPanel

## LRU 缓存顺序追踪
var _cache_order: Array[String] = []

## 覆盖层管理：overlay_id 字符串 → {overlay: Control, layer: int}
var _overlays: Dictionary = {}  # String → Dictionary

## 活跃 Toast 列表
var _active_toasts: Array[UIToast] = []

## 弹窗队列：Array of Dictionary{panel_id, data, priority}
var _popup_queue: Array[Dictionary] = []

## 当前正在显示的排队弹窗（如果有）
var _current_queued_popup: UIPanel = null

## 循环导航保护：递归深度计数器
var _open_depth: int = 0

## 每个层级对应的 CanvasLayer 节点
var _layer_nodes: Dictionary = {}  # int → CanvasLayer

## 背景遮罩节点（按层级）
var _dimmers: Dictionary = {}  # int → ColorRect

# ─── 初始化 ───

func _ready() -> void:
	# 初始化默认层级的栈和 CanvasLayer
	for layer in UILayer.get_all_layers():
		_ensure_layer(layer)

func _process(_delta: float) -> void:
	# 每帧重置递归深度（二级保障，防止异常状态持续）
	_open_depth = 0

# ─── 面板栈操作 ───

## 打开面板
## id: 面板在 UIRegistry 中的 ResourceLocation
## data: 传递给 _on_open() 的参数字典
## layer_override: 覆盖默认层级（-1 表示使用注册时的默认值）
## 返回打开的 UIPanel 实例，失败返回 null
func open_panel(id: ResourceLocation, data: Dictionary = {},
				layer_override: int = -1) -> UIPanel:
	# 循环导航保护
	_open_depth += 1
	if _open_depth > MAX_OPEN_DEPTH:
		push_error("UIManager: open_panel 递归深度超过 %d，疑似循环导航，已中断" % MAX_OPEN_DEPTH)
		_open_depth -= 1
		return null

	var id_str := id.to_string()

	# 同面板防重复
	if _active_panel_ids.has(id_str):
		push_warning("UIManager: 面板已打开: %s" % id_str)
		_open_depth -= 1
		return null

	# 尝试从缓存获取
	var panel: UIPanel = null
	if _cached_panels.has(id_str):
		panel = _cached_panels[id_str]
		_cached_panels.erase(id_str)
		_cache_order.erase(id_str)
	else:
		# 从 UIRegistry 实例化
		var ui_reg := _get_ui_registry()
		if ui_reg == null:
			push_error("UIManager: UIRegistry 未注册，请先调用 RegistryManager.register_registry(\"ui\", UIRegistry.new())")
			_open_depth -= 1
			return null
		panel = ui_reg.instantiate_panel(id)
		if panel == null:
			_open_depth -= 1
			return null
		panel._on_init()

	# 确定目标层级
	var target_layer: int = layer_override if layer_override >= 0 else panel.ui_layer
	_ensure_layer(target_layer)

	# 暂停当前栈顶面板
	var stack: Array = _panel_stacks[target_layer]
	if not stack.is_empty():
		var top_panel: UIPanel = stack.back()
		top_panel._on_pause()
		top_panel.visible = false
		EventBus.publish(UIPauseEvent.new(top_panel.panel_id, target_layer))

	# 将面板推入栈
	stack.append(panel)
	_active_panel_ids[id_str] = target_layer

	# 添加到场景树
	var layer_node: CanvasLayer = _layer_nodes[target_layer]
	layer_node.add_child(panel)
	panel.visible = true

	# 背景遮罩
	if target_layer >= UILayer.NORMAL:
		_show_background_dimmer(target_layer)

	# 调用生命周期
	panel._on_open(data)
	EventBus.publish(UIOpenEvent.new(id, target_layer))

	_open_depth -= 1
	return panel

## 弹出指定层级栈顶面板（返回键行为）
func back(layer: int = UILayer.NORMAL) -> void:
	_ensure_layer(layer)
	var stack: Array = _panel_stacks[layer]
	if stack.is_empty():
		return
	var panel: UIPanel = stack.pop_back()
	_do_close_panel(panel, layer)

	# 恢复新栈顶
	if not stack.is_empty():
		var new_top: UIPanel = stack.back()
		new_top.visible = true
		new_top._on_resume()
		EventBus.publish(UIResumeEvent.new(new_top.panel_id, layer))
	else:
		_hide_background_dimmer(layer)

	# 弹窗队列：POPUP 层栈空时自动弹下一个
	if layer == UILayer.POPUP:
		_try_show_next_popup()

## 关闭指定面板（可不在栈顶）
func close_panel(id: ResourceLocation) -> void:
	var id_str := id.to_string()
	if not _active_panel_ids.has(id_str):
		push_warning("UIManager: 面板未打开: %s" % id_str)
		return

	var layer: int = _active_panel_ids[id_str]
	var stack: Array = _panel_stacks[layer]

	# 从栈中移除
	var index := -1
	for i in range(stack.size()):
		if stack[i].panel_id.to_string() == id_str:
			index = i
			break
	if index < 0:
		return

	var panel: UIPanel = stack[index]
	var was_top := (index == stack.size() - 1)
	stack.remove_at(index)
	_do_close_panel(panel, layer)

	# 如果移除的是栈顶，恢复下方面板
	if was_top and not stack.is_empty():
		var new_top: UIPanel = stack.back()
		new_top.visible = true
		new_top._on_resume()
		EventBus.publish(UIResumeEvent.new(new_top.panel_id, layer))
	elif stack.is_empty():
		_hide_background_dimmer(layer)

	# 弹窗队列处理
	if layer == UILayer.POPUP:
		_try_show_next_popup()

## 关闭指定层级或全部层级的所有面板
func close_all(layer: int = -1) -> void:
	if layer >= 0:
		_close_all_in_layer(layer)
	else:
		for l in _panel_stacks.keys():
			_close_all_in_layer(l)

## 获取指定层级的栈顶面板
func get_top_panel(layer: int = UILayer.NORMAL) -> UIPanel:
	_ensure_layer(layer)
	var stack: Array = _panel_stacks[layer]
	if stack.is_empty():
		return null
	return stack.back()

## O(1) 检查面板是否已打开
func is_panel_open(id: ResourceLocation) -> bool:
	return _active_panel_ids.has(id.to_string())

# ─── 覆盖层管理 ───

## 添加持久覆盖层（HUD、小地图等）
func add_overlay(id: ResourceLocation, overlay: Control,
				layer: int = UILayer.SCENE) -> void:
	var id_str := id.to_string()
	if _overlays.has(id_str):
		push_warning("UIManager: 覆盖层已存在: %s" % id_str)
		return
	_ensure_layer(layer)
	var layer_node: CanvasLayer = _layer_nodes[layer]
	layer_node.add_child(overlay)
	_overlays[id_str] = {"overlay": overlay, "layer": layer}

## 移除覆盖层
func remove_overlay(id: ResourceLocation) -> void:
	var id_str := id.to_string()
	if not _overlays.has(id_str):
		return
	var info: Dictionary = _overlays[id_str]
	var overlay: Control = info["overlay"]
	if is_instance_valid(overlay):
		overlay.queue_free()
	_overlays.erase(id_str)

## 获取覆盖层实例
func get_overlay(id: ResourceLocation) -> Control:
	var id_str := id.to_string()
	if _overlays.has(id_str):
		return _overlays[id_str]["overlay"]
	return null

## 显示/隐藏覆盖层
func set_overlay_visible(id: ResourceLocation, visible: bool) -> void:
	var overlay := get_overlay(id)
	if overlay:
		overlay.visible = visible

# ─── Toast 系统 ───

## 显示 Toast 通知（自动消失，可同时显示多个）
func show_toast(toast_id: ResourceLocation, data: Dictionary = {},
				duration: float = 3.0) -> UIToast:
	var ui_reg := _get_ui_registry()
	if ui_reg == null:
		push_error("UIManager: UIRegistry 未注册")
		return null
	var toast := ui_reg.instantiate_toast(toast_id)
	if toast == null:
		return null

	_ensure_layer(UILayer.TOAST)
	var layer_node: CanvasLayer = _layer_nodes[UILayer.TOAST]
	layer_node.add_child(toast)
	toast._on_show(data)
	toast.start_dismiss_timer(duration)
	toast.dismissed.connect(_on_toast_dismissed.bind(toast), CONNECT_ONE_SHOT)
	_active_toasts.append(toast)
	return toast

## 手动关闭指定 Toast
func dismiss_toast(toast: UIToast) -> void:
	if is_instance_valid(toast):
		toast.set_process(false)
		toast._on_dismiss()
		_remove_toast(toast)

## 关闭所有 Toast
func dismiss_all_toasts() -> void:
	var toasts_copy := _active_toasts.duplicate()
	for toast in toasts_copy:
		if is_instance_valid(toast):
			toast.set_process(false)
			toast._on_dismiss()
			_remove_toast(toast)

# ─── 弹窗队列 ───

## 将弹窗加入队列（FIFO + 优先级排序，逐个弹出）
func queue_popup(panel_id: ResourceLocation, data: Dictionary = {},
				priority: int = 0) -> void:
	_popup_queue.append({
		"panel_id": panel_id,
		"data": data,
		"priority": priority
	})
	# 按优先级降序排列（高优先级先弹）
	_popup_queue.sort_custom(func(a, b): return a["priority"] > b["priority"])

	# 如果当前 POPUP 栈为空且没有排队弹窗正在显示，立即弹出
	_try_show_next_popup()

# ─── 内部方法 ───

## 获取 UIRegistry
func _get_ui_registry() -> UIRegistry:
	if not RegistryManager.has_registry("ui"):
		return null
	return RegistryManager.get_registry("ui") as UIRegistry

## 确保指定层级的数据结构和 CanvasLayer 已创建
func _ensure_layer(layer: int) -> void:
	if not _panel_stacks.has(layer):
		_panel_stacks[layer] = []
	if not _layer_nodes.has(layer):
		var canvas_layer := CanvasLayer.new()
		canvas_layer.layer = layer
		canvas_layer.name = "UILayer_%d" % layer
		add_child(canvas_layer)
		_layer_nodes[layer] = canvas_layer

## 关闭面板的内部实现（调用生命周期，处理缓存/销毁）
func _do_close_panel(panel: UIPanel, layer: int) -> void:
	var id_str := panel.panel_id.to_string()
	_active_panel_ids.erase(id_str)

	panel._on_close()
	EventBus.publish(UICloseEvent.new(panel.panel_id, layer))

	# 从场景树移除
	if panel.get_parent():
		panel.get_parent().remove_child(panel)

	match panel.cache_mode:
		UIPanel.CacheMode.CACHE:
			# LRU 缓存淘汰
			if _cached_panels.size() >= MAX_CACHED_PANELS:
				var oldest := _cache_order.pop_front()
				if _cached_panels.has(oldest):
					var old_panel: UIPanel = _cached_panels[oldest]
					old_panel._on_destroy()
					old_panel.queue_free()
					_cached_panels.erase(oldest)
			_cache_order.append(id_str)
			_cached_panels[id_str] = panel
		UIPanel.CacheMode.NONE:
			panel._on_destroy()
			panel.queue_free()

## 关闭指定层级的所有面板
func _close_all_in_layer(layer: int) -> void:
	_ensure_layer(layer)
	var stack: Array = _panel_stacks[layer]
	while not stack.is_empty():
		var panel: UIPanel = stack.pop_back()
		_do_close_panel(panel, layer)
	_hide_background_dimmer(layer)

## Toast 自动消失回调
func _on_toast_dismissed(toast: UIToast) -> void:
	_remove_toast(toast)

## 从活跃列表中移除 Toast 并释放
func _remove_toast(toast: UIToast) -> void:
	var idx := _active_toasts.find(toast)
	if idx >= 0:
		_active_toasts.remove_at(idx)
	if is_instance_valid(toast):
		toast.queue_free()

## 尝试从弹窗队列弹出下一个
func _try_show_next_popup() -> void:
	# 只在 POPUP 栈为空时弹出
	_ensure_layer(UILayer.POPUP)
	var popup_stack: Array = _panel_stacks[UILayer.POPUP]
	if not popup_stack.is_empty():
		return
	if _popup_queue.is_empty():
		return
	var next: Dictionary = _popup_queue.pop_front()
	open_panel(next["panel_id"], next["data"], UILayer.POPUP)

## 显示背景遮罩
func _show_background_dimmer(layer: int) -> void:
	if _dimmers.has(layer):
		_dimmers[layer].visible = true
		return
	_ensure_layer(layer)
	var layer_node: CanvasLayer = _layer_nodes[layer]
	var dimmer := ColorRect.new()
	dimmer.name = "BackgroundDimmer"
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	# 确保遮罩在面板下方
	layer_node.add_child(dimmer)
	layer_node.move_child(dimmer, 0)
	_dimmers[layer] = dimmer

## 隐藏背景遮罩
func _hide_background_dimmer(layer: int) -> void:
	if _dimmers.has(layer):
		_dimmers[layer].visible = false
