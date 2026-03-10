@tool
extends EditorPlugin

var _panel_instance: Control = null

func _enter_tree():
	# 自动注册 Autoload 单例
	_register_autoload("RegistryManager", "res://addons/mc_game_framework/autoload/registry_manager.gd")
	_register_autoload("EventBus", "res://addons/mc_game_framework/autoload/event_bus.gd")
	_register_autoload("I18NManager", "res://addons/mc_game_framework/autoload/i18n_manager.gd")
	print("[MinecraftStyleFramework] Editor plugin enabled. Autoloads registered.")

# 内部方法：检查并注册 Autoload
func _register_autoload(name: String, path: String) -> void:
	add_autoload_singleton(name, path)
	print("[MinecraftStyleFramework] Autoload registered: %s -> %s" % [name, path])

func _exit_tree():
	# 自动卸载 Autoload 单例
	_unregister_autoload("RegistryManager")
	_unregister_autoload("EventBus")
	_unregister_autoload("I18NManager")
	print("[MinecraftStyleFramework] Editor plugin disabled. Autoloads unregistered.")

# 内部方法：卸载 Autoload
func _unregister_autoload(name: String) -> void:
	remove_autoload_singleton(name)
	print("[MinecraftStyleFramework] Autoload unregistered: %s" % name)
