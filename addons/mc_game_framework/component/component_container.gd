## ComponentContainer — Data Component 容器
##
## 对齐 Minecraft DataComponentMap 设计：
## - 管理一个宿主上挂载的所有 Component
## - 支持 get/set/remove/has
## - 支持序列化/反序列化
## - 支持差量 Patch、合并覆盖
## - 支持默认值裁剪（仅持久化非默认值的组件）
extends RefCounted
class_name ComponentContainer

## 组件数据存储 { ResourceLocation.to_string() -> value }
var _data: Dictionary = {}
## 组件类型引用 { ResourceLocation.to_string() -> ComponentType }
var _types: Dictionary = {}

# ── 基本操作 ──────────────────────────────────────────

## 获取指定组件的值
func get_component(type: ComponentType) -> Variant:
	var key := type.id.to_string()
	if _data.has(key):
		return _data[key]
	return type.get_default_value()

## 设置指定组件的值
func set_component(type: ComponentType, value: Variant) -> void:
	var key := type.id.to_string()
	_data[key] = value
	_types[key] = type

## 移除指定组件
func remove_component(type: ComponentType) -> bool:
	var key := type.id.to_string()
	_types.erase(key)
	return _data.erase(key)

## 是否拥有指定组件
func has_component(type: ComponentType) -> bool:
	return _data.has(type.id.to_string())

## 获取所有已设置的组件 ID 列表
func get_component_ids() -> Array:
	return _data.keys()

## 获取已设置组件的数量
func size() -> int:
	return _data.size()

## 清空所有组件
func clear() -> void:
	_data.clear()
	_types.clear()

# ── 序列化 ────────────────────────────────────────────

## 编码所有需要持久化的组件为 Map 数据
func encode(ops: DynamicOps) -> DataResult:
	var entries: Dictionary = {}
	var diagnostics: Array = []
	for key in _data:
		var type: ComponentType = _types.get(key)
		if type == null:
			diagnostics.append(DataResult.Diagnostic.new(
				DataResult.DiagnosticLevel.WARNING,
				"Component type not found for key '%s', skipping" % key, key))
			continue
		# 根据持久化策略决定是否写入
		match type.persistent_policy:
			ComponentType.PersistentPolicy.NONE:
				continue
			ComponentType.PersistentPolicy.NON_DEFAULT:
				if type.is_default(_data[key]):
					continue
			ComponentType.PersistentPolicy.ALWAYS:
				pass
		var result := type.encode_value(_data[key], ops)
		if result.is_error():
			diagnostics.append(DataResult.Diagnostic.new(
				DataResult.DiagnosticLevel.RECOVERABLE,
				"Failed to encode component '%s': %s" % [key, result.get_error()], key))
			continue
		entries[key] = result.get_value()
		diagnostics.append_array(result.get_diagnostics())
	var r := DataResult.success(ops.create_map(entries))
	r._diagnostics = diagnostics
	return r

## 从 Map 数据解码组件
## - type_registry 可传 Dictionary{id_string -> ComponentType}
## - 或传入 ComponentTypeRegistry
## - 或留空，默认从 RegistryManager 的 "component_type" 注册表读取
func decode(data: Variant, ops: DynamicOps, type_registry: Variant = null) -> DataResult:
	var registry_result := _resolve_type_registry(type_registry)
	if registry_result.is_error():
		return registry_result
	var entries_result := ops.get_map_entries(data)
	if entries_result.is_error():
		return entries_result
	var entries: Dictionary = entries_result.get_value()
	var resolved_type_registry: Dictionary = registry_result.get_value()
	var diagnostics: Array = []
	for key in entries:
		var type: ComponentType = resolved_type_registry.get(key)
		if type == null:
			diagnostics.append(DataResult.Diagnostic.new(
				DataResult.DiagnosticLevel.WARNING,
				"Unknown component type '%s', skipping" % key, key))
			continue
		var result := type.decode_value(entries[key], ops)
		if result.is_error():
			diagnostics.append(DataResult.Diagnostic.new(
				DataResult.DiagnosticLevel.RECOVERABLE,
				"Failed to decode component '%s': %s" % [key, result.get_error()], key))
			continue
		_data[key] = result.get_value()
		_types[key] = type
		diagnostics.append_array(result.get_diagnostics())
	var r := DataResult.success(self)
	r._diagnostics = diagnostics
	return r

func _resolve_type_registry(type_registry: Variant) -> DataResult:
	if type_registry == null:
		return _resolve_registry_from_manager(ComponentTypeRegistry.REGISTRY_KEY)
	if type_registry is Dictionary:
		return DataResult.success(type_registry)
	if type_registry is ComponentTypeRegistry:
		return DataResult.success((type_registry as ComponentTypeRegistry).get_all_component_types())
	if type_registry is String:
		return _resolve_registry_from_manager(type_registry)
	return DataResult.error("ComponentContainer.decode: type_registry must be Dictionary, ComponentTypeRegistry, String, or null")

func _resolve_registry_from_manager(registry_name: String) -> DataResult:
	var registry = RegistryManager.get_registry(registry_name)
	if registry == null:
		return DataResult.error(
			"ComponentContainer.decode: ComponentTypeRegistry '%s' not found. Call RegistryManager.register_registry(\"%s\", ComponentTypeRegistry.new()) first" % [registry_name, registry_name]
		)
	if not registry is ComponentTypeRegistry:
		return DataResult.error(
			"ComponentContainer.decode: registry '%s' must be a ComponentTypeRegistry" % registry_name
		)
	return DataResult.success((registry as ComponentTypeRegistry).get_all_component_types())

# ── Patch / 合并 ──────────────────────────────────────

## 应用差量 Patch（设置/覆盖指定组件，移除标记为 null 的组件）
func apply_patch(patch: ComponentContainer) -> void:
	for key in patch._data:
		if patch._data[key] == null:
			_data.erase(key)
			_types.erase(key)
		else:
			_data[key] = patch._data[key]
			if patch._types.has(key):
				_types[key] = patch._types[key]

## 合并另一个容器的组件（覆盖已存在的）
func merge(other: ComponentContainer) -> void:
	for key in other._data:
		_data[key] = other._data[key]
		if other._types.has(key):
			_types[key] = other._types[key]

## 创建当前容器的深拷贝
func duplicate_container() -> ComponentContainer:
	var copy := ComponentContainer.new()
	copy._data = _data.duplicate(true)
	copy._types = _types.duplicate()
	return copy

func _to_string() -> String:
	return "ComponentContainer(size=%d, keys=%s)" % [_data.size(), str(_data.keys())]
