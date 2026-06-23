using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace MinecraftStyleFramework.Codec.Ops
{
    /// <summary>
    /// DynamicOps implementation for JSON using Newtonsoft.Json.Linq.
    /// </summary>
    public sealed class JsonOps : DynamicOps
    {
        public static readonly JsonOps Instance = new();
        private JsonOps() { }

        public override object Empty() => new JObject();
        public override object CreateInt(int value) => new JValue(value);
        public override object CreateFloat(float value) => new JValue(value);
        public override object CreateBool(bool value) => new JValue(value);
        public override object CreateString(string value) => new JValue(value);

        public override object CreateList(IList<object> values)
        {
            var arr = new JArray();
            foreach (var v in values)
                arr.Add(v is JToken jt ? jt : JToken.FromObject(v));
            return arr;
        }

        public override object CreateMap(Dictionary<string, object> entries)
        {
            var obj = new JObject();
            foreach (var kv in entries)
                obj[kv.Key] = kv.Value is JToken jt ? jt : (kv.Value != null ? JToken.FromObject(kv.Value) : JValue.CreateNull());
            return obj;
        }

        public override DataResult<int> GetInt(object value)
        {
            if (value is JValue jv && (jv.Type == JTokenType.Integer))
                return DataResult<int>.Success(jv.Value<int>());
            if (value is int i) return DataResult<int>.Success(i);
            if (value is long l) return DataResult<int>.Success((int)l);
            return DataResult<int>.Error($"Expected int, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<float> GetFloat(object value)
        {
            if (value is JValue jv)
            {
                if (jv.Type == JTokenType.Float) return DataResult<float>.Success(jv.Value<float>());
                if (jv.Type == JTokenType.Integer) return DataResult<float>.Success(jv.Value<float>());
            }
            if (value is float f) return DataResult<float>.Success(f);
            if (value is double d) return DataResult<float>.Success((float)d);
            if (value is int i) return DataResult<float>.Success(i);
            return DataResult<float>.Error($"Expected float, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<bool> GetBool(object value)
        {
            if (value is JValue jv && jv.Type == JTokenType.Boolean)
                return DataResult<bool>.Success(jv.Value<bool>());
            if (value is bool b) return DataResult<bool>.Success(b);
            return DataResult<bool>.Error($"Expected bool, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<string> GetString(object value)
        {
            if (value is JValue jv && jv.Type == JTokenType.String)
                return DataResult<string>.Success(jv.Value<string>());
            if (value is string s) return DataResult<string>.Success(s);
            return DataResult<string>.Error($"Expected string, got: {value?.GetType().Name ?? "null"}");
        }

        public override DataResult<object> GetMapValue(object mapValue, string key)
        {
            if (mapValue is JObject jo)
            {
                var token = jo[key];
                if (token == null) return DataResult<object>.Error($"Key '{key}' not found in JObject");
                return DataResult<object>.Success((object)token);
            }
            if (mapValue is Dictionary<string, object> dict)
            {
                if (dict.TryGetValue(key, out var v)) return DataResult<object>.Success(v);
                return DataResult<object>.Error($"Key '{key}' not found in Dictionary");
            }
            return DataResult<object>.Error($"Expected JObject or Dictionary, got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override object SetMapValue(object mapValue, string key, object value)
        {
            if (mapValue is JObject jo)
            {
                var clone = (JObject)jo.DeepClone();
                clone[key] = value is JToken jt ? jt : JToken.FromObject(value);
                return clone;
            }
            var dict = mapValue as Dictionary<string, object> ?? new Dictionary<string, object>();
            dict[key] = value;
            return dict;
        }

        public override object RemoveMapValue(object mapValue, string key)
        {
            if (mapValue is JObject jo)
            {
                var clone = (JObject)jo.DeepClone();
                clone.Remove(key);
                return clone;
            }
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
            if (mapValue is JObject jo)
                return DataResult<IEnumerable<string>>.Success(jo.Properties().Select(p => p.Name));
            if (mapValue is Dictionary<string, object> dict)
                return DataResult<IEnumerable<string>>.Success(dict.Keys);
            return DataResult<IEnumerable<string>>.Error($"Expected JObject or Dictionary, got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override DataResult<Dictionary<string, object>> GetMapEntries(object mapValue)
        {
            if (mapValue is JObject jo)
            {
                var dict = new Dictionary<string, object>();
                foreach (var prop in jo.Properties())
                    dict[prop.Name] = prop.Value;
                return DataResult<Dictionary<string, object>>.Success(dict);
            }
            if (mapValue is Dictionary<string, object> d)
                return DataResult<Dictionary<string, object>>.Success(d);
            return DataResult<Dictionary<string, object>>.Error($"Expected JObject or Dictionary, got: {mapValue?.GetType().Name ?? "null"}");
        }

        public override DataResult<IList<object>> GetList(object value)
        {
            if (value is JArray ja)
                return DataResult<IList<object>>.Success(ja.Cast<object>().ToList());
            if (value is IList<object> list)
                return DataResult<IList<object>>.Success(list);
            return DataResult<IList<object>>.Error($"Expected JArray or IList, got: {value?.GetType().Name ?? "null"}");
        }

        public override object MergeMaps(object first, object second)
        {
            var result = new JObject();
            if (first is JObject jo1)
                foreach (var prop in jo1.Properties())
                    result[prop.Name] = prop.Value.DeepClone();
            if (second is JObject jo2)
                foreach (var prop in jo2.Properties())
                    result[prop.Name] = prop.Value.DeepClone();
            return result;
        }

        public override bool IsMap(object value) => value is JObject || value is Dictionary<string, object>;
        public override bool IsList(object value) => value is JArray || value is IList<object>;
        public override bool IsNumber(object value) => value is JValue jv && (jv.Type == JTokenType.Integer || jv.Type == JTokenType.Float);
        public override bool IsString(object value) => value is JValue jv && jv.Type == JTokenType.String;
        public override string GetName() => "JsonOps";
    }
}
