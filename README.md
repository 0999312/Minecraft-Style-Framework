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

## 5. Stack-based UI Framework (Design Plan)

A miHoYo-style stack-based UI management system, integrated with Registry, EventBus, and ResourceLocation.

### 5.1 Architecture Overview

```
┌───────────────────────────────────────────────────────────┐
│                     UIManager (Autoload)                   │
│               Stack-based UI Manager Singleton             │
├───────────────────────────────────────────────────────────┤
│  Panel Stacks  │ Overlay Manager │ Toast Manager │ Popup  │
│  (per-layer)   │ (persistent UI) │ (auto-dismiss)│ Queue  │
├───────────────────────────────────────────────────────────┤
│  UIRegistry (extends RegistryBase, via RegistryManager)   │
│  EventBus integration  │  ResourceLocation identifiers    │
└───────────────────────────────────────────────────────────┘
```

The UI system manages four categories of UI elements:

| Category | Model | Example |
|----------|-------|---------|
| **Panel** | Per-layer stack (push/pop) | Inventory, Shop, Settings |
| **Overlay** | Persistent (add/remove) | HUD, Minimap, Watermark |
| **Toast** | List with auto-dismiss | "Item obtained!", Achievement |
| **Popup Queue** | FIFO queue, one at a time | Confirm dialogs, Rewards |

### 5.2 File Structure

```
addons/mc_game_framework/
├── autoload/
│   └── ui_manager.gd          # Stack-based UI manager (Autoload)
├── registry/
│   └── ui_registry.gd         # UI panel registry (extends RegistryBase)
├── ui/
│   ├── ui_layer.gd            # Layer constants
│   ├── ui_panel.gd            # Panel base class (stack-managed)
│   └── ui_toast.gd            # Toast base class (auto-dismiss)
├── event/ui/
│   ├── ui_open_event.gd       # Panel opened
│   ├── ui_close_event.gd      # Panel closed
│   ├── ui_pause_event.gd      # Panel paused (covered by new panel)
│   └── ui_resume_event.gd     # Panel resumed (uncovered)
└── mc_game_framework.gd       # Modified: register UIManager autoload
```

### 5.3 UILayer — Layer Constants

```gdscript
# ui/ui_layer.gd
extends RefCounted
class_name UILayer

const SCENE  := 0      # In-world UI (damage numbers, nameplates)
const NORMAL := 100    # Full-screen panels (inventory, map, shop)
const POPUP  := 200    # Modal dialogs (confirm, alert)
const TOAST  := 300    # Notifications (auto-dismiss)
const SYSTEM := 400    # System-level (loading screen, disconnect)

static func get_all_layers() -> Array[int]:
    return [SCENE, NORMAL, POPUP, TOAST, SYSTEM]
```

Integer constants allow users to define custom layers between built-in ones (e.g., `150` for sub-menus).

### 5.4 UIPanel — Panel Base Class

```gdscript
# ui/ui_panel.gd
extends Control
class_name UIPanel

var panel_id: ResourceLocation
var ui_layer: int = UILayer.NORMAL
var cache_mode: int = CacheMode.NONE

enum CacheMode {
    NONE,    # Destroyed on close
    CACHE,   # Hidden on close, reused on next open
}

# ---- Lifecycle callbacks (override in subclasses) ----
func _on_init() -> void: pass         # First creation only
func _on_open(data: Dictionary = {}) -> void: pass  # Each open
func _on_pause() -> void: pass        # Covered by new panel
func _on_resume() -> void: pass       # Uncovered (top panel closed)
func _on_close() -> void: pass        # Removed from stack
func _on_destroy() -> void: pass      # Before queue_free (NONE mode)
```

**Lifecycle flow:**
```
instantiate → _on_init → _on_open(data)
    ↓ (new panel pushed)       ↑ (top panel popped)
_on_pause ←──────────────→ _on_resume
    ↓ (panel closed)
_on_close → [CACHE: hide] or [NONE: _on_destroy → queue_free]
```

### 5.5 UIRegistry — Panel Registration

