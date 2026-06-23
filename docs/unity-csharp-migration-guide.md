# Minecraft-Style-Framework → Unity C# Migration Guide

**Target:** Unity 2022 LTS | **Language:** C# 9.0 (.NET Standard 2.1) | **Source:** Godot 4.x GDScript

---

## 1. Project Mapping Overview

| Godot Concept | Unity Equivalent |
|---|---|
| `addons/mc_game_framework/` | `Assets/Plugins/MinecraftStyleFramework/` |
| `.gd` script files | `.cs` files |
| `class_name` | C# class name / namespace |
| `extends RefCounted` | Plain C# class (no base) |
| `extends Resource` | `ScriptableObject` |
| `extends Node` | `MonoBehaviour` |
| `extends EditorPlugin` | `EditorWindow` / custom `Editor` |
| `extends EditorInspectorPlugin` | `PropertyDrawer` / custom `Editor` |
| `Autoload` singleton | `[RuntimeInitializeOnLoadMethod]` static singleton / `MonoBehaviour` placed in `DontDestroyOnLoad` |
| `PackedScene.instantiate()` | `Instantiate(prefab)` |
| `Signal` (Godot built-in) | `UnityEvent` / C# `event` / `Action` |
| `ResourceSaver.save()` | `AssetDatabase.CreateAsset()` / `EditorJsonUtility.ToJson()` |
| `ResourceLoader.load()` | `AssetDatabase.LoadAssetAtPath<>()` / `Resources.Load<>()` |
| `TranslationServer` | Unity Localization Package |
| `JSON.parse_string()` | `JsonUtility.FromJson<>()` / `Newtonsoft.Json` |
| `@tool` | `[ExecuteInEditMode]` / `[ExecuteAlways]` |
| `Dictionary` | `Dictionary<TKey, TValue>` |
| `Array` (untyped) | `List<object>` / `List<T>` |
| `Variant` (Godot dynamic type) | `object` / generics `<T>` |
| `Callable` | `Func<>` / `Action` / `delegate` |
| `StringName` | `string` (interned via `string.Intern()`) |

---

## 2. Namespace & Assembly Structure

```
Assets/Plugins/MinecraftStyleFramework/
├── Runtime/
│   ├── MinecraftStyleFramework.asmdef
│   ├── Utils/
│   │   └── ResourceLocation.cs
│   ├── Registry/
│   │   ├── RegistryBase.cs
│   │   ├── RegistryManager.cs
│   │   ├── ComponentTypeRegistry.cs
│   │   └── UIRegistry.cs
│   ├── Event/
│   │   ├── Event.cs
│   │   ├── SignalEvent.cs
│   │   ├── LanguageChangedEvent.cs
│   │   └── UI/
│   │       ├── UIOpenEvent.cs
│   │       ├── UICloseEvent.cs
│   │       ├── UIPauseEvent.cs
│   │       └── UIResumeEvent.cs
│   ├── Codec/
│   │   ├── Core/
│   │   │   ├── Codec.cs
│   │   │   ├── MapCodec.cs
│   │   │   ├── DataResult.cs
│   │   │   ├── DynamicOps.cs
│   │   │   └── CodecResource.cs
│   │   └── Ops/
│   │       ├── JsonOps.cs
│   │       └── UnityResourceOps.cs
│   ├── Component/
│   │   ├── ComponentType.cs
│   │   ├── ComponentContainer.cs
│   │   └── ComponentHost.cs
│   ├── Tag/
│   │   ├── Tag.cs
│   │   └── TagRegistry.cs
│   ├── I18N/
│   │   └── I18NManager.cs
│   └── UI/
│       ├── UILayer.cs
│       ├── UIPanel.cs
│       ├── UIToast.cs
│       └── UIManager.cs
├── Editor/
│   ├── MinecraftStyleFramework.Editor.asmdef
│   ├── CodecResourceInspector.cs
│   └── ComponentInspector.cs
└── Tests/
    ├── MinecraftStyleFramework.Tests.asmdef
    ├── TestResourceLocation.cs
    ├── TestCodec.cs
    ├── TestDataResult.cs
    ├── TestEvent.cs
    ├── TestEventBus.cs
    ├── TestRegistryBase.cs
    ├── TestTagSystem.cs
    ├── TestComponentSystem.cs
    └── TestUIFramework.cs
```

---

## 3. Subsystem Migration Detail

### 3.1 ResourceLocation (`utils/resource_location.gd`)

**Godot source:** RefCounted with `namespace_id: String`, `id: String`, regex validation, `from_string()`, `parse()`.

**Unity C# mapping:**

```csharp
// ResourceLocation.cs
namespace MinecraftStyleFramework.Utils
{
    /// <summary>
    /// Minecraft-style resource identifier (namespace:path).
    /// Use ToString() as dictionary key, not the object reference.
    /// </summary>
    public sealed class ResourceLocation : IEquatable<ResourceLocation>
    {
        private static readonly Regex NamespacePattern = new("^[a-z0-9_\\-.]+$", RegexOptions.Compiled);
        private static readonly Regex PathPattern = new("^[a-z0-9_\\-./]+$", RegexOptions.Compiled);

        public string NamespaceId { get; }
        public string Path { get; }
        private readonly string _cached;

        public ResourceLocation(string ns, string path)
        {
            NamespaceId = ns;
            Path = path;
            _cached = $"{ns}:{path}";
        }

        public static ResourceLocation FromString(string locationStr) { /* split on ':', validate non-empty */ }
        public static DataResult<ResourceLocation> Parse(string locationStr) { /* strict Mojang-style validation */ }
        public static DataResult<bool> Validate(string locationStr) { /* wrapper calling Parse().Map */ }
        public static DataResult<string> ValidateNamespace(string ns) { /* regex check */ }
        public static DataResult<string> ValidatePath(string path) { /* regex check */ }
        public static bool IsValid(string locationStr) { /* calls Parse -> isSuccess */ }

        public override string ToString() => _cached;
        public bool Equals(ResourceLocation other) => other != null && NamespaceId == other.NamespaceId && Path == other.Path;
        public override bool Equals(object obj) => obj is ResourceLocation rl && Equals(rl);
        public override int GetHashCode() => HashCode.Combine(NamespaceId, Path);
    }
}
```

**Key changes:**
- Use `IEquatable<>` and override `Equals`/`GetHashCode` so object can be used as dictionary key directly (unlike Godot where `.to_string()` was required as key).
- `static var` regex → `static readonly Regex` (thread-safe, precompiled).
- `RefCounted` base class not needed → plain C# reference types, GC-managed.

---

### 3.2 DataResult (`codec/core/data_result.gd`)

**Godot source:** RefCounted with `Status.SUCCESS/ERROR/PARTIAL` enum, `_value: Variant`, `_diagnostics: Array[Diagnostic]`, functional combinators (`map`, `flat_map`, `apply`).

**Unity C# mapping:**

