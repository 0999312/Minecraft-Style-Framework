# Minecraft-Style-Framework Technical Guide (Unity C#)

This is the primary technical documentation for the Unity C# edition. It contains API introductions, architecture notes, usage examples, and implementation details.

For the Chinese edition, see [`technical-guide.zh-CN.md`](./technical-guide.zh-CN.md).

---

## 1. Introduction

**Minecraft-Style-Framework** is a Unity game feature framework inspired by Minecraft's underlying architectural design — especially data-driven patterns, decoupled systems, and extensibility. It is suitable for games with many items, event-driven interactions, and strong modularity requirements.

**Target:** Unity 2022 LTS | C# 9.0 (.NET Standard 2.1)

**Dependency:** Newtonsoft.Json (Json.NET)

---

## 2. Features

| Module | Description |
|--------|-------------|
| **ResourceLocation** | `namespace:path` identifiers with Mojang-style validation |
| **RegistryBase / RegistryManager** | Type-safe centralized registries for game data |
| **EventBus / AsyncEventBus** | Priority-based event dispatch with cancellation and coroutine async support |
| **Tag System** | Dynamic grouping of registry entries without modifying objects |
| **I18N** | JSON-based localization with nested key support |
| **Codec System** | DFU-style declarative encode/decode for JSON and object formats |
| **Data Component System** | Attachable data with persistence policies and network sync hints |
| **UI Framework** | Stack-based UI with panel stacks, overlays, toasts, popup queues |

---

## 3. Installation

1. Copy `Assets/Plugins/MinecraftStyleFramework/` into your Unity project's `Assets/` folder.
2. Install **Newtonsoft.Json** via Unity Package Manager:
   - Window → Package Manager → Add package by name: `com.unity.nuget.newtonsoft-json`
3. Access framework singletons in your code:
   - `RegistryManager.Instance`
   - `EventBusManager.Sync` / `EventBusManager.Async`
   - `I18NManager.Instance`
   - `UIManager.Instance`

### Manager Setup

All managers extend `SingletonMonoBehaviour<T>`. Create an empty GameObject in your first scene and attach `EventBusManager`, `I18NManager`, and `UIManager` components. They auto-register as singletons via `DontDestroyOnLoad`.

---

## 4. Core Modules & Usage

### 4.1 ResourceLocation

`ResourceLocation` is the core identifier throughout the framework, formatted as `namespace:path`.

```csharp
using MinecraftStyleFramework.Utils;

// Simple construction
var swordId = new ResourceLocation("my_mod", "iron_sword");

// Parse from string (lenient, returns null on failure)
var arrowId = ResourceLocation.FromString("my_mod:arrow");

// Strict parsing with validation (returns DataResult)
var result = ResourceLocation.Parse("my_mod:items/diamond_sword");
if (result.IsSuccess)
{
    ResourceLocation id = result.Value;
}

// Validation check
bool valid = ResourceLocation.IsValid("demo:block.stone"); // true
bool invalid = ResourceLocation.IsValid("Demo:ITEMS");     // false
```

**Validation Rules:**
- **Namespace:** lowercase `a-z`, digits `0-9`, `_`, `-`, `.`
- **Path:** lowercase `a-z`, digits `0-9`, `_`, `-`, `.`, `/`

**Key Design:** Implements `IEquatable<ResourceLocation>` with proper `GetHashCode()`, so it can be used directly as a Dictionary key.

---

### 4.2 Registry System

Use `RegistryBase<T>` for type-safe registries or `RegistryBase` (non-generic) for heterogeneous entries.

```csharp
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.Utils;
using UnityEngine;

// Define a typed registry
public class ItemRegistry : RegistryBase<ScriptableObject>
{
    protected override string GetExpectedTypeName() => "ItemData";
}

// Register a registry instance
var itemRegistry = new ItemRegistry();
RegistryManager.Instance.RegisterRegistry("item", itemRegistry);

// Register entries
var swordId = new ResourceLocation("demo", "sword");
itemRegistry.Register(swordId, swordAsset);

// Retrieve entries
var item = itemRegistry.GetEntry(swordId);
bool exists = itemRegistry.HasEntry(swordId);
```

---

### 4.3 EventBus

Events inherit from the `Event` class. The EventBus dispatches handlers by priority (lower = runs first) and supports cancellation via the `[Cancelable]` attribute. Access via `EventBusManager.Sync` (sync) or `EventBusManager.Async` (coroutine).