```gdscript
# registry/ui_registry.gd
extends RegistryBase
class_name UIRegistry

func register_panel(id: ResourceLocation, scene: PackedScene,
                     default_layer: int = UILayer.NORMAL,
                     cache_mode: int = UIPanel.CacheMode.NONE) -> void:
    register(id, {"scene": scene, "default_layer": default_layer,
                   "cache_mode": cache_mode})

func instantiate_panel(id: ResourceLocation) -> UIPanel:
    var info = get_entry(id)
    # ... validates scene root extends UIPanel, sets panel_id/layer/cache_mode
```

Registered via `RegistryManager.register_registry("ui", UIRegistry.new())`.

### 5.6 UIManager — Core Manager

#### Panel Stack Operations
```gdscript
# Core API
func open_panel(id: ResourceLocation, data: Dictionary = {},
                layer_override: int = -1) -> UIPanel
func back(layer: int = UILayer.NORMAL) -> void      # Pop top
func close_panel(id: ResourceLocation) -> void       # Close specific
func close_all(layer: int = -1) -> void              # Close all
func get_top_panel(layer: int = UILayer.NORMAL) -> UIPanel
func is_panel_open(id: ResourceLocation) -> bool
```

#### Overlay Management (Persistent UI)
```gdscript
func add_overlay(id: ResourceLocation, overlay: Control,
                  layer: int = UILayer.SCENE) -> void
func remove_overlay(id: ResourceLocation) -> void
func get_overlay(id: ResourceLocation) -> Control
func set_overlay_visible(id: ResourceLocation, visible: bool) -> void
```

Overlays are **not** stack-managed. They persist until explicitly removed. Use for HUD, minimap, debug info, etc.

#### Toast System (Auto-dismiss Notifications)
```gdscript
func show_toast(toast_id: ResourceLocation, data: Dictionary = {},
                duration: float = 3.0) -> UIToast
func dismiss_toast(toast: UIToast) -> void
func dismiss_all_toasts() -> void
```

Toasts are **not** stack-managed. Multiple can be visible simultaneously. Each auto-dismisses after its `duration` expires. Use for achievement popups, item notifications, etc.

#### Popup Queue (Sequential Modal Dialogs)
```gdscript
func queue_popup(panel_id: ResourceLocation, data: Dictionary = {},
                  priority: int = 0) -> void
```

When multiple popups are requested simultaneously (e.g., network error + daily reward + item full), they are **queued** instead of all stacking at once. The queue processes one popup at a time — when the current popup closes, the next one in the queue is shown automatically. Higher priority values are shown first.

### 5.7 Circular Navigation Protection

To prevent A↔B infinite loop scenarios (e.g., panel A's `_on_resume()` opens panel B, which closes and triggers A's `_on_resume()` again):

```gdscript
const MAX_OPEN_DEPTH := 8
var _open_depth: int = 0

func open_panel(...) -> UIPanel:
    _open_depth += 1
    if _open_depth > MAX_OPEN_DEPTH:
        push_error("UIManager: recursive open_panel depth exceeded %d, "
                   + "possible circular navigation detected" % MAX_OPEN_DEPTH)
        _open_depth -= 1
        return null
    # ... normal logic ...
    _open_depth -= 1
    return panel

func _process(_delta: float) -> void:
    _open_depth = 0  # Reset each frame as secondary safeguard
```

**Protection mechanisms:**
1. **Same-panel guard**: `open_panel` rejects panels already in any stack.
2. **Recursion depth limit**: Catches indirect cycles (A→B→C→A) within a single frame.
3. **Per-frame reset**: `_open_depth` resets every frame, so legitimate cross-frame sequential opens are never blocked.

### 5.8 Background Dimmer (Auto-managed Overlay)

When a NORMAL or POPUP panel opens, UIManager can automatically show a semi-transparent dark overlay behind the panel to visually separate it from the scene:

```gdscript
# Automatically managed by UIManager
func _show_background_dimmer(layer: int) -> void:
    # Show a semi-transparent ColorRect behind the panel
    
func _hide_background_dimmer(layer: int) -> void:
    # Hide when the stack for that layer becomes empty
```

