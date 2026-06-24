using System.Collections.Generic;

namespace MinecraftStyleFramework.Codec
{
    /// <summary>
    /// Abstract data carrier interface. Codecs operate through DynamicOps
    /// without knowing the underlying format.
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