```csharp
using MinecraftStyleFramework.Events;
using MinecraftStyleFramework.Utils;
using UnityEngine;

// Define a custom event
public class ItemUsedEvent : Event
{
    public GameObject User { get; }
    public ResourceLocation ItemId { get; }

    public ItemUsedEvent(GameObject user, ResourceLocation itemId)
    {
        User = user;
        ItemId = itemId;
    }
}

// Define a cancelable event
[Cancelable]
public class DamageEvent : Event
{
    public float Amount { get; }
    public DamageEvent(float amount) { Amount = amount; }
}

// Register handlers (lower priority runs first, default 0)
EventBusManager.Sync.Register<ItemUsedEvent>(evt =>
{
    Debug.Log($"Item used: {evt.ItemId}");
});

EventBusManager.Sync.Register<DamageEvent>(evt =>
{
    evt.SetCancelled(true); // stops downstream handlers
}, priority: -10);

// Publish
var usedEvent = new ItemUsedEvent(player, swordId);
EventBusManager.Sync.Post(usedEvent);

// Async (coroutine) variant
EventBusManager.Async.Register<ItemUsedEvent>(evt =>
{
    Debug.Log($"Async: {evt.ItemId}");
    return null; // return IEnumerator for yield-based operations
});

yield return EventBusManager.Async.Post(new ItemUsedEvent(player, swordId), cancelled =>
{
    Debug.Log($"Async post complete, cancelled: {cancelled}");
});
```

---

### 4.4 Tag System

Tags allow dynamic grouping of registry entries without modifying their implementation.

```csharp
using MinecraftStyleFramework.Tags;
using MinecraftStyleFramework.Utils;

// Create a tag for a specific registry
var weaponTag = new Tag(ResourceLocation.FromString("registry:item"));

// Add entries
weaponTag.AddEntry(ResourceLocation.FromString("demo:sword"));
weaponTag.AddEntry(ResourceLocation.FromString("demo:bow"));

// Query
if (weaponTag.HasEntry(currentItemId))
{
    Debug.Log("This is a weapon!");
}

// Get all entries
var entries = weaponTag.GetEntries();
```

---

### 4.5 I18N System

JSON-based localization with nested key support and placeholder replacement.

```csharp
using MinecraftStyleFramework.I18N;

// Load translations from JSON string
string enJson = @"{
    ""ui"": {
        ""title"": ""My Game"",
        ""greeting"": ""Hello, {0}!""
    },
    ""item"": {
        ""sword"": ""Iron Sword""
    }
}";
I18NManager.Instance.LoadTranslation("en", enJson);

// Set language (publishes LanguageChangedEvent)
I18NManager.Instance.SetLanguage("en");

// Get text (keys are dot-separated)
string title = I18NManager.Instance.GetText("ui.title");       // "My Game"
string greet = I18NManager.Instance.GetText("ui.greeting", "Player"); // "Hello, Player!"
```

---

## 5. Codec System

### 5.1 Architecture

| Layer | Responsibility | Key Classes |
|-------|---------------|-------------|
| **Result Layer** | Decoded values, diagnostics, partial-success | `DataResult<T>` |
| **Declaration Layer** | Encoding/decoding rules | `Codec<T>`, `MapCodec<T>` |
| **Carrier Layer** | Storage-format adaptation | `DynamicOps`, `JsonOps`, `UnityResourceOps` |

### 5.2 DataResult

```csharp
using MinecraftStyleFramework.Codec;

var result = codec.Decode(data, JsonOps.Instance);
if (result.IsSuccess)
{
    var value = result.Value;
}
else if (result.IsPartial)
{
    var partial = result.Value;
    foreach (var d in result.Diagnostics)
        Debug.Log(d);
}
else
{
    Debug.LogError($"Error: {result.ErrorMessage}");
}
```

### 5.3 Primitive Codecs

```csharp
using MinecraftStyleFramework.Codec;

Codec.Bool    // Codec<bool>
Codec.Int     // Codec<int>
Codec.Float   // Codec<float>
Codec.String  // Codec<string>
Codec.ResourceLocation  // Codec<ResourceLocation>
```

### 5.4 Codec Combinators