### 5.9 Performance Optimizations

| Issue | Solution |
|-------|----------|
| `is_panel_open()` scans all stacks O(N×M) | Maintain `_active_panel_ids: Dictionary` hash set for O(1) lookup |
| `close_panel(id)` searches all layers | Use `_active_panel_ids` to map panel ID → layer for direct access |
| Cached panels leak memory if never reopened | `MAX_CACHED_PANELS` limit with LRU eviction policy |
| High-frequency Toast events cause EventBus overhead | Toasts skip EventBus publishing by default; opt-in via flag |

**Active panel index:**
```gdscript
var _active_panel_ids: Dictionary = {}  # String(panel_id) → int(layer)

func _is_panel_in_any_stack(id_str: String) -> bool:
    return _active_panel_ids.has(id_str)  # O(1) instead of O(N×M)
```

**Cache eviction:**
```gdscript
const MAX_CACHED_PANELS := 10
var _cache_order: Array[String] = []  # LRU order tracking

func _do_close_panel(panel: UIPanel) -> void:
    match panel.cache_mode:
        UIPanel.CacheMode.CACHE:
            if _cached_panels.size() >= MAX_CACHED_PANELS:
                var oldest = _cache_order.pop_front()
                _cached_panels[oldest]._on_destroy()
                _cached_panels[oldest].queue_free()
                _cached_panels.erase(oldest)
            _cache_order.append(panel.panel_id.to_string())
            _cached_panels[panel.panel_id.to_string()] = panel
```

### 5.10 Usage Example

```gdscript
# ---- Registration (game initialization) ----
var ui_reg: UIRegistry = RegistryManager.get_registry("ui")

ui_reg.register_panel(
    ResourceLocation.from_string("game:inventory"),
    preload("res://scenes/ui/inventory.tscn"),
    UILayer.NORMAL, UIPanel.CacheMode.CACHE
)

ui_reg.register_panel(
    ResourceLocation.from_string("game:confirm_dialog"),
    preload("res://scenes/ui/confirm_dialog.tscn"),
    UILayer.POPUP
)

# ---- Runtime usage ----
# Open a panel
UIManager.open_panel(
    ResourceLocation.from_string("game:inventory"),
    {"selected_tab": "weapons"}
)

# Queue multiple popups (shown one at a time)
UIManager.queue_popup(ResourceLocation.from_string("game:daily_reward"), {}, 10)
UIManager.queue_popup(ResourceLocation.from_string("game:network_error"), {}, 99)

# Show a toast (auto-dismisses)
UIManager.show_toast(ResourceLocation.from_string("game:item_toast"),
                     {"item": "Iron Sword", "count": 1}, 3.0)

# Add persistent HUD overlay
UIManager.add_overlay(ResourceLocation.from_string("game:hud"),
                       preload("res://scenes/ui/hud.tscn").instantiate())

# Back button behavior
UIManager.back()  # Pops top panel from NORMAL stack
```

### 5.11 Stack Behavior Example

```
Action                          Stack [bottom→top]      Visible
─────────────────────────────────────────────────────────────────
open(main_menu)                [main_menu]              main_menu ✅
open(inventory)                [main_menu, inventory]   inventory ✅ (main_menu paused)
open(shop)                     [main_menu, inv, shop]   shop ✅ (inventory paused)
back()                         [main_menu, inventory]   inventory ✅ (resumed)
queue_popup(confirm)           POPUP:[confirm]          confirm ✅ (dimmer shown)
queue_popup(reward)            queue:[reward]            confirm still shown
back(POPUP)                    POPUP:[]                 reward auto-shown from queue
show_toast(achievement)        toasts:[achievement]     achievement (auto-dismiss 3s)
back()                         [main_menu]              main_menu ✅ (resumed)
```

## 6. Important Notice
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

## 5. 栈式UI框架（设计方案）

一套类似 miHoYo 的栈式UI管理系统，与 Registry、EventBus、ResourceLocation 体系深度集成。

