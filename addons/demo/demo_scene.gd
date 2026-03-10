extends Control

# Demo scene for Minecraft-Style-Framework addon (Godot 4.6)
# This script builds a UI that visually demonstrates the addon's features:
# ResourceLocation, Registry, Tag, EventBus, I18n. If addon classes/resources
# are present in the project they will be used; otherwise the demo uses local
# fallback implementations so the demo is always visual and interactive.

@onready var title: Label = null
@onready var output: Label = null
@onready var preview: TextureRect = null

var registry := {}
var tags := {}

# Simple internal event bus fallback
class_name SimpleEventBus
signal demo_event(data)
func emit_event(data):
	emit_signal("demo_event", data)

func _ready() -> void:
	# Build UI
	self.anchor_left = 0.0
	self.anchor_top = 0.0
	self.anchor_right = 1.0
	self.anchor_bottom = 1.0

	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchor_left = 0.0
	main_vbox.anchor_top = 0.0
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.margin_left = 8
	main_vbox.margin_top = 8
	main_vbox.margin_right = -8
	main_vbox.margin_bottom = -8
	add_child(main_vbox)

	# Header
	title = Label.new()
	title.text = "Minecraft-Style-Framework - Addon Demo (Godot 4.6)"
	title.add_theme_color_override("font_color", Color8(30,30,30))
	title.theme_override_font_size = 18
	main_vbox.add_child(title)

	var hbox = HBoxContainer.new()
	 hbox.custom_minimum_size = Vector2(0, 420)
	main_vbox.add_child(hbox)

	# Left: Buttons
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(300, 0)
hbox.add_child(left_vbox)

	var btn_resource = Button.new(); btn_resource.text = "ResourceLocation: Load icon"; left_vbox.add_child(btn_resource)
	btn_resource.pressed.connect(_on_resource_demo)

	var btn_registry = Button.new(); btn_registry.text = "Registry: Add / Get / Remove"; left_vbox.add_child(btn_registry)
	btn_registry.pressed.connect(_on_registry_demo)

	var btn_tag = Button.new(); btn_tag.text = "Tag: Add tag / Query"; left_vbox.add_child(btn_tag)
	btn_tag.pressed.connect(_on_tag_demo)

	var btn_event = Button.new(); btn_event.text = "EventBus: Emit message"; left_vbox.add_child(btn_event)
	btn_event.pressed.connect(_on_event_demo)

	var btn_i18n = Button.new(); btn_i18n.text = "I18n: Toggle language"; left_vbox.add_child(btn_i18n)
	btn_i18n.pressed.connect(_on_i18n_demo)

	# Spacer
	left_vbox.add_child(VSeparator.new())

	# Right: Preview and Output
	var right_vbox = VBoxContainer.new()
hbox.add_child(right_vbox)

	preview = TextureRect.new()
	preview.expand = true
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(320, 240)
	right_vbox.add_child(preview)

	output = Label.new()
	output.text = "Output:\n(press buttons on the left to run demonstrations)"
	output.v_size_flags = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(output)

	# Try to wire to addon EventBus if exists, otherwise use fallback
	if _has_addon_class("EventBus"):
		# attempt to instantiate addon's EventBus (user project may provide a class)
		var bus = _instantiate_addon_class("EventBus")
		if bus:
			# If it has a signal we subscribe; assume signal 'demo_event' or 'emitted'
			if bus.has_signal("demo_event"):
				bus.connect("demo_event", Callable(self, "_on_event_received"))
			elif bus.has_signal("emitted"):
				bus.connect("emitted", Callable(self, "_on_event_received"))
			else:
				# fallback: if it provides a method to register, try common names
				if bus.has_method("subscribe"):
					bus.subscribe(Callable(self, "_on_event_received"))
			else:
				# do nothing; event demo will use local bus
				pass
		else:
			# use internal bus instance and connect
			var local_bus = SimpleEventBus.new()
			local_bus.connect("demo_event", Callable(self, "_on_event_received"))
			self.set_meta("local_bus", local_bus)

		# Load default preview icon if present
		_on_resource_demo()

	func _has_addon_class(class_name: String) -> bool:
	# Best-effort: check if a script file with the class name exists in addons/ or project
	var paths = ["res://addons/", "res://"]
	for p in paths:
		var glob = p + "**/%s.gd".format(class_name)
		# ResourceLoader doesn't provide globbing; we attempt a couple of common paths
		var try_path = p + class_name + ".gd"
		if FileAccess.file_exists(try_path):
			return true
	# Not found by naive check
	return false

	func _instantiate_addon_class(class_name: String) -> Object:
	var try_path = "res://addons/%s.gd".format(class_name)
	if FileAccess.file_exists(try_path):
		var s = load(try_path)
		if typeof(s) == TYPE_SCRIPT:
			return s.new()
	# try root
	try_path = "res://%s.gd".format(class_name)
	if FileAccess.file_exists(try_path):
		var s = load(try_path)
		if typeof(s) == TYPE_SCRIPT:
			return s.new()
	return null

