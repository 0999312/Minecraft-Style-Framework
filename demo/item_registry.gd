# item_registry.gd
extends RegistryBase
class_name ItemRegistry

func register_item(id: ResourceLocation, item_resource: Resource) -> void:
	register(id, item_resource)

func unregister_item(id: ResourceLocation) -> bool:
	return unregister(id)

func get_item(id: ResourceLocation) -> ItemInfo:
	var entry = get_entry(id)
	if entry is ItemInfo:
		return entry
	return null

func instantiate_item(id: ResourceLocation) -> Node:
	var info = get_item(id)
	if not info:
		return null
	if info.scene:
		return info.scene.instantiate()
	elif info.script:
		# 注意：如果 script 是一个脚本对象，需要调用 new()
		if info.script is Script:
			return info.script.new()
		else:
			push_error("Invalid script in ItemInfo for ", id.to_string())
	return null

func _validate_entry(entry: Variant) -> bool:
	return entry is ItemInfo

func _get_expected_type_name() -> String:
	return "ItemInfo"
