## ComponentType — Data Component 类型定义
##
## 对齐 Minecraft Data Component 设计：
## - 每个组件类型声明 ID、Codec、持久化策略、网络同步策略、默认值
## - 挂载范围为通用对象（Node / Resource / 纯数据对象）
extends RefCounted
class_name ComponentType

## 持久化策略
enum PersistentPolicy {
	NONE,       ## 不持久化
	ALWAYS,     ## 始终持久化
	NON_DEFAULT,## 仅非默认值时持久化（默认值裁剪）
}

## 网络同步策略
enum NetworkSyncPolicy {
	NONE,       ## 不同步
	FULL,       ## 全量同步
	TRACKED,    ## 变化时同步
}

## 组件 ID
var id: ResourceLocation
## 编解码器
var codec: Codec
## 持久化策略
var persistent_policy: PersistentPolicy
## 网络同步策略
var network_sync_policy: NetworkSyncPolicy
## 默认值工厂（Callable 返回新的默认值实例）
var _default_factory: Callable

func _init(
	p_id: ResourceLocation,
	p_codec: Codec,
	p_default_factory: Callable = Callable(),
	p_persistent: PersistentPolicy = PersistentPolicy.NON_DEFAULT,
	p_network: NetworkSyncPolicy = NetworkSyncPolicy.NONE
) -> void:
	id = p_id
	codec = p_codec
	_default_factory = p_default_factory
	persistent_policy = p_persistent
	network_sync_policy = p_network

## 获取默认值
func get_default_value() -> Variant:
	if _default_factory.is_valid():
		return _default_factory.call()
	return null

## 判断值是否等于默认值
func is_default(value: Variant) -> bool:
	var default_val = get_default_value()
	if default_val == null and value == null:
		return true
	if default_val == null or value == null:
		return false
	if typeof(default_val) == typeof(value):
		return default_val == value
	return false

## 编码组件值
func encode_value(value: Variant, ops: DynamicOps) -> DataResult:
	return codec.encode(value, ops)

## 解码组件值
func decode_value(data: Variant, ops: DynamicOps) -> DataResult:
	return codec.decode(data, ops)

func _to_string() -> String:
	return "ComponentType(%s)" % id.to_string()

# ═══════════════════════════════════════════════════════
# Builder 风格构造
# ═══════════════════════════════════════════════════════

class Builder extends RefCounted:
	var _id: ResourceLocation
	var _codec: Codec
	var _default_factory: Callable = Callable()
	var _persistent: PersistentPolicy = PersistentPolicy.NON_DEFAULT
	var _network: NetworkSyncPolicy = NetworkSyncPolicy.NONE

	func _init(id: ResourceLocation, codec: Codec) -> void:
		_id = id
		_codec = codec

	func with_default(factory: Callable) -> Builder:
		_default_factory = factory
		return self

	func persistent(policy: PersistentPolicy) -> Builder:
		_persistent = policy
		return self

	func network(policy: NetworkSyncPolicy) -> Builder:
		_network = policy
		return self

	func build() -> ComponentType:
		return ComponentType.new(_id, _codec, _default_factory, _persistent, _network)
