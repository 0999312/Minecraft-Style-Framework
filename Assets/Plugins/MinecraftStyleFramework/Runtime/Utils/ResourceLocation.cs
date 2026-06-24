using System;
using System.Text.RegularExpressions;
using MinecraftStyleFramework.Codec;

namespace MinecraftStyleFramework.Utils
{
    /// <summary>
    /// Minecraft-style resource identifier (namespace:path).
    /// Immutable value type for use as dictionary key.
    /// </summary>
    public sealed class ResourceLocation : IEquatable<ResourceLocation>
    {
        private static readonly Regex NamespacePattern = new("^[a-z0-9_\\-.]+$", RegexOptions.Compiled);
        private static readonly Regex PathPattern = new("^[a-z0-9_\\-./]+$", RegexOptions.Compiled);

        public string Namespace { get; }
        public string Path { get; }
        private readonly string _cached;
        private readonly int _hashCode;

        public ResourceLocation(string ns, string path)
        {
            Namespace = ns ?? throw new ArgumentNullException(nameof(ns));
            Path = path ?? throw new ArgumentNullException(nameof(path));
            _cached = $"{ns}:{path}";
            _hashCode = HashCode.Combine(ns, path);
        }

        /// <summary>
        /// Parse without strict validation (backward-compatible).
        /// Returns null on invalid format.
        /// </summary>
        public static ResourceLocation FromString(string locationStr)
        {
            if (string.IsNullOrEmpty(locationStr)) return null;
            var idx = locationStr.IndexOf(':');
            if (idx < 0) return null;
            var ns = locationStr.Substring(0, idx);
            var path = locationStr.Substring(idx + 1);
            if (string.IsNullOrEmpty(ns) || string.IsNullOrEmpty(path)) return null;
            return new ResourceLocation(ns, path);
        }

        /// <summary>
        /// Strict Mojang-style validation. Returns DataResult with validation errors.
        /// </summary>
        public static DataResult<ResourceLocation> Parse(string locationStr)
        {
            if (string.IsNullOrEmpty(locationStr))
                return DataResult<ResourceLocation>.Error("ResourceLocation: empty string");
            var idx = locationStr.IndexOf(':');
            if (idx < 0)
                return DataResult<ResourceLocation>.Error($"Invalid ResourceLocation format (missing ':'): {locationStr}");
            var ns = locationStr.Substring(0, idx);
            var path = locationStr.Substring(idx + 1);
            if (string.IsNullOrEmpty(ns) || string.IsNullOrEmpty(path))
                return DataResult<ResourceLocation>.Error($"ResourceLocation namespace and path must not be empty: {locationStr}");
            var nsResult = ValidateNamespace(ns);
            if (nsResult.IsError) return DataResult<ResourceLocation>.Error(nsResult.ErrorMessage);
            var pathResult = ValidatePath(path);
            if (pathResult.IsError) return DataResult<ResourceLocation>.Error(pathResult.ErrorMessage);
            return DataResult<ResourceLocation>.Success(new ResourceLocation(ns, path));
        }

        public static DataResult<string> ValidateNamespace(string ns)
        {
            if (string.IsNullOrEmpty(ns))
                return DataResult<string>.Error("ResourceLocation namespace must not be empty");
            if (!NamespacePattern.IsMatch(ns))
                return DataResult<string>.Error($"Invalid ResourceLocation namespace '{ns}': only lowercase letters (a-z), digits (0-9), '_', '-', '.' are allowed");
            return DataResult<string>.Success(ns);
        }

        public static DataResult<string> ValidatePath(string path)
        {
            if (string.IsNullOrEmpty(path))
                return DataResult<string>.Error("ResourceLocation path must not be empty");
            if (!PathPattern.IsMatch(path))
                return DataResult<string>.Error($"Invalid ResourceLocation path '{path}': only lowercase letters (a-z), digits (0-9), '_', '-', '.', '/' are allowed");
            return DataResult<string>.Success(path);
        }

        public static bool IsValid(string locationStr) => Parse(locationStr).IsSuccess;

        public override string ToString() => _cached;
        public bool Equals(ResourceLocation other) => other != null && Namespace == other.Namespace && Path == other.Path;
        public override bool Equals(object obj) => obj is ResourceLocation rl && Equals(rl);
        public override int GetHashCode() => _hashCode;
        public static bool operator ==(ResourceLocation left, ResourceLocation right) => Equals(left, right);
        public static bool operator !=(ResourceLocation left, ResourceLocation right) => !Equals(left, right);
    }
}
