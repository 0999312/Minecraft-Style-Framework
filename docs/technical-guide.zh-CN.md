# Minecraft-Style-Framework 技术文档

这是本项目的中文技术文档，内容对应英文主文档 [`technical-guide.md`](./technical-guide.md)，包含 API 介绍、架构说明、使用示例与实现约束。

## 1. 简介

**Minecraft-Style-Framework** 是一个面向 Godot 的游戏功能框架，受 Minecraft 底层设计思路启发，强调数据驱动、系统解耦与高扩展性。适合物品较多、事件交互复杂、模块边界清晰要求较高的项目。

## 2. 功能列表

- **ResourceLocation**：`namespace:path` 风格标识符，支持 Mojang 风格合法性校验。
- **Registry 与 RegistryManager**：集中管理游戏数据的注册表体系。
- **EventBus**：支持取消事件和 Godot `Signal` 联动的全局事件总线。
- **Tag 系统**：无需修改对象本身即可动态分类注册表项。
- **I18n**：基于 JSON 的本地化系统。
- **Codec 系统**：面向 JSON / Godot Resource 的 DFU 风格声明式编解码。
- **Data Component 系统**：可挂载到任意对象的数据组件，支持持久化策略与网络同步提示标签。
- **UI 框架**：与 Registry / EventBus 深度集成的栈式 UI 体系。
- **编辑器 Inspector 支持**：用于 CodecResource 与组件容器的可视化检查。

## 3. 安装

1. 将 `addons/mc_game_framework/` 拷贝到目标 Godot 项目的 `addons/` 目录。
2. 在 **项目 -> 项目设置 -> 插件** 中启用 `Minecraft-Style-Framework`。
3. 启用后会自动注册四个 Autoload：
   - `RegistryManager`
   - `EventBus`
   - `I18NManager`
   - `UIManager`

## 4. 核心模块与用法

### 4.1 ResourceLocation

`ResourceLocation` 是框架内的统一标识符。

```gdscript
var sword_id = ResourceLocation.from_string("my_mod:iron_sword")
var arrow_id = ResourceLocation.new("my_mod", "arrow")
```

### 4.2 注册表系统

通过继承 `RegistryBase` 创建自定义注册表。

```gdscript
extends RegistryBase
class_name ItemRegistry

func register_item(id: ResourceLocation, item_resource: Resource) -> void:
    register(id, item_resource)

func _get_expected_type_name() -> String:
    return "ItemInfo"

var registry = ItemRegistry.new()
var item_id = ResourceLocation.from_string("demo:sword")
registry.register_item(item_id, preload("res://demo/sword.tscn"))
var my_sword_node = registry.instantiate_item(item_id)
```

### 4.3 EventBus

事件基于抽象类 `Event`。

```gdscript
extends Event
class_name ItemUsedEvent

var user: Node
var item_id: ResourceLocation

func _init(p_user: Node, p_item_id: ResourceLocation):
    user = p_user
    item_id = p_item_id

func _ready():
    EventBus.subscribe("ItemUsedEvent", _on_item_used)

func _on_item_used(event: Event):
    var e = event as ItemUsedEvent
    if e:
        print("Item used: ", e.item_id.to_string())

func use_item(item: ResourceLocation):
    var event = ItemUsedEvent.new(self, item)
    EventBus.publish(event)

EventBus.bind_signal($MyButton.pressed, func(): return ButtonPressedEvent.new())
```

### 4.4 Tag 系统

```gdscript
var weapon_tag = Tag.new(ResourceLocation.from_string("registry:item"))

weapon_tag.add_entry(ResourceLocation.from_string("demo:sword"))
weapon_tag.add_entry(ResourceLocation.from_string("demo:bow"))

if weapon_tag.has_entry(current_item_id):
    print("这是一个武器！")
```

## 5. 栈式 UI 框架

UI 系统由 `UIManager`、`UIRegistry`、`EventBus` 与 `ResourceLocation` 构成。

### 5.1 架构概览

```text
┌───────────────────────────────────────────────────────────┐
│                    UIManager（Autoload）                  │
│                     栈式 UI 管理器                        │
├───────────────────────────────────────────────────────────┤
│  面板栈（按层级）│ 覆盖层管理 │ Toast 管理 │ 弹窗队列      │
├───────────────────────────────────────────────────────────┤
│   UIRegistry（继承 RegistryBase，通过 RegistryManager 注册）│
│   EventBus 集成   │  ResourceLocation 标识符             │
└───────────────────────────────────────────────────────────┘
```

### 5.2 文件结构

