extends RefCounted
class_name UILayer
## UI 层级常量定义
## 使用整数常量（非枚举），便于用户在内置层级之间自定义扩展

const SCENE  := 0      # 场景内UI（伤害数字、名字牌）
const NORMAL := 100    # 普通全屏面板（背包、地图、商店）
const POPUP  := 200    # 弹窗（确认框、提示框）
const TOAST  := 300    # 通知提示（自动消失）
const SYSTEM := 400    # 系统级（Loading画面、断网提示）

static func get_all_layers() -> Array[int]:
	return [SCENE, NORMAL, POPUP, TOAST, SYSTEM]
