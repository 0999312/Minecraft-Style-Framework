# Minecraft-Style-Framework 技术文档（Unity C#）

本文档为 Unity C# 版本的中文技术文档，包含 API 介绍、架构说明、使用示例与实现细节。

英文版请参阅 [`technical-guide.md`](./technical-guide.md)。

---

## 1. 简介

**Minecraft-Style-Framework** 是一个面向 Unity 的游戏功能框架，受 Minecraft 底层设计思路启发，强调数据驱动、系统解耦与高扩展性。适合物品较多、事件交互复杂、模块边界清晰要求较高的项目。

**目标平台：** Unity 2022 LTS | C# 9.0（.NET Standard 2.1）

**外部依赖：** Newtonsoft.Json（Json.NET）

---

## 2. 功能列表

| 模块 | 说明 |
|------|------|
| **ResourceLocation** | `namespace:path` 风格标识符，Mojang 风格合法性校验 |
| **RegistryBase / RegistryManager** | 泛型类型安全的集中注册表体系 |
| **EventBus** | 全局事件总线，支持取消事件 |
| **Tag 系统** | 无需修改对象即可动态分类注册表项 |
| **I18N** | 基于 JSON 的本地化系统，支持嵌套键 |
| **Codec 系统** | DFU 风格声明式编解码，支持 JsonOps / UnityResourceOps |
| **Data Component 系统** | 可挂载到任意对象的数据组件，含持久化策略与网络同步标签 |
| **UI 框架** | 栈式 UI，含面板栈、覆盖层、Toast 通知、弹窗队列 |

---

## 3. 安装

1. 将 `Assets/Plugins/MinecraftStyleFramework/` 目录拷贝到你的 Unity 项目的 `Assets/` 下。
2. 通过 Unity Package Manager 安装 **Newtonsoft.Json**：
   - Window → Package Manager → 按名称添加：`com.unity.nuget.newtonsoft-json`
3. 在代码中访问框架单例：
   - `RegistryManager.Instance`
   - `EventBus.Instance`
   - `I18NManager.Instance`
   - `UIManager.Instance`（需在场景中挂载 `UIManager` 组件到持久 GameObject 上）

### UIManager 配置

在首个场景中创建空 GameObject，挂载 `UIManager` 组件。它会通过 `DontDestroyOnLoad` 自动注册为单例。

---

## 4. 核心模块与用法

### 4.1 ResourceLocation

`ResourceLocation` 是框架内的统一标识符，格式为 `namespace:path`。

```csharp
using MinecraftStyleFramework.Utils;

// 直接构造
var swordId = new ResourceLocation("my_mod", "iron_sword");

// 从字符串解析（宽松模式，失败返回 null）
var arrowId = ResourceLocation.FromString("my_mod:arrow");

// 严格解析（返回 DataResult，含校验错误信息）
var result = ResourceLocation.Parse("my_mod:items/diamond_sword");
if (result.IsSuccess)
{
    ResourceLocation id = result.Value;
}

// 合法性检查
bool valid = ResourceLocation.IsValid("demo:block.stone"); // true
bool invalid = ResourceLocation.IsValid("Demo:ITEMS");     // false
```

**校验规则：**
- **Namespace：** 小写字母 `a-z`、数字 `0-9`、`_`、`-`、`.`
- **Path：** 小写字母 `a-z`、数字 `0-9`、`_`、`-`、`.`、`/`

**设计要点：** 实现了 `IEquatable<ResourceLocation>` 并重写 `GetHashCode()`，可直接用作 Dictionary 键。

---

### 4.2 注册表系统

使用 `RegistryBase<T>` 创建类型安全的注册表，或使用 `RegistryBase`（非泛型）存储异构条目。