# --- Demo handlers ---
func _on_resource_demo() -> void:
	# Try to load repository icon.svg as a visual resource
	var icon_path = "res://icon.svg"
	if FileAccess.file_exists(icon_path):
		var tex = load(icon_path)
		if tex:
			preview.texture = tex
			output.text = "ResourceLocation demo:\nLoaded resource: %s".format(icon_path)
			return
	# Fallback: show a colored rectangle as preview
	preview.texture = null
	output.text = "ResourceLocation demo:\nicon.svg not found in project; showing fallback placeholder."

func _on_registry_demo() -> void:
	# Demonstrates simple registry operations
	registry["player_health"] = 20
	registry["player_name"] = "DemoPlayer"
	var lines = ["Registry demo:"]
	lines.append("Set player_health = %d" % registry["player_health"])
	lines.append("Set player_name = %s" % registry["player_name"])
	# Read
	var health = registry.get("player_health", -1)
	lines.append("Read player_health -> %d" % health)
	# Remove
	registry.erase("player_name")
	lines.append("Removed player_name; now get -> %s" % str(registry.get("player_name", "<nil>")))
	output.text = String.join(lines, "\n")

func _on_tag_demo() -> void:
	# Demonstrates tagging system: add tag to an id and query
	var id = "stone_block"
tags[id] = ["mined", "solid"]
	output.text = "Tag demo:\nAdded tags %s to id %s\nQuery: is 'mined' in tags? %s".format(str(tags[id]), id, str("mined" in tags[id]))

func _on_event_demo() -> void:
	# Emit an event via addon EventBus if present, otherwise via local bus
	if _has_addon_class("EventBus"):
		var bus = _instantiate_addon_class("EventBus")
		if bus and bus.has_method("emit"):
			bus.emit("demo_event", {"msg": "Hello from addon EventBus"})
			output.text = "EventBus demo: emitted via addon EventBus"
			return
	# local fallback
	var local_bus = self.get_meta("local_bus")
	if local_bus:
		local_bus.emit_event({"msg": "Hello from fallback EventBus"})
		output.text = "EventBus demo: emitted via fallback local event bus"

func _on_event_received(data) -> void:
	output.text = "EventBus received:\n%s".format(str(data))

func _on_i18n_demo() -> void:
	# Toggle two-demo translations: English / Chinese
	var cur = self.get_meta("demo_lang")
	if cur == "zh":
		self.set_meta("demo_lang", "en")
		output.text = "I18n demo:\nSwitched to English: 'Hello, Demo'"
	else:
		self.set_meta("demo_lang", "zh")
		output.text = "I18n demo:\n切换到中文: '你好, 演示'"


# Utility
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		# ensure meta default
		if not self.has_meta("demo_lang"):
			self.set_meta("demo_lang", "en")