## Codec / Component 系统演示
##
## 展示：
## 1. 基础类型 Codec 使用
## 2. RecordCodecBuilder 风格组合式声明
## 3. JsonOps / GodotResourceOps 编解码
## 4. CodecResource 基础用法
## 5. Data Component 挂载到 Node / Resource
## 6. ResourceLocation Mojang 风格校验
extends Node

# ═══════════════════════════════════════════════════════
# 1. 定义一个简单的物品数据结构
# ═══════════════════════════════════════════════════════

## 物品数据（用于演示 Record 风格 Codec）
class ItemData extends RefCounted:
	var item_name: String
	var damage: int
	var weight: float
	var enchantable: bool

	func _init(p_name: String = "", p_damage: int = 0, p_weight: float = 1.0, p_enchantable: bool = false) -> void:
		item_name = p_name
		damage = p_damage
		weight = p_weight
		enchantable = p_enchantable

	func _to_string() -> String:
		return "ItemData(name=%s, damage=%d, weight=%.1f, enchantable=%s)" % [item_name, damage, weight, enchantable]

## 为 ItemData 定义 Codec（DFU RecordCodecBuilder 风格）
static func item_data_codec() -> Codec:
	return Codec.record(
		MapCodec.build(
			[
				Codec.STRING().field_of("name").for_getter(func(item: ItemData): return item.item_name),
				Codec.INT().field_of("damage").for_getter(func(item: ItemData): return item.damage),
				Codec.FLOAT().optional_field_of("weight", 1.0).for_getter(func(item: ItemData): return item.weight),
				Codec.BOOL().optional_field_of("enchantable", false).for_getter(func(item: ItemData): return item.enchantable),
			],
			func(name: String, damage: int, weight: float, enchantable: bool) -> ItemData: return ItemData.new(name, damage, weight, enchantable)
		)
	)

class DemoItemResource extends CodecResource:
	var item_name: String = ""
	var damage: int = 0
	
	func _init(item_name: String = "", damage: int = 0) -> void:
		item_name = item_name
		damage = damage
	
	static func get_type_id() -> String:
		return "demo:item_resource"

	static func get_codec() -> Codec:
		return Codec.record(
			MapCodec.build(
				[
					Codec.STRING().field_of("item_name").for_getter(func(item: DemoItemResource): return item.item_name),
					Codec.INT().field_of("damage").for_getter(func(item: DemoItemResource): return item.damage),
				],
				func(item_name: String, damage: int) -> DemoItemResource: return DemoItemResource.new(item_name, damage)
			)
		)

# ═══════════════════════════════════════════════════════
# 3. 定义 ComponentType（用于 Data Component 演示）
# ═══════════════════════════════════════════════════════

static func health_component_type() -> ComponentType:
	return ComponentType.Builder.new(
		ResourceLocation.new("demo", "health"),
		Codec.INT()
	).with_default(func(): return 20).persistent(
		ComponentType.PersistentPolicy.ALWAYS
	).build()

static func display_name_component_type() -> ComponentType:
	return ComponentType.Builder.new(
		ResourceLocation.new("demo", "display_name"),
		Codec.STRING()
	).with_default(func(): return "Unknown").persistent(
		ComponentType.PersistentPolicy.NON_DEFAULT
	).build()

# ═══════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════

func _ready() -> void:
	print("=".repeat(60))
	print("  Codec / Component System Demo")
	print("=".repeat(60))

	_demo_resource_location_validation()
	_demo_basic_codecs()
	_demo_record_codec()
	_demo_list_and_map_codec()
	_demo_codec_resource()
	_demo_data_components()

	print("\n" + "=".repeat(60))
	print("  All demos completed!")
	print("=".repeat(60))

# ── Demo 1: ResourceLocation 校验 ─────────────────────