```csharp
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.Utils;
using UnityEngine;

// 定义类型注册表
public class ItemRegistry : RegistryBase<ScriptableObject>
{
    protected override string GetExpectedTypeName() => "ItemData";
}

// 注册一个注册表实例
var itemRegistry = new ItemRegistry();
RegistryManager.Instance.RegisterRegistry("item", itemRegistry);

// 注册条目
var swordId = new ResourceLocation("demo", "sword");
itemRegistry.Register(swordId, swordAsset);

// 获取条目
var item = itemRegistry.GetEntry(swordId);
bool exists = itemRegistry.HasEntry(swordId);
```

---

### 4.3 EventBus

事件继承抽象类 `Event`，EventBus 支持事件取消。

```csharp
using MinecraftStyleFramework.Events;
using MinecraftStyleFramework.Utils;

// 定义自定义事件
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

// 订阅
EventBus.Instance.Subscribe<ItemUsedEvent>(evt =>
{
    var e = evt as ItemUsedEvent;
    Debug.Log($"物品使用: {e.ItemId}");
});

// 发布
var usedEvent = new ItemUsedEvent(player, swordId);
EventBus.Instance.Publish(usedEvent);

// 取消事件（阻止后续监听器处理）
EventBus.Instance.Subscribe<ItemUsedEvent>(evt =>
{
    evt.Cancel(); // 后续监听器不会收到此事件
});
```

---

### 4.4 Tag 系统

Tag 允许无侵入式地对注册表条目进行动态分类。

```csharp
using MinecraftStyleFramework.Tags;
using MinecraftStyleFramework.Utils;

// 创建一个面向特定注册表的 Tag
var weaponTag = new Tag(ResourceLocation.FromString("registry:item"));

// 添加条目
weaponTag.AddEntry(ResourceLocation.FromString("demo:sword"));
weaponTag.AddEntry(ResourceLocation.FromString("demo:bow"));

// 查询
if (weaponTag.HasEntry(currentItemId))
{
    Debug.Log("这是一个武器！");
}

// 获取所有条目
var entries = weaponTag.GetEntries();
```

---

### 4.5 I18N 系统

基于 JSON 的本地化，支持嵌套键和占位符替换。

```csharp
using MinecraftStyleFramework.I18N;

// 从 JSON 字符串加载翻译
string zhJson = @"{
    ""ui"": {
        ""title"": ""我的游戏"",
        ""greeting"": ""你好，{0}！""
    },
    ""item"": {
        ""sword"": ""铁剑""
    }
}";
I18NManager.Instance.LoadTranslation("zh", zhJson);

// 切换语言（会发布 LanguageChangedEvent）
I18NManager.Instance.SetLanguage("zh");

// 获取文本（键用点号分隔）
string title = I18NManager.Instance.GetText("ui.title");           // "我的游戏"
string greet = I18NManager.Instance.GetText("ui.greeting", "玩家"); // "你好，玩家！"
```

---

## 5. Codec 系统

### 5.1 架构

| 层级 | 职责 | 核心类 |
|------|------|--------|
| **结果层** | 承载解码结果、诊断与部分成功状态 | `DataResult<T>` |
| **声明层** | 描述编码与解码规则 | `Codec<T>`、`MapCodec<T>` |
| **载体层** | 适配不同存储格式 | `DynamicOps`、`JsonOps`、`UnityResourceOps` |

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
    Debug.LogError($"错误: {result.ErrorMessage}");
}
```

### 5.3 基础类型 Codec

```csharp
Codec.Bool              // Codec<bool>
Codec.Int               // Codec<int>
Codec.Float             // Codec<float>
Codec.String            // Codec<string>
Codec.ResourceLocation  // Codec<ResourceLocation>
```

### 5.4 Codec 组合器

```csharp
// 列表
Codec<List<int>> intList = Codec.Int.ListOf();

// 键值对 Map
Codec<Dictionary<string, int>> map = Codec.MapOf(Codec.String, Codec.Int);

// Record（结构化对象）
var itemCodec = Codec.Record(MapCodec.Build<ItemData>(
    new IMapCodecField<ItemData>[]
    {
        Codec.String.FieldOf("name").ForGetter<ItemData>(item => item.Name),
        Codec.Int.FieldOf("damage").ForGetter<ItemData>(item => item.Damage),
        Codec.Float.OptionalFieldOf("weight", () => 1.0f).ForGetter<ItemData>(item => item.Weight),
    },
    args => new ItemData((string)args[0], (int)args[1], (float)args[2])
));