```csharp
// DataResult.cs
namespace MinecraftStyleFramework.Codec
{
    public enum DataResultStatus { Success, Error, Partial }
    public enum DiagnosticLevel { Fatal, Recoverable, Warning }

    public class Diagnostic
    {
        public DiagnosticLevel Level { get; }
        public string Message { get; }
        public string Path { get; }

        public Diagnostic(DiagnosticLevel level, string message, string path = "") { ... }
        public override string ToString() => string.IsNullOrEmpty(Path)
            ? $"[{Level}] {Message}"
            : $"[{Level}] {Path}: {Message}";
    }

    public class DataResult<T>
    {
        public DataResultStatus Status { get; private set; }
        public T Value { get; private set; }
        public string ErrorMessage { get; private set; }
        public List<Diagnostic> Diagnostics { get; private set; } = new();

        public static DataResult<T> Success(T value) { ... }
        public static DataResult<T> Error(string message) { ... }
        public static DataResult<T> Partial(T partialValue, string message) { ... }

        public bool IsSuccess => Status == DataResultStatus.Success;
        public bool IsError => Status == DataResultStatus.Error;
        public bool IsPartial => Status == DataResultStatus.Partial;

        public T GetValueOrDefault(T defaultValue) => Status != DataResultStatus.Error ? Value : defaultValue;

        public DataResult<U> Map<U>(Func<T, U> transform) { ... }
        public DataResult<U> FlatMap<U>(Func<T, DataResult<U>> transform) { ... }
        public DataResult<T> Apply<U>(DataResult<Func<T, U>> funcResult) { ... } // not commonly needed in C#

        public DataResult<T> AddDiagnostic(DiagnosticLevel level, string message, string path = "") { ... }
        public DataResult<T> SetPathPrefix(string prefix) { ... }

        public override string ToString() => Status switch
        {
            DataResultStatus.Success => $"DataResult.Success({Value})",
            DataResultStatus.Error => $"DataResult.Error({ErrorMessage})",
            DataResultStatus.Partial => $"DataResult.Partial({Value}, {ErrorMessage})",
            _ => "DataResult.Unknown"
        };
    }
}
```

**Key changes:**
- `Variant` → generic `<T>`. Strongly typed, no runtime type checks.
- `_diagnostics: Array` → `List<Diagnostic>`.
- `Callable` → `Func<T, U>` / `Func<T, DataResult<U>>`.
- `apply()` is rarely idiomatic in C#; can be kept as a utility but likely unused.

**Non-generic helper (for cases where T is irrelevant/unknown):**

```csharp
public static class DataResult
{
    public static DataResult<bool> Success() => DataResult<bool>.Success(true); // replaces `DataResult.success(true)` in Validate()
    public static DataResult<T> Error<T>(string message) => DataResult<T>.Error(message);
}
```

---

### 3.3 DynamicOps (`codec/core/dynamic_ops.gd`)

**Godot source:** Abstract class with methods for creating/reading basic types, maps, lists. Two implementations: `JsonOps`, `GodotResourceOps`.

**Unity C# mapping:**

```csharp
// DynamicOps.cs
namespace MinecraftStyleFramework.Codec
{
    /// <summary>
    /// Abstract data carrier. Codecs don't care about the underlying format,
    /// only about read/write semantics. Equivalent to DFU DynamicOps.
    /// </summary>
    public abstract class DynamicOps
    {
        // --- Creation ---
        public abstract object Empty();
        public abstract object CreateInt(int value);
        public abstract object CreateFloat(float value);
        public abstract object CreateBool(bool value);
        public abstract object CreateString(string value);
        public abstract object CreateList(IList<object> values);
        public abstract object CreateMap(Dictionary<string, object> entries);

        // --- Reading ---
        public abstract DataResult<int> GetInt(object value);
        public abstract DataResult<float> GetFloat(object value);
        public abstract DataResult<bool> GetBool(object value);
        public abstract DataResult<string> GetString(object value);

        // --- Composite ---
        public abstract DataResult<object> GetMapValue(object mapValue, string key);
        public abstract object SetMapValue(object mapValue, string key, object value);
        public abstract object RemoveMapValue(object mapValue, string key);
        public abstract DataResult<IEnumerable<string>> GetMapKeys(object mapValue);
        public abstract DataResult<Dictionary<string, object>> GetMapEntries(object mapValue);
        public abstract DataResult<IList<object>> GetList(object value);
        public abstract object MergeMaps(object first, object second);

        // --- Type checks ---
        public abstract bool IsMap(object value);
        public abstract bool IsList(object value);
        public abstract bool IsNumber(object value);
        public abstract bool IsString(object value);
        public abstract string GetName();
    }
}
```

**JsonOps migration note:** Godot JSON → .NET `System.Text.Json` or `Newtonsoft.Json`. Recommend **Newtonsoft.Json** (Json.NET) for its flexibility with `JToken`/`JObject`/`JArray` which maps cleanly to the DynamicOps pattern.

```csharp
// JsonOps.cs — uses Newtonsoft.Json.Linq for the Variant-equivalent
public sealed class JsonOps : DynamicOps
{
    public static readonly JsonOps Instance = new();

    public override object CreateInt(int value) => new JValue(value);
    public override object CreateString(string value) => new JValue(value);
    public override object CreateMap(Dictionary<string, object> entries) { /* convert to JObject */ }
    public override object CreateList(IList<object> values) => new JArray(values);

    public override DataResult<int> GetInt(object value) =>
        value is JValue jv && jv.Type == JTokenType.Integer
            ? DataResult<int>.Success(jv.Value<int>())
            : DataResult<int>.Error($"Expected int, got: {value}");

    // ... etc
}
```

**UnityResourceOps** replaces `GodotResourceOps`:

```csharp
// UnityResourceOps.cs
// Uses Dictionary<string, object> as intermediate representation (same structure as JsonOps)
// Additional support for UnityEngine.Object property reflection.
// Uses Unity's SerializedObject / SerializedProperty for ScriptableObject reading.
public sealed class UnityResourceOps : DynamicOps
{
    public static readonly UnityResourceOps Instance = new();

    // get_map_value: supports both Dictionary and UnityEngine.Object
    public override DataResult<object> GetMapValue(object mapValue, string key)
    {
        if (mapValue is Dictionary<string, object> dict)
            return dict.TryGetValue(key, out var v) ? DataResult<object>.Success(v) : DataResult<object>.Error($"Key '{key}' not found");
        if (mapValue is UnityEngine.Object uObj)
        {
            using var so = new SerializedObject(uObj);
            var prop = so.FindProperty(key);
            if (prop != null) return DataResult<object>.Success(GetPropertyValue(prop));
            return DataResult<object>.Error($"Property '{key}' not found on {uObj}");
        }
        return DataResult<object>.Error($"Expected Dictionary or UnityEngine.Object, got: {mapValue?.GetType().Name}");
    }

    // Static helpers - wraps Unity Editor API
    public static DataResult<string> SaveResource(ScriptableObject res, string path) { ... }
    public static DataResult<T> LoadResource<T>(string path) where T : UnityEngine.Object { ... }
}
```

---

### 3.4 Codec (`codec/core/codec.gd`)