### 5.1 架构概览

```
┌───────────────────────────────────────────────────────────┐
│                    UIManager（Autoload 单例）               │
│                   栈式 UI 管理器                            │
├───────────────────────────────────────────────────────────┤
│  面板栈（按层级）│ 覆盖层管理器 │ Toast 管理器 │ 弹窗队列  │
├───────────────────────────────────────────────────────────┤
│  UIRegistry（继承 RegistryBase，通过 RegistryManager 注册）│
│  EventBus 集成   │  ResourceLocation 标识符                │
└───────────────────────────────────────────────────────────┘
```

UI 系统管理四类 UI 元素：

| 类别 | 模型 | 示例 |
|------|------|------|
| **面板 (Panel)** | 分层栈式（Push/Pop） | 背包、商店、设置 |
| **覆盖层 (Overlay)** | 持久显示（Add/Remove） | HUD、小地图、水印 |
| **Toast 提示** | 列表式、自动消失 | "获得物品×3"、成就解锁 |
| **弹窗队列 (Popup Queue)** | FIFO 队列、逐个弹出 | 确认框、奖励领取 |

### 5.2 文件结构

```
addons/mc_game_framework/
├── autoload/
│   └── ui_manager.gd          # 栈式UI管理器（Autoload）
├── registry/
│   └── ui_registry.gd         # UI注册表（继承 RegistryBase）
├── ui/
│   ├── ui_layer.gd            # 层级常量定义
│   ├── ui_panel.gd            # 面板基类（栈管理）
│   └── ui_toast.gd            # Toast基类（自动消失）
├── event/ui/
│   ├── ui_open_event.gd       # 面板打开事件
│   ├── ui_close_event.gd      # 面板关闭事件
│   ├── ui_pause_event.gd      # 面板暂停事件
│   └── ui_resume_event.gd     # 面板恢复事件
└── mc_game_framework.gd       # 需修改：注册 UIManager autoload
```

### 5.3 UILayer — 层级常量

```gdscript
# ui/ui_layer.gd
extends RefCounted
class_name UILayer

const SCENE  := 0      # 场景内UI（伤害数字、名字牌）
const NORMAL := 100    # 普通全屏面板（背包、地图、商店）
const POPUP  := 200    # 弹窗（确认框、提示框）
const TOAST  := 300    # 通知提示（自动消失）
const SYSTEM := 400    # 系统级（Loading画面、断网提示）

static func get_all_layers() -> Array[int]:
    return [SCENE, NORMAL, POPUP, TOAST, SYSTEM]
```

使用整数常量（非 Enum），便于用户在内置层级之间自定义扩展（如 `150` 用于子菜单）。

### 5.4 UIPanel — 面板基类

```gdscript
# ui/ui_panel.gd
extends Control
class_name UIPanel

var panel_id: ResourceLocation
var ui_layer: int = UILayer.NORMAL
var cache_mode: int = CacheMode.NONE

enum CacheMode {
    NONE,    # 关闭时销毁
    CACHE,   # 关闭时隐藏，下次打开时复用
}

# ---- 生命周期回调（子类覆写） ----
func _on_init() -> void: pass         # 首次创建（仅一次）
func _on_open(data: Dictionary = {}) -> void: pass  # 每次打开
func _on_pause() -> void: pass        # 被新面板覆盖
func _on_resume() -> void: pass       # 上方面板关闭后恢复
func _on_close() -> void: pass        # 从栈中移除
func _on_destroy() -> void: pass      # 销毁前（NONE 模式）
```

**生命周期流程：**
```
实例化 → _on_init → _on_open(data)
    ↓ (新面板 Push)              ↑ (栈顶面板 Pop)
_on_pause ←──────────────→ _on_resume
    ↓ (面板关闭)
_on_close → [CACHE: 隐藏] 或 [NONE: _on_destroy → queue_free]
```

### 5.5 UIRegistry — 面板注册表

