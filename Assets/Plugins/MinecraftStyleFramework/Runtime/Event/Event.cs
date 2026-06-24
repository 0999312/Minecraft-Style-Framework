namespace MinecraftStyleFramework.Events
{
    /// <summary>
    /// Base class for all framework events. Supports cancellation.
    /// </summary>
    public abstract class Event
    {
        private bool _cancelled;

        /// <summary>Cancel the event to prevent further listener processing.</summary>
        public void Cancel() => _cancelled = true;

        /// <summary>Check if the event has been cancelled.</summary>
        public bool IsCancelled => _cancelled;

        /// <summary>
        /// Returns the event type name. Defaults to the class name.
        /// </summary>
        public virtual string GetEventType() => GetType().Name;
    }
}