**Godot source:** Abstract base `Codec` with `encode(value, ops)` / `decode(value, ops)` returning `DataResult`. Contains static factory methods (`INT()`, `STRING()`, `BOOL()`, `FLOAT()`, `RESOURCE_LOCATION()`, `list_of()`, `field_of()`, `optional_field_of()`, `xmap()`, `flat_xmap()`, `either()`, `dispatch()`, `record()`, `unit()`, `map_of()`) and nested inner classes for each combinator.

**Unity C# mapping:**

```csharp
// Codec.cs
namespace MinecraftStyleFramework.Codec
{
    public abstract class Codec<T>
    {
        public abstract DataResult<object> Encode(T value, DynamicOps ops);
        public abstract DataResult<T> Decode(object value, DynamicOps ops);

        // --- Combinators ---
        public MapCodec<T> FieldOf(string name) =>
            new FieldMapCodec<T>(name, this, optional: false, defaultFactory: null);

        public MapCodec<T> OptionalFieldOf(string name, Func<T> defaultFactory) =>
            new FieldMapCodec<T>(name, this, optional: true, defaultFactory);

        public Codec<List<T>> ListOf() => new ListCodec<T>(this);

        public Codec<U> Xmap<U>(Func<T, U> decodeFn, Func<U, T> encodeFn) =>
            new XmapCodec<T, U>(this, decodeFn, encodeFn);

        public Codec<U> FlatXmap<U>(Func<T, DataResult<U>> decodeFn, Func<U, DataResult<T>> encodeFn) =>
            new FlatXmapCodec<T, U>(this, decodeFn, encodeFn);
    }

    // Static factory class (non-generic, for discovery)
    public static class Codec
    {
        public static Codec<bool> Bool { get; } = new PrimitiveCodec<bool>(
            (ops, v) => ops.CreateBool(v),
            (ops, v) => ops.GetBool(v));

        public static Codec<int> Int { get; } = new PrimitiveCodec<int>(
            (ops, v) => ops.CreateInt(v),
            (ops, v) => ops.GetInt(v));

        public static Codec<float> Float { get; } = new PrimitiveCodec<float>(
            (ops, v) => ops.CreateFloat(v),
            (ops, v) => ops.GetFloat(v));

        public static Codec<string> String { get; } = new PrimitiveCodec<string>(
            (ops, v) => ops.CreateString(v),
            (ops, v) => ops.GetString(v));

        public static Codec<ResourceLocation> ResourceLocation { get; } = new ResourceLocationCodec();

        public static Codec<Dictionary<TKey, TValue>> MapOf<TKey, TValue>(
            Codec<TKey> keyCodec, Codec<TValue> valueCodec) => new MapOfCodec<TKey, TValue>(keyCodec, valueCodec);

        public static Codec<object> Either(Codec<object> first, Codec<object> second) =>
            new EitherCodec(first, second);

        public static Codec<object> Dispatch(string typeKey, Codec<object> typeCodec,
            Func<object, Codec<object>> dispatchFn) => new DispatchCodec(typeKey, typeCodec, dispatchFn);

        public static Codec<TR> Record<TR>(MapCodec<TR> mapCodec) => new RecordCodec<TR>(mapCodec);

        public static Codec<T> Unit<T>(T value) => new UnitCodec<T>(value);
    }
}
```

**Inner classes become top-level or nested internal classes:**

| Godot Inner Class | C# Equivalent |
|---|---|
| `PrimitiveCodec` | `PrimitiveCodec<T>` |
| `ResourceLocationCodec` | `ResourceLocationCodec : Codec<ResourceLocation>` |
| `ListCodec` | `ListCodec<T> : Codec<List<T>>` |
| `MapOfCodec` | `MapOfCodec<TKey, TValue> : Codec<Dictionary<TKey, TValue>>` |
| `XmapCodec` | `XmapCodec<TFrom, TTo> : Codec<TTo>` |
| `FlatXmapCodec` | `FlatXmapCodec<TFrom, TTo> : Codec<TTo>` |
| `EitherCodec` | `EitherCodec : Codec<object>` (loses type safety, by design) |
| `DispatchCodec` | `DispatchCodec : Codec<object>` (type key dispatch, runtime polymorphism) |
| `UnitCodec` | `UnitCodec<T> : Codec<T>` |
| `RecordCodec` | `RecordCodec<T> : Codec<T>` — wraps a `MapCodec<T>` |

**Mapping notes:**
- `field_of("name")` on a `Codec<T>` returns a `MapCodec<T>` — this is the same in C#.
- `for_getter(getter)` on a `MapCodec` — only used during encode, to extract the field from the larger object. In C#, keep this as a `MapCodec<T>` with an optional `Func<TOwner, T> getter` field.
- `Callable` → `Func<>`. Use lambda closures: `func(item: ItemData): return item.item_name` → `(ItemData item) => item.item_name`.

---

### 3.5 MapCodec (`codec/core/map_codec.gd`)

**Godot source:** `MapCodec` with `decode_from_map(map_value, ops)` / `encode_to_map(value, ops)`. Contains `FieldCodec` (single field), `GetterMapCodec` (wraps a field with a getter), `RecordMapCodec` (combines multiple fields via constructor).

**Unity C# mapping:**

```csharp
// MapCodec.cs
namespace MinecraftStyleFramework.Codec
{
    public abstract class MapCodec<T>
    {
        public abstract DataResult<T> DecodeFromMap(object mapValue, DynamicOps ops);
        public abstract DataResult<object> EncodeToMap(T value, DynamicOps ops);

        public Codec<T> ToCodec() => Codec.Record(this);

        /// <summary>
        /// Attach a getter for extracting this field from a larger container during encode.
        /// The MapCodec itself remains typed to the field, but encode receives the outer object.
        /// </summary>
        public MapCodecWithGetter<TOuter, T> ForGetter<TOuter>(Func<TOuter, T> getter) =>
            new MapCodecWithGetter<TOuter, T>(this, getter);
    }

    // Non-generic static factory
    public static class MapCodec
    {
        public static MapCodec<TR> Build<TR>(
            IReadOnlyList<object> // actually IMapCodecField<TR> instances
            fields,
            Func<object[], TR> constructor) => new RecordMapCodec<TR>(fields, constructor);
    }

    /// <summary>
    /// Single-field MapCodec. Created by Codec.FieldOf() / Codec.OptionalFieldOf().
    /// </summary>
    public class FieldMapCodec<T> : MapCodec<T> { ... }

    /// <summary>
    /// Wraps a MapCodec with a getter for encode. The decode path is unchanged (reads from map).
    /// On encode, the getter extracts TField from TOwner.
    /// </summary>
    public class MapCodecWithGetter<TOwner, TField> : MapCodec<TField> { ... }

    /// <summary>
    /// Multi-field record. Decodes all fields from map, calls constructor. Encodes by merging field maps.
    /// </summary>
    public class RecordMapCodec<TR> : MapCodec<TR> { ... }
}
```

**Builder pattern (from demo-codec-entry.gd):**

