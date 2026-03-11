# meta_registry.gd
extends RegistryBase

@export var REGISTRY_NAMESPACE = "core";

# 注册一个注册表实例
func register_registry(type_name: String, registry: RegistryBase) -> void:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	register(id, registry)

# 获取指定类型的注册表
func get_registry(type_name: String) -> RegistryBase:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return get_entry(id)

# 检查注册表是否存在
func has_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return has_entry(id)

# 移除注册表
func unregister_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return unregister(id)
