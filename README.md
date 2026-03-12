# Minecraft-Style-Framework

[中文文档在下方 (Scroll down for Chinese version)](#minecraft-style-framework-中文文档)

## 1. Introduction
**Minecraft-Style-Framework** is a Godot game feature framework inspired by the underlying architectural design of Minecraft (such as data-driven patterns and decoupled systems). It is highly suitable for developing games that require a massive amount of items, event-driven interactions, and extreme extensibility (e.g., Sandbox games, RPGs).

## 2. Features
* **ResourceLocation**: Namespace-based identifiers, working exactly like Minecraft's ID system (e.g., `namespace:path`).
* **Registry & RegistryManager**: A structured registry system designed for centralized management of game data and resources.
* **EventBus**: A decoupled global event dispatching center. It supports event cancellation and can seamlessly bridge with Godot's native `Signal`.
* **Tag System**: Easily group and classify game elements using tags (e.g., grouping all items that are "flammable") without modifying their internal code.
* **I18n (Localization)**: A simple localization system that reads `.json` files to avoid hard-coded text.

## 3. Installation
1. **Get the Plugin**: Copy the entire `addons/mc_game_framework/` directory from this repository into your Godot project's `addons/` directory.
2. **Enable the Plugin**: Open the Godot Editor, go to **Project** -> **Project Settings** -> **Plugins**, and check the enable box for `Minecraft-Style-Framework`.
3. **Autoloads**: Once enabled, the plugin automatically registers three core singletons (Autoloads) into your project:
   * `RegistryManager`
   * `EventBus`
   * `I18NManager`

## 4. Core Modules & Usage

### 4.1 ResourceLocation
`ResourceLocation` (RL) is the core identifier in this framework. It formats IDs like `namespace:path` (e.g., `minecraft:stone`). All resources, events, and registry entries should use it for unique identification.

```gdscript
# Create an identifier from a string
var sword_id = ResourceLocation.from_string("my_mod:iron_sword")

# Or create it with namespace and path explicitly
var arrow_id = ResourceLocation.new("my_mod", "arrow")
```

### 4.2 Registry System
Used for centralizing and managing a specific type of object. You can create a custom registry by extending `RegistryBase`. 

```gdscript
# 1. Define a registry
extends RegistryBase
class_name ItemRegistry

func register_item(id: ResourceLocation, item_resource: Resource) -> void:
    register(id, item_resource)

# Override this method to limit the data type this registry accepts
func _get_expected_type_name() -> String:
    return "ItemInfo"

# 2. Use the registry
var registry = ItemRegistry.new()
var item_id = ResourceLocation.from_string("demo:sword")

# Register an item
registry.register_item(item_id, preload("res://demo/sword.tscn"))

# Fetch and instantiate
var my_sword_node = registry.instantiate_item(item_id)
```

### 4.3 EventBus
A decoupled global event dispatcher. Events are triggered based on the abstract `Event` class.

```gdscript
# 1. Create a custom event
extends Event
class_name ItemUsedEvent

var user: Node
var item_id: ResourceLocation

func _init(p_user: Node, p_item_id: ResourceLocation):
    user = p_user
    item_id = p_item_id

# 2. Subscribe and publish
# Subscribe to the event (e.g., in a Player controller)
func _ready():
    EventBus.subscribe("ItemUsedEvent", _on_item_used)

func _on_item_used(event: Event):
    var e = event as ItemUsedEvent
    if e:
        print("Item used: ", e.item_id.to_string())
        # You can cancel the event to prevent further listeners from handling it
        # e.cancel()

# Publish the event (e.g., in an Inventory script)
func use_item(item: ResourceLocation):
    var event = ItemUsedEvent.new(self, item)
    EventBus.publish(event)

# 3. Bind with Godot Signals
# bind_signal(target_signal, event_factory_callable)
EventBus.bind_signal($MyButton.pressed, func(): return ButtonPressedEvent.new())
```

### 4.4 Tag System
Allows you to classify multiple registry entries dynamically.
```gdscript
var weapon_tag = Tag.new(ResourceLocation.from_string("registry:item"))

weapon_tag.add_entry(ResourceLocation.from_string("demo:sword"))
weapon_tag.add_entry(ResourceLocation.from_string("demo:bow"))

if weapon_tag.has_entry(current_item_id):
    print("This is a weapon!")
```

## 5. Important Notice
Since this plugin is a brand-new project and the demo game is still under development, please feel free to submit feedback if you encounter any issues while using it. Pull Requests are highly welcome!

---

# Minecraft-Style-Framework (中文文档)

## 1. 简介
这是一个旨在将 Minecraft 优秀的底层设计理念（如数据驱动、解耦体系）引入 Godot 引擎的游戏功能框架。适合用来开发拥有大量物品、事件驱动及需要极强扩展性的游戏（例如沙盒、RPG等）。

## 2. 功能列表
* **ResourceLocation**：基于命名空间和路径的同名标识符（类似 `minecraft:stone`）。
* **基于 ResourceLocation 的注册表与总注册表**：用于集中管理游戏内的数据与资源。
* **事件总线 (EventBus)**：解耦的事件广播与监听系统，支持阻止事件传递，并支持与 Godot 原生 `Signal` 无缝联动。
* **标签系统 (Tag)**：用于为游戏元素打标签，方便进行分类检索（例如：所有“可燃物”物品），无需修改物品本身的数据。
* **I18n 系统**：读取外部 JSON 文件的本地化系统，避免硬编码游戏文本。

## 3. 安装与配置
1. **获取插件**：将本项目 `addons/mc_game_framework/` 目录完整拷贝到你的 Godot 项目的 `addons/` 目录下。
2. **启用插件**：在 Godot 编辑器顶部菜单栏打开 **项目 (Project)** -> **项目设置 (Project Settings)** -> **插件 (Plugins)**，勾选并启用 `Minecraft-Style-Framework`。
3. **Autoload 确认**：启用插件后，系统会自动注册三个核心单例：
   * `RegistryManager`
   * `EventBus`
   * `I18NManager`

## 4. 核心功能与用法示例

### 4.1 标识符 ResourceLocation
所有的资源、事件、注册表项都应使用 `ResourceLocation` 进行唯一标记：
```gdscript
# 创建一个标识符
var sword_id = ResourceLocation.from_string("my_mod:iron_sword")

# 或者单独传入 namespace 和 path
var arrow_id = ResourceLocation.new("my_mod", "arrow")
```

### 4.2 注册表系统
通过继承 `RegistryBase` 创建自定义注册表进行数据管理：
```gdscript
# 1. 定义注册表
extends RegistryBase
class_name ItemRegistry

func register_item(id: ResourceLocation, item_resource: Resource) -> void:
    register(id, item_resource)

# 覆写此方法限定该注册表接受的数据类型
func _get_expected_type_name() -> String:
    return "ItemInfo"

# 2. 使用注册表
var registry = ItemRegistry.new()
var item_id = ResourceLocation.from_string("demo:sword")

# 注册物品
registry.register_item(item_id, preload("res://demo/sword.tscn"))

# 获取与实例化
var my_sword_node = registry.instantiate_item(item_id)
```

### 4.3 事件总线 (EventBus)
全局解耦的事件派发中心。

```gdscript
# 1. 创建自定义事件
extends Event
class_name ItemUsedEvent

var user: Node
var item_id: ResourceLocation

func _init(p_user: Node, p_item_id: ResourceLocation):
    user = p_user
    item_id = p_item_id

# 2. 订阅与发布事件
func _ready():
    EventBus.subscribe("ItemUsedEvent", _on_item_used)

func _on_item_used(event: Event):
    var e = event as ItemUsedEvent
    if e:
        print("Item used: ", e.item_id.to_string())
        # 可以取消事件，阻止后续监听器处理
        # e.cancel()

func use_item(item: ResourceLocation):
    var event = ItemUsedEvent.new(self, item)
    EventBus.publish(event)

# 3. 与原生 Godot 信号绑定
EventBus.bind_signal($MyButton.pressed, func(): return ButtonPressedEvent.new())
```

### 4.4 标签系统 (Tag)
允许动态给多个注册表项分类：
```gdscript
var weapon_tag = Tag.new(ResourceLocation.from_string("registry:item"))

weapon_tag.add_entry(ResourceLocation.from_string("demo:sword"))
weapon_tag.add_entry(ResourceLocation.from_string("demo:bow"))

if weapon_tag.has_entry(current_item_id):
    print("这是一个武器！")
```

## 5. 注意事项
由于本插件是全新的项目、示例游戏仍在开发当中，所以在插件使用期间遇到任何问题请及时提交反馈，欢迎提供 Pull Request。