```csharp
// Godot:
// MapCodec.build([fields], func(...) -> Record: ...)
//
// C#:
var itemCodec = Codec.Record(MapCodec.Build<ItemData>(
    new IMapCodecField<ItemData>[] {
        Codec.String.FieldOf("name").ForGetter<ItemData>(item => item.ItemName),
        Codec.Int.FieldOf("damage").ForGetter<ItemData>(item => item.Damage),
        Codec.Float.OptionalFieldOf("weight", () => 1.0f).ForGetter<ItemData>(item => item.Weight),
        Codec.Bool.OptionalFieldOf("enchantable", () => false).ForGetter<ItemData>(item => item.Enchantable),
    },
    args => new ItemData((string)args[0], (int)args[1], (float)args[2], (bool)args[3])
));
```

---

### 3.6 CodecResource (`codec/core/codec_resource.gd`)

**Godot source:** Abstract `Resource` subclass with `get_type_id()`, `get_codec()`, `encode_with()`, `decode_with()`, `to_json_data()`, `from_json_data()`, `save_to_file()`, `load_from_file()`.

**Unity C# mapping:**

```csharp
// CodecResource.cs
namespace MinecraftStyleFramework.Codec
{
    /// <summary>
    /// Codec-driven ScriptableObject. Bridges runtime objects with Unity asset persistence.
    /// Subclasses declare a type ID and a Codec. The codec handles serialization/deserialization.
    /// </summary>
    public abstract class CodecResource : ScriptableObject
    {
        /// <summary>Resource type ID. Subclasses MUST override.</summary>
        public abstract string GetTypeId();

        /// <summary>Get the Codec for this resource type. Subclasses MUST override.</summary>
        public abstract Codec<object> GetCodec(); // or typed via generic subclass

        /// <summary>Whether persistence to Unity asset is allowed.</summary>
        public virtual bool AllowsResourcePersistence() => true;

        public DataResult<object> EncodeWith(DynamicOps ops) => GetCodec().Encode(this, ops);

        public static DataResult<T> DecodeWith<T>(object data, DynamicOps ops, Codec<T> codec)
            => codec.Decode(data, ops);

        public DataResult<object> ToJsonData() => EncodeWith(JsonOps.Instance);
        public static DataResult<T> FromJsonData<T>(object data, Codec<T> codec) =>
            DecodeWith(data, JsonOps.Instance, codec);

        // Unity-specific: save/load via AssetDatabase
        public DataResult<string> SaveToFile(string path) { /* Editor-only: AssetDatabase.CreateAsset */ }
        public static DataResult<T> LoadFromFile<T>(string path) where T : CodecResource { /* AssetDatabase.LoadAssetAtPath */ }
    }
}
```

**Key differences:**
- Godot `Resource` → Unity `ScriptableObject`.
- Godot `ResourceSaver.save(res, path)` → Unity `AssetDatabase.CreateAsset(so, path)` (editor-only).
- Godot `ResourceLoader.load(path)` → Unity `AssetDatabase.LoadAssetAtPath<T>(path)` (editor) or `Resources.Load<T>(path)` (runtime).
- `.tres` / `.res` file formats → `.asset` file format.

---

### 3.7 Registry System

#### RegistryBase (`registry/registry_base.gd`)

**Godot source:** `Dictionary`-backed generic registry keyed by `ResourceLocation.to_string()`. Virtual `_validate_entry()` for type-restricted subclasses.

**Unity C# mapping:**

```csharp
// RegistryBase.cs
namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Generic registry keyed by ResourceLocation. Subclasses can enforce type constraints.
    /// </summary>
    public class RegistryBase<TEntry>
    {
        protected readonly Dictionary<string, TEntry> Entries = new();

        public virtual bool Register(ResourceLocation id, TEntry entry)
        {
            if (!ValidateEntry(entry))
            {
                Debug.LogWarning($"Registry entry validation failed for '{id}': expected {GetExpectedTypeName()}");
                return false;
            }
            var key = id.ToString();
            if (Entries.ContainsKey(key))
                Debug.LogWarning($"Overwriting registry entry: {key}");
            Entries[key] = entry;
            return true;
        }

        public bool Unregister(ResourceLocation id) => Entries.Remove(id.ToString());
        public TEntry GetEntry(ResourceLocation id) => Entries.TryGetValue(id.ToString(), out var e) ? e : default;
        public bool HasEntry(ResourceLocation id) => Entries.ContainsKey(id.ToString());
        public IReadOnlyDictionary<string, TEntry> GetAllEntries() => Entries;
        public IEnumerable<string> GetAllKeys() => Entries.Keys;
        public void Clear() => Entries.Clear();

        protected virtual bool ValidateEntry(TEntry entry) => true;
        protected virtual string GetExpectedTypeName() => typeof(TEntry).Name;
    }
}
```

#### RegistryManager (`autoload/registry_manager.gd`)

**Godot source:** Meta-registry storing `RegistryBase` instances, keyed by `ResourceLocation("core", type_name)`.

**Unity C# mapping:**

```csharp
// RegistryManager.cs
namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Meta-registry singleton. Stores individual registries keyed by type name.
    /// Accessible as a static singleton throughout the app.
    /// </summary>
    public static class RegistryManager
    {
        private const string RegistryNamespace = "core";
        private static readonly Dictionary<string, object> Registries = new();

        public static void RegisterRegistry<T>(string typeName, RegistryBase<T> registry)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            Registries[id.ToString()] = registry;
        }

        public static RegistryBase<T> GetRegistry<T>(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return Registries.TryGetValue(id.ToString(), out var r) ? r as RegistryBase<T> : null;
        }

        public static bool HasRegistry(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return Registries.ContainsKey(id.ToString());
        }

        public static bool UnregisterRegistry(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return Registries.Remove(id.ToString());
        }

        // Convenience shortcuts
        public static ComponentTypeRegistry ComponentTypes =>
            GetRegistry<ComponentType>("component_type") as ComponentTypeRegistry; // TODO: cast to typed wrapper

        public static UIRegistry UIRegistry =>
            GetRegistry<UIPanelInfo>("ui") as UIRegistry;
    }
}
```

**Key difference:** Godot `Autoload` (scene-tree singleton) → C# `static class` with static state. No Node lifecycle needed. Use `[RuntimeInitializeOnLoadMethod]` for initialization that requires the scene to be loaded.

#### ComponentTypeRegistry (`registry/component_type_registry.gd`)

```csharp
public class ComponentTypeRegistry : RegistryBase<ComponentType>
{
    public const string RegistryKey = "component_type";

    public void RegisterComponentType(ComponentType componentType) => Register(componentType.Id, componentType);
    public ComponentType GetComponentType(ResourceLocation id) => GetEntry(id);
    public ComponentType GetComponentType(string id) => GetEntry(ResourceLocation.FromString(id));
    public bool HasComponentType(ResourceLocation id) => HasEntry(id);
    public bool UnregisterComponentType(ResourceLocation id) => Unregister(id);
    public IReadOnlyDictionary<string, ComponentType> GetAllComponentTypes() => GetAllEntries();

    protected override bool ValidateEntry(ComponentType entry) => entry != null;
    protected override string GetExpectedTypeName() => nameof(ComponentType);
}
```

