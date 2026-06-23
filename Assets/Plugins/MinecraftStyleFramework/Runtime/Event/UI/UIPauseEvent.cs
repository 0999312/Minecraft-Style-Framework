using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Events.UI
{
    /// <summary>Event published when a UI panel is paused (covered by another panel).</summary>
    public class UIPauseEvent : Event
    {
        public ResourceLocation PanelId { get; }
        public int Layer { get; }

        public UIPauseEvent(ResourceLocation panelId, int layer)
        {
            PanelId = panelId;
            Layer = layer;
        }
    }
}
