using System.Runtime.CompilerServices;

namespace MinecraftStyleFramework.Components
{
    /// <summary>
    /// Static utility for attaching ComponentContainers to arbitrary objects.
    /// Uses weak associations to avoid memory leaks.
    /// </summary>
    public static class ComponentHost
    {
        private static readonly ConditionalWeakTable<object, ComponentContainer> Containers = new();

        /// <summary>Set a component value on an object.</summary>
        public static void SetComponent(object target, ComponentType type, object value)
        {
            var container = GetOrCreateContainer(target);
            container?.Set(type, value);
        }

        /// <summary>Get a component value from an object.</summary>
        public static object GetComponent(object target, ComponentType type)
        {
            var container = GetContainer(target);
            return container?.Get(type) ?? type?.GetDefault();
        }

        /// <summary>Get a typed component value from an object.</summary>
        public static T GetComponent<T>(object target, ComponentType type)
        {
            var container = GetContainer(target);
            if (container != null) return container.Get<T>(type);
            var def = type?.GetDefault();
            if (def is T typed) return typed;
            return default;
        }

        /// <summary>Check if an object has a specific component.</summary>
        public static bool HasComponent(object target, ComponentType type)
        {
            var container = GetContainer(target);
            return container?.Has(type) ?? false;
        }

        /// <summary>Remove a component from an object.</summary>
        public static bool RemoveComponent(object target, ComponentType type)
        {
            var container = GetContainer(target);
            return container?.Remove(type) ?? false;
        }

        /// <summary>Get the container for an object.</summary>
        public static ComponentContainer GetContainer(object target)
        {
            if (target == null) return null;
            return Containers.TryGetValue(target, out var container) ? container : null;
        }

        /// <summary>Get or create a container for an object.</summary>
        public static ComponentContainer GetOrCreateContainer(object target)
        {
            if (target == null) return null;
            return Containers.GetOrCreateValue(target);
        }

        /// <summary>Remove the entire container for an object (cleanup).</summary>
        public static void RemoveContainer(object target)
        {
            if (target == null) return;
            Containers.Remove(target);
        }
    }
}