#### UIRegistry (`registry/ui_registry.gd`)

```csharp
public class UIPanelInfo
{
    public GameObject Prefab;
    public int DefaultLayer = UILayer.Normal;
    public UIPanel.CacheMode CacheMode = UIPanel.CacheMode.Destroy;
    public bool IsToast;
}

public class UIRegistry : RegistryBase<UIPanelInfo>
{
    public void RegisterPanel(ResourceLocation id, GameObject prefab,
        int defaultLayer = UILayer.Normal,
        UIPanel.CacheMode cacheMode = UIPanel.CacheMode.Destroy)
    {
        Register(id, new UIPanelInfo { Prefab = prefab, DefaultLayer = defaultLayer, CacheMode = cacheMode });
    }

    public void RegisterToast(ResourceLocation id, GameObject prefab)
    {
        Register(id, new UIPanelInfo { Prefab = prefab, DefaultLayer = UILayer.Toast, IsToast = true });
    }

    public UIPanel InstantiatePanel(ResourceLocation id)
    {
        var info = GetEntry(id);
        if (info?.Prefab == null) { Debug.LogError($"UIRegistry: panel not found: {id}"); return null; }
        var go = Object.Instantiate(info.Prefab);
        if (!go.TryGetComponent<UIPanel>(out var panel))
        {
            Debug.LogError($"UIRegistry: prefab root must have UIPanel component: {id}");
            Object.Destroy(go);
            return null;
        }
        panel.PanelId = id;
        panel.UILayer = info.DefaultLayer;
        panel.CacheModeValue = info.CacheMode;
        return panel;
    }

    public UIToast InstantiateToast(ResourceLocation id) { /* same pattern for UIToast */ }
}
```

---

### 3.8 Event System

#### Event / EventBus (`event/event.gd`, `autoload/event_bus.gd`)

**Godot source:** `Event` base (RefCounted, cancellable, `get_event_type()` by class_name), `EventBus` Node (subscribe/unsubscribe/publish, stale listener cleanup, signal bridging).

**Unity C# mapping:**

```csharp
// Event.cs
namespace MinecraftStyleFramework.Event
{
    public class Event
    {
        public bool IsCancelled { get; private set; }
        public void Cancel() => IsCancelled = true;
        public virtual string GetEventType() => GetType().Name;
    }

    // SignalEvent.cs - bridges UnityEvents/C# events to framework Event
    public class SignalEvent : Event
    {
        public WeakReference<UnityEngine.Object> SourceRef { get; }
        public string SignalName { get; }

        public SignalEvent(UnityEngine.Object source, string signalName)
        {
            SourceRef = new WeakReference<UnityEngine.Object>(source);
            SignalName = signalName;
        }

        public UnityEngine.Object GetSourceNode() =>
            SourceRef.TryGetTarget(out var target) && target ? target : null;

        public bool IsSourceValid() =>
            SourceRef.TryGetTarget(out var target) && target;
    }

    // Derived events follow same pattern (LanguageChangedEvent, UI*Events)
    public class LanguageChangedEvent : Event
    {
        public string LangCode { get; }
        public LanguageChangedEvent(string langCode) => LangCode = langCode;
    }

    public class UIOpenEvent : Event
    {
        public ResourceLocation PanelId { get; }
        public int Layer { get; }
        public UIOpenEvent(ResourceLocation panelId, int layer) { PanelId = panelId; Layer = layer; }
    }
    // ... same for UICloseEvent, UIPauseEvent, UIResumeEvent
}
```

```csharp
// EventBus.cs
namespace MinecraftStyleFramework.Event
{
    /// <summary>
    /// Static event bus singleton. Decoupled pub/sub.
    /// </summary>
    public static class EventBus
    {
        private static readonly Dictionary<string, List<(object owner, Action<Event> handler)>> Listeners = new();

        public static void Subscribe<T>(Action<T> listener) where T : Event
        {
            var eventType = typeof(T).Name;
            if (!Listeners.ContainsKey(eventType))
                Listeners[eventType] = new List<(object, Action<Event>)>();
            Listeners[eventType].Add((listener.Target, e => listener((T)e)));
        }

        public static void Unsubscribe<T>(Action<T> listener) where T : Event
        {
            var eventType = typeof(T).Name;
            if (Listeners.TryGetValue(eventType, out var list))
                list.RemoveAll(x => x.owner == listener.Target && /* match delegate */);
        }

        public static void Publish(Event evt)
        {
            var eventType = evt.GetEventType();
            if (!Listeners.TryGetValue(eventType, out var list)) return;

            // Iterate copy to allow modifications during iteration
            var copy = new List<(object, Action<Event>)>(list);
            var stale = new List<(object, Action<Event>)>();

            foreach (var (owner, handler) in copy)
            {
                // Clean up handlers from destroyed objects
                if (owner is UnityEngine.Object uObj && !uObj)
                {
                    stale.Add((owner, handler));
                    continue;
                }
                if (evt.IsCancelled) break;
                handler(evt);
            }

            // Remove stale
            foreach (var s in stale)
                list.Remove(s);
        }

        public static void ClearListeners(string eventType)
        {
            if (Listeners.TryGetValue(eventType, out var list))
                list.Clear();
        }

        public static void ClearAllListeners() => Listeners.Clear();
    }
}
```

