using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace MinecraftStyleFramework.Codec.Ops
{
    /// <summary>
    /// DynamicOps implementation that operates on Dictionary&lt;string, object&gt; and uses
    /// reflection for reading from plain C# objects. Suitable for ScriptableObject serialization.
    /// </summary>
    public sealed class UnityResourceOps : DynamicOps
    {
        public static readonly UnityResourceOps Instance = new();
        private UnityResourceOps() { }

        public override object Empty() => new Dictionary<string, object>();
        public override object CreateInt(int value) => value;
        public override object CreateFloat(float value) => value;
        public override object CreateBool(bool value) => value;
        public override object CreateString(string value) => value;

        public override object CreateList(IList<object> values) => new List<object>(values);

        public override object CreateMap(Dictionary<string, object> entries) =>
            new Dictionary<string, object>(entries);

        public override DataResult<int> GetInt(object value)
        {
            if (value is int i) return DataResult<int>.Success(i);
            if (value is long l) return DataResult<int>.Success((int)l);
            return DataResult<int>.Error($"Expected int, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<float> GetFloat(object value)
        {
            if (value is float f) return DataResult<float>.Success(f);
            if (value is double d) return DataResult<float>.Success((float)d);
            if (value is int i) return DataResult<float>.Success(i);
            return DataResult<float>.Error($"Expected float, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<bool> GetBool(object value)
        {
            if (value is bool b) return DataResult<bool>.Success(b);
            return DataResult<bool>.Error($"Expected bool, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<string> GetString(object value)
        {
            if (value is string s) return DataResult<string>.Success(s);
            return DataResult<string>.Error($"Expected string, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<object> GetMapValue(object mapValue, string key)
        {
            if (mapValue is Dictionary<string, object> dict)
            {
                if (dict.TryGetValue(key, out var v)) return DataResult<object>.Success(v);
                return DataResult<object>.Error($"Key '{key}' not found in Dictionary");
            }
            // Reflection fallback for plain objects
            if (mapValue != null)
            {
                var type = mapValue.GetType();
                var prop = type.GetProperty(key, BindingFlags.Public | BindingFlags.Instance);
                if (prop != null) return DataResult<object>.Success(prop.GetValue(mapValue));
                var field = type.GetField(key, BindingFlags.Public | BindingFlags.Instance);
                if (field != null) return DataResult<object>.Success(field.GetValue(mapValue));
            }
            return DataResult<object>.Error($"Expected Dictionary or object with property '{key}', got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override object SetMapValue(object mapValue, string key, object value)
        {
            var dict = mapValue as Dictionary<string, object> ?? new Dictionary<string, object>();
            dict[key] = value;
            return dict;
        }

        public override object RemoveMapValue(object mapValue, string key)
        {
            if (mapValue is Dictionary<string, object> dict)
            {
                var clone = new Dictionary<string, object>(dict);
                clone.Remove(key);
                return clone;
            }
            return mapValue;
        }

        public override DataResult<IEnumerable<string>> GetMapKeys(object mapValue)
        {
            if (mapValue is Dictionary<string, object> dict)
                return DataResult<IEnumerable<string>>.Success(dict.Keys);
            return DataResult<IEnumerable<string>>.Error($"Expected Dictionary, got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override DataResult<Dictionary<string, object>> GetMapEntries(object mapValue)
        {
            if (mapValue is Dictionary<string, object> d)
                return DataResult<Dictionary<string, object>>.Success(d);
            return DataResult<Dictionary<string, object>>.Error($"Expected Dictionary, got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override DataResult<IList<object>> GetList(object value)
        {
            if (value is List<object> list) return DataResult<IList<object>>.Success(list);
            if (value is IList<object> ilist) return DataResult<IList<object>>.Success(ilist);
            return DataResult<IList<object>>.Error($"Expected List, got: {value?.GetType().Name ?? "null"}");
        }

        public override object MergeMaps(object first, object second)
        {
            var result = new Dictionary<string, object>();
            if (first is Dictionary<string, object> d1)
                foreach (var kv in d1) result[kv.Key] = kv.Value;
            if (second is Dictionary<string, object> d2)
                foreach (var kv in d2) result[kv.Key] = kv.Value;
            return result;
        }

        public override bool IsMap(object value) => value is Dictionary<string, object>;
        public override bool IsList(object value) => value is IList<object>;
        public override bool IsNumber(object value) => value is int || value is float || value is double || value is long;
        public override bool IsString(object value) => value is string;
        public override string GetName() => "UnityResourceOps";
    }
}
