using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Events.UI
{
    /// <summary>Event published when a UI panel is opened.</summary>
    public class UIOpenEvent : Event
    {
        public ResourceLocation PanelId { get; }
        public int Layer { get; }

        public UIOpenEvent(ResourceLocation panelId, int layer)
        {
            PanelId = panelId;
            Layer = layer;
        }
    }
}
