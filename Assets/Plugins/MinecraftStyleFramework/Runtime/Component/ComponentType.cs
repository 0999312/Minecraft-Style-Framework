using System;
using MinecraftStyleFramework.Codec;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Components
{
    /// <summary>Persistence policy for component data.</summary>
    public enum PersistentPolicy { None, Always, NonDefault }

    /// <summary>Network sync hint for component data.</summary>
    public enum NetworkSyncTag { None, Full, Tracked }

    /// <summary>
    /// Defines a component type that can be attached to any object.
    /// </summary>
    public sealed class ComponentType
    {
        public ResourceLocation Id { get; }
        public Codec<object> Codec { get; }
        public Func<object> DefaultFactory { get; }
        public PersistentPolicy Persistence { get; }
        public NetworkSyncTag NetworkSync { get; }

        private ComponentType(
            ResourceLocation id,
            Codec<object> codec,
            Func<object> defaultFactory,
            PersistentPolicy persistence,
            NetworkSyncTag networkSync)
        {
            Id = id;
            Codec = codec;
            DefaultFactory = defaultFactory;
            Persistence = persistence;
            NetworkSync = networkSync;
        }

        /// <summary>Get the default value for this component type.</summary>
        public object GetDefault() => DefaultFactory?.Invoke();

        /// <summary>Builder for creating ComponentType instances.</summary>
        public class Builder
        {
            private readonly ResourceLocation _id;
            private readonly Codec<object> _codec;
            private Func<object> _defaultFactory;
            private PersistentPolicy _persistence = PersistentPolicy.None;
            private NetworkSyncTag _networkSync = NetworkSyncTag.None;

            public Builder(ResourceLocation id, Codec<object> codec)
            {
                _id = id ?? throw new ArgumentNullException(nameof(id));
                _codec = codec ?? throw new ArgumentNullException(nameof(codec));
            }

            public Builder WithDefault(Func<object> factory)
            {
                _defaultFactory = factory;
                return this;
            }

            public Builder Persistent(PersistentPolicy policy)
            {
                _persistence = policy;
                return this;
            }

            public Builder WithNetworkSync(NetworkSyncTag sync)
            {
                _networkSync = sync;
                return this;
            }

            public ComponentType Build() =>
                new(_id, _codec, _defaultFactory, _persistence, _networkSync);
        }
    }
}