```text
addons/mc_game_framework/
├── autoload/
│   └── ui_manager.gd
├── registry/
│   └── ui_registry.gd
├── ui/
│   ├── ui_layer.gd
│   ├── ui_panel.gd
│   └── ui_toast.gd
├── event/ui/
│   ├── ui_open_event.gd
│   ├── ui_close_event.gd
│   ├── ui_pause_event.gd
│   └── ui_resume_event.gd
└── mc_game_framework.gd
```

### 5.3 UILayer

```gdscript
extends RefCounted
class_name UILayer

const SCENE  := 0
const NORMAL := 100
const POPUP  := 200
const TOAST  := 300
const SYSTEM := 400

static func get_all_layers() -> Array[int]:
    return [SCENE, NORMAL, POPUP, TOAST, SYSTEM]
```

### 5.4 UIPanel

```gdscript
extends Control
class_name UIPanel

var panel_id: ResourceLocation
var ui_layer: int = UILayer.NORMAL
var cache_mode: int = CacheMode.NONE

enum CacheMode {
    NONE,
    CACHE,
}

func _on_init() -> void: pass
func _on_open(data: Dictionary = {}) -> void: pass
func _on_pause() -> void: pass
func _on_resume() -> void: pass
func _on_close() -> void: pass
func _on_destroy() -> void: pass
```

### 5.5 UIRegistry

```gdscript
extends RegistryBase
class_name UIRegistry

func register_panel(id: ResourceLocation, scene: PackedScene,
                     default_layer: int = UILayer.NORMAL,
                     cache_mode: int = UIPanel.CacheMode.NONE) -> void:
    register(id, {"scene": scene, "default_layer": default_layer,
                   "cache_mode": cache_mode})
```

注册方式：

```gdscript
RegistryManager.register_registry("ui", UIRegistry.new())
```

### 5.6 UIManager 核心 API

```gdscript
func open_panel(id: ResourceLocation, data: Dictionary = {},
                layer_override: int = -1) -> UIPanel
func back(layer: int = UILayer.NORMAL) -> void
func close_panel(id: ResourceLocation) -> void
func close_all(layer: int = -1) -> void
func get_top_panel(layer: int = UILayer.NORMAL) -> UIPanel
func is_panel_open(id: ResourceLocation) -> bool

func add_overlay(id: ResourceLocation, overlay: Control,
                 layer: int = UILayer.SCENE) -> void
func remove_overlay(id: ResourceLocation) -> void
func get_overlay(id: ResourceLocation) -> Control
func set_overlay_visible(id: ResourceLocation, visible: bool) -> void

func show_toast(toast_id: ResourceLocation, data: Dictionary = {},
                duration: float = 3.0) -> UIToast
func dismiss_toast(toast: UIToast) -> void
func dismiss_all_toasts() -> void

func queue_popup(panel_id: ResourceLocation, data: Dictionary = {},
                 priority: int = 0) -> void
```

### 5.7 安全与性能说明

- 同面板重复打开会被拦截。
- 递归打开保护使用 `MAX_OPEN_DEPTH := 8`。
- `_active_panel_ids` 提供 O(1) 活跃面板查询。
- 缓存面板使用 `MAX_CACHED_PANELS := 10` 与 LRU 淘汰策略。

### 5.8 使用示例

```gdscript
var ui_reg: UIRegistry = RegistryManager.get_registry("ui")

ui_reg.register_panel(
    ResourceLocation.from_string("game:inventory"),
    preload("res://scenes/ui/inventory.tscn"),
    UILayer.NORMAL, UIPanel.CacheMode.CACHE
)

UIManager.open_panel(
    ResourceLocation.from_string("game:inventory"),
    {"selected_tab": "weapons"}
)

UIManager.queue_popup(ResourceLocation.from_string("game:daily_reward"), {}, 10)
UIManager.show_toast(ResourceLocation.from_string("game:item_toast"),
                     {"item": "Iron Sword", "count": 1}, 3.0)
```

## 6. Codec 系统

### 6.1 架构

| 层级 | 职责 | 核心类 |
|------|------|--------|
| **结果层** | 承载解码结果、诊断与部分成功状态 | `DataResult` |
| **声明层** | 描述编码与解码规则 | `Codec`, `MapCodec` |
| **载体层** | 适配不同存储格式 | `DynamicOps`, `JsonOps`, `GodotResourceOps` |

### 6.2 DataResult

```gdscript
var result = codec.decode(data, JsonOps.INSTANCE)
if result.is_success():
    var value = result.get_value()
elif result.is_partial():
    var partial = result.get_value()
    for d in result.get_diagnostics():
        print(d)
else:
    print("错误: ", result.get_error())
```

### 6.3 Codec 组合器

