extends RegistryBase
class_name ComponentTypeRegistry
## Data Component 类型注册表
## 通过现有 RegistryManager 接入，不作为 Autoload

const REGISTRY_KEY := "component_type"

## 注册一个 ComponentType
func register_component_type(component_type: ComponentType) -> void:
	if component_type == null:
		push_error("ComponentTypeRegistry: component_type must not be null")
		return
	register(component_type.id, component_type)

## 获取指定组件类型
func get_component_type(id: Variant) -> ComponentType:
	var normalized_id := _normalize_id(id)
	if normalized_id == null:
		return null
	return get_entry(normalized_id) as ComponentType

## 检查组件类型是否存在
func has_component_type(id: Variant) -> bool:
	var normalized_id := _normalize_id(id)
	if normalized_id == null:
		return false
	return has_entry(normalized_id)

## 移除组件类型
func unregister_component_type(id: Variant) -> bool:
	var normalized_id := _normalize_id(id)
	if normalized_id == null:
		return false
	return unregister(normalized_id)

## 获取全部组件类型
func get_all_component_types() -> Dictionary:
	return get_all_entries()

func _validate_entry(entry: Variant) -> bool:
	return entry is ComponentType

func _get_expected_type_name() -> String:
	return "ComponentType"

func _normalize_id(id: Variant) -> ResourceLocation:
	if id is ResourceLocation:
		return id
	if id is String:
		return ResourceLocation.from_string(id)
	push_error("ComponentTypeRegistry: id must be ResourceLocation or String")
	return null
