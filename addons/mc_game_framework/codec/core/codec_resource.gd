## CodecResource — Codec 驱动的 Godot Resource 基类
##
## 支持 Godot Resource (.tres/.res) 落盘：
## - 每个资源脚本声明：类型 ID、Codec
## - 通过 Codec 实现序列化/反序列化
## - 编辑器下可通过 Inspector 编辑并触发 Codec 校验
## - 作为运行时对象与 Godot Resource 持久化之间的桥接层
extends Resource
class_name CodecResource

## 资源类型 ID（子类必须覆写）
static func get_type_id() -> String:
	return ""

## 获取此资源类型的 Codec（子类必须覆写）
## 返回: Codec 或 MapCodec
static func get_codec() -> Codec:
	push_error("CodecResource.get_codec(): subclass must override this method")
	return null

## 是否允许落盘为 Godot Resource（默认允许）
static func allows_resource_persistence() -> bool:
	return true

# ── 序列化 API ────────────────────────────────────────

## 使用 Codec 编码为指定 ops 格式
func encode_with(ops: DynamicOps) -> DataResult:
	var codec := get_codec()
	if codec == null:
		return DataResult.error("No codec defined for resource type: %s" % get_type_id())
	return codec.encode(self, ops)

## 使用 Codec 从数据解码（类方法，返回新实例）
## 需要子类在 codec 中定义构造逻辑
static func decode_with(data: Variant, ops: DynamicOps) -> DataResult:
	var codec := get_codec()
	if codec == null:
		return DataResult.error("No codec defined for resource type")
	return codec.decode(data, ops)

## 编码为 JSON 字典
func to_json_data() -> DataResult:
	return encode_with(JsonOps.INSTANCE)

## 从 JSON 字典解码
static func from_json_data(data: Variant) -> DataResult:
	return decode_with(data, JsonOps.INSTANCE)

## 编码为 Godot Resource 属性字典
func to_resource_data() -> DataResult:
	return encode_with(GodotResourceOps.INSTANCE)

## 保存为 .tres 文件
func save_to_file(path: String) -> DataResult:
	if not allows_resource_persistence():
		return DataResult.error("Resource type '%s' does not allow resource persistence" % get_type_id())
	return GodotResourceOps.save_resource(self, path)

## 从 .tres/.res 文件加载
static func load_from_file(path: String) -> DataResult:
	return GodotResourceOps.load_resource(path)