```gdscript
Codec.BOOL()
Codec.INT()
Codec.FLOAT()
Codec.STRING()
Codec.RESOURCE_LOCATION()

Codec.INT().list_of()
Codec.map_of(Codec.STRING(), Codec.INT())

var item_codec = Codec.record(
    MapCodec.build(
        [
            Codec.STRING().field_of("name").for_getter(func(item): return item.name),
            Codec.INT().field_of("damage").for_getter(func(item): return item.damage),
            Codec.FLOAT().optional_field_of("weight", 1.0).for_getter(func(item): return item.weight),
        ],
        func(name, damage, weight):
            return ItemData.new(name, damage, weight)
    )
)

codec.xmap(decode_fn, encode_fn)
codec.flat_xmap(decode_fn, encode_fn)
Codec.either(Codec.INT(), Codec.STRING())
Codec.dispatch("type", Codec.STRING(), func(type_name): return get_codec_for(type_name))
```

### 6.4 DynamicOps

```gdscript
var codec = item_codec()
var json_result = codec.encode(item, JsonOps.INSTANCE)
var res_result = codec.encode(item, GodotResourceOps.INSTANCE)
```

### 6.5 CodecResource

```gdscript
extends CodecResource
class_name MyItemResource

@export var item_name: String = ""
@export var damage: int = 0

static func get_type_id() -> String:
    return "mymod:item"

static func get_codec() -> Codec:
    return Codec.record(MapCodec.build([
        Codec.STRING().field_of("item_name").for_getter(func(r): return r.item_name),
        Codec.INT().field_of("damage").for_getter(func(r): return r.damage),
    ], func(name, dmg): return MyItemResource.new()))
```

## 7. Data Component 系统

Data Component 可挂载到任意 `Node`、`Resource` 或 `RefCounted` 对象。

### 7.1 定义组件类型

```gdscript
var HEALTH = ComponentType.Builder.new(
    ResourceLocation.new("game", "health"),
    Codec.INT()
).with_default(func(): return 20).persistent(
    ComponentType.PersistentPolicy.ALWAYS
).build()
```

### 7.2 通过 RegistryManager 注册组件类型

Data Component 类型必须接入现有注册表体系，其注册表是普通 `RegistryBase` 子类，而不是 Autoload。

```gdscript
if not RegistryManager.has_registry(ComponentTypeRegistry.REGISTRY_KEY):
    RegistryManager.register_registry(
        ComponentTypeRegistry.REGISTRY_KEY,
        ComponentTypeRegistry.new()
    )

var component_reg: ComponentTypeRegistry = RegistryManager.get_registry(
    ComponentTypeRegistry.REGISTRY_KEY
)
component_reg.register_component_type(HEALTH)
```

### 7.3 挂载组件到对象

```gdscript
ComponentHost.set_component(node, HEALTH, 15)
var hp = ComponentHost.get_component(node, HEALTH)

ComponentHost.set_component(resource, HEALTH, 100)

var container = ComponentHost.get_container(node)
var json = container.encode(JsonOps.INSTANCE)
```

### 7.4 通过注册表体系解码

```gdscript
var decoded_container := ComponentContainer.new()
var result = decoded_container.decode(json.get_value(), JsonOps.INSTANCE)

var result2 = decoded_container.decode(
    json.get_value(),
    JsonOps.INSTANCE,
    component_reg
)
```

若未显式传入注册表，`ComponentContainer.decode()` 会默认从 `RegistryManager` 查找 `"component_type"` 注册表。

### 7.5 持久化策略

- `NONE`
- `ALWAYS`
- `NON_DEFAULT`

### 7.6 网络同步标签

- `NONE`
- `FULL`
- `TRACKED`

这些只是元数据提示，并不是内置的自动同步系统。

## 8. ResourceLocation 校验规则

- **namespace**：小写 `a-z`、数字 `0-9`、`_`、`-`、`.`
- **path**：小写 `a-z`、数字 `0-9`、`_`、`-`、`.`、`/`

```gdscript
var result = ResourceLocation.parse("minecraft:items/diamond_sword")
var bad = ResourceLocation.parse("Minecraft:ITEMS")
ResourceLocation.is_valid("demo:block.stone")
```

## 9. 使用须知

- 当前插件只注册 4 个 Autoload：`RegistryManager`、`EventBus`、`I18NManager`、`UIManager`。
- Data Component 类型注册必须走 `RegistryManager`，不得额外引入新的 Autoload。
- 当前 Codec 层聚焦 `JsonOps` 与 `GodotResourceOps` 两类声明式编解码载体。
- `demo/` 下的示例仍是本仓库最直接的使用参考。

## 10. 反馈

项目仍在持续演进，欢迎提交 Issue、反馈与 Pull Request。
