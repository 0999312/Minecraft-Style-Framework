extends RegistryBase
class_name TagRegistry

# 注册一个新标签，registry_type 为指向具体注册表的 ResourceLocation
func register_tag(tag_id: ResourceLocation, registry_type: ResourceLocation) -> Tag:
	if has_entry(tag_id):
		push_warning("Tag already exists: ", tag_id.to_string())
		return get_entry(tag_id)
	var new_tag = Tag.new(registry_type)
	register(tag_id, new_tag)
	return new_tag

# 获取标签对象
func get_tag(tag_id: ResourceLocation) -> Tag:
	return get_entry(tag_id)

# 向标签添加条目
func add_to_tag(tag_id: ResourceLocation, entry_id: ResourceLocation) -> void:
	var tag = get_tag(tag_id)
	if tag:
		tag.add_entry(entry_id)
	else:
		push_error("Tag not found: ", tag_id.to_string())

# 从标签移除条目
func remove_from_tag(tag_id: ResourceLocation, entry_id: ResourceLocation) -> bool:
	var tag = get_tag(tag_id)
	if tag:
		return tag.remove_entry(entry_id)
	return false

# 检查条目是否属于标签
func has_entry_in_tag(tag_id: ResourceLocation, entry_id: ResourceLocation) -> bool:
	var tag = get_tag(tag_id)
	if tag:
		return tag.has_entry(entry_id)
	return false

# 获取标签的所有条目
func get_all_entries_of_tag(tag_id: ResourceLocation) -> Array[ResourceLocation]:
	var tag = get_tag(tag_id)
	if tag:
		return tag.get_all_entries()
	return []

# 删除标签（同时从注册表中移除）
func delete_tag(tag_id: ResourceLocation) -> bool:
	return unregister(tag_id)

# 获取所有标签 ID
func get_all_tag_ids() -> Array[ResourceLocation]:
	return get_all_keys().map(func(s): return ResourceLocation.from_string(s))
