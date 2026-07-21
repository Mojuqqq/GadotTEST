extends Node

var item_menu_open: bool = false
var enemy_menu_open: bool = false

func _ready():
	print("Debug: F1 — выбор предмета, F2 — выбор врага")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1 and not item_menu_open:
			open_item_menu()
		if event.keycode == KEY_F2 and not enemy_menu_open:
			open_enemy_menu()
		# Закрыть меню по Escape
		if event.keycode == KEY_ESCAPE:
			close_all_menus()

func open_item_menu():
	var room = GameManager.get_current_room()
	if not room:
		print("Нет текущей комнаты.")
		return
	if GameManager.all_items.is_empty():
		print("Нет предметов.")
		return
	
	item_menu_open = true
	var menu = create_menu("Выберите предмет:", GameManager.all_items, func(item):
		give_item(item)
	)
	room.add_child(menu)

func open_enemy_menu():
	var room = GameManager.get_current_room()
	if not room:
		print("Нет текущей комнаты.")
		return
	if GameManager.enemy_pool.is_empty():
		print("Пул врагов пуст.")
		return
	
	enemy_menu_open = true
	var menu = create_menu("Выберите врага:", GameManager.enemy_pool, func(scene):
		spawn_enemy(scene)
	)
	room.add_child(menu)

func create_menu(title: String, item_list: Array, callback: Callable) -> CanvasLayer:
	var layer = CanvasLayer.new()
	layer.layer = 100  # выше всего
	var panel = Panel.new()
	panel.size = Vector2(300, 400)
	panel.position = Vector2( (get_viewport().size.x - 300) / 2, (get_viewport().size.y - 400) / 2 )
	panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	
	var vbox = VBoxContainer.new()
	vbox.size = Vector2(280, 380)
	vbox.position = Vector2(10, 10)
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var item_vbox = VBoxContainer.new()
	scroll.add_child(item_vbox)
	
	for item in item_list:
		var btn = Button.new()
		var display_name = item.name if item is ItemData else item.resource_path.get_file().get_basename()
		btn.text = display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			callback.call(item)
			layer.queue_free()
			item_menu_open = false
			enemy_menu_open = false
		)
		item_vbox.add_child(btn)
	
	# Кнопка закрытия
	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(func():
		layer.queue_free()
		item_menu_open = false
		enemy_menu_open = false
	)
	vbox.add_child(close_btn)
	
	layer.add_child(panel)
	return layer

func give_item(item: ItemData):
	var room = GameManager.get_current_room()
	if not room:
		print("Нет текущей комнаты.")
		return
	var chest_scene = preload("res://Scenes/Chest.tscn")
	var chest = chest_scene.instantiate()
	chest.item = item
	room.add_child(chest)
	chest.position = Vector2(GameManager.room_width / 2.0, GameManager.room_height / 2.0)
	print("Дебаг: создан сундук с предметом: ", item.name)

func spawn_enemy(scene: PackedScene):
	var room = GameManager.get_current_room()
	if not room:
		print("Нет текущей комнаты.")
		return
	var enemy = scene.instantiate()
	room.add_child(enemy)
	var margin = 50
	var x = randf_range(margin, GameManager.room_width - margin)
	var y = randf_range(margin, GameManager.room_height - margin)
	enemy.position = Vector2(x, y)
	if enemy.has_method("set_room_limits"):
		var limits = Rect2(room.global_position.x, room.global_position.y, GameManager.room_width, GameManager.room_height)
		enemy.set_room_limits(limits)
	if room.is_active:
		enemy.set_physics_process(true)
		if room.has_method("update_enemies_list"):
			room.update_enemies_list()
	print("Дебаг: спавнен враг ", enemy.name)

func close_all_menus():
	# Найти все CanvasLayer с layer=100 и удалить
	for child in get_tree().current_scene.get_children():
		if child is CanvasLayer and child.layer == 100:
			child.queue_free()
	item_menu_open = false
	enemy_menu_open = false