```csharp
// List
Codec<List<int>> intList = Codec.Int.ListOf();

// Map
Codec<Dictionary<string, int>> stringIntMap = Codec.MapOf(Codec.String, Codec.Int);

// Record (structured object)
var itemCodec = Codec.Record(MapCodec.Build<ItemData>(
    new IMapCodecField<ItemData>[]
    {
        Codec.String.FieldOf("name").ForGetter<ItemData>(item => item.Name),
        Codec.Int.FieldOf("damage").ForGetter<ItemData>(item => item.Damage),
        Codec.Float.OptionalFieldOf("weight", () => 1.0f).ForGetter<ItemData>(item => item.Weight),
    },
    args => new ItemData((string)args[0], (int)args[1], (float)args[2])
));

// Xmap (transform)
Codec<MyEnum> enumCodec = Codec.String.Xmap(
    str => Enum.Parse<MyEnum>(str),
    val => val.ToString()
);

// FlatXmap (fallible transform)
Codec<int> positiveInt = Codec.Int.FlatXmap<int>(
    v => v > 0 ? DataResult<int>.Success(v) : DataResult<int>.Error("Must be positive"),
    v => DataResult<int>.Success(v)
);
```

### 5.5 DynamicOps

The same codec works with different storage formats:

```csharp
using MinecraftStyleFramework.Codec.Ops;

// Encode to JSON
var jsonResult = itemCodec.Encode(myItem, JsonOps.Instance);

// Encode to Dictionary (for Unity serialization)
var dictResult = itemCodec.Encode(myItem, UnityResourceOps.Instance);

// Decode from JSON
var decoded = itemCodec.Decode(jsonData, JsonOps.Instance);
```

---

## 6. Data Component System

