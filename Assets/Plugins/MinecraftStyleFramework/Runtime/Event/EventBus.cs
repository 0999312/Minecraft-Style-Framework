using System;
using System.Collections.Generic;

namespace MinecraftStyleFramework.Events
{
    public class EventBus
    {
        private SortedSet<TaskItemBase> Handler = new();

        public void Register<T>(Action<T> handler, int priority) where T : Event
        {
            Handler.Add(new TaskItem<T>(priority, handler));
        }

        public void Register<T>(Action<T> handler) where T : Event
        {
            Register(handler, 0);
        }

        public bool Post(Event evt)
        {
            foreach (TaskItemBase task in Handler)
            {
                task.Delegate(evt);
                if (evt.Cancelled) return true;
            }

            return evt.Cancelled;
        }
    }
}
