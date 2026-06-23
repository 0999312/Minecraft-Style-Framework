using System;
using System.Collections.Generic;

namespace MinecraftStyleFramework.Events
{
    /// <summary>
    /// Global event bus for decoupled publish/subscribe communication.
    /// Singleton accessed via EventBus.Instance.
    /// </summary>
    public sealed class EventBus
    {
        private static EventBus _instance;
        public static EventBus Instance => _instance ??= new EventBus();

        private readonly Dictionary<string, List<Action<Event>>> _listeners = new();

        /// <summary>Subscribe to an event type.</summary>
        public void Subscribe(string eventType, Action<Event> listener)
        {
            if (!_listeners.TryGetValue(eventType, out var list))
            {
                list = new List<Action<Event>>();
                _listeners[eventType] = list;
            }

            if (!list.Contains(listener))
            {
                list.Add(listener);
            }
        }

        /// <summary>Subscribe using generic type.</summary>
        public void Subscribe<T>(Action<Event> listener) where T : Event =>
            Subscribe(typeof(T).Name, listener);

        /// <summary>Unsubscribe from an event type.</summary>
        public void Unsubscribe(string eventType, Action<Event> listener)
        {
            if (_listeners.TryGetValue(eventType, out var list))
            {
                list.Remove(listener);
            }
        }

        /// <summary>Unsubscribe using generic type.</summary>
        public void Unsubscribe<T>(Action<Event> listener) where T : Event =>
            Unsubscribe(typeof(T).Name, listener);

        /// <summary>Publish an event to all subscribers.</summary>
        public void Publish(Event evt)
        {
            var eventType = evt.GetEventType();
            if (!_listeners.TryGetValue(eventType, out var list))
            {
                return;
            }

            var copy = new List<Action<Event>>(list);
            foreach (var listener in copy)
            {
                if (evt.IsCancelled)
                {
                    break;
                }

                listener(evt);
            }
        }

        /// <summary>Remove all listeners for a specific event type.</summary>
        public void ClearListeners(string eventType)
        {
            if (_listeners.TryGetValue(eventType, out var list))
            {
                list.Clear();
            }
        }

        /// <summary>Remove all listeners.</summary>
        public void ClearAllListeners() => _listeners.Clear();

        /// <summary>Reset the singleton instance (useful for testing).</summary>
        public static void Reset() => _instance = new EventBus();
    }
}