Data Components can be attached to any object (GameObjects, plain C# objects, ScriptableObjects).

### 6.1 Define Component Types

```csharp
using MinecraftStyleFramework.Components;
using MinecraftStyleFramework.Codec;
using MinecraftStyleFramework.Utils;

// Wrap Codec.Int as Codec<object> for ComponentType
var healthCodec = Codec.Int.Xmap<object>(v => (object)v, o => (int)o);

var HEALTH = new ComponentType.Builder(
    new ResourceLocation("game", "health"),
    healthCodec
)
.WithDefault(() => 20)
.Persistent(PersistentPolicy.Always)
.WithNetworkSync(NetworkSyncTag.Full)
.Build();
```

### 6.2 Register Component Types

```csharp
using MinecraftStyleFramework.Registry;

// Register the ComponentTypeRegistry
if (!RegistryManager.Instance.HasRegistry(ComponentTypeRegistry.RegistryKey))
{
    RegistryManager.Instance.RegisterRegistry(
        ComponentTypeRegistry.RegistryKey,
        new ComponentTypeRegistry()
    );
}

var reg = RegistryManager.Instance.GetRegistry<ComponentTypeRegistry>(ComponentTypeRegistry.RegistryKey);
reg.RegisterComponentType(HEALTH);
```

### 6.3 Attach Components to Objects

```csharp
using MinecraftStyleFramework.Components;

// Set component on any object
ComponentHost.SetComponent(gameObject, HEALTH, 15);

// Get component
int hp = ComponentHost.GetComponent<int>(gameObject, HEALTH); // 15

// Check existence
bool has = ComponentHost.HasComponent(gameObject, HEALTH); // true

// Encode all components
var container = ComponentHost.GetContainer(gameObject);
var json = container.Encode(JsonOps.Instance);
```

### 6.4 Decode Components

```csharp
var newContainer = new ComponentContainer();
var result = newContainer.Decode(json.Value, JsonOps.Instance, reg);
```

### 6.5 Persistence Policies

| Policy | Behavior |
|--------|----------|
| `None` | Never persisted |
| `Always` | Always included in encode output |
| `NonDefault` | Only persisted if value differs from default |

### 6.6 Network Sync Tags

| Tag | Meaning |
|-----|---------|
| `None` | No sync hint |
| `Full` | Full value sync suggested |
| `Tracked` | Only changes tracked |

These are metadata hints only — not an automatic replication system.

---

## 7. Stack-based UI Framework

### 7.1 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  UIManager (MonoBehaviour)               │
│               Stack-based UI Manager Singleton          │
├─────────────────────────────────────────────────────────┤
│  Panel Stacks  │ Overlay Mgr │ Toast Mgr │ Popup Queue │
│  (per-layer)   │ (persistent)│ (auto-off)│ (priority)  │
├─────────────────────────────────────────────────────────┤
│  UIRegistry    │  EventBusManager integration              │
│  ResourceLocation identifiers                           │
└─────────────────────────────────────────────────────────┘
```

### 7.2 UILayer Constants

```csharp
UILayer.Scene   // 0
UILayer.Normal  // 100
UILayer.Popup   // 200
UILayer.Toast   // 300
UILayer.System  // 400
```

### 7.3 UIPanel

Create a MonoBehaviour that extends `UIPanel`:

```csharp
using MinecraftStyleFramework.UI;
using System.Collections.Generic;

public class InventoryPanel : UIPanel
{
    public override void OnInit()
    {
        // Called once on first instantiation
    }

    public override void OnOpen(Dictionary<string, object> data = null)
    {
        // Called each time the panel opens
        if (data != null && data.TryGetValue("tab", out var tab))
            SelectTab((string)tab);
    }

    public override void OnPause() { /* covered by another panel */ }
    public override void OnResume() { /* above panel closed */ }
    public override void OnClose() { /* panel closing */ }
    public override void OnPanelDestroy() { /* removed from cache */ }
}
```

### 7.4 UIRegistry Setup

```csharp
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.UI;
using MinecraftStyleFramework.Utils;

// Register UIRegistry
var uiReg = new UIRegistry();
RegistryManager.Instance.RegisterRegistry("ui", uiReg);

// Register panels (prefab must have UIPanel component)
uiReg.RegisterPanel(
    ResourceLocation.FromString("game:inventory"),
    inventoryPrefab,
    UILayer.Normal,
    UIPanelCacheMode.Cache
);

// Register toasts (prefab must have UIToast component)
uiReg.RegisterToast(
    ResourceLocation.FromString("game:item_toast"),
    toastPrefab
);
```

### 7.5 UIManager API

```csharp
// Open panel
UIManager.Instance.OpenPanel(
    ResourceLocation.FromString("game:inventory"),
    new Dictionary<string, object> { { "tab", "weapons" } }
);

// Back (pop top panel)
UIManager.Instance.Back(UILayer.Normal);

// Close specific panel
UIManager.Instance.ClosePanel(ResourceLocation.FromString("game:inventory"));

// Close all panels
UIManager.Instance.CloseAll();

// Check if panel is open (O(1))
bool open = UIManager.Instance.IsPanelOpen(ResourceLocation.FromString("game:inventory"));

// Overlays
UIManager.Instance.AddOverlay(ResourceLocation.FromString("game:hud"), hudObject, UILayer.Scene);
UIManager.Instance.SetOverlayVisible(ResourceLocation.FromString("game:hud"), false);
UIManager.Instance.RemoveOverlay(ResourceLocation.FromString("game:hud"));

// Toasts
UIManager.Instance.ShowToast(
    ResourceLocation.FromString("game:item_toast"),
    new Dictionary<string, object> { { "item", "Iron Sword" } },
    3.0f
);
UIManager.Instance.DismissAllToasts();

// Popup queue (FIFO + priority)
UIManager.Instance.QueuePopup(
    ResourceLocation.FromString("game:daily_reward"),
    null, priority: 10
);
```

### 7.6 Safety & Performance

- Duplicate open protection (same panel cannot open twice)
- Recursive navigation guard (`MaxOpenDepth = 8`)
- O(1) active panel lookup via `_activePanelIds` dictionary
- LRU cache eviction for cached panels (`MaxCachedPanels = 10`)

---

## 8. Assembly Structure

```
MinecraftStyleFramework.asmdef          — Runtime assembly
MinecraftStyleFramework.Editor.asmdef   — Editor-only assembly
MinecraftStyleFramework.Tests.asmdef    — Test assembly (EditMode)
```

Namespace hierarchy:
- `MinecraftStyleFramework.Utils`
- `MinecraftStyleFramework.Registry`
- `MinecraftStyleFramework.Events`
- `MinecraftStyleFramework.Events.UI`
- `MinecraftStyleFramework.Codec`
- `MinecraftStyleFramework.Codec.Ops`
- `MinecraftStyleFramework.Components`
- `MinecraftStyleFramework.Tags`
- `MinecraftStyleFramework.I18N`
- `MinecraftStyleFramework.UI`

---

## 9. Migration Notes (from Godot GDScript)

| Godot Concept | Unity Equivalent |
|---|---|
| `Autoload` singleton | Static `Instance` property / `MonoBehaviour` + `DontDestroyOnLoad` |
| `RefCounted` | Plain C# class (GC-managed) |
| `Variant` | `object` / generics `<T>` |
| `Callable` | `Func<>` / `Action<>` |
| `Signal` | C# `event` / `Action` |
| `PackedScene.instantiate()` | `Object.Instantiate(prefab)` |
| `Dictionary` (untyped) | `Dictionary<TKey, TValue>` |
| `StringName` | `string` |

---

## 10. Feedback

The project is still evolving. Issues, feedback, and pull requests are welcome.
