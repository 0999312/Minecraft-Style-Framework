using System;
using System.Collections.Generic;
using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Codec
{
    /// <summary>
    /// Base abstract Codec. Type-safe encode/decode between runtime values and DynamicOps carriers.
    /// </summary>
    public abstract class Codec<T>
    {
        public abstract DataResult<object> Encode(T value, DynamicOps ops);
        public abstract DataResult<T> Decode(object value, DynamicOps ops);

        public MapCodec<T> FieldOf(string name) =>
            new FieldMapCodec<T>(name, this, false, null);

        public MapCodec<T> OptionalFieldOf(string name, Func<T> defaultFactory = null) =>
            new FieldMapCodec<T>(name, this, true, defaultFactory);

        public Codec<List<T>> ListOf() => new ListCodec<T>(this);

        public Codec<U> Xmap<U>(Func<T, U> decodeFn, Func<U, T> encodeFn) =>
            new XmapCodec<T, U>(this, decodeFn, encodeFn);

        public Codec<U> FlatXmap<U>(Func<T, DataResult<U>> decodeFn, Func<U, DataResult<T>> encodeFn) =>
            new FlatXmapCodec<T, U>(this, decodeFn, encodeFn);
    }

    /// <summary>Static factory for common codecs.</summary>
    public static class Codec
    {
        public static Codec<bool> Bool { get; } = new PrimitiveCodec<bool>(
            (v, ops) => DataResult<object>.Success(ops.CreateBool(v)),
            (v, ops) => ops.GetBool(v));

        public static Codec<int> Int { get; } = new PrimitiveCodec<int>(
            (v, ops) => DataResult<object>.Success(ops.CreateInt(v)),
            (v, ops) => ops.GetInt(v));

        public static Codec<float> Float { get; } = new PrimitiveCodec<float>(
            (v, ops) => DataResult<object>.Success(ops.CreateFloat(v)),
            (v, ops) => ops.GetFloat(v));

        public static Codec<string> String { get; } = new PrimitiveCodec<string>(
            (v, ops) => DataResult<object>.Success(ops.CreateString(v)),
            (v, ops) => ops.GetString(v));

        public static Codec<ResourceLocation> ResourceLocation { get; } = new ResourceLocationCodec();

        public static Codec<Dictionary<TKey, TValue>> MapOf<TKey, TValue>(
            Codec<TKey> keyCodec, Codec<TValue> valueCodec) =>
            new MapOfCodec<TKey, TValue>(keyCodec, valueCodec);

        public static Codec<object> Either(Codec<object> first, Codec<object> second) =>
            new EitherCodec(first, second);

        public static Codec<object> Dispatch(string typeKey, Codec<string> typeCodec,
            Func<string, Codec<object>> dispatchFn) =>
            new DispatchCodec(typeKey, typeCodec, dispatchFn);

        public static Codec<T> Record<T>(MapCodec<T> mapCodec) => new RecordCodec<T>(mapCodec);

        public static Codec<T> Unit<T>(T value) => new UnitCodec<T>(value);
    }

    // --- Internal codec implementations ---

    internal class PrimitiveCodec<T> : Codec<T>
    {
        private readonly Func<T, DynamicOps, DataResult<object>> _encoder;
        private readonly Func<object, DynamicOps, DataResult<T>> _decoder;

        public PrimitiveCodec(Func<T, DynamicOps, DataResult<object>> encoder,
            Func<object, DynamicOps, DataResult<T>> decoder)
        {
            _encoder = encoder;
            _decoder = decoder;
        }

        public override DataResult<object> Encode(T value, DynamicOps ops) => _encoder(value, ops);
        public override DataResult<T> Decode(object value, DynamicOps ops) => _decoder(value, ops);
    }

    internal class ResourceLocationCodec : Codec<ResourceLocation>
    {
        public override DataResult<object> Encode(ResourceLocation value, DynamicOps ops)
        {
            if (value == null) return DataResult<object>.Error("Cannot encode null ResourceLocation");
            return DataResult<object>.Success(ops.CreateString(value.ToString()));
        }

        public override DataResult<ResourceLocation> Decode(object value, DynamicOps ops)
        {
            var strResult = ops.GetString(value);
            if (strResult.IsError) return DataResult<ResourceLocation>.Error(strResult.ErrorMessage);
            return ResourceLocation.Parse(strResult.Value);
        }
    }

    internal class ListCodec<T> : Codec<List<T>>
    {
        private readonly Codec<T> _elementCodec;
        public ListCodec(Codec<T> elementCodec) { _elementCodec = elementCodec; }

        public override DataResult<object> Encode(List<T> value, DynamicOps ops)
        {
            if (value == null) return DataResult<object>.Error("Cannot encode null list");
            var encoded = new List<object>();
            var diagnostics = new List<Diagnostic>();
            for (int i = 0; i < value.Count; i++)
            {
                var result = _elementCodec.Encode(value[i], ops);
                if (result.IsError)
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Fatal, $"Failed to encode list element [{i}]: {result.ErrorMessage}", $"[{i}]"));
                else
                {
                    encoded.Add(result.Value);
                    diagnostics.AddRange(result.Diagnostics);
                }
            }
            var r = DataResult<object>.Success(ops.CreateList(encoded));
            r.Diagnostics.AddRange(diagnostics);
            return r;
        }

        public override DataResult<List<T>> Decode(object value, DynamicOps ops)
        {
            var listResult = ops.GetList(value);
            if (listResult.IsError) return DataResult<List<T>>.Error(listResult.ErrorMessage);
            var rawList = listResult.Value;
            var decoded = new List<T>();
            var diagnostics = new List<Diagnostic>();
            bool hasErrors = false;
            for (int i = 0; i < rawList.Count; i++)
            {
                var result = _elementCodec.Decode(rawList[i], ops);
                if (result.IsError)
                {
                    hasErrors = true;
                    diagnostics.Add(new Diagnostic(DiagnosticLevel.Recoverable, $"Failed to decode list element [{i}]: {result.ErrorMessage}", $"[{i}]"));
                }
                else
                {
                    decoded.Add(result.Value);
                    diagnostics.AddRange(result.Diagnostics);
                }
            }
            var r = hasErrors
                ? DataResult<List<T>>.Partial(decoded, "Some list elements failed to decode")
                : DataResult<List<T>>.Success(decoded);
            r.Diagnostics.AddRange(diagnostics);
            return r;
        }
    }

    internal class MapOfCodec<TKey, TValue> : Codec<Dictionary<TKey, TValue>>
    {
        private readonly Codec<TKey> _keyCodec;
        private readonly Codec<TValue> _valueCodec;

        public MapOfCodec(Codec<TKey> keyCodec, Codec<TValue> valueCodec)
        {
            _keyCodec = keyCodec;
            _valueCodec = valueCodec;
        }

        public override DataResult<object> Encode(Dictionary<TKey, TValue> value, DynamicOps ops)
        {
            if (value == null) return DataResult<object>.Error("Cannot encode null map");
            var entries = new Dictionary<string, object>();
            foreach (var kv in value)
            {
                var keyResult = _keyCodec.Encode(kv.Key, ops);
                if (keyResult.IsError) continue;
                var keyStr = ops.GetString(keyResult.Value);
                if (keyStr.IsError) continue;
                var valResult = _valueCodec.Encode(kv.Value, ops);
                if (valResult.IsError) continue;
                entries[keyStr.Value] = valResult.Value;
            }
            return DataResult<object>.Success(ops.CreateMap(entries));
        }

        public override DataResult<Dictionary<TKey, TValue>> Decode(object value, DynamicOps ops)
        {
            var entriesResult = ops.GetMapEntries(value);
            if (entriesResult.IsError) return DataResult<Dictionary<TKey, TValue>>.Error(entriesResult.ErrorMessage);
            var dict = new Dictionary<TKey, TValue>();
            foreach (var kv in entriesResult.Value)
            {
                var keyDecoded = _keyCodec.Decode(ops.CreateString(kv.Key), ops);
                if (keyDecoded.IsError) continue;
                var valDecoded = _valueCodec.Decode(kv.Value, ops);
                if (valDecoded.IsError) continue;
                dict[keyDecoded.Value] = valDecoded.Value;
            }
            return DataResult<Dictionary<TKey, TValue>>.Success(dict);
        }
    }

    internal class XmapCodec<TFrom, TTo> : Codec<TTo>
    {
        private readonly Codec<TFrom> _inner;
        private readonly Func<TFrom, TTo> _decodeFn;
        private readonly Func<TTo, TFrom> _encodeFn;

        public XmapCodec(Codec<TFrom> inner, Func<TFrom, TTo> decodeFn, Func<TTo, TFrom> encodeFn)
        {
            _inner = inner;
            _decodeFn = decodeFn;
            _encodeFn = encodeFn;
        }

        public override DataResult<object> Encode(TTo value, DynamicOps ops) =>
            _inner.Encode(_encodeFn(value), ops);

        public override DataResult<TTo> Decode(object value, DynamicOps ops) =>
            _inner.Decode(value, ops).Map(_decodeFn);
    }

    internal class FlatXmapCodec<TFrom, TTo> : Codec<TTo>
    {
        private readonly Codec<TFrom> _inner;
        private readonly Func<TFrom, DataResult<TTo>> _decodeFn;
        private readonly Func<TTo, DataResult<TFrom>> _encodeFn;

        public FlatXmapCodec(Codec<TFrom> inner, Func<TFrom, DataResult<TTo>> decodeFn,
            Func<TTo, DataResult<TFrom>> encodeFn)
        {
            _inner = inner;
            _decodeFn = decodeFn;
            _encodeFn = encodeFn;
        }

        public override DataResult<object> Encode(TTo value, DynamicOps ops) =>
            _encodeFn(value).FlatMap(from => _inner.Encode(from, ops));

        public override DataResult<TTo> Decode(object value, DynamicOps ops) =>
            _inner.Decode(value, ops).FlatMap(_decodeFn);
    }

    internal class EitherCodec : Codec<object>
    {
        private readonly Codec<object> _first;
        private readonly Codec<object> _second;

        public EitherCodec(Codec<object> first, Codec<object> second)
        {
            _first = first;
            _second = second;
        }

        public override DataResult<object> Encode(object value, DynamicOps ops)
        {
            var result = _first.Encode(value, ops);
            return result.IsError ? _second.Encode(value, ops) : result;
        }

        public override DataResult<object> Decode(object value, DynamicOps ops)
        {
            var result = _first.Decode(value, ops);
            return result.IsError ? _second.Decode(value, ops) : result;
        }
    }

    internal class DispatchCodec : Codec<object>
    {
        private readonly string _typeKey;
        private readonly Codec<string> _typeCodec;
        private readonly Func<string, Codec<object>> _dispatchFn;

        public DispatchCodec(string typeKey, Codec<string> typeCodec, Func<string, Codec<object>> dispatchFn)
        {
            _typeKey = typeKey;
            _typeCodec = typeCodec;
            _dispatchFn = dispatchFn;
        }

        public override DataResult<object> Encode(object value, DynamicOps ops)
        {
            // Dispatch encode requires the type to be known - implementation detail
            return DataResult<object>.Error("DispatchCodec.Encode requires type information on the value");
        }

        public override DataResult<object> Decode(object value, DynamicOps ops)
        {
            var typeValue = ops.GetMapValue(value, _typeKey);
            if (typeValue.IsError) return DataResult<object>.Error($"Dispatch type key '{_typeKey}' not found");
            var typeResult = _typeCodec.Decode(typeValue.Value, ops);
            if (typeResult.IsError) return DataResult<object>.Error($"Failed to decode dispatch type: {typeResult.ErrorMessage}");
            var codec = _dispatchFn(typeResult.Value);
            if (codec == null) return DataResult<object>.Error($"No codec found for dispatch type: {typeResult.Value}");
            return codec.Decode(value, ops);
        }
    }

    internal class RecordCodec<T> : Codec<T>
    {
        private readonly MapCodec<T> _mapCodec;
        public RecordCodec(MapCodec<T> mapCodec) { _mapCodec = mapCodec; }

        public override DataResult<object> Encode(T value, DynamicOps ops) =>
            _mapCodec.EncodeToMap(value, ops);

        public override DataResult<T> Decode(object value, DynamicOps ops) =>
            _mapCodec.DecodeFromMap(value, ops);
    }

    internal class UnitCodec<T> : Codec<T>
    {
        private readonly T _value;
        public UnitCodec(T value) { _value = value; }

        public override DataResult<object> Encode(T value, DynamicOps ops) =>
            DataResult<object>.Success(ops.Empty());

        public override DataResult<T> Decode(object value, DynamicOps ops) =>
            DataResult<T>.Success(_value);
    }
}
