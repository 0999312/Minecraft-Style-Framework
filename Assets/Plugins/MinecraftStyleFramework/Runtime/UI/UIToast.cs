using System;
using System.Collections;
using System.Collections.Generic;
using MinecraftStyleFramework.Utils;
using UnityEngine;

namespace MinecraftStyleFramework.UI
{
    /// <summary>
    /// Base class for toast notifications that auto-dismiss.
    /// </summary>
    public abstract class UIToast : MonoBehaviour
    {
        /// <summary>Toast identifier.</summary>
        public ResourceLocation ToastId { get; set; }

        /// <summary>Event raised when the toast should be dismissed.</summary>
        public event Action<UIToast> Dismissed;

        /// <summary>Called when the toast is shown.</summary>
        public virtual void OnShow(Dictionary<string, object> data = null) { }

        /// <summary>Called when the toast is dismissed.</summary>
        public virtual void OnDismiss() { }

        /// <summary>Start the auto-dismiss timer.</summary>
        public void StartDismissTimer(float duration)
        {
            StartCoroutine(DismissAfter(duration));
        }

        private IEnumerator DismissAfter(float duration)
        {
            yield return new WaitForSeconds(duration);
            Dismissed?.Invoke(this);
        }

        /// <summary>Manually trigger dismiss.</summary>
        public void DismissNow() => Dismissed?.Invoke(this);
    }
}
