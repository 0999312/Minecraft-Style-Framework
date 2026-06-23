using System;
using System.Collections.Generic;
using MinecraftStyleFramework.Events;
using Newtonsoft.Json.Linq;

namespace MinecraftStyleFramework.I18N
{
    /// <summary>
    /// JSON-based localization manager.
    /// Singleton accessed via I18NManager.Instance.
    /// </summary>
    public sealed class I18NManager
    {
        private static I18NManager _instance;
        public static I18NManager Instance => _instance ??= new I18NManager();

        private string _currentLocale = "en";
        private readonly Dictionary<string, Dictionary<string, string>> _translations = new();

        /// <summary>Current language code.</summary>
        public string CurrentLanguage => _currentLocale;

        /// <summary>
        /// Load a translation from JSON string.
        /// JSON should be a flat or nested key-value dictionary.
        /// </summary>
        public bool LoadTranslation(string langCode, string jsonContent)
        {
            if (string.IsNullOrEmpty(langCode) || string.IsNullOrEmpty(jsonContent))
            {
                return false;
            }

            try
            {
                var jObj = JObject.Parse(jsonContent);
                var flat = new Dictionary<string, string>();
                FlattenDict(jObj, string.Empty, flat);

                _translations[langCode] = flat;
                UnityEngine.Debug.Log($"[I18N] Language [{langCode}] loaded with {flat.Count} entries");
                return true;
            }
            catch (Exception ex)
            {
                UnityEngine.Debug.LogError($"[I18N] Failed to parse JSON for '{langCode}': {ex.Message}");
                return false;
            }
        }

        /// <summary>Set the current language and publish LanguageChangedEvent.</summary>
        public void SetLanguage(string langCode)
        {
            _currentLocale = langCode;
            EventBus.Instance.Publish(new LanguageChangedEvent(langCode));
        }

        /// <summary>Get translated text for a key. Supports placeholder replacement {0}, {1}, etc.</summary>
        public string GetText(string key, params object[] args)
        {
            if (_translations.TryGetValue(_currentLocale, out var dict) &&
                dict.TryGetValue(key, out var text))
            {
                if (args.Length > 0)
                {
                    for (var i = 0; i < args.Length; i++)
                    {
                        text = text.Replace($"{{{i}}}", args[i]?.ToString() ?? string.Empty);
                    }
                }

                return text;
            }

            return key;
        }

        /// <summary>Check if a key exists in the current language.</summary>
        public bool HasKey(string key)
        {
            return _translations.TryGetValue(_currentLocale, out var dict) && dict.ContainsKey(key);
        }

        /// <summary>Get all available language codes.</summary>
        public IEnumerable<string> GetAvailableLanguages() => _translations.Keys;

        private static void FlattenDict(JObject source, string prefix, Dictionary<string, string> output)
        {
            foreach (var prop in source.Properties())
            {
                var fullKey = string.IsNullOrEmpty(prefix) ? prop.Name : $"{prefix}.{prop.Name}";
                if (prop.Value is JObject nested)
                {
                    FlattenDict(nested, fullKey, output);
                }
                else
                {
                    output[fullKey] = prop.Value.ToString();
                }
            }
        }

        /// <summary>Reset the singleton (useful for testing).</summary>
        public static void Reset() => _instance = new I18NManager();
    }
}
