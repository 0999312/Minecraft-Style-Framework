using System;

namespace MinecraftStyleFramework.Events
{
    public class TaskItemBase : IComparable<TaskItemBase>
    {
        public int Priority { get; }
        public Action<Event> Delegate { get; }

        public TaskItemBase(int priority, Action<Event> action)
        {
            Priority = priority;
            Delegate = action;
        }

        public TaskItemBase(Action<Event> action) : this(0, action)
        {
        }

        public int CompareTo(TaskItemBase other)
        {
            if (other == null) return 1;
            return Priority.CompareTo(other.Priority);
        }
    }
}
