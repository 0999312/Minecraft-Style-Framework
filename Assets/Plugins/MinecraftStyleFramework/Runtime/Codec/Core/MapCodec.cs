using System;
using System.Collections.Generic;

namespace MinecraftStyleFramework.Codec
{
    /// <summary>
    /// MapCodec: operates on a single field within a map structure.
    /// </summary>
    public abstract class MapCodec<T>
    {
        public abstract DataResult<T> DecodeFromMap(object mapValue, DynamicOps ops);
        public abstract DataResult<object> EncodeToMap(T value, DynamicOps ops);

        public Codec<T> ToCodec() => Codec.Record(this);

        public MapCodecWithGetter<TOuter, T> ForGetter<TOuter>(Func<TOuter, T> getter) =>
            new MapCodecWithGetter<TOuter, T>(this, getter);
    }

    /// <summary>Non-generic static factory for MapCodec.</summary>
    public static class MapCodec
    {
        public static MapCodec<T> Build<T>(IMapCodecField<T>[] fields, Func<object[], T> constructor) =>
            new RecordMapCodec<T>(fields, constructor);
    }

    /// <summary>Interface for fields that participate in record encoding/decoding.</summary>
    public interface IMapCodecField<TOwner>
    {
        DataResult<object> DecodeField(object mapValue, DynamicOps ops);
        DataResult<object> EncodeField(TOwner owner, object existingMap, DynamicOps ops);
    }

    /// <summary>Single-field MapCodec.</summary>
    public class FieldMapCodec<T> : MapCodec<T>
    {
        private readonly string _name;
        private readonly Codec<T> _codec;
        private readonly bool _optional;
        private readonly Func<T> _defaultFactory;

        public FieldMapCodec(string name, Codec<T> codec, bool optional, Func<T> defaultFactory)
        {
            _name = name;
            _codec = codec;
            _optional = optional;
            _defaultFactory = defaultFactory;
        }

        public override DataResult<T> DecodeFromMap(object mapValue, DynamicOps ops)
        {
            var fieldValue = ops.GetMapValue(mapValue, _name);
            if (fieldValue.IsError)
            {
                if (_optional)
                    return DataResult<T>.Success(_defaultFactory != null ? _defaultFactory() : default);
                return DataResult<T>.Error($"Required field '{_name}' not found: {fieldValue.ErrorMessage}");
            }
            return _codec.Decode(fieldValue.Value, ops);
        }

        public override DataResult<object> EncodeToMap(T value, DynamicOps ops)
        {
            var encoded = _codec.Encode(value, ops);
            if (encoded.IsError) return encoded;
            var map = ops.CreateMap(new Dictionary<string, object> { { _name, encoded.Value } });
            return DataResult<object>.Success(map);
        }
    }

    /// <summary>Wraps a MapCodec with a getter for record encode.</summary>
    public class MapCodecWithGetter<TOwner, TField> : IMapCodecField<TOwner>
    {
        private readonly MapCodec<TField> _inner;
        private readonly Func<TOwner, TField> _getter;

        public MapCodecWithGetter(MapCodec<TField> inner, Func<TOwner, TField> getter)
        {
            _inner = inner;
            _getter = getter;
        }

        public DataResult<object> DecodeField(object mapValue, DynamicOps ops)
        {
            var result = _inner.DecodeFromMap(mapValue, ops);
            return result.Map<object>(v => v);
        }

        public DataResult<object> EncodeField(TOwner owner, object existingMap, DynamicOps ops)
        {
            var fieldValue = _getter(owner);
            var encoded = _inner.EncodeToMap(fieldValue, ops);
            if (encoded.IsError) return encoded;
            return DataResult<object>.Success(ops.MergeMaps(existingMap, encoded.Value));
        }
    }

    /// <summary>Multi-field record MapCodec.</summary>
    public class RecordMapCodec<T> : MapCodec<T>
    {
        private readonly IMapCodecField<T>[] _fields;
        private readonly Func<object[], T> _constructor;

        public RecordMapCodec(IMapCodecField<T>[] fields, Func<object[], T> constructor)
        {
            _fields = fields;
            _constructor = constructor;
        }

        public override DataResult<T> DecodeFromMap(object mapValue, DynamicOps ops)
        {
            var args = new object[_fields.Length];
            var diagnostics = new List<Diagnostic>();
            bool hasError = false;

            for (int i = 0; i < _fields.Length; i++)
            {
                var result = _fields[i].DecodeField(mapValue, ops);
                if (result.IsError)
                {
                    hasError = true;
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Fatal, result.ErrorMessage));
                }
                else
                {
                    args[i] = result.Value;
                    diagnostics.AddRange(result.Diagnostics);
                }
            }

            if (hasError)
            {
                var errResult = DataResult<T>.Error("Failed to decode record: missing or invalid fields");
                errResult.Diagnostics.AddRange(diagnostics);
                return errResult;
            }

            var obj = _constructor(args);
            var r = DataResult<T>.Success(obj);
            r.Diagnostics.AddRange(diagnostics);
            return r;
        }

        public override DataResult<object> EncodeToMap(T value, DynamicOps ops)
        {
            object map = ops.CreateMap(new Dictionary<string, object>());
            foreach (var field in _fields)
            {
                var result = field.EncodeField(value, map, ops);
                if (result.IsError) return result;
                map = result.Value;
            }
            return DataResult<object>.Success(map);
        }
    }
}
