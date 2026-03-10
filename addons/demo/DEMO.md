# Demo: Minecraft-Style-Framework Addon (Godot 4.6)

This demo visually demonstrates the current features of the Addon inside Godot so
that behavior is visible in the scene instead of being printed only to logs.

Files added: `addons/demo/DemoScene.tscn`, `addons/demo/demo_scene.gd`, `addons/demo/DEMO.md`.

How to open
1. Open Godot 4.6 and load the project at the repository root (project.godot is present).
2. Open `res://addons/demo/DemoScene.tscn` and run the scene.

What the demo shows
- ResourceLocation: attempts to load `res://icon.svg` and display it. If not present the demo shows a fallback placeholder.
- Registry: visually demonstrates adding, reading, and removing keys from a simple registry map.
- Tag: demonstrates tagging an id and querying its tags.
- EventBus: attempts to use an existing `EventBus` addon class if found; otherwise uses a local fallback event bus and shows events in the UI.
- I18n: toggles between English and Chinese sample strings.

Implementation notes
- The demo script uses fallbacks when the corresponding addon classes are not found so the demo works out-of-the-box.
- If your addon provides classes named `EventBus.gd`, `Registry.gd`, `Tag.gd`, `I18n.gd`, or `ResourceLocation.gd` under `res://` or `res://addons/`, the demo will try to instantiate and use them when available.

If you want me to refine the demo to call concrete addon APIs, I can update the demo to match the actual class names and method signatures — tell me where the addon classes are (paths and class/method names) or I can scan the repo for them and adapt the demo accordingly.

---

Commit message: "Add interactive demo scene and documentation for addon features (Godot 4.6)"