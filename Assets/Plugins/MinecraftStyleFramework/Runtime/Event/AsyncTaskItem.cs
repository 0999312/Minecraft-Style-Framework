using System;
using System.Collections;

namespace MinecraftStyleFramework.Events
{
    public class AsyncTaskItem<T> : AsyncTaskItemBase where T : Event
    {
        public AsyncTaskItem(int priority, Func<T, IEnumerator> action) : base(priority, evt =>
        {
            if (evt is T)
            {
                return action((T)evt);
            }

            return null;
        })
        { }

        public AsyncTaskItem(Func<T, IEnumerator> action) : this(0, action) { }
    }
}
