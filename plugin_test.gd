# demo/demo_ui.gd
extends Node

# UI 节点引用（将在 _ready 中创建）
var item_list: VBoxContainer
var tag_filter: VBoxContainer
var event_log: VBoxContainer
var world: Node2D
var _signal_button: Button  # 新增：保存 SignalButton 引用
var _scroll: ScrollContainer  # 新增，用于调试
# 缓存物品ID对应的UI行控件
var item_rows: Dictionary = {}  # 物品ID字符串 -> HBoxContainer
var current_filter: String = "all"  # "all" 或 标签ID字符串

func _ready() -> void:
		
	var manager = RegistryManager
	if not manager.has_registry("item"):
		manager.register_registry("item", ItemRegistry.new())
		print("Item Registries Registered")
	if not manager.has_registry("tag"):
		manager.register_registry("tag", TagRegistry.new())
		print("Tag Registries Registered")
	
	var item_reg: ItemRegistry = manager.get_registry("item")
	var tag_reg: TagRegistry = manager.get_registry("tag")
	print(item_reg)
	print(tag_reg)
	if not item_reg:
		push_error("Item Registries not available")
		return
	if not tag_reg:
		push_error("Tag Registries not available")
		return
	
	# 创建UI布局
	setup_ui()
	
	# 注册物品和标签
	initialize_registries(item_reg, tag_reg)
	
	# 刷新UI
	refresh_item_list(item_reg, tag_reg)
	refresh_tag_filters(tag_reg)
	
	# 订阅事件
	EventBus.subscribe("ItemUsedEvent", _on_item_used)
	EventBus.subscribe("SignalEvent", _on_signal_event)
	
	# 信号联动：按钮信号 -> 事件
	EventBus.bind_signal(_signal_button.pressed, func():
		return SignalEvent.new(_signal_button, "pressed")
	)
	
	# 计时器信号演示
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	add_child(timer)
	timer.start()
	if _signal_button:
		EventBus.bind_signal(_signal_button.pressed, func():
			return SignalEvent.new(_signal_button, "pressed")
		)
	# 计时器信号演示
	EventBus.bind_signal(timer.timeout, func():
		return SignalEvent.new(timer, "timeout")
	)
	
	add_event_log("Demo started")
	
	await get_tree().process_frame
	print("Scroll size: ", _scroll.size)
	print("Item list child count: ", item_list.get_child_count())

func setup_ui() -> void:
	# 主容器
	var main = VBoxContainer.new()
	main.anchor_right = 1.0
	main.anchor_bottom = 1.0
	main.add_theme_constant_override("separation", 10)
	add_child(main)
	
	# 标题
	var title = Label.new()
	title.text = "Godot 4 Game Framework Demo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)
	
	# 水平分割
	var hsplit = HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(hsplit)
	
	# 左侧面板
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size.x = 400
	hsplit.add_child(left_panel)
	
	var filter_label = Label.new()
	filter_label.text = "Filter by Tag:"
	left_panel.add_child(filter_label)
	
	tag_filter = VBoxContainer.new()
	left_panel.add_child(tag_filter)
	
	var items_label = Label.new()
	items_label.text = "Items:"
	left_panel.add_child(items_label)
	
	# 物品列表滚动区域
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_scroll)
	
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(item_list)
	
	# 右侧面板
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size.x = 300
	hsplit.add_child(right_panel)
	
	var log_label = Label.new()
	log_label.text = "Event Log:"
	right_panel.add_child(log_label)
	
	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(log_scroll)
	
	event_log = VBoxContainer.new()
	event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(event_log)
	
	# 底部按钮面板
	var btn_panel = HBoxContainer.new()
	main.add_child(btn_panel)
	btn_panel.name = "ButtonPanel"
	
	var btn_spawn_sword = Button.new()
	btn_spawn_sword.text = "Spawn Sword"
	btn_spawn_sword.pressed.connect(_on_spawn_sword)
	btn_panel.add_child(btn_spawn_sword)
	
	var btn_spawn_bow = Button.new()
	btn_spawn_bow.text = "Spawn Bow"
	btn_spawn_bow.pressed.connect(_on_spawn_bow)
	btn_panel.add_child(btn_spawn_bow)
	
	var btn_spawn_arrow = Button.new()
	btn_spawn_arrow.text = "Spawn Arrow"
	btn_spawn_arrow.pressed.connect(_on_spawn_arrow)
	btn_panel.add_child(btn_spawn_arrow)
	
	_signal_button = Button.new()
	_signal_button.text = "Trigger Signal Event"
	btn_panel.add_child(_signal_button)
	# 世界层（用于放置生成的物品）
	world = Node2D.new()
	world.name = "World"
	add_child(world)

func initialize_registries(item_reg: ItemRegistry, tag_reg: TagRegistry) -> void:
	# 定义资源ID
	var sword_id = ResourceLocation.from_string("demo:sword")
	var bow_id = ResourceLocation.from_string("demo:bow")
	var arrow_id = ResourceLocation.from_string("demo:arrow")
	var weapon_tag_id = ResourceLocation.from_string("demo:weapons")
	var ranged_tag_id = ResourceLocation.from_string("demo:ranged")
	var item_registry_id = ResourceLocation.from_string("core:item")
	
	# 创建物品信息并注册
	var sword_info = ItemInfo.new()
	sword_info.item_name = "Iron Sword"
	sword_info.scene = preload("res://demo/sword.tscn")
	item_reg.register_item(sword_id, sword_info)
	
	var bow_info = ItemInfo.new()
	bow_info.item_name = "Bow"
	bow_info.scene = preload("res://demo/bow.tscn")
	item_reg.register_item(bow_id, bow_info)
	
	var arrow_info = ItemInfo.new()
	arrow_info.item_name = "Arrow"
	arrow_info.scene = preload("res://demo/arrow.tscn")
	item_reg.register_item(arrow_id, arrow_info)
	
	# 注册标签
	var weapon_tag = tag_reg.register_tag(weapon_tag_id, item_registry_id)
	var ranged_tag = tag_reg.register_tag(ranged_tag_id, item_registry_id)
	weapon_tag.add_entry(sword_id)
	weapon_tag.add_entry(bow_id)
	ranged_tag.add_entry(bow_id)
	ranged_tag.add_entry(arrow_id)

