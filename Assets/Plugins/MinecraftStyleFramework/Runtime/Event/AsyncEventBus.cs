using System;
using System.Collections;
using System.Collections.Generic;

namespace MinecraftStyleFramework.Events
{
    public class AsyncEventBus
    {
        private SortedSet<AsyncTaskItemBase> Handler = new();

        public void Register<T>(Func<T, IEnumerator> handler, int priority) where T : Event
        {
            Handler.Add(new AsyncTaskItem<T>(priority, handler));
        }

        public void Register<T>(Func<T, IEnumerator> handler) where T : Event
        {
            Register(handler, 0);
        }

        public IEnumerator Post(Event evt, Action<bool> calledAfterFinish)
        {
            bool isCancelled = false;
            foreach (AsyncTaskItemBase task in Handler)
            {
                IEnumerator call = task.Delegate(evt);
                if (call != null) yield return call;
                if (evt.Cancelled)
                {
                    isCancelled = true;
                    break;
                }
            }

            calledAfterFinish(isCancelled);
            yield break;
        }
    }
}
