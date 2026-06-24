using System;

namespace MinecraftStyleFramework.Events
{
    public class Event
    {
        public bool Cancelled { get; private set; }

        public virtual bool IsCancelable()
        {
            var attributes = GetType().GetCustomAttributes(typeof(Cancelable), true);
            return attributes.Length > 0;
        }

        public virtual void SetCancelled(bool cancelled)
        {
            if (!IsCancelable())
            {
                throw new NotSupportedException("Event is not cancelable");
            }
            Cancelled = Cancelled || cancelled;
        }
    }
}
