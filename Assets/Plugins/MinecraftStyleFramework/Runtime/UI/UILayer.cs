namespace MinecraftStyleFramework.UI
{
    /// <summary>
    /// UI layer constants defining rendering order.
    /// </summary>
    public static class UILayer
    {
        public const int Scene = 0;
        public const int Normal = 100;
        public const int Popup = 200;
        public const int Toast = 300;
        public const int System = 400;

        public static int[] GetAllLayers() => new[] { Scene, Normal, Popup, Toast, System };
    }
}