```gdscript
# registry/ui_registry.gd
extends RegistryBase
class_name UIRegistry

func register_panel(id: ResourceLocation, scene: PackedScene,
                     default_layer: int = UILayer.NORMAL,
                     cache_mode: int = UIPanel.CacheMode.NONE) -> void:
    register(id, {"scene": scene, "default_layer": default_layer,
                   "cache_mode": cache_mode})

func instantiate_panel(id: ResourceLocation) -> UIPanel:
    var info = get_entry(id)
    # ... 校验场景根节点必须继承 UIPanel，设置 panel_id/layer/cache_mode
```

通过 `RegistryManager.register_registry("ui", UIRegistry.new())` 注册到元注册表。

### 5.6 UIManager — 核心管理器

#### 面板栈操作
```gdscript
func open_panel(id: ResourceLocation, data: Dictionary = {},
                layer_override: int = -1) -> UIPanel
func back(layer: int = UILayer.NORMAL) -> void      # 弹出栈顶
func close_panel(id: ResourceLocation) -> void       # 关闭指定面板
func close_all(layer: int = -1) -> void              # 关闭全部
func get_top_panel(layer: int = UILayer.NORMAL) -> UIPanel
func is_panel_open(id: ResourceLocation) -> bool
```

#### 覆盖层管理（持久UI）
```gdscript
func add_overlay(id: ResourceLocation, overlay: Control,
                  layer: int = UILayer.SCENE) -> void
func remove_overlay(id: ResourceLocation) -> void
func get_overlay(id: ResourceLocation) -> Control
func set_overlay_visible(id: ResourceLocation, visible: bool) -> void
```

覆盖层**不参与栈管理**，添加后持久显示直到手动移除。适用于 HUD、小地图、调试信息等。

#### Toast 系统（自动消失通知）
```gdscript
func show_toast(toast_id: ResourceLocation, data: Dictionary = {},
                duration: float = 3.0) -> UIToast
func dismiss_toast(toast: UIToast) -> void
func dismiss_all_toasts() -> void
```

Toast **不参与栈管理**，可同时显示多个，到期自动消失。适用于成就弹窗、物品获取通知等。

#### 弹窗队列（顺序弹窗）
```gdscript
func queue_popup(panel_id: ResourceLocation, data: Dictionary = {},
                  priority: int = 0) -> void
```

当多个弹窗几乎同时请求打开时（如：网络断连 + 每日奖励 + 背包已满），它们被**排入队列**，逐个显示。当前弹窗关闭后自动弹出队列中的下一个。`priority` 越高越先弹出。

### 5.7 循环导航保护

防止 A↔B 无限循环（如：面板 A 的 `_on_resume()` 打开 B，B 关闭后触发 A 的 `_on_resume()` 又打开 B）：

```gdscript
const MAX_OPEN_DEPTH := 8
var _open_depth: int = 0

func open_panel(...) -> UIPanel:
    _open_depth += 1
    if _open_depth > MAX_OPEN_DEPTH:
        push_error("UIManager: open_panel 递归深度超过 %d，"
                   + "疑似循环导航，已中断" % MAX_OPEN_DEPTH)
        _open_depth -= 1
        return null
    # ... 正常逻辑 ...
    _open_depth -= 1
    return panel

func _process(_delta: float) -> void:
    _open_depth = 0  # 每帧重置，作为二级保障
```

**三重保护机制：**
1. **同面板拦截**：`open_panel` 拒绝已在任意栈中的面板。
2. **递归深度限制**：捕获间接循环（A→B→C→A），单帧内限制连续打开次数。
3. **帧级重置**：每帧清零 `_open_depth`，合法的跨帧连续打开不受影响。

### 5.8 背景遮罩（自动管理的覆盖层）

当 NORMAL 或 POPUP 层有面板打开时，UIManager 可自动在面板下方显示半透明黑色遮罩，将面板与游戏场景在视觉上隔开：

```gdscript
# UIManager 内部自动管理
func _show_background_dimmer(layer: int) -> void:
    # 在面板下方显示半透明 ColorRect

func _hide_background_dimmer(layer: int) -> void:
    # 该层级栈变空时隐藏遮罩
```

