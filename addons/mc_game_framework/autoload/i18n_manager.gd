extends Node

# 加载某个语言的 JSON 翻译文件，并注册到 TranslationServer
func load_translation(lang_code: String, file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("Cannot open translation file: ", file_path)
		return false

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		printerr("JSON parsing failed or invalid format: file must contain a key-value dictionary")
		return false

	var translation = Translation.new()
	translation.locale = lang_code

	for key in data:
		translation.add_message(key, data[key])

	_remove_translation(lang_code)
	TranslationServer.add_translation(translation)

	print("Language [", lang_code, "] loaded successfully with ", data.size(), " entries")
	return true

# 辅助函数：移除已注册的指定语言翻译
func _remove_translation(lang_code: String) -> void:
	var all_translations = TranslationServer.get_translations()
	for t in all_translations:
		if t.locale == lang_code:
			TranslationServer.remove_translation(t)
			break

# 切换当前语言
func set_language(lang_code: String) -> void:
	TranslationServer.set_locale(lang_code)

# 获取当前语言代码
func get_current_language() -> String:
	return TranslationServer.get_locale()

# 获取翻译文本，支持占位符替换（格式：{0}, {1} ...）
func get_text(key: String, args: Array = []) -> String:
	var text = tr(key)
	if args.is_empty():
		return text
	# 使用 String.format 进行占位符替换
	return text.format(args)
