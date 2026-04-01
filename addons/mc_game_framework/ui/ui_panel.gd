extends Control
class_name UIPanel
## 栈式UI面板基类
## 所有需要通过 UIManager 管理的面板都应继承此类

## 面板标识符（由 UIManager 在打开时自动赋值）
var panel_id: ResourceLocation

## 面板所在的UI层级（由 UIManager 在打开时自动赋值）
var ui_layer: int = UILayer.NORMAL

## 缓存模式
var cache_mode: int = CacheMode.NONE

## 缓存模式枚举
enum CacheMode {
	NONE,    # 关闭时销毁（queue_free）
	CACHE,   # 关闭时隐藏，下次打开时复用
}

# ---- 生命周期回调（子类覆写） ----

## 首次创建时调用（仅一次）
func _on_init() -> void:
	pass

## 每次打开时调用，data 为外部传入的参数字典
func _on_open(_data: Dictionary = {}) -> void:
	pass

## 被新面板覆盖时调用
func _on_pause() -> void:
	pass

## 上方面板关闭后恢复时调用
func _on_resume() -> void:
	pass

## 从栈中移除时调用
func _on_close() -> void:
	pass

## 销毁前调用（仅 CacheMode.NONE 时）
func _on_destroy() -> void:
	pass
