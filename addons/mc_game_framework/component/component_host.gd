## ComponentHost — Data Component 宿主适配器
##
## 挂载范围为通用对象（Node / Resource / 纯数据对象）：
## - 通过容器模式解耦组件存储与宿主类
## - Node 通过元数据方式挂载
## - Resource 直接持有容器引用
## - 纯数据对象通过包装器挂载
extends RefCounted
class_name ComponentHost

## 元数据键名（用于 Node 挂载）
const META_KEY := &"__component_container"

# ── 静态 API：通用宿主操作 ─────────────────────────────

## 获取宿主上的 ComponentContainer（若不存在则创建）
static func get_or_create(host: Variant) -> ComponentContainer:
	var container := get_container(host)
	if container != null:
		return container
	container = ComponentContainer.new()
	set_container(host, container)
	return container

## 获取宿主上的 ComponentContainer（若不存在返回 null）
static func get_container(host: Variant) -> ComponentContainer:
	if host is Node:
		if host.has_meta(META_KEY):
			var meta = host.get_meta(META_KEY)
			if meta is ComponentContainer:
				return meta
		return null
	elif host is Resource:
		if host.has_meta(META_KEY):
			var meta = host.get_meta(META_KEY)
			if meta is ComponentContainer:
				return meta
		return null
	elif host is RefCounted:
		# 纯数据对象：检查是否有 _component_container 属性
		if host.has_method("get") and host.get("_component_container") is ComponentContainer:
			return host.get("_component_container")
		return null
	return null

## 设置宿主上的 ComponentContainer
static func set_container(host: Variant, container: ComponentContainer) -> void:
	if host is Node:
		host.set_meta(META_KEY, container)
	elif host is Resource:
		host.set_meta(META_KEY, container)
	elif host is RefCounted:
		if host.has_method("set"):
			host.set("_component_container", container)

## 移除宿主上的 ComponentContainer
static func remove_container(host: Variant) -> void:
	if host is Node:
		host.remove_meta(META_KEY)
	elif host is Resource:
		host.remove_meta(META_KEY)

# ── 便捷方法 ──────────────────────────────────────────

## 直接获取宿主上的指定组件值
static func get_component(host: Variant, type: ComponentType) -> Variant:
	var container := get_container(host)
	if container == null:
		return type.get_default_value()
	return container.get_component(type)

## 直接设置宿主上的指定组件值
static func set_component(host: Variant, type: ComponentType, value: Variant) -> void:
	var container := get_or_create(host)
	container.set_component(type, value)

## 直接移除宿主上的指定组件
static func remove_component(host: Variant, type: ComponentType) -> bool:
	var container := get_container(host)
	if container == null:
		return false
	return container.remove_component(type)

## 判断宿主是否拥有指定组件
static func has_component(host: Variant, type: ComponentType) -> bool:
	var container := get_container(host)
	if container == null:
		return false
	return container.has_component(type)
