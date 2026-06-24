# Minecraft-Style-Framework (Unity C#)

Minecraft-Style-Framework is a Unity game feature framework inspired by Minecraft-style data-driven architecture, decoupled systems, and extensible runtime design.

> **Target Platform:** Unity 2022 LTS | **Language:** C# 9.0 (.NET Standard 2.1)

## Documentation

- English Technical Guide: [`docs/technical-guide.md`](./docs/technical-guide.md)
- 中文技术文档: [`docs/technical-guide.zh-CN.md`](./docs/technical-guide.zh-CN.md)

## Overview

This package provides:

- `ResourceLocation` identifiers (Mojang-style `namespace:path`)
- `RegistryBase<T>` + `RegistryManager` (centralized game data management)
- `EventBus` (decoupled pub/sub with cancellation)
- Tag system (dynamic grouping without modifying objects)
- I18N system (JSON-based localization)
- DFU-style declarative Codec system (encode/decode with `JsonOps` / `UnityResourceOps`)
- Data Component system (attachable data with persistence policies)
- Stack-based UI framework (panel stacks, overlays, toasts, popup queues)

## Quick Start

1. Copy `Assets/Plugins/MinecraftStyleFramework/` into your Unity project.
2. Install **Newtonsoft.Json** (Json.NET) via Package Manager or NuGet.
3. Access singletons:
   - `RegistryManager.Instance`
   - `EventBus.Instance`
   - `I18NManager.Instance`
   - `UIManager.Instance` (attach `UIManager` MonoBehaviour to a persistent GameObject)

## Project Structure

```
Assets/Plugins/MinecraftStyleFramework/
├── Runtime/
│   ├── MinecraftStyleFramework.asmdef
│   ├── Utils/ResourceLocation.cs
│   ├── Registry/
│   ├── Event/
│   ├── Codec/
│   ├── Component/
│   ├── Tag/
│   ├── I18N/
│   └── UI/
├── Editor/
│   └── MinecraftStyleFramework.Editor.asmdef
└── Tests/
    └── MinecraftStyleFramework.Tests.asmdef
```

## Dependencies

- **Unity 2022.3 LTS** or later
- **Newtonsoft.Json** (Json.NET) — for Codec/JsonOps and I18N

## Feedback

The project is still evolving. Issues, feedback, and pull requests are welcome.

---

# Minecraft-Style-Framework（Unity C# 版，中文简介）

Minecraft-Style-Framework 是一个面向 Unity 的游戏功能框架，目标是把 Minecraft 风格的数据驱动、模块解耦与高扩展性设计引入到 Unity 项目开发中。

## 文档入口

- English Technical Guide: [`docs/technical-guide.md`](./docs/technical-guide.md)
- 中文技术文档: [`docs/technical-guide.zh-CN.md`](./docs/technical-guide.zh-CN.md)

## 快速说明

- 插件目录：`Assets/Plugins/MinecraftStyleFramework/`
- 单例访问：
  - `RegistryManager.Instance`
  - `EventBus.Instance`
  - `I18NManager.Instance`
  - `UIManager.Instance`（需挂载到不销毁的 GameObject 上）

## 适合什么项目

- 物品/资源量较大
- 依赖事件驱动交互
- 需要较强的模块化与可扩展性
- 希望统一 Registry / Codec / Component / UI 体系

欢迎提交 Issue 与 Pull Request。
