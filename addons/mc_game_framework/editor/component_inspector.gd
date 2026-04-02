## ComponentInspectorPlugin — Data Component 容器可视编辑器
##
## 编辑器可视化支持：
## - 在 Inspector 中展示 Node/Resource 上已挂载的组件列表
## - 显示组件 ID、当前值、默认值差异
## - 显示持久化策略与网络同步标签
extends EditorInspectorPlugin
class_name ComponentInspectorPlugin

func _can_handle(object: Object) -> bool:
	if object is Node:
		return object.has_meta(ComponentHost.META_KEY)
	if object is Resource:
		return object.has_meta(ComponentHost.META_KEY)
	return false

func _parse_begin(object: Object) -> void:
	var container := ComponentHost.get_container(object)
	if container == null:
		return

	# 标题
	var header := Label.new()
	header.text = "📦 Data Components (%d)" % container.size()
	header.add_theme_font_size_override("font_size", 14)
	add_custom_control(header)

	add_custom_control(HSeparator.new())

	# 遍历已挂载组件
	for key in container.get_component_ids():
		var type: ComponentType = container._types.get(key)
		var value = container._data.get(key)

		var component_box := VBoxContainer.new()

		# 组件 ID
		var id_label := Label.new()
		id_label.text = "🏷️ %s" % key
		component_box.add_child(id_label)

		# 当前值
		var val_label := Label.new()
		val_label.text = "  Value: %s" % str(value)
		component_box.add_child(val_label)

		if type != null:
			# 是否为默认值
			var is_default := type.is_default(value)
			var default_label := Label.new()
			default_label.text = "  Default: %s" % ("Yes ✅" if is_default else "No (modified)")
			component_box.add_child(default_label)

			# 持久化策略
			var persist_label := Label.new()
			var persist_text := "NONE"
			match type.persistent_policy:
				ComponentType.PersistentPolicy.ALWAYS:
					persist_text = "ALWAYS"
				ComponentType.PersistentPolicy.NON_DEFAULT:
					persist_text = "NON_DEFAULT"
			var network_text := "NONE"
			match type.network_sync_policy:
				ComponentType.NetworkSyncPolicy.FULL:
					network_text = "FULL"
				ComponentType.NetworkSyncPolicy.TRACKED:
					network_text = "TRACKED"
			persist_label.text = "  Persistent: %s | Network Tag: %s" % [persist_text, network_text]
			component_box.add_child(persist_label)

		add_custom_control(component_box)
		add_custom_control(HSeparator.new())
