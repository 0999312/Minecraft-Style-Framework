using System.Collections.Generic;
using MinecraftStyleFramework.Codec;
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Components
{
    /// <summary>
    /// Container that holds component values for an object.
    /// </summary>
    public class ComponentContainer
    {
        private readonly Dictionary<ResourceLocation, object> _components = new();

        /// <summary>Set a component value.</summary>
        public void Set(ComponentType type, object value)
        {
            if (type == null) return;
            _components[type.Id] = value;
        }

        /// <summary>Get a component value.</summary>
        public object Get(ComponentType type)
        {
            if (type == null) return null;
            return _components.TryGetValue(type.Id, out var value) ? value : type.GetDefault();
        }

        /// <summary>Get a component value with type casting.</summary>
        public T Get<T>(ComponentType type)
        {
            var value = Get(type);
            if (value is T typed) return typed;
            return default;
        }

        /// <summary>Check if a component is set.</summary>
        public bool Has(ComponentType type) => type != null && _components.ContainsKey(type.Id);

        /// <summary>Remove a component.</summary>
        public bool Remove(ComponentType type) => type != null && _components.Remove(type.Id);

        /// <summary>Get all component IDs.</summary>
        public IEnumerable<ResourceLocation> GetAllIds() => _components.Keys;

        /// <summary>Encode all components to the given DynamicOps format.</summary>
        public DataResult<object> Encode(DynamicOps ops, ComponentTypeRegistry registry = null)
        {
            registry ??= RegistryManager.Instance.GetRegistry<ComponentTypeRegistry>(ComponentTypeRegistry.RegistryKey);
            if (registry == null)
                return DataResult<object>.Error("ComponentTypeRegistry not found");

            var entries = new Dictionary<string, object>();
            foreach (var kv in _components)
            {
                var componentType = registry.GetComponentType(kv.Key);
                if (componentType == null) continue;
                if (componentType.Persistence == PersistentPolicy.None) continue;
                if (componentType.Persistence == PersistentPolicy.NonDefault)
                {
                    var defaultVal = componentType.GetDefault();
                    if (Equals(kv.Value, defaultVal)) continue;
                }

                var encoded = componentType.Codec.Encode(kv.Value, ops);
                if (encoded.IsSuccess || encoded.IsPartial)
                    entries[kv.Key.ToString()] = encoded.Value;
            }

            return DataResult<object>.Success(ops.CreateMap(entries));
        }

        /// <summary>Decode components from the given DynamicOps format.</summary>
        public DataResult<ComponentContainer> Decode(object data, DynamicOps ops, ComponentTypeRegistry registry = null)
        {
            registry ??= RegistryManager.Instance.GetRegistry<ComponentTypeRegistry>(ComponentTypeRegistry.RegistryKey);
            if (registry == null)
                return DataResult<ComponentContainer>.Error("ComponentTypeRegistry not found");

            var mapEntries = ops.GetMapEntries(data);
            if (mapEntries.IsError)
                return DataResult<ComponentContainer>.Error(mapEntries.ErrorMessage);

            var diagnostics = new List<Diagnostic>();
            foreach (var kv in mapEntries.Value)
            {
                var id = ResourceLocation.FromString(kv.Key);
                if (id == null)
                {
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Warning, $"Invalid component ID: {kv.Key}"));
                    continue;
                }

                var componentType = registry.GetComponentType(id);
                if (componentType == null)
                {
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Warning, $"Unknown component type: {id}"));
                    continue;
                }

                var decoded = componentType.Codec.Decode(kv.Value, ops);
                if (decoded.IsError)
                {
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Recoverable, $"Failed to decode component '{id}': {decoded.ErrorMessage}"));
                    continue;
                }

                _components[id] = decoded.Value;
                diagnostics.AddRange(decoded.Diagnostics);
            }

            var result = diagnostics.Count > 0
                ? DataResult<ComponentContainer>.Partial(this, "Some components failed to decode")
                : DataResult<ComponentContainer>.Success(this);
            result.Diagnostics.AddRange(diagnostics);
            return result;
        }
    }
}
