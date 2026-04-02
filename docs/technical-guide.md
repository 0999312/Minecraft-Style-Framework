# Minecraft-Style-Framework Technical Guide

This is the primary technical documentation for the project. It contains API-oriented introductions, architecture notes, usage examples, and implementation constraints.

For the Chinese edition, see [`technical-guide.zh-CN.md`](./technical-guide.zh-CN.md).

## 1. Introduction

**Minecraft-Style-Framework** is a Godot game feature framework inspired by the underlying architectural design of Minecraft, especially data-driven patterns and decoupled systems. It is suitable for games with many items, event-driven interactions, and strong extensibility requirements.

## 2. Features

- **ResourceLocation**: Namespace-based identifiers like `namespace:path`, with Mojang-style validation rules.
- **Registry & RegistryManager**: Structured registries for centralized game data management.
- **EventBus**: Decoupled global event dispatching with cancellation and Godot `Signal` bridging.
- **Tag System**: Dynamic grouping of registry entries without modifying their implementation.
- **I18n**: JSON-based localization support.
- **Codec System**: DFU-style declarative codecs for JSON and Godot Resource formats.
- **Data Component System**: Minecraft-style attachable data components with persistence policies and optional network-sync hints.
- **UI Framework**: Stack-based UI framework integrated with the registry and event systems.
- **Editor Inspector Support**: Inspector extensions for CodecResource and component visualization.

## 3. Installation

1. Copy `addons/mc_game_framework/` into your Godot project's `addons/` directory.
2. Enable `Minecraft-Style-Framework` in **Project -> Project Settings -> Plugins**.
3. After enabling the plugin, Godot registers four Autoload singletons:
   - `RegistryManager`
   - `EventBus`
   - `I18NManager`
   - `UIManager`

## 4. Core Modules & Usage

### 4.1 ResourceLocation

`ResourceLocation` is the core identifier in the framework. It formats IDs as `namespace:path`.

```gdscript
var sword_id = ResourceLocation.from_string("my_mod:iron_sword")
var arrow_id = ResourceLocation.new("my_mod", "arrow")
```

### 4.2 Registry System

Extend `RegistryBase` to manage a specific kind of data.

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

Events derive from the abstract `Event` class.

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

### 4.4 Tag System

```gdscript
var weapon_tag = Tag.new(ResourceLocation.from_string("registry:item"))

weapon_tag.add_entry(ResourceLocation.from_string("demo:sword"))
weapon_tag.add_entry(ResourceLocation.from_string("demo:bow"))

if weapon_tag.has_entry(current_item_id):
    print("This is a weapon!")
```

## 5. Stack-based UI Framework

The UI system integrates `UIManager`, `UIRegistry`, `EventBus`, and `ResourceLocation`.

### 5.1 Architecture Overview

```text
┌───────────────────────────────────────────────────────────┐
│                     UIManager (Autoload)                  │
│               Stack-based UI Manager Singleton            │
├───────────────────────────────────────────────────────────┤
│  Panel Stacks  │ Overlay Manager │ Toast Manager │ Popup  │
│  (per-layer)   │ (persistent UI) │ (auto-dismiss)│ Queue  │
├───────────────────────────────────────────────────────────┤
│  UIRegistry (extends RegistryBase, via RegistryManager)   │
│  EventBus integration  │  ResourceLocation identifiers    │
└───────────────────────────────────────────────────────────┘
```

### 5.2 File Structure

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

Register it through:

```gdscript
RegistryManager.register_registry("ui", UIRegistry.new())
```

### 5.6 UIManager Core API

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

### 5.7 Safety and Performance Notes

- Same-panel guard prevents duplicate opens.
- Recursive open protection uses `MAX_OPEN_DEPTH := 8`.
- `_active_panel_ids` provides O(1) active-panel lookup.
- Cached panels are limited by `MAX_CACHED_PANELS := 10` with LRU eviction.

### 5.8 Usage Example

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

## 6. Codec System

### 6.1 Architecture

| Layer | Responsibility | Key Classes |
|-------|---------------|-------------|
| **Result Layer** | Decoded values, diagnostics, partial-success state | `DataResult` |
| **Declaration Layer** | Encoding and decoding declarations | `Codec`, `MapCodec` |
| **Carrier Layer** | Storage-format adaptation | `DynamicOps`, `JsonOps`, `GodotResourceOps` |

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
    print("Error: ", result.get_error())
```

### 6.3 Codec Combinators

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

## 7. Data Component System

Data Components can be attached to any `Node`, `Resource`, or `RefCounted` object.

### 7.1 Define Component Types

```gdscript
var HEALTH = ComponentType.Builder.new(
    ResourceLocation.new("game", "health"),
    Codec.INT()
).with_default(func(): return 20).persistent(
    ComponentType.PersistentPolicy.ALWAYS
).build()
```

### 7.2 Register Component Types via RegistryManager

Data Component types use the existing registry system. Their registry is a normal `RegistryBase` subclass, not an Autoload.

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

### 7.3 Attach Components to Objects

```gdscript
ComponentHost.set_component(node, HEALTH, 15)
var hp = ComponentHost.get_component(node, HEALTH)

ComponentHost.set_component(resource, HEALTH, 100)

var container = ComponentHost.get_container(node)
var json = container.encode(JsonOps.INSTANCE)
```

### 7.4 Decode Through the Registry System

```gdscript
var decoded_container := ComponentContainer.new()
var result = decoded_container.decode(json.get_value(), JsonOps.INSTANCE)

var result2 = decoded_container.decode(
    json.get_value(),
    JsonOps.INSTANCE,
    component_reg
)
```

When no explicit registry is provided, `ComponentContainer.decode()` looks up the `"component_type"` registry from `RegistryManager`.

### 7.5 Persistence Policies

- `NONE`
- `ALWAYS`
- `NON_DEFAULT`

### 7.6 Network Sync Tags

- `NONE`
- `FULL`
- `TRACKED`

These are metadata hints only. They are not a built-in automatic replication system.

## 8. ResourceLocation Validation Rules

- **Namespace**: lowercase `a-z`, digits `0-9`, `_`, `-`, `.`
- **Path**: lowercase `a-z`, digits `0-9`, `_`, `-`, `.`, `/`

```gdscript
var result = ResourceLocation.parse("minecraft:items/diamond_sword")
var bad = ResourceLocation.parse("Minecraft:ITEMS")
ResourceLocation.is_valid("demo:block.stone")
```

## 9. Usage Notes

- The plugin currently adds exactly four Autoloads: `RegistryManager`, `EventBus`, `I18NManager`, and `UIManager`.
- Data Component type registration must integrate through `RegistryManager` and must not introduce a new Autoload.
- The Codec layer currently focuses on declarative codecs over `JsonOps` and `GodotResourceOps`.
- Demo scenes under `demo/` are the main usage reference in this repository.

## 10. Feedback

The project is still evolving. Issues, feedback, and pull requests are welcome.
