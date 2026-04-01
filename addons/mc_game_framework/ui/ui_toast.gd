extends Control
class_name UIToast
## Toast 提示基类
## 与 UIPanel 不同，Toast 不参与栈管理，可同时显示多个，到期自动消失

## Toast 标识符
var toast_id: ResourceLocation

## 显示持续时间（秒）
var duration: float = 3.0

## 剩余计时
var _remaining: float = 0.0

## Toast 消失时发出的信号（UIManager 监听此信号进行清理）
signal dismissed()

## 由 UIManager 调用，启动自动消失计时
func start_dismiss_timer(p_duration: float) -> void:
	duration = p_duration
	_remaining = p_duration
	set_process(true)

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		set_process(false)
		_on_dismiss()
		dismissed.emit()

# ---- 生命周期回调（子类覆写） ----

## 显示时调用
func _on_show(_data: Dictionary = {}) -> void:
	pass

## 消失时调用（自动消失或手动关闭）
func _on_dismiss() -> void:
	pass