**Key changes:**
- `StringName` → `string` (C# `typeof(T).Name`).
- `Callable` → `Action<T>` delegates.
- Godot signal bridging (`bind_signal`) is low-priority for Unity port; Unity `UnityEvent.AddListener()` + manual `Publish()` is the direct equivalent.
- `WeakRef` + `is_instance_valid()` → `WeakReference<T>` + `TryGetTarget()`.

---

### 3.9 Tag System (`tag/tag.gd`, `tag/tag_registry.gd`)

```csharp
// Tag.cs
namespace MinecraftStyleFramework.Tag
{
    /// <summary>
    /// Dynamically groups registry entries. Points to a parent registry type
    /// and tracks member entry IDs.
    /// </summary>
    public class Tag
    {
        public ResourceLocation RegistryType { get; }
        private readonly HashSet<string> _entries = new();

        public Tag(ResourceLocation registryType) => RegistryType = registryType;

        public void AddEntry(ResourceLocation entryId) => _entries.Add(entryId.ToString());
        public bool RemoveEntry(ResourceLocation entryId) => _entries.Remove(entryId.ToString());
        public bool HasEntry(ResourceLocation entryId) => _entries.Contains(entryId.ToString());
        public IReadOnlyCollection<string> GetAllEntries() => _entries;
        public int EntryCount => _entries.Count;
        public void ClearEntries() => _entries.Clear();
    }
}

// TagRegistry.cs
public class TagRegistry : RegistryBase<Tag>
{
    public Tag RegisterTag(ResourceLocation tagId, ResourceLocation registryType)
    {
        if (HasEntry(tagId))
        {
            Debug.LogWarning($"Tag already exists: {tagId}");
            return GetEntry(tagId);
        }
        var tag = new Tag(registryType);
        Register(tagId, tag);
        return tag;
    }

    public Tag GetTag(ResourceLocation tagId) => GetEntry(tagId);
    public void AddToTag(ResourceLocation tagId, ResourceLocation entryId) { ... }
    public bool RemoveFromTag(ResourceLocation tagId, ResourceLocation entryId) { ... }
    public bool HasEntryInTag(ResourceLocation tagId, ResourceLocation entryId) { ... }
    public IReadOnlyCollection<string> GetEntriesOfTag(ResourceLocation tagId) { ... }
    public bool DeleteTag(ResourceLocation tagId) => Unregister(tagId);
    public IEnumerable<ResourceLocation> GetAllTagIds() { ... }
}
```

**Key change:** `Dictionary<string, bool>` for set semantics → `HashSet<string>`.

---

### 3.10 Component System

#### ComponentType (`component/component_type.gd`)

```csharp
// ComponentType.cs
namespace MinecraftStyleFramework.Component
{
    public enum PersistentPolicy { None, Always, NonDefault }
    public enum NetworkSyncPolicy { None, Full, Tracked }

    public class ComponentType
    {
        public ResourceLocation Id { get; }
        public object Codec { get; } // ICodec — actual type depends on component value
        public PersistentPolicy Persistence { get; }
        public NetworkSyncPolicy NetworkSync { get; }
        private readonly Func<object> _defaultFactory;

        public ComponentType(ResourceLocation id, object codec,
            Func<object> defaultFactory = null,
            PersistentPolicy persistence = PersistentPolicy.NonDefault,
            NetworkSyncPolicy networkSync = NetworkSyncPolicy.None) { ... }

        public object GetDefaultValue() => _defaultFactory?.Invoke();

        public bool IsDefault(object value) { ... }

        // Builder pattern
        public class Builder
        {
            // Fluent API: .WithDefault(() => ...).Persistent(...).Network(...).Build()
        }
    }
}
```

#### ComponentContainer (`component/component_container.gd`)

```csharp
// ComponentContainer.cs
public class ComponentContainer
{
    private readonly Dictionary<string, object> _data = new();
    private readonly Dictionary<string, ComponentType> _types = new();

    public T GetComponent<T>(ComponentType type) { ... }
    public void SetComponent(ComponentType type, object value) { ... }
    public bool RemoveComponent(ComponentType type) { ... }
    public bool HasComponent(ComponentType type) { ... }
    public IEnumerable<string> GetComponentIds() => _data.Keys;
    public int Count => _data.Count;
    public void Clear() { _data.Clear(); _types.Clear(); }

    // Serialization
    public DataResult<object> Encode(DynamicOps ops) { /* with persistence policy filtering */ }
    public DataResult<ComponentContainer> Decode(object data, DynamicOps ops, object typeRegistry = null) { ... }

    // Patch/Merge
    public void ApplyPatch(ComponentContainer patch) { ... }
    public void Merge(ComponentContainer other) { ... }
    public ComponentContainer Duplicate() { ... }
}
```

#### ComponentHost (`component/component_host.gd`)

```csharp
// ComponentHost.cs
public static class ComponentHost
{
    // Unity: use a dedicated MonoBehaviour component to hold the container
    // or attach via a wrapper class.

    // Option A: Require a ComponentContainerBehaviour on the GameObject
    public static ComponentContainer GetOrCreate(GameObject host)
    {
        var behaviour = host.GetComponent<ComponentContainerBehaviour>();
        if (behaviour == null)
            behaviour = host.AddComponent<ComponentContainerBehaviour>();
        return behaviour.Container;
    }

    // Or Option B: pure data approach using a dictionary keyed by GameObject instance ID
    private static readonly Dictionary<int, ComponentContainer> ContainerMap = new();

    public static ComponentContainer GetOrCreate(UnityEngine.Object host) { ... }
    public static ComponentContainer GetContainer(UnityEngine.Object host) { ... }
    public static void SetContainer(UnityEngine.Object host, ComponentContainer container) { ... }
    public static void RemoveContainer(UnityEngine.Object host) { ... }

    // Convenience methods
    public static T GetComponent<T>(UnityEngine.Object host, ComponentType type) { ... }
    public static void SetComponent(UnityEngine.Object host, ComponentType type, object value) { ... }
    public static bool HasComponent(UnityEngine.Object host, ComponentType type) { ... }
}

// Helper MonoBehaviour to attach containers to GameObjects
public class ComponentContainerBehaviour : MonoBehaviour
{
    public ComponentContainer Container { get; private set; } = new ComponentContainer();
}
```

**Key difference from Godot:** In Godot, `meta` (dynamic metadata on any `Object`) is used for attachment. Unity doesn't have an equivalent — use either:
- A dedicated `MonoBehaviour` component (cleaner, visible in Inspector).
- A static `Dictionary<int, ComponentContainer>` keyed by instance ID (lighter, invisible).

---

### 3.11 I18N System (`autoload/i18n_manager.gd`)

**Godot source:** Uses `TranslationServer` for locale switching and `tr()` for lookups. Recursively flattens nested JSON into dotted keys. Placeholder substitution via `"{0}".format(args)`.

**Unity C# mapping:**

```csharp
// I18NManager.cs
namespace MinecraftStyleFramework.I18N
{
    /// <summary>
    /// JSON-based internationalization with nested key flattening and placeholder substitution.
    /// Uses Unity's Localization package as backend, or can operate standalone.
    /// </summary>
    public static class I18NManager
    {
        private static readonly Dictionary<string, Dictionary<string, string>> LangData = new();

        public static bool LoadTranslation(string langCode, string filePath)
        {
            // Read JSON, flatten nested keys, store in LangData[langCode]
            // Uses Unity's Resources.Load<TextAsset>(filePath) or Addressables
        }

        public static void SetLanguage(string langCode)
        {
            // Switch current locale
            EventBus.Publish(new LanguageChangedEvent(langCode));
        }

        public static string GetCurrentLanguage() { ... }

        /// <summary>
        /// Get translated text with optional placeholder substitution {0}, {1}, etc.
        /// </summary>
        public static string GetText(string key, params object[] args)
        {
            // Lookup in current language data
            // Apply string.Format(text, args) for placeholder substitution
        }
    }
}
```

**Recommendation:** Integrate with Unity's [Localization Package](https://docs.unity3d.com/Packages/com.unity.localization@latest) for production use. The custom `I18NManager` provides a compatible API wrapper.

---

### 3.12 UI Framework

#### UILayer (`ui/ui_layer.gd`)

```csharp
// UILayer.cs
public static class UILayer
{
    public const int Scene  = 0;    // In-scene UI (damage numbers, nameplates)
    public const int Normal = 100;  // Full-screen panels (inventory, map, shop)
    public const int Popup  = 200;  // Popup dialogs (confirm, alert)
    public const int Toast  = 300;  // Toast notifications (auto-dismiss)
    public const int System = 400;  // System-level (loading screen, disconnect)

    public static readonly int[] AllLayers = { Scene, Normal, Popup, Toast, System };
}
```

#### UIPanel (`ui/ui_panel.gd`)

```csharp
// UIPanel.cs
public abstract class UIPanel : MonoBehaviour
{
    public ResourceLocation PanelId { get; set; }
    public int UILayer { get; set; } = UILayer.Normal;

    public enum CacheMode { Destroy, Cache }
    public CacheMode CacheModeValue { get; set; } = CacheMode.Destroy;

    // Lifecycle callbacks (virtual, override in subclasses)
    public virtual void OnInit() { }
    public virtual void OnOpen(Dictionary<string, object> data) { }
    public virtual void OnPause() { }
    public virtual void OnResume() { }
    public virtual void OnClose() { }
    public virtual void OnDestroy() { } // Called before actual Destroy when CacheMode.Destroy
}
```

#### UIToast (`ui/ui_toast.gd`)

```csharp
// UIToast.cs
public abstract class UIToast : MonoBehaviour
{
    public ResourceLocation ToastId { get; set; }
    public float Duration { get; set; } = 3.0f;

    public event Action Dismissed; // UnityEvent or C# event

    private float _remaining;
    private bool _timing;

    public void StartDismissTimer(float duration) { Duration = duration; _remaining = duration; _timing = true; }

    protected virtual void Update()
    {
        if (!_timing) return;
        _remaining -= Time.deltaTime;
        if (_remaining <= 0) { _timing = false; OnDismiss(); Dismissed?.Invoke(); }
    }

    public virtual void OnShow(Dictionary<string, object> data) { }
    public virtual void OnDismiss() { }
}
```

#### UIManager (`autoload/ui_manager.gd`)

```csharp
// UIManager.cs
public class UIManager : MonoBehaviour
{
    public static UIManager Instance { get; private set; }

    // Constants matching Godot source
    private const int MaxOpenDepth = 8;
    private const int MaxCachedPanels = 10;

    // Panel stacks per layer
    private Dictionary<int, List<UIPanel>> _panelStacks = new();
    // Active panel lookup O(1)
    private Dictionary<string, int> _activePanelIds = new();
    // LRU cache
    private Dictionary<string, UIPanel> _cachedPanels = new();
    private LinkedList<string> _cacheOrder = new();
    // Overlays
    private Dictionary<string, (GameObject overlay, int layer)> _overlays = new();
    // Toasts
    private List<UIToast> _activeToasts = new();
    // Popup queue
    private List<(ResourceLocation panelId, Dictionary<string, object> data, int priority)> _popupQueue = new();
    // Canvas layers
    private Dictionary<int, Canvas> _layerNodes = new();
    // Dimmer backgrounds
    private Dictionary<int, UnityEngine.UI.Image> _dimmers = new();
    // Recursion guard
    private int _openDepth;

    private void Awake()
    {
        if (Instance != null) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
        foreach (var layer in UILayer.AllLayers) EnsureLayer(layer);
    }

    private void Update() => _openDepth = 0;

    public UIPanel OpenPanel(ResourceLocation id, Dictionary<string, object> data = null, int layerOverride = -1) { ... }
    public void Back(int layer = UILayer.Normal) { ... }
    public void ClosePanel(ResourceLocation id) { ... }
    public void CloseAll(int layer = -1) { ... }
    public UIPanel GetTopPanel(int layer = UILayer.Normal) { ... }
    public bool IsPanelOpen(ResourceLocation id) { ... }

    // Overlays
    public void AddOverlay(ResourceLocation id, GameObject overlay, int layer = UILayer.Scene) { ... }
    public void RemoveOverlay(ResourceLocation id) { ... }
    public void SetOverlayVisible(ResourceLocation id, bool visible) { ... }

    // Toast
    public UIToast ShowToast(ResourceLocation toastId, Dictionary<string, object> data = null, float duration = 3.0f) { ... }
    public void DismissToast(UIToast toast) { ... }
    public void DismissAllToasts() { ... }

    // Popup queue
    public void QueuePopup(ResourceLocation panelId, Dictionary<string, object> data = null, int priority = 0) { ... }
}
```

**Key differences:**
- Godot `CanvasLayer` → Unity `Canvas` with `sortingOrder` for layer stacking.
- Godot `ColorRect` background dimmer → Unity `Image` component with semi-transparent black color.
- Godot `CanvasLayer.layer` → Unity `Canvas.sortingOrder` (map layer constants: Scene=0, Normal=100, Popup=200, Toast=300, System=400).
- Godot `add_child()` / `remove_child()` → Unity `Transform.SetParent()` and `Destroy()`.
- Godot `queue_free()` → Unity `Destroy(gameObject)`.

---

### 3.13 Editor Support

#### Plugin Entry (`mc_game_framework.gd`)

**Godot source:** `@tool extends EditorPlugin` registers 4 autoloads + 2 inspector plugins.

**Unity C# mapping:** Two aspects:

1. **Runtime autoload equivalents** — handled by static classes (RegistryManager, EventBus, I18NManager) and a `[RuntimeInitializeOnLoadMethod]` for UIManager which needs a MonoBehaviour.

2. **Editor inspectors** — Unity `PropertyDrawer` or custom `Editor`:

```csharp
// CodecResourceInspector.cs (Editor-only)
[CustomEditor(typeof(CodecResource), true)]
public class CodecResourceInspector : Editor
{
    public override void OnInspectorGUI()
    {
        var res = (CodecResource)target;
        EditorGUILayout.LabelField("Type ID", res.GetTypeId());

        if (GUILayout.Button("Validate with Codec"))
        {
            var result = res.EncodeWith(JsonOps.Instance);
            // Show result in console / dialog
        }

        DrawDefaultInspector();
    }
}

// ComponentInspector.cs (Editor-only)
[CustomEditor(typeof(ComponentContainerBehaviour), true)]
public class ComponentInspector : Editor
{
    public override void OnInspectorGUI()
    {
        var behaviour = (ComponentContainerBehaviour)target;
        var container = behaviour.Container;

        EditorGUILayout.LabelField($"Data Components ({container.Count})", EditorStyles.boldLabel);

        foreach (var id in container.GetComponentIds())
        {
            var type = container.GetType(id);
            var value = container.GetRawData(id);

            EditorGUILayout.LabelField(id, EditorStyles.boldLabel);
            EditorGUILayout.LabelField("  Value", value?.ToString() ?? "null");

            if (type != null)
            {
                var isDefault = type.IsDefault(value);
                EditorGUILayout.LabelField("  Default", isDefault ? "Yes (default)" : "No (modified)");
                EditorGUILayout.LabelField("  Persistent", type.Persistence.ToString());
                EditorGUILayout.LabelField("  Network", type.NetworkSync.ToString());
            }

            EditorGUILayout.Separator();
        }
    }
}
```

---

### 3.14 Testing

**Godot source:** 130 GUT tests (GdUnit/GUT framework), 9 test files.

**Unity C# mapping:** Unity Test Framework (UTF) with NUnit.

```csharp
// TestResourceLocation.cs
using NUnit.Framework;
using MinecraftStyleFramework.Utils;

public class TestResourceLocation
{
    [Test]
    public void Parse_ValidNamespacePath_ReturnsSuccess()
    {
        var r = ResourceLocation.Parse("minecraft:stone");
        Assert.IsTrue(r.IsSuccess);
        Assert.AreEqual("minecraft", r.Value.NamespaceId);
        Assert.AreEqual("stone", r.Value.Path);
    }

    [Test]
    public void Parse_InvalidUppercase_ReturnsError()
    {
        var r = ResourceLocation.Parse("Minecraft:Stone");
        Assert.IsTrue(r.IsError);
    }

    [Test]
    public void FromString_EmptyString_ReturnsNull()
    {
        var r = ResourceLocation.FromString("");
        Assert.IsNull(r);
    }
}
```

| Godot Test File | Unity Test File |
|---|---|
| `test_resource_location.gd` | `TestResourceLocation.cs` |
| `test_codec.gd` | `TestCodec.cs` |
| `test_data_result.gd` | `TestDataResult.cs` |
| `test_event.gd` + `test_event_bus.gd` | `TestEvent.cs` + `TestEventBus.cs` |
| `test_registry_base.gd` | `TestRegistryBase.cs` |
| `test_tag_system.gd` | `TestTagSystem.cs` |
| `test_component_system.gd` | `TestComponentSystem.cs` |
| `test_ui_framework.gd` | `TestUIFramework.cs` |

Run via: `Unity Test Runner` window or CLI: `unity -runTests -projectPath . -testResults results.xml`

---

## 4. Migration Order (Recommended)

| Phase | Subsystems | Rationale |
|---|---|---|
| **1** | `ResourceLocation` + `DataResult` | Foundation — all other systems depend on these |
| **2** | `DynamicOps` + `JsonOps` + `UnityResourceOps` | Carrier abstraction needed before Codec |
| **3** | `Codec` + `MapCodec` (all combinators) | Static factories, combinators, primitive codecs |
| **4** | `RegistryBase` + `RegistryManager` | Meta-registry before dependent registries |
| **5** | `Event` + `EventBus` | Event types then publish/subscribe bus |
| **6** | `Tag` + `TagRegistry` | Depends on Registry + ResourceLocation |
| **7** | `ComponentType` + `ComponentContainer` + `ComponentHost` | Depends on Codec + Registry |
| **8** | `CodecResource` | Depends on Codec + UnityResourceOps |
| **9** | `UILayer` + `UIPanel` + `UIToast` + `UIManager` + `UIRegistry` | Depends on EventBus + Registry |
| **10** | `I18NManager` | Depends on EventBus |
| **11** | Editor inspectors | Depends on CodecResource + ComponentHost |
| **12** | Tests (ported alongside each phase) | 130 tests, ported incrementally |

---

## 5. Critical Design Decisions

### 5.1 Singleton Pattern
**Godot:** Autoload singletons live in the scene tree as Nodes.  
**Unity:** Use `static class` where possible (EventBus, RegistryManager, I18NManager). For UIManager (requires MonoBehaviour for Canvas/GameObject management), use `DontDestroyOnLoad` + `Instance` pattern with `Awake()` guard.

### 5.2 Variant vs Generics
**Godot:** `Variant` is a dynamic union type. Dictionary keys are weakly typed.  
**Unity C#:** Strongly typed generics (`DataResult<T>`, `Codec<T>`, `RegistryBase<T>`). This reduces runtime errors but requires more type parameters in the API. The `EitherCodec` and `DispatchCodec` must use `object` as the common type since they resolve at runtime.

### 5.3 Resource Persistence
**Godot:** `.tres`/`.res` (text/binary Godot Resource format).  
**Unity:** `.asset` (ScriptableObject serialized by Unity). Editor-only for `AssetDatabase.CreateAsset()`; use `Resources.Load()` or Addressables for runtime. The `GodotResourceOps.save_resource()` and `load_resource()` calls are editor-only in Unity.

### 5.4 Scene/Prefab Instantiation
**Godot:** `PackedScene.instantiate()` returns a Node.  
**Unity:** `Instantiate(prefab)` returns a GameObject clone. Equivalent but note that Unity prefabs require `.GetComponent<T>()` to retrieve the script, while Godot's typed scene instantiation directly returns a typed node.

### 5.5 Signal Bridging
**Godot:** `EventBus.bind_signal(signal, factory)` converts Godot signals to framework events.  
**Unity:** Use `UnityEvent.AddListener(() => EventBus.Publish(...))` or C# `event` + handler that calls `EventBus.Publish()`. This is simpler in Unity since UnityEvents already support lambda attachment.

### 5.6 Regex
**Godot:** `RegEx.new()` + `.compile()`.  
**Unity C#:** `System.Text.RegularExpressions.Regex` with `RegexOptions.Compiled`. The pattern syntax is identical (both use PCRE-compatible regex).

### 5.7 JSON Processing
**Godot:** Built-in `JSON.parse_string()` / `JSON.stringify()`.  
**Unity:** `Newtonsoft.Json` (Json.NET) is recommended for its `JToken`/`JObject`/`JArray` types which closely match the Godot Variant model. The built-in `JsonUtility` is simpler but cannot handle nested dictionaries without wrapper classes.

---

## 6. File Count Summary

| Directory | Godot Files (.gd) | Unity C# Files (.cs) |
|---|---|---|
| Utils | 1 | 1 |
| Registry | 3 | 3 |
| Event + Event/UI | 7 | 7 |
| Codec/Core | 3 | 3 |
| Codec/Ops | 2 | 2 |
| Component | 3 | 3 (+1 helper MonoBehaviour) |
| Tag | 2 | 2 |
| I18N | 1 | 1 |
| UI | 4 | 4 |
| Editor | 2 | 2 |
| Plugin Entry | 1 | N/A (replaced by asmdef + static init) |
| **Framework Total** | **29** | **~28** |
| Tests | 9 | 9 |
| Demo | 1 | 1 |
| **Grand Total** | **39** | **~38** |

---

## 7. API Breaking Changes (from GDScript to C#)

1. **ResourceLocation as dictionary key:** Godot requires `.to_string()` for Dictionary keys. C# uses `IEquatable<>` + overridden `Equals`/`GetHashCode` — use the object directly.
2. **DataResult is generic:** `DataResult` → `DataResult<T>`. Static helpers in non-generic `DataResult` class for type inference.
3. **Codec is generic:** `Codec` → `Codec<T>`. Static factory in non-generic `Codec` class.
4. **MapCodec is generic:** `MapCodec` → `MapCodec<T>`.
5. **`Callable` → `Func<>`/`Action`:** All callback parameters change to typed delegates.
6. **`Array` (untyped) → `List<T>`:** All collection types are explicitly typed.
7. **`push_warning()` / `push_error()` → `Debug.LogWarning()` / `Debug.LogError()`.**
8. **`print()` → `Debug.Log()`.**
