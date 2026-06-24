using MinecraftStyleFramework.Components;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Registry for ComponentType instances. Integrated via RegistryManager.
    /// </summary>
    public class ComponentTypeRegistry
    {
        public const string RegistryKey = "component_type";

        private readonly RegistryBase<ComponentType> _inner = new();

        /// <summary>Register a component type.</summary>
        public void RegisterComponentType(ComponentType componentType)
        {
            if (componentType == null)
            {
                UnityEngine.Debug.LogError("ComponentTypeRegistry: componentType must not be null");
                return;
            }

            _inner.Register(componentType.Id, componentType);
        }

        /// <summary>Get a component type by ID.</summary>
        public ComponentType GetComponentType(ResourceLocation id) => _inner.GetEntry(id);

        /// <summary>Get a component type by string ID.</summary>
        public ComponentType GetComponentType(string idStr)
        {
            var id = ResourceLocation.FromString(idStr);
            return id != null ? _inner.GetEntry(id) : null;
        }

        /// <summary>Check if a component type exists.</summary>
        public bool HasComponentType(ResourceLocation id) => _inner.HasEntry(id);

        /// <summary>Remove a component type.</summary>
        public bool UnregisterComponentType(ResourceLocation id) => _inner.Unregister(id);

        /// <summary>Get all component types.</summary>
        public System.Collections.Generic.IReadOnlyDictionary<ResourceLocation, ComponentType> GetAll() =>
            _inner.GetAllEntries();
    }
}
