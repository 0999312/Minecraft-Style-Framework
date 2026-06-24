using System.Collections.Generic;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Tags
{
    /// <summary>
    /// Registry for managing tags. Tags are grouped by their target registry.
    /// </summary>
    public class TagRegistry
    {
        private readonly Dictionary<ResourceLocation, Tag> _tags = new();

        /// <summary>Register a tag.</summary>
        public void RegisterTag(ResourceLocation tagId, Tag tag)
        {
            if (tagId == null || tag == null)
            {
                return;
            }

            _tags[tagId] = tag;
        }

        /// <summary>Get a tag by ID.</summary>
        public Tag GetTag(ResourceLocation tagId) =>
            _tags.TryGetValue(tagId, out var tag) ? tag : null;

        /// <summary>Check if a tag exists.</summary>
        public bool HasTag(ResourceLocation tagId) => _tags.ContainsKey(tagId);

        /// <summary>Remove a tag.</summary>
        public bool RemoveTag(ResourceLocation tagId) => _tags.Remove(tagId);

        /// <summary>Get all tags.</summary>
        public IReadOnlyDictionary<ResourceLocation, Tag> GetAllTags() => _tags;

        /// <summary>
        /// Get all tags that contain the specified entry.
        /// </summary>
        public List<Tag> GetTagsForEntry(ResourceLocation entryId)
        {
            var result = new List<Tag>();
            foreach (var tag in _tags.Values)
            {
                if (tag.HasEntry(entryId))
                {
                    result.Add(tag);
                }
            }

            return result;
        }
    }
}