func _demo_resource_location_validation() -> void:
	print("\n--- Demo 1: ResourceLocation Mojang-style Validation ---")

	# 合法
	var valid := ["minecraft:stone", "demo:items/sword", "my_mod:block.dirt", "a-b:c-d"]
	for s in valid:
		var result := ResourceLocation.parse(s)
		print("  '%s' -> %s" % [s, "✅ VALID" if result.is_success() else "❌ " + result.get_error()])

	# 非法
	var invalid := ["Minecraft:Stone", "demo:UPPER", "bad space:id", "demo:", ":path", "no_colon"]
	for s in invalid:
		var result := ResourceLocation.parse(s)
		print("  '%s' -> %s" % [s, "✅ VALID" if result.is_success() else "❌ " + result.get_error()])

# ── Demo 2: 基础类型 Codec ─────────────────────────────

func _demo_basic_codecs() -> void:
	print("\n--- Demo 2: Basic Type Codecs ---")
	var ops := JsonOps.INSTANCE

	# INT
	var int_codec := Codec.INT()
	var encoded := int_codec.encode(42, ops)
	print("  INT encode(42) -> %s" % str(encoded.get_value()))
	var decoded := int_codec.decode(42, ops)
	print("  INT decode(42) -> %s" % str(decoded.get_value()))

	# STRING
	var str_codec := Codec.STRING()
	encoded = str_codec.encode("hello", ops)
	print("  STRING encode('hello') -> %s" % str(encoded.get_value()))

	# BOOL
	var bool_codec := Codec.BOOL()
	encoded = bool_codec.encode(true, ops)
	print("  BOOL encode(true) -> %s" % str(encoded.get_value()))

	# Error case
	var bad := int_codec.decode("not a number", ops)
	print("  INT decode('not a number') -> %s" % bad.to_string())

# ── Demo 3: Record Codec (DFU 风格声明) ───────────────

func _demo_record_codec() -> void:
	print("\n--- Demo 3: Record Codec (Declarative DFU-style) ---")
	var json_ops := JsonOps.INSTANCE
	var resource_ops := GodotResourceOps.INSTANCE
	var codec := item_data_codec()

	# 编码
	var item := ItemData.new("Diamond Sword", 7, 1.5, true)
	var encode_result := codec.encode(item, json_ops)
	if encode_result.is_success():
		var json := JsonOps.to_json_string(encode_result.get_value())
		print("  Encode to JSON: %s" % json)
	var resource_encode_result := codec.encode(item, resource_ops)
	if resource_encode_result.is_success():
		print("  Encode to Godot Resource data: %s" % str(resource_encode_result.get_value()))

	# 解码
	var json_data := {"name": "Iron Pickaxe", "damage": 4, "weight": 2.0, "enchantable": true}
	var decode_result := codec.decode(json_data, json_ops)
	if decode_result.is_success():
		print("  Decode: %s" % str(decode_result.get_value()))

	# 可选字段缺失时使用默认值
	var partial_data := {"name": "Stick", "damage": 1}
	var partial_result := codec.decode(partial_data, json_ops)
	if not partial_result.is_error():
		var decoded_item: ItemData = partial_result.get_value()
		print("  Partial decode (defaults): %s" % str(decoded_item))
		print("    weight=%.1f (default), enchantable=%s (default)" % [decoded_item.weight, decoded_item.enchantable])

# ── Demo 4: List & Map Codec ──────────────────────────

func _demo_list_and_map_codec() -> void:
	print("\n--- Demo 4: List & Map Codec ---")
	var ops := JsonOps.INSTANCE

	# List
	var list_codec := Codec.INT().list_of()
	var list_data := [1, 2, 3, 4, 5]
	var encoded := list_codec.encode(list_data, ops)
	print("  List encode: %s" % str(encoded.get_value()))
	var decoded := list_codec.decode([10, 20, 30], ops)
	print("  List decode: %s" % str(decoded.get_value()))

	# Map
	var map_codec := Codec.map_of(Codec.STRING(), Codec.INT())
	var map_data := {"health": 20, "mana": 100, "stamina": 50}
	encoded = map_codec.encode(map_data, ops)
	print("  Map encode: %s" % str(encoded.get_value()))

