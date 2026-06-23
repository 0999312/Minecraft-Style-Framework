using MinecraftStyleFramework.Utils;

namespace MinecraftStyleFramework.Events.UI
{
    /// <summary>Event published when a UI panel is resumed (above panel closed).</summary>
    public class UIResumeEvent : Event
    {
        public ResourceLocation PanelId { get; }
        public int Layer { get; }

        public UIResumeEvent(ResourceLocation panelId, int layer)
        {
            PanelId = panelId;
            Layer = layer;
        }
    }
}
