## 全局事件总线系统，管理事件的发布和订阅
## 支持 Callable 回调和 Signal 信号两种方式
extends Node

# ===== 内部类和数据结构 =====

## 监听器条目
class ListenerEntry:
	var callable: Callable
	var priority: int
	var is_signal: bool = false
	
	func _init(p_callable: Callable, p_priority: int = 0, p_is_signal: bool = false):
		callable = p_callable
		priority = p_priority
		is_signal = p_is_signal

## 存储监听器：键为事件类型字符串，值为 ListenerEntry 数组
var _listeners: Dictionary = {}

## 存储信号：键为事件类型字符串，值为 Signal 对象
var _signals: Dictionary = {}

## 发出事件时的栈追踪，用于调试
var _event_stack: Array = []

## 是否启用调试模式
var debug_enabled: bool = false

# ===== 订阅相关方法 =====

## 订阅事件（基于 Callable 回调）
## 参数：
##   event_class: 事件类（GDScript 对象）
##   listener: 监听回调函数
##   priority: 优先级（数字越大优先级越高）
func subscribe(event_class: GDScript, listener: Callable, priority: int = 0) -> void:
	if not event_class:
		push_error("EventBus: event_class 不能为空")
		return
	
	var event_type = _get_event_type_name(event_class)
	
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	
	# 检查是否已订阅（防止重复订阅）
	var listeners_arr = _listeners[event_type]
	for entry in listeners_arr:
		if entry.callable == listener:
			if debug_enabled:
				print("EventBus: 监听器已存在，跳过重复订阅 - %s" % event_type)
			return
	
	var entry = ListenerEntry.new(listener, priority, false)
	listeners_arr.append(entry)
	_sort_listeners(event_type)
	
	if debug_enabled:
		print("EventBus: 已订阅事件 - %s (优先级: %d)" % [event_type, priority])

## 取消订阅事件
## 参数：
##   event_class: 事件类
##   listener: 要移除的监听器
func unsubscribe(event_class: GDScript, listener: Callable) -> void:
	if not event_class:
		return
	
	var event_type = _get_event_type_name(event_class)
	
	if _listeners.has(event_type):
		var listeners_arr = _listeners[event_type]
		for i in range(listeners_arr.size() - 1, -1, -1):
			if listeners_arr[i].callable == listener:
				listeners_arr.remove_at(i)
				if debug_enabled:
					print("EventBus: 已取消订阅 - %s" % event_type)
				break

## 订阅信号形式的事件（Godot Signal）
## 返回内部生成的 Signal，允许在其他地方使用 .connect() 进行连接
## 参数：
##   event_class: 事件类
##   priority: 优先级
func subscribe_signal(event_class: GDScript, priority: int = 0) -> Signal:
	if not event_class:
		push_error("EventBus: event_class 不能为空")
		return Signal()
	
	var event_type = _get_event_type_name(event_class)
	
	# 如果还没有为此事件类型创建信号，则创建一个
	if not _signals.has(event_type):
		_signals[event_type] = Signal()
		if debug_enabled:
			print("EventBus: 创建信号 - %s" % event_type)
	
	return _signals[event_type]

# ===== 发布相关方法 =====

## 发布事件，所有订阅者都会收到通知
## 参数：
##   event: 事件对象
##   event_class: 事件类（可选，若为空则自动获取）
func post(event: Event, event_class: GDScript = null) -> void:
	if not event:
		push_error("EventBus: 事件对象不能为空")
		return
	
	if not event_class:
		event_class = event.get_script()
	
	if not event_class:
		push_error("EventBus: 无法确定事件类型")
		return
	
	var event_type = _get_event_type_name(event_class)
	
	# 记录调试信息
	if debug_enabled:
		_event_stack.append(event_type)
		print("EventBus: 发布事件 - %s [深度: %d]" % [event_type, _event_stack.size()])
	
	# 发送给 Callable 监听器
	_post_to_callable_listeners(event, event_type)
	
	# 发送给 Signal 监听器
	_post_to_signal_listeners(event, event_type)
	
	if debug_enabled:
		_event_stack.pop_back()

## 异步发布事件（下一帧执行）
func post_deferred(event: Event, event_class: GDScript = null) -> void:
	var call_class = event_class if event_class else event.get_script()
	call_deferred("post", event, call_class)

# ===== 内部辅助方法 =====

## 发送事件给所有 Callable 监听器
func _post_to_callable_listeners(event: Event, event_type: String) -> void:
	if not _listeners.has(event_type):
		return
	
	# 复制一份监听器列表，以防在遍历时修改
	var listeners_copy = _listeners[event_type].duplicate()
	
	for entry in listeners_copy:
		if event.cancelled:
			if debug_enabled:
				print("EventBus: 事件已被取��，停止派发 - %s" % event_type)
			break
		
		# 调用监听器
		if entry.callable.is_valid():
			entry.callable.call(event)
		else:
			if debug_enabled:
				print("EventBus: 监听器无效 - %s" % event_type)

## 发送事件给所有 Signal 监听器
func _post_to_signal_listeners(event: Event, event_type: String) -> void:
	if not _signals.has(event_type):
		return
	
	if event.cancelled:
		return
	
	var signal_obj = _signals[event_type]
	if signal_obj:
		signal_obj.emit(event)

## 获取事件类型的字符串名称
func _get_event_type_name(event_class: GDScript) -> String:
	var eventclass_name = event_class.resource_name if event_class.resource_name else event_class.get_class()
	return str(eventclass_name)

## 按优先级排序监听器（优先级高的在前）
func _sort_listeners(event_type: String) -> void:
	if _listeners.has(event_type):
		_listeners[event_type].sort_custom(func(a: ListenerEntry, b: ListenerEntry) -> bool:
			return a.priority > b.priority
		)

# ===== 工具方法 =====

## 获取特定事件的监听器数量
func get_listener_count(event_class: GDScript) -> int:
	var event_type = _get_event_type_name(event_class)
	if _listeners.has(event_type):
		return _listeners[event_type].size()
	return 0

## 清空所有监听器和信号
func clear_all() -> void:
	_listeners.clear()
	_signals.clear()
	if debug_enabled:
		print("EventBus: 已清空所有监听器和信号")

## 清空特定事件的所有监听器
func clear_event(event_class: GDScript) -> void:
	var event_type = _get_event_type_name(event_class)
	if _listeners.has(event_type):
		_listeners[event_type].clear()
	if _signals.has(event_type):
		_signals.erase(event_type)
	if debug_enabled:
		print("EventBus: 已清空事件监听器 - %s" % event_type)

## 打印所有已注册的事件信息（调试用）
func debug_print_listeners() -> void:
	print("\n===== EventBus 调试信息 =====")
	print("已注册事件数: %d" % _listeners.size())
	for event_type in _listeners:
		var count = _listeners[event_type].size()
		print("  - %s: %d 个监听器" % [event_type, count])
	print("==============================\n")
