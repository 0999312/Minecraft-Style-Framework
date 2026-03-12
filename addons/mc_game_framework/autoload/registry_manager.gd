# meta_registry.gd
extends Node

const REGISTRY_NAMESPACE := "core"

var _registry: RegistryBase = RegistryBase.new()

# 注册一个注册表实例
func register_registry(type_name: String, registry: RegistryBase) -> void:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	_registry.register(id, registry)

# 获取指定类型的注册表
func get_registry(type_name: String) -> RegistryBase:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return _registry.get_entry(id)

# 检查注册表是否存在
func has_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return _registry.has_entry(id)

# 移除注册表
func unregister_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return _registry.unregister(id)
