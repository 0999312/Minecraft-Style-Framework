extends Event
class_name LanguageChangedEvent

var lang_code: String

func _init(p_lang_code: String) -> void:
	lang_code = p_lang_code