### 5.9 性能优化

| 问题 | 方案 |
|------|------|
| `is_panel_open()` 全栈扫描 O(N×M) | 维护 `_active_panel_ids: Dictionary` 哈希集，O(1) 查找 |
| `close_panel(id)` 遍历所有层级 | 利用 `_active_panel_ids` 映射面板ID→层级，直接定位 |
| 缓存面板内存泄漏 | `MAX_CACHED_PANELS` 上限 + LRU 淘汰策略 |
| 高频 Toast 事件风暴 | Toast 默认不发布 EventBus 事件；可选 opt-in |

**活跃面板索引：**
```gdscript
var _active_panel_ids: Dictionary = {}  # String(panel_id) → int(layer)

func _is_panel_in_any_stack(id_str: String) -> bool:
    return _active_panel_ids.has(id_str)  # O(1)
```

**缓存淘汰：**
```gdscript
const MAX_CACHED_PANELS := 10
var _cache_order: Array[String] = []  # LRU 顺序追踪

func _do_close_panel(panel: UIPanel) -> void:
    match panel.cache_mode:
        UIPanel.CacheMode.CACHE:
            if _cached_panels.size() >= MAX_CACHED_PANELS:
                var oldest = _cache_order.pop_front()
                _cached_panels[oldest]._on_destroy()
                _cached_panels[oldest].queue_free()
                _cached_panels.erase(oldest)
            _cache_order.append(panel.panel_id.to_string())
            _cached_panels[panel.panel_id.to_string()] = panel
```

### 5.10 使用示例

```gdscript
# ---- 注册阶段（游戏初始化） ----
var ui_reg: UIRegistry = RegistryManager.get_registry("ui")

ui_reg.register_panel(
    ResourceLocation.from_string("game:inventory"),
    preload("res://scenes/ui/inventory.tscn"),
    UILayer.NORMAL, UIPanel.CacheMode.CACHE
)

ui_reg.register_panel(
    ResourceLocation.from_string("game:confirm_dialog"),
    preload("res://scenes/ui/confirm_dialog.tscn"),
    UILayer.POPUP
)

# ---- 运行时 ----
# 打开面板
UIManager.open_panel(
    ResourceLocation.from_string("game:inventory"),
    {"selected_tab": "weapons"}
)

# 排队弹窗（逐个弹出）
UIManager.queue_popup(ResourceLocation.from_string("game:daily_reward"), {}, 10)
UIManager.queue_popup(ResourceLocation.from_string("game:network_error"), {}, 99)

# 显示 Toast（自动消失）
UIManager.show_toast(ResourceLocation.from_string("game:item_toast"),
                     {"item": "铁剑", "count": 1}, 3.0)

# 添加持久 HUD 覆盖层
UIManager.add_overlay(ResourceLocation.from_string("game:hud"),
                       preload("res://scenes/ui/hud.tscn").instantiate())

# 返回键行为
UIManager.back()  # 弹出 NORMAL 栈顶面板
```

### 5.11 栈行为示意

```
操作                             栈状态 [底→顶]            可见面板
────────────────────────────────────────────────────────────────────
open(main_menu)                [main_menu]               main_menu ✅
open(inventory)                [main_menu, inventory]    inventory ✅（main_menu 暂停）
open(shop)                     [main_menu, inv, shop]    shop ✅（inventory 暂停）
back()                         [main_menu, inventory]    inventory ✅（恢复）
queue_popup(confirm)           POPUP:[confirm]           confirm ✅（遮罩显示）
queue_popup(reward)            队列:[reward]             confirm 仍显示
back(POPUP)                    POPUP:[]                  reward 自动从队列弹出
show_toast(achievement)        toasts:[achievement]      achievement（3秒后自动消失）
back()                         [main_menu]               main_menu ✅（恢复）
```

## 6. 注意事项
由于本插件是全新的项目、示例游戏仍在开发当中，所以在插件使用期间遇到任何问题请及时提交反馈，欢迎提供 Pull Request。
