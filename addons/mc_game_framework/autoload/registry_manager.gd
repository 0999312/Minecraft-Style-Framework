# meta_registry.gd
extends RegistryBase

@export var REGISTRY_NAMESPACE = "core";

func _ready() -> void:
	pass
	# 初始化内置注册表
	#register_registry("item", ItemRegistry.new())
	#register_registry("entity", EntityRegistry.new())  # 若存在
	#register_registry("scene", SceneRegistry.new())    # 若存在
	#register_registry("tag", TagRegistry.new())

# 注册一个注册表实例
func register_registry(type_name: String, registry: RegistryBase) -> void:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	register(id, registry)

# 获取指定类型的注册表
func get_registry(type_name: String) -> RegistryBase:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return get_entry(id)

# 泛型辅助方法：获取并自动转换为指定类型
func get_registry_as(type_name: String, class_script: GDScript) -> Variant:
	var reg = get_registry(type_name)
	if reg and reg.is_instance_of(class_script):
		return reg
	return null

# 检查注册表是否存在
func has_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return has_entry(id)

# 移除注册表
func unregister_registry(type_name: String) -> bool:
	var id = ResourceLocation.new(REGISTRY_NAMESPACE, type_name)
	return unregister(id)