// Xmap（类型变换）
Codec<MyEnum> enumCodec = Codec.String.Xmap(
    str => Enum.Parse<MyEnum>(str),
    val => val.ToString()
);

// FlatXmap（可能失败的变换）
Codec<int> positiveInt = Codec.Int.FlatXmap<int>(
    v => v > 0 ? DataResult<int>.Success(v) : DataResult<int>.Error("必须为正数"),
    v => DataResult<int>.Success(v)
);
```

### 5.5 DynamicOps

同一份 Codec 定义可用于不同存储格式：

```csharp
using MinecraftStyleFramework.Codec.Ops;

// 编码为 JSON
var jsonResult = itemCodec.Encode(myItem, JsonOps.Instance);

// 编码为 Dictionary（用于 Unity 序列化）
var dictResult = itemCodec.Encode(myItem, UnityResourceOps.Instance);

// 从 JSON 解码
var decoded = itemCodec.Decode(jsonData, JsonOps.Instance);
```

---

## 6. Data Component 系统

Data Component 可挂载到任意对象（GameObject、普通 C# 对象、ScriptableObject）。

### 6.1 定义组件类型

```csharp
using MinecraftStyleFramework.Components;
using MinecraftStyleFramework.Codec;
using MinecraftStyleFramework.Utils;

// 将 Codec.Int 包装为 Codec<object>
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

### 6.2 注册组件类型

```csharp
using MinecraftStyleFramework.Registry;

// 注册 ComponentTypeRegistry
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

### 6.3 挂载组件到对象

```csharp
using MinecraftStyleFramework.Components;

// 设置组件值
ComponentHost.SetComponent(gameObject, HEALTH, 15);

// 获取组件值
int hp = ComponentHost.GetComponent<int>(gameObject, HEALTH); // 15

// 检查是否存在
bool has = ComponentHost.HasComponent(gameObject, HEALTH); // true

// 编码所有组件
var container = ComponentHost.GetContainer(gameObject);
var json = container.Encode(JsonOps.Instance);
```

### 6.4 解码组件

```csharp
var newContainer = new ComponentContainer();
var result = newContainer.Decode(json.Value, JsonOps.Instance, reg);
```

### 6.5 持久化策略

| 策略 | 行为 |
|------|------|
| `None` | 永不持久化 |
| `Always` | 始终包含在编码输出中 |
| `NonDefault` | 仅当值与默认值不同时才持久化 |

### 6.6 网络同步标签

| 标签 | 含义 |
|------|------|
| `None` | 无同步提示 |
| `Full` | 建议全量同步 |
| `Tracked` | 仅追踪变化 |

这些仅为元数据提示，并非内置自动同步系统。

---

## 7. 栈式 UI 框架

### 7.1 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                 UIManager（MonoBehaviour）               │
│               栈式 UI 管理器单例                         │
├─────────────────────────────────────────────────────────┤
│  面板栈（按层级）│ 覆盖层管理 │ Toast 管理 │ 弹窗队列    │
├─────────────────────────────────────────────────────────┤
│  UIRegistry     │  EventBus 集成                        │
│  ResourceLocation 标识符                                │
└─────────────────────────────────────────────────────────┘
```

### 7.2 UILayer 常量

```csharp
UILayer.Scene   // 0
UILayer.Normal  // 100
UILayer.Popup   // 200
UILayer.Toast   // 300
UILayer.System  // 400
```

### 7.3 UIPanel

创建继承 `UIPanel` 的 MonoBehaviour：