func refresh_item_list(item_reg: ItemRegistry, tag_reg: TagRegistry) -> void:
	# 清空现有列表
	for child in item_list.get_children():
		child.queue_free()
	item_rows.clear()
	
	# 遍历所有物品
	for key in item_reg.get_all_keys():
		var id = ResourceLocation.from_string(key)
		if not id:
			continue
		var info = item_reg.get_item(id)
		if not info:
			continue
		
		# 创建一行
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.name = id.to_string()
		print("item: " + id.to_string())
		# 颜色块代表物品图标
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(30, 30)
		color_rect.size = Vector2(30, 30)
		# 根据物品设置颜色
		if id.id == "sword":
			color_rect.color = Color.GRAY
		elif id.id == "bow":
			color_rect.color = Color.BROWN
		elif id.id == "arrow":
			color_rect.color = Color.YELLOW
		else:
			color_rect.color = Color.WHITE
		row.add_child(color_rect)
		
		# 物品名称
		var name_label = Label.new()
		name_label.text = info.item_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		
		# 标签显示
		var tag_label = Label.new()
		tag_label.text = _get_tags_string(id, tag_reg)
		row.add_child(tag_label)
		
		# 使用按钮
		var use_btn = Button.new()
		use_btn.text = "Use"
		use_btn.pressed.connect(_on_use_item.bind(id))
		row.add_child(use_btn)
		
		item_list.add_child(row)
		item_rows[key] = row

func _get_tags_string(item_id: ResourceLocation, tag_reg: TagRegistry) -> String:
	var tags = []
	for tag_key in tag_reg.get_all_keys():
		var tag_id = ResourceLocation.from_string(tag_key)
		if tag_reg.has_entry_in_tag(tag_id, item_id):
			tags.append(tag_id.id)
	return "[" + ", ".join(tags) + "]"

func refresh_tag_filters(tag_reg: TagRegistry) -> void:
	# 清空现有过滤器
	for child in tag_filter.get_children():
		child.queue_free()
	
	# “所有物品”按钮
	var all_btn = Button.new()
	all_btn.text = "All Items"
	all_btn.pressed.connect(_on_filter_all)
	tag_filter.add_child(all_btn)
	
	# 每个标签一个按钮
	for key in tag_reg.get_all_keys():
		var tag_id = ResourceLocation.from_string(key)
		if not tag_id:
			continue
		var btn = Button.new()
		btn.text = tag_id.to_string()
		# 正确绑定参数
		btn.pressed.connect(_on_filter_tag.bind(tag_id))
		tag_filter.add_child(btn)

func _on_filter_all() -> void:
	current_filter = "all"
	_apply_filter()

func _on_filter_tag(tag_id: ResourceLocation) -> void:
	current_filter = tag_id.to_string()
	_apply_filter()

func _apply_filter() -> void:
	var tag_reg = RegistryManager.get_registry("tag")
	if not tag_reg:
		return
	print("Apply Filter: " + current_filter)
	for key in item_rows:
		var row = item_rows[key]
		var item_id = ResourceLocation.from_string(key)
		if not item_id:
			row.visible = false
			continue
		
		var visible = false
		if current_filter == "all":
			visible = true
		else:
			var filter_id = ResourceLocation.from_string(current_filter)
			if filter_id:
				visible = tag_reg.has_entry_in_tag(filter_id, item_id)
			else:
				visible = false
		row.visible = visible
		print("Item: " + key + (" true" if visible else " false"))

func add_event_log(message: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	var label = Label.new()
	label.text = "[%s] %s" % [timestamp, message]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_log.add_child(label)
	# 滚动到底部
	await get_tree().process_frame  # 等待布局更新
	var scroll = event_log.get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = (int)(scroll.get_v_scroll_bar().max_value)

func _on_use_item(item_id: ResourceLocation) -> void:
	EventBus.publish(ItemUsedEvent.new(item_id, self))
	add_event_log("Used item: " + item_id.to_string())

func _on_item_used(event: ItemUsedEvent) -> void:
	add_event_log("Event received: ItemUsed - " + event.item_id.to_string())

func _on_signal_event(event: SignalEvent) -> void:
	add_event_log("Event received: Signal from " + event.source_node.name + "." + event.signal_name)

func _on_spawn_sword() -> void:
	_spawn_item(ResourceLocation.from_string("demo:sword"), Vector2(100, 300))

func _on_spawn_bow() -> void:
	_spawn_item(ResourceLocation.from_string("demo:bow"), Vector2(200, 350))

func _on_spawn_arrow() -> void:
	_spawn_item(ResourceLocation.from_string("demo:arrow"), Vector2(300, 300))

func _spawn_item(item_id: ResourceLocation, pos: Vector2) -> void:
	var item_reg = RegistryManager.get_registry("item")
	if not item_reg:
		return
	var instance = item_reg.instantiate_item(item_id)
	if instance:
		world.add_child(instance)
		instance.position = pos
		add_event_log("Spawned: " + item_id.to_string())
	else:
		add_event_log("Failed to spawn: " + item_id.to_string())
