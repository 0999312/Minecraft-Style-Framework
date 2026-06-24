using System.Collections.Generic;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Tags
{
    /// <summary>
    /// Tag for dynamic grouping of registry entries without modifying their implementation.
    /// </summary>
    public class Tag
    {
        /// <summary>The registry this tag applies to.</summary>
        public ResourceLocation RegistryId { get; }

        private readonly HashSet<ResourceLocation> _entries = new();

        public Tag(ResourceLocation registryId)
        {
            RegistryId = registryId;
        }

        /// <summary>Add an entry to this tag.</summary>
        public void AddEntry(ResourceLocation id)
        {
            if (id != null)
            {
                _entries.Add(id);
            }
        }

        /// <summary>Remove an entry from this tag.</summary>
        public bool RemoveEntry(ResourceLocation id) => _entries.Remove(id);

        /// <summary>Check if an entry belongs to this tag.</summary>
        public bool HasEntry(ResourceLocation id) => _entries.Contains(id);

        /// <summary>Get all entries in this tag.</summary>
        public IReadOnlyCollection<ResourceLocation> GetEntries() => _entries;

        /// <summary>Number of entries in this tag.</summary>
        public int Count => _entries.Count;

        /// <summary>Clear all entries.</summary>
        public void Clear() => _entries.Clear();
    }
}
