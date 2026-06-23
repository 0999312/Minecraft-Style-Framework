using System;
using System.Collections.Generic;

namespace MinecraftStyleFramework.Codec
{
    public enum DataResultStatus { Success, Error, Partial }
    public enum DiagnosticLevel { Fatal, Recoverable, Warning }

    public class Diagnostic
    {
        public DiagnosticLevel Level { get; }
        public string Message { get; }
        public string Path { get; }

        public Diagnostic(DiagnosticLevel level, string message, string path = "")
        {
            Level = level;
            Message = message;
            Path = path;
        }

        public override string ToString() => string.IsNullOrEmpty(Path)
            ? $"[{Level}] {Message}"
            : $"[{Level}] {Path}: {Message}";
    }

    public class DataResult<T>
    {
        public DataResultStatus Status { get; private set; }
        public T Value { get; private set; }
        public string ErrorMessage { get; private set; }
        public List<Diagnostic> Diagnostics { get; private set; } = new();

        private DataResult() { }

        public static DataResult<T> Success(T value) => new()
        {
            Status = DataResultStatus.Success,
            Value = value
        };

        public static DataResult<T> Error(string message) => new()
        {
            Status = DataResultStatus.Error,
            ErrorMessage = message
        };

        public static DataResult<T> Partial(T partialValue, string message) => new()
        {
            Status = DataResultStatus.Partial,
            Value = partialValue,
            ErrorMessage = message
        };

        public bool IsSuccess => Status == DataResultStatus.Success;
        public bool IsError => Status == DataResultStatus.Error;
        public bool IsPartial => Status == DataResultStatus.Partial;

        public T GetValueOrDefault(T defaultValue) =>
            Status != DataResultStatus.Error ? Value : defaultValue;

        public DataResult<U> Map<U>(Func<T, U> transform)
        {
            if (IsError) return DataResult<U>.Error(ErrorMessage);
            var result = IsSuccess
                ? DataResult<U>.Success(transform(Value))
                : DataResult<U>.Partial(transform(Value), ErrorMessage);
            result.Diagnostics.AddRange(Diagnostics);
            return result;
        }

        public DataResult<U> FlatMap<U>(Func<T, DataResult<U>> transform)
        {
            if (IsError) return DataResult<U>.Error(ErrorMessage);
            var inner = transform(Value);
            inner.Diagnostics.InsertRange(0, Diagnostics);
            if (IsPartial && inner.IsSuccess)
            {
                inner.Status = DataResultStatus.Partial;
                inner.ErrorMessage = ErrorMessage;
            }
            return inner;
        }

        public DataResult<T> AddDiagnostic(DiagnosticLevel level, string message, string path = "")
        {
            Diagnostics.Add(new Diagnostic(level, message, path));
            return this;
        }

        public override string ToString() => Status switch
        {
            DataResultStatus.Success => $"DataResult.Success({Value})",
            DataResultStatus.Error => $"DataResult.Error({ErrorMessage})",
            DataResultStatus.Partial => $"DataResult.Partial({Value}, {ErrorMessage})",
            _ => "DataResult.Unknown"
        };
    }

    /// <summary>Non-generic helper methods.</summary>
    public static class DataResult
    {
        public static DataResult<T> Success<T>(T value) => DataResult<T>.Success(value);
        public static DataResult<T> Error<T>(string message) => DataResult<T>.Error(message);
        public static DataResult<T> Partial<T>(T value, string message) => DataResult<T>.Partial(value, message);
    }
}
