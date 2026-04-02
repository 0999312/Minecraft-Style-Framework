# Minecraft-Style-Framework

Minecraft-Style-Framework is a Godot feature framework inspired by Minecraft-style data-driven architecture, decoupled systems, and extensible runtime design.

> English-first documentation:
> - Technical Guide (EN): [`docs/technical-guide.md`](./docs/technical-guide.md)
> - 技术文档（中文）: [`docs/technical-guide.zh-CN.md`](./docs/technical-guide.zh-CN.md)

## Overview

This repository currently provides:

- `ResourceLocation` identifiers
- `RegistryBase` + `RegistryManager`
- `EventBus`
- Tag system
- I18n system
- DFU-style declarative Codec system
- Data Component system
- Stack-based UI framework
- Editor inspector support

## Quick Start

1. Copy `addons/mc_game_framework/` into your Godot project's `addons/` directory.
2. Enable `Minecraft-Style-Framework` in **Project -> Project Settings -> Plugins**.
3. After enabling the plugin, Godot registers four Autoload singletons:
   - `RegistryManager`
   - `EventBus`
   - `I18NManager`
   - `UIManager`

For API details, architecture notes, usage examples, and technical caveats, read the technical guide:

- English: [`docs/technical-guide.md`](./docs/technical-guide.md)
- 中文: [`docs/technical-guide.zh-CN.md`](./docs/technical-guide.zh-CN.md)

## Repository Notes

- Main framework code: `addons/mc_game_framework/`
- Demo content: `demo/`
- Plugin entry: `addons/mc_game_framework/mc_game_framework.gd`

## Feedback

The project is still evolving. Issues, feedback, and pull requests are welcome.

---

# Minecraft-Style-Framework（中文简介）

Minecraft-Style-Framework 是一个面向 Godot 的游戏功能框架，目标是把 Minecraft 风格的数据驱动、模块解耦与高扩展性设计引入到项目开发中。

## 文档入口

- English Technical Guide: [`docs/technical-guide.md`](./docs/technical-guide.md)
- 中文技术文档: [`docs/technical-guide.zh-CN.md`](./docs/technical-guide.zh-CN.md)

## 快速说明

- 插件主体目录：`addons/mc_game_framework/`
- 启用插件后会自动注册 4 个 Autoload：
  - `RegistryManager`
  - `EventBus`
  - `I18NManager`
  - `UIManager`
- API 介绍、使用须知、架构说明与示例现已拆分到独立技术文档中。

## 适合什么项目

- 物品/资源量较大
- 依赖事件驱动交互
- 需要较强的模块化与可扩展性
- 希望统一 Registry / Codec / Component / UI 体系

欢迎提交 Issue 与 Pull Request。
