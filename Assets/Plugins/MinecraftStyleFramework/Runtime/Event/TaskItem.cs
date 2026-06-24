using System;

namespace MinecraftStyleFramework.Events
{
    public class TaskItem<T> : TaskItemBase where T : Event
    {
        public TaskItem(int priority, Action<T> action) : base(priority, evt =>
        {
            if (evt is T)
            {
                action((T)evt);
            }
        })
        { }

        public TaskItem(Action<T> action) : this(0, action) { }
    }
}