```csharp
using MinecraftStyleFramework.UI;
using System.Collections.Generic;

public class InventoryPanel : UIPanel
{
    public override void OnInit()
    {
        // 首次实例化时调用一次
    }

    public override void OnOpen(Dictionary<string, object> data = null)
    {
        // 每次打开时调用
        if (data != null && data.TryGetValue("tab", out var tab))
            SelectTab((string)tab);
    }

    public override void OnPause() { /* 被新面板覆盖时 */ }
    public override void OnResume() { /* 上方面板关闭后恢复 */ }
    public override void OnClose() { /* 面板关闭时 */ }
    public override void OnPanelDestroy() { /* 从缓存中移除时 */ }
}
```

### 7.4 UIRegistry 配置

```csharp
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.UI;
using MinecraftStyleFramework.Utils;

// 注册 UIRegistry
var uiReg = new UIRegistry();
RegistryManager.Instance.RegisterRegistry("ui", uiReg);

// 注册面板（Prefab 必须包含 UIPanel 组件）
uiReg.RegisterPanel(
    ResourceLocation.FromString("game:inventory"),
    inventoryPrefab,
    UILayer.Normal,
    UIPanelCacheMode.Cache
);

// 注册 Toast（Prefab 必须包含 UIToast 组件）
uiReg.RegisterToast(
    ResourceLocation.FromString("game:item_toast"),
    toastPrefab
);
```

### 7.5 UIManager 核心 API

```csharp
// 打开面板
UIManager.Instance.OpenPanel(
    ResourceLocation.FromString("game:inventory"),
    new Dictionary<string, object> { { "tab", "weapons" } }
);

// 返回（弹出栈顶面板）
UIManager.Instance.Back(UILayer.Normal);

// 关闭指定面板
UIManager.Instance.ClosePanel(ResourceLocation.FromString("game:inventory"));

// 关闭所有面板
UIManager.Instance.CloseAll();

// 检查面板是否打开（O(1)）
bool open = UIManager.Instance.IsPanelOpen(ResourceLocation.FromString("game:inventory"));

// 覆盖层
UIManager.Instance.AddOverlay(ResourceLocation.FromString("game:hud"), hudObject, UILayer.Scene);
UIManager.Instance.SetOverlayVisible(ResourceLocation.FromString("game:hud"), false);
UIManager.Instance.RemoveOverlay(ResourceLocation.FromString("game:hud"));

// Toast 通知
UIManager.Instance.ShowToast(
    ResourceLocation.FromString("game:item_toast"),
    new Dictionary<string, object> { { "item", "铁剑" } },
    3.0f
);
UIManager.Instance.DismissAllToasts();

// 弹窗队列（FIFO + 优先级）
UIManager.Instance.QueuePopup(
    ResourceLocation.FromString("game:daily_reward"),
    null, priority: 10
);
```

### 7.6 安全与性能

- 同面板防重复打开保护
- 递归导航保护（`MaxOpenDepth = 8`）
- `_activePanelIds` 提供 O(1) 活跃面板查询
- 缓存面板 LRU 淘汰策略（`MaxCachedPanels = 10`）

---

## 8. 程序集结构

```
MinecraftStyleFramework.asmdef          — 运行时程序集
MinecraftStyleFramework.Editor.asmdef   — 仅编辑器程序集
MinecraftStyleFramework.Tests.asmdef    — 测试程序集（EditMode）
```

命名空间层级：
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

## 9. 从 Godot GDScript 迁移说明

| Godot 概念 | Unity 对应 |
|---|---|
| `Autoload` 单例 | 静态 `Instance` 属性 / `MonoBehaviour` + `DontDestroyOnLoad` |
| `RefCounted` | 普通 C# 类（GC 管理） |
| `Variant` | `object` / 泛型 `<T>` |
| `Callable` | `Func<>` / `Action<>` |
| `Signal` | C# `event` / `Action` |
| `PackedScene.instantiate()` | `Object.Instantiate(prefab)` |
| `Dictionary`（无类型） | `Dictionary<TKey, TValue>` |
| `StringName` | `string` |

---

## 10. 反馈

项目仍在持续演进，欢迎提交 Issue、反馈与 Pull Request。
