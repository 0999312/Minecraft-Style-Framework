using System.Collections.Generic;
using System.Linq;
using MinecraftStyleFramework.Events;
using MinecraftStyleFramework.Events.UI;
using MinecraftStyleFramework.Registry;
using MinecraftStyleFramework.Utils;
using UnityEngine;

namespace MinecraftStyleFramework.UI
{
    /// <summary>
    /// Stack-based UI manager. Manages panel stacks, overlays, toasts, and popup queues.
    /// Attach to a persistent GameObject (DontDestroyOnLoad).
    /// </summary>
    public class UIManager : MonoBehaviour
    {
        private const int MaxOpenDepth = 8;
        private const int MaxCachedPanels = 10;
        private const string UIRegistryKey = "ui";

        private static UIManager _instance;
        public static UIManager Instance => _instance;

        private readonly Dictionary<int, List<UIPanel>> _panelStacks = new();
        private readonly Dictionary<string, int> _activePanelIds = new();
        private readonly Dictionary<string, UIPanel> _cachedPanels = new();
        private readonly List<string> _cacheOrder = new();
        private readonly Dictionary<string, (GameObject obj, int layer)> _overlays = new();
        private readonly List<UIToast> _activeToasts = new();
        private readonly List<(ResourceLocation panelId, Dictionary<string, object> data, int priority)> _popupQueue = new();
        private readonly Dictionary<int, Transform> _layerRoots = new();

        private int _openDepth;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);

