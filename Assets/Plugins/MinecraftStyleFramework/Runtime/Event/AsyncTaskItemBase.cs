using System;
using System.Collections;

namespace MinecraftStyleFramework.Events
{
    public class AsyncTaskItemBase : IComparable<AsyncTaskItemBase>
    {
        public int Priority { get; }
        public Func<Event, IEnumerator> Delegate { get; }

        public AsyncTaskItemBase(int priority, Func<Event, IEnumerator> action)
        {
            Priority = priority;
            Delegate = action;
        }

        public AsyncTaskItemBase(Func<Event, IEnumerator> action) : this(0, action)
        {
        }

        public int CompareTo(AsyncTaskItemBase other)
        {
            if (other == null) return 1;
            return Priority.CompareTo(other.Priority);
        }
    }
}
