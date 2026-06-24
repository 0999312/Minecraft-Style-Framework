using System.Collections.Generic;
using MinecraftStyleFramework.UI;
using MinecraftStyleFramework.Utils;
using UnityEngine;

namespace MinecraftStyleFramework.Registry
{
    /// <summary>
    /// Registry for UI panels and toasts. Stores prefab references and default settings.
    /// </summary>
    public class UIRegistry
    {
        private readonly Dictionary<ResourceLocation, PanelInfo> _panels = new();
        private readonly Dictionary<ResourceLocation, GameObject> _toasts = new();

        /// <summary>Register a panel prefab.</summary>
        public void RegisterPanel(
            ResourceLocation id,
            GameObject prefab,
            int defaultLayer = UILayer.Normal,
            UIPanelCacheMode cacheMode = UIPanelCacheMode.None)
        {
            if (id == null || prefab == null) return;
            _panels[id] = new PanelInfo(prefab, defaultLayer, cacheMode);
        }

        /// <summary>Register a toast prefab.</summary>
        public void RegisterToast(ResourceLocation id, GameObject prefab)
        {
            if (id == null || prefab == null) return;
            _toasts[id] = prefab;
        }

        /// <summary>Instantiate a panel from the registry.</summary>
        public UIPanel InstantiatePanel(ResourceLocation id)
        {
            if (!_panels.TryGetValue(id, out var info))
            {
                Debug.LogError($"UIRegistry: panel not found: {id}");
                return null;
            }

            var instance = Object.Instantiate(info.Prefab);
            var panel = instance.GetComponent<UIPanel>();
            if (panel == null)
            {
                Debug.LogError($"UIRegistry: prefab must have UIPanel component: {id}");
                Object.Destroy(instance);
                return null;
            }

            panel.PanelId = id;
            panel.Layer = info.DefaultLayer;
            panel.CacheMode = info.CacheMode;
            return panel;
        }

        /// <summary>Instantiate a toast from the registry.</summary>
        public UIToast InstantiateToast(ResourceLocation id)
        {
            if (!_toasts.TryGetValue(id, out var prefab))
            {
                Debug.LogError($"UIRegistry: toast not found: {id}");
                return null;
            }

            var instance = Object.Instantiate(prefab);
            var toast = instance.GetComponent<UIToast>();
            if (toast == null)
            {
                Debug.LogError($"UIRegistry: prefab must have UIToast component: {id}");
                Object.Destroy(instance);
                return null;
            }

            toast.ToastId = id;
            return toast;
        }

        /// <summary>Check if a panel is registered.</summary>
        public bool HasPanel(ResourceLocation id) => _panels.ContainsKey(id);

        /// <summary>Check if a toast is registered.</summary>
        public bool HasToast(ResourceLocation id) => _toasts.ContainsKey(id);

        private class PanelInfo
        {
            public GameObject Prefab { get; }
            public int DefaultLayer { get; }
            public UIPanelCacheMode CacheMode { get; }

            public PanelInfo(GameObject prefab, int defaultLayer, UIPanelCacheMode cacheMode)
            {
                Prefab = prefab;
                DefaultLayer = defaultLayer;
                CacheMode = cacheMode;
            }
        }
    }
}
