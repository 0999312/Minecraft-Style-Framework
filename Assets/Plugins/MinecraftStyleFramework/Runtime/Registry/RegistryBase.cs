using System.Collections.Generic;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Base registry class for centralized game data management.
    /// Stores entries keyed by ResourceLocation.
    /// </summary>
    public class RegistryBase<T> where T : class
    {
        private readonly Dictionary<ResourceLocation, T> _entries = new();

        /// <summary>Register an entry.</summary>
        public virtual void Register(ResourceLocation id, T entry)
        {
            if (id == null || entry == null)
            {
                return;
            }

            if (!ValidateEntry(entry))
            {
                UnityEngine.Debug.LogError($"Registry entry validation failed for '{id}': expected type {GetExpectedTypeName()}");
                return;
            }

            if (_entries.ContainsKey(id))
            {
                UnityEngine.Debug.LogWarning($"Overwriting registry entry: {id}");
            }

            _entries[id] = entry;
        }

        /// <summary>Unregister an entry.</summary>
        public bool Unregister(ResourceLocation id) => _entries.Remove(id);

        /// <summary>Get an entry by ID.</summary>
        public T GetEntry(ResourceLocation id) =>
            _entries.TryGetValue(id, out var entry) ? entry : null;

        /// <summary>Check if an entry exists.</summary>
        public bool HasEntry(ResourceLocation id) => _entries.ContainsKey(id);

        /// <summary>Get all entries.</summary>
        public IReadOnlyDictionary<ResourceLocation, T> GetAllEntries() => _entries;

        /// <summary>Get all registered keys.</summary>
        public IEnumerable<ResourceLocation> GetAllKeys() => _entries.Keys;

        /// <summary>Clear all entries.</summary>
        public void Clear() => _entries.Clear();

        /// <summary>Entry count.</summary>
        public int Count => _entries.Count;

        /// <summary>Override to validate entries before registration.</summary>
        protected virtual bool ValidateEntry(T entry) => true;

        /// <summary>Override to provide expected type name for error messages.</summary>
        protected virtual string GetExpectedTypeName() => typeof(T).Name;
    }

    /// <summary>
    /// Non-generic registry base that stores entries as object.
    /// Used when entry types are heterogeneous.
    /// </summary>
    public class RegistryBase : RegistryBase<object>
    {
    }
}
