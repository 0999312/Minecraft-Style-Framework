namespace MinecraftStyleFramework.Events
{
    /// <summary>Event published when the language is changed.</summary>
    public class LanguageChangedEvent : Event
    {
        public string LangCode { get; }

        public LanguageChangedEvent(string langCode)
        {
            LangCode = langCode;
        }
    }
}
