using System.Collections.Generic;
using MinecraftStyleFramework.Utils;
using UnityEngine;

namespace MinecraftStyleFramework.UI
{
    /// <summary>
    /// Panel cache mode.
    /// </summary>
    public enum UIPanelCacheMode { None, Cache }

    /// <summary>
    /// Base class for all UI panels. Attach to a GameObject that serves as a panel root.
    /// </summary>
    public abstract class UIPanel : MonoBehaviour
    {
        /// <summary>Panel identifier in the registry.</summary>
        public ResourceLocation PanelId { get; set; }

        /// <summary>Which layer this panel belongs to.</summary>
        public int Layer { get; set; } = UILayer.Normal;

        /// <summary>Cache mode for this panel.</summary>
        public UIPanelCacheMode CacheMode { get; set; } = UIPanelCacheMode.None;

        /// <summary>Called once when the panel is first instantiated.</summary>
        public virtual void OnInit() { }

        /// <summary>Called each time the panel is opened.</summary>
        public virtual void OnOpen(Dictionary<string, object> data = null) { }

        /// <summary>Called when the panel is paused (covered by another panel).</summary>
        public virtual void OnPause() { }

        /// <summary>Called when the panel is resumed (above panel closed).</summary>
        public virtual void OnResume() { }

        /// <summary>Called when the panel is closed.</summary>
        public virtual void OnClose() { }

        /// <summary>Called when the panel is destroyed (removed from cache).</summary>
        public virtual void OnPanelDestroy() { }
    }
}
