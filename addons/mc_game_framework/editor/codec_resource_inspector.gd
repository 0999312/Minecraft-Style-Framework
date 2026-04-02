## CodecResourceInspectorPlugin — CodecResource 自定义 Inspector
##
## 编辑器可视化支持：
## - 为 CodecResource 展示类型信息与 Codec 校验入口
## - 校验错误路径高亮
## - 保存前 Codec 校验
extends EditorInspectorPlugin
class_name CodecResourceInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is CodecResource

func _parse_begin(object: Object) -> void:
	if not (object is CodecResource):
		return

	var res := object as CodecResource

	# 类型 ID
	var type_label := Label.new()
	type_label.text = "🏷️ Type ID: %s" % res.get_type_id()
	add_custom_control(type_label)

	# Codec 校验按钮
	var validate_btn := Button.new()
	validate_btn.text = "🔍 Validate with Codec"
	validate_btn.pressed.connect(_on_validate_pressed.bind(res))
	add_custom_control(validate_btn)

	# 分隔线
	add_custom_control(HSeparator.new())

func _on_validate_pressed(res: CodecResource) -> void:
	var result := res.encode_with(JsonOps.INSTANCE)
	_show_validation_result(result)

func _show_validation_result(result: DataResult) -> void:
	if result.is_success():
		print("[CodecInspector] ✅ Validation passed")
	elif result.is_partial():
		print("[CodecInspector] ⚠️ Validation partial: %s" % result.get_error())
		for d: DataResult.Diagnostic in result.get_diagnostics():
			print("  ", d.to_string())
	else:
		print("[CodecInspector] ❌ Validation failed: %s" % result.get_error())
		for d: DataResult.Diagnostic in result.get_diagnostics():
			print("  ", d.to_string())