            foreach (var layer in UILayer.GetAllLayers())
                EnsureLayer(layer);
        }

        private void Update()
        {
            _openDepth = 0;
        }

        /// <summary>Open a panel by ResourceLocation.</summary>
        public UIPanel OpenPanel(ResourceLocation id, Dictionary<string, object> data = null, int layerOverride = -1)
        {
            if (id == null)
            {
                Debug.LogError("UIManager: panel id must not be null");
                return null;
            }

            _openDepth++;
            if (_openDepth > MaxOpenDepth)
            {
                Debug.LogError($"UIManager: open_panel recursion depth exceeded {MaxOpenDepth}, aborting");
                _openDepth--;
                return null;
            }

            var idStr = id.ToString();
            if (_activePanelIds.ContainsKey(idStr))
            {
                Debug.LogWarning($"UIManager: Panel already open: {idStr}");
                _openDepth--;
                return null;
            }

            UIPanel panel;
            if (_cachedPanels.TryGetValue(idStr, out var cached))
            {
                panel = cached;
                _cachedPanels.Remove(idStr);
                _cacheOrder.Remove(idStr);
            }
            else
            {
                var uiReg = GetUIRegistry();
                if (uiReg == null)
                {
                    Debug.LogError($"UIManager: UIRegistry not registered. Call RegistryManager.Instance.RegisterRegistry(\"{UIRegistryKey}\", ...)");
                    _openDepth--;
                    return null;
                }

                panel = uiReg.InstantiatePanel(id);
                if (panel == null)
                {
                    _openDepth--;
                    return null;
                }

                panel.OnInit();
            }

            var targetLayer = layerOverride >= 0 ? layerOverride : panel.Layer;
            EnsureLayer(targetLayer);

            var stack = _panelStacks[targetLayer];
            if (stack.Count > 0)
            {
                var top = stack[^1];
                top.OnPause();
                top.gameObject.SetActive(false);
                EventBus.Instance.Publish(new UIPauseEvent(top.PanelId, targetLayer));
            }

            stack.Add(panel);
            _activePanelIds[idStr] = targetLayer;
            panel.transform.SetParent(_layerRoots[targetLayer], false);
            panel.gameObject.SetActive(true);

            panel.OnOpen(data);
            EventBus.Instance.Publish(new UIOpenEvent(id, targetLayer));

            _openDepth--;
            return panel;
        }

        /// <summary>Pop the top panel from a layer (back navigation).</summary>
        public void Back(int layer = UILayer.Normal)
        {
            EnsureLayer(layer);
            var stack = _panelStacks[layer];
            if (stack.Count == 0) return;

            var panel = stack[^1];
            stack.RemoveAt(stack.Count - 1);
            DoClosePanel(panel, layer);

            if (stack.Count > 0)
            {
                var newTop = stack[^1];
                newTop.gameObject.SetActive(true);
                newTop.OnResume();
                EventBus.Instance.Publish(new UIResumeEvent(newTop.PanelId, layer));
            }

            if (layer == UILayer.Popup)
                TryShowNextPopup();
        }

        /// <summary>Close a specific panel by ID.</summary>
        public void ClosePanel(ResourceLocation id)
        {
            if (id == null) return;

            var idStr = id.ToString();
            if (!_activePanelIds.TryGetValue(idStr, out var layer)) return;

            var stack = _panelStacks[layer];
            var index = -1;
            for (var i = 0; i < stack.Count; i++)
            {
                if (stack[i].PanelId.ToString() == idStr)
                {
                    index = i;
                    break;
                }
            }

            if (index < 0) return;

            var panel = stack[index];
            var wasTop = index == stack.Count - 1;
            stack.RemoveAt(index);
            DoClosePanel(panel, layer);

            if (wasTop && stack.Count > 0)
            {
                var newTop = stack[^1];
                newTop.gameObject.SetActive(true);
                newTop.OnResume();
                EventBus.Instance.Publish(new UIResumeEvent(newTop.PanelId, layer));
            }

            if (layer == UILayer.Popup)
                TryShowNextPopup();
        }

        /// <summary>Close all panels in a layer, or all layers if layer is -1.</summary>
        public void CloseAll(int layer = -1)
        {
            if (layer >= 0)
            {
                CloseAllInLayer(layer);
                return;
            }

            foreach (var l in _panelStacks.Keys.ToList())
                CloseAllInLayer(l);
        }

        /// <summary>Get the top panel of a layer.</summary>
        public UIPanel GetTopPanel(int layer = UILayer.Normal)
        {
            EnsureLayer(layer);
            var stack = _panelStacks[layer];
            return stack.Count > 0 ? stack[^1] : null;
        }

        /// <summary>Check if a panel is open (O(1)).</summary>
        public bool IsPanelOpen(ResourceLocation id) => id != null && _activePanelIds.ContainsKey(id.ToString());

        /// <summary>Add a persistent overlay (HUD, minimap, etc.).</summary>
        public void AddOverlay(ResourceLocation id, GameObject overlay, int layer = UILayer.Scene)
        {
            if (id == null || overlay == null) return;

            var idStr = id.ToString();
            if (_overlays.ContainsKey(idStr)) return;
            EnsureLayer(layer);
            overlay.transform.SetParent(_layerRoots[layer], false);
            _overlays[idStr] = (overlay, layer);
        }

        /// <summary>Remove an overlay.</summary>
        public void RemoveOverlay(ResourceLocation id)
        {
            if (id == null) return;

            var idStr = id.ToString();
            if (!_overlays.TryGetValue(idStr, out var info)) return;
            if (info.obj != null) Destroy(info.obj);
            _overlays.Remove(idStr);
        }

        /// <summary>Get an overlay.</summary>
        public GameObject GetOverlay(ResourceLocation id)
        {
            if (id == null) return null;
            var idStr = id.ToString();
            return _overlays.TryGetValue(idStr, out var info) ? info.obj : null;
        }

        /// <summary>Show/hide an overlay.</summary>
        public void SetOverlayVisible(ResourceLocation id, bool visible)
        {
            var obj = GetOverlay(id);
            if (obj != null) obj.SetActive(visible);
        }

        /// <summary>Show a toast notification.</summary>
        public UIToast ShowToast(ResourceLocation toastId, Dictionary<string, object> data = null, float duration = 3f)
        {
            var uiReg = GetUIRegistry();
            if (uiReg == null) return null;

            var toast = uiReg.InstantiateToast(toastId);
            if (toast == null) return null;

            EnsureLayer(UILayer.Toast);
            toast.transform.SetParent(_layerRoots[UILayer.Toast], false);
            toast.gameObject.SetActive(true);
            toast.OnShow(data);
            toast.StartDismissTimer(duration);
            toast.Dismissed += OnToastDismissed;
            _activeToasts.Add(toast);
            return toast;
        }

        /// <summary>Manually dismiss a toast.</summary>
        public void DismissToast(UIToast toast)
        {
            if (toast == null) return;
            toast.OnDismiss();
            RemoveToast(toast);
        }

        /// <summary>Dismiss all active toasts.</summary>
        public void DismissAllToasts()
        {
            var copy = new List<UIToast>(_activeToasts);
            foreach (var toast in copy)
            {
                toast.OnDismiss();
                RemoveToast(toast);
            }
        }

        /// <summary>Queue a popup panel (FIFO + priority).</summary>
        public void QueuePopup(ResourceLocation panelId, Dictionary<string, object> data = null, int priority = 0)
        {
            if (panelId == null) return;

            _popupQueue.Add((panelId, data ?? new Dictionary<string, object>(), priority));
            _popupQueue.Sort((a, b) => b.priority.CompareTo(a.priority));
            TryShowNextPopup();
        }

        private UIRegistry GetUIRegistry() =>
            RegistryManager.Instance.GetRegistry<UIRegistry>(UIRegistryKey);

        private void EnsureLayer(int layer)
        {
            if (_panelStacks.ContainsKey(layer)) return;

            _panelStacks[layer] = new List<UIPanel>();
            var go = new GameObject($"UILayer_{layer}");
            go.transform.SetParent(transform, false);
            _layerRoots[layer] = go.transform;
        }

        private void DoClosePanel(UIPanel panel, int layer)
        {
            if (panel == null) return;

            var idStr = panel.PanelId?.ToString();
            if (!string.IsNullOrEmpty(idStr))
                _activePanelIds.Remove(idStr);

            panel.OnClose();
            EventBus.Instance.Publish(new UICloseEvent(panel.PanelId, layer));
            panel.transform.SetParent(null);

            if (panel.CacheMode == UIPanelCacheMode.Cache && !string.IsNullOrEmpty(idStr))
            {
                if (_cachedPanels.Count >= MaxCachedPanels)
                {
                    var oldest = _cacheOrder[0];
                    _cacheOrder.RemoveAt(0);
                    if (_cachedPanels.TryGetValue(oldest, out var old))
                    {
                        old.OnPanelDestroy();
                        Destroy(old.gameObject);
                        _cachedPanels.Remove(oldest);
                    }
                }

                _cacheOrder.Add(idStr);
                _cachedPanels[idStr] = panel;
                panel.gameObject.SetActive(false);
            }
            else
            {
                panel.OnPanelDestroy();
                Destroy(panel.gameObject);
            }
        }

        private void CloseAllInLayer(int layer)
        {
            EnsureLayer(layer);
            var stack = _panelStacks[layer];
            while (stack.Count > 0)
            {
                var panel = stack[^1];
                stack.RemoveAt(stack.Count - 1);
                DoClosePanel(panel, layer);
            }
        }

        private void OnToastDismissed(UIToast toast) => RemoveToast(toast);

        private void RemoveToast(UIToast toast)
        {
            if (toast == null) return;

            _activeToasts.Remove(toast);
            toast.Dismissed -= OnToastDismissed;
            Destroy(toast.gameObject);
        }

        private void TryShowNextPopup()
        {
            EnsureLayer(UILayer.Popup);
            if (_panelStacks[UILayer.Popup].Count > 0) return;
            if (_popupQueue.Count == 0) return;

            var next = _popupQueue[0];
            _popupQueue.RemoveAt(0);
            OpenPanel(next.panelId, next.data, UILayer.Popup);
        }
    }
}
