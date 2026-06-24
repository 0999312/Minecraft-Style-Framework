using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Events
{
    public class EventBusManager : SingletonMonoBehaviour<EventBusManager>
    {
        public EventBus _Sync { get; private set; }
        public AsyncEventBus _Async { get; private set; }

        protected override void Awake()
        {
            base.Awake();
            _Sync = new EventBus();
            _Async = new AsyncEventBus();
        }

        public static EventBus Sync
        {
            get => INSTANCE._Sync;
        }

        public static AsyncEventBus Async
        {
            get => INSTANCE._Async;
        }
    }
}
