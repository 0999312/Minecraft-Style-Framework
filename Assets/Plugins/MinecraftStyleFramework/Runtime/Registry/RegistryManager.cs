using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Meta-registry that manages all registry instances.
    /// Singleton accessed via RegistryManager.Instance.
    /// </summary>
    public sealed class RegistryManager
    {
        private const string RegistryNamespace = "core";

        private static RegistryManager _instance;
        public static RegistryManager Instance => _instance ??= new RegistryManager();

        private readonly RegistryBase _registry = new();

        /// <summary>Register a registry instance.</summary>
        public void RegisterRegistry(string typeName, object registry)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            _registry.Register(id, registry);
        }

        /// <summary>Get a registry by type name.</summary>
        public T GetRegistry<T>(string typeName) where T : class
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return _registry.GetEntry(id) as T;
        }

        /// <summary>Get a registry by type name (untyped).</summary>
        public object GetRegistry(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return _registry.GetEntry(id);
        }

        /// <summary>Check if a registry exists.</summary>
        public bool HasRegistry(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return _registry.HasEntry(id);
        }

        /// <summary>Remove a registry.</summary>
        public bool UnregisterRegistry(string typeName)
        {
            var id = new ResourceLocation(RegistryNamespace, typeName);
            return _registry.Unregister(id);
        }

        /// <summary>Reset the singleton (useful for testing).</summary>
        public static void Reset() => _instance = new RegistryManager();
    }
}
