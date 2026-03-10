## 事件基类，所有自定义事件应继承此类
class_name Event
extends Resource

## 是否已被取消（后续监听器不再处理）
var cancelled: bool = false

## 事件发出时的时间戳
var timestamp: float

func _init() -> void:
	timestamp = Time.get_ticks_msec()

## 取消事件，后续监听器不再处理
func cancel() -> void:
	cancelled = true

## 获取事件的类型名称
func get_event_type() -> StringName:
	return get_script().resource_name if get_script() else get_class()
