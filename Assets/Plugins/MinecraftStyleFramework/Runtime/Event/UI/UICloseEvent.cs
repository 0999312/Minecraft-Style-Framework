using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Events.UI
{
    /// <summary>Event published when a UI panel is closed.</summary>
    public class UICloseEvent : Event
    {
        public ResourceLocation PanelId { get; }
        public int Layer { get; }

        public UICloseEvent(ResourceLocation panelId, int layer)
        {
            PanelId = panelId;
            Layer = layer;
        }
    }
}