# ── Demo 5: CodecResource ─────────────────────────────

func _demo_codec_resource() -> void:
	print("\n--- Demo 5: CodecResource ---")
	var res := DemoItemResource.new()
	res.item_name = "Golden Apple"
	res.damage = 0

	var json_result := res.to_json_data()
	if json_result.is_success():
		print("  CodecResource to JSON: %s" % JsonOps.to_json_string(json_result.get_value()))

	var resource_result := res.to_resource_data()
	if resource_result.is_success():
		print("  CodecResource to Godot Resource data: %s" % str(resource_result.get_value()))

	var decoded_result := DemoItemResource.from_json_data({"item_name": "Stone Axe", "damage": 3})
	if decoded_result.is_success():
		print("  CodecResource decode: %s" % str(decoded_result.get_value()))

# ── Demo 6: Data Components ──────────────────────────

func _demo_data_components() -> void:
	print("\n--- Demo 6: Data Components ---")

	if not RegistryManager.has_registry(ComponentTypeRegistry.REGISTRY_KEY):
		RegistryManager.register_registry(ComponentTypeRegistry.REGISTRY_KEY, ComponentTypeRegistry.new())
	var component_registry := RegistryManager.get_registry(ComponentTypeRegistry.REGISTRY_KEY) as ComponentTypeRegistry

	var health_type := health_component_type()
	var name_type := display_name_component_type()
	if not component_registry.has_component_type(health_type.id):
		component_registry.register_component_type(health_type)
	if not component_registry.has_component_type(name_type.id):
		component_registry.register_component_type(name_type)

	print("  Component registry key: %s" % ComponentTypeRegistry.REGISTRY_KEY)
	print("    registered health? %s" % str(component_registry.has_component_type(health_type.id)))
	print("    registered display_name? %s" % str(component_registry.has_component_type(name_type.id)))

	# 挂载到 Node
	var node := Node.new()
	node.name = "TestEntity"
	add_child(node)

	ComponentHost.set_component(node, health_type, 15)
	ComponentHost.set_component(node, name_type, "Creeper")

	print("  Node '%s' components:" % node.name)
	print("    health = %s" % str(ComponentHost.get_component(node, health_type)))
	print("    display_name = %s" % str(ComponentHost.get_component(node, name_type)))
	print("    has health? %s" % str(ComponentHost.has_component(node, health_type)))

	# 序列化组件容器
	var container := ComponentHost.get_container(node)
	var encode_result := container.encode(JsonOps.INSTANCE)
	if encode_result.is_success():
		print("    Serialized: %s" % JsonOps.to_json_string(encode_result.get_value()))
		var decoded_container := ComponentContainer.new()
		var decode_result := decoded_container.decode(encode_result.get_value(), JsonOps.INSTANCE)
		if decode_result.is_success():
			print("    Decoded via RegistryManager: health = %s" % str(decoded_container.get_component(health_type)))
			print("    Decoded via RegistryManager: display_name = %s" % str(decoded_container.get_component(name_type)))

	# 挂载到 Resource
	var res := Resource.new()
	ComponentHost.set_component(res, health_type, 100)
	print("\n  Resource components:")
	print("    health = %s" % str(ComponentHost.get_component(res, health_type)))

	# 默认值裁剪演示
	ComponentHost.set_component(node, name_type, "Unknown")  # 设为默认值
	var container2 := ComponentHost.get_container(node)
	var pruned := container2.encode(JsonOps.INSTANCE)
	if pruned.is_success():
		print("\n  After setting display_name='Unknown' (default), serialized:")
		print("    %s" % JsonOps.to_json_string(pruned.get_value()))
		print("    (display_name omitted because persistent_policy=NON_DEFAULT and value==default)")

	node.queue_free()
