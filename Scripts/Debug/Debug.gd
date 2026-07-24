extends Node


const SCREEN_MAIN: StringName = &"main"
const SCREEN_ITEMS: StringName = &"items"
const SCREEN_ADD_ITEMS: StringName = &"add_items"
const SCREEN_ENEMIES: StringName = &"enemies"
const SCREEN_SPAWN_ENEMIES: StringName = &"spawn_enemies"
const SCREEN_GOLD: StringName = &"gold"
const SCREEN_KEYS: StringName = &"keys"


var menu_layer: CanvasLayer = null
var content_box: VBoxContainer = null
var title_label: Label = null
var status_label: Label = null

var gold_amount_spin: SpinBox = null
var key_amount_spin: SpinBox = null

var current_screen: StringName = SCREEN_MAIN
var was_tree_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not OS.is_debug_build():
		set_process_input(false)
		return

	print("Debug: F1 — открыть дебаг-меню")


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	var is_f1: bool = (
		key_event.keycode == KEY_F1
		or key_event.physical_keycode == KEY_F1
	)

	if not is_f1:
		return

	if is_instance_valid(menu_layer):
		close_debug_menu()
	else:
		open_debug_menu()

	get_viewport().set_input_as_handled()


# =========================================================
# ОТКРЫТИЕ И ЗАКРЫТИЕ
# =========================================================

func open_debug_menu() -> void:
	if is_instance_valid(menu_layer):
		return

	was_tree_paused = get_tree().paused
	get_tree().paused = true

	_create_menu_interface()
	_show_main_menu()


func close_debug_menu() -> void:
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()

	menu_layer = null
	content_box = null
	title_label = null
	status_label = null
	gold_amount_spin = null
	key_amount_spin = null

	current_screen = SCREEN_MAIN
	get_tree().paused = was_tree_paused


func _create_menu_interface() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "DebugMenu"
	menu_layer.layer = 100
	add_child(menu_layer)

	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP

	menu_layer.add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var center_container := CenterContainer.new()

	background.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var panel := PanelContainer.new()

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	panel.custom_minimum_size = Vector2(
		maxf(
			320.0,
			minf(520.0, viewport_size.x - 40.0)
		),
		maxf(
			360.0,
			minf(600.0, viewport_size.y - 40.0)
		)
	)

	center_container.add_child(panel)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		24
	)
	margin.add_theme_constant_override(
		"margin_right",
		24
	)
	margin.add_theme_constant_override(
		"margin_top",
		20
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		20
	)

	panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override(
		"separation",
		12
	)

	margin.add_child(root_box)

	title_label = Label.new()
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		24
	)

	root_box.add_child(title_label)

	var separator := HSeparator.new()
	root_box.add_child(separator)

	content_box = VBoxContainer.new()
	content_box.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	content_box.add_theme_constant_override(
		"separation",
		8
	)

	root_box.add_child(content_box)

	var status_separator := HSeparator.new()
	root_box.add_child(status_separator)

	status_label = Label.new()
	status_label.text = ""
	status_label.custom_minimum_size = Vector2(
		0.0,
		44.0
	)
	status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	root_box.add_child(status_label)


# =========================================================
# ОСНОВНОЕ МЕНЮ
# =========================================================

func _show_main_menu() -> void:
	current_screen = SCREEN_MAIN
	_clear_content()

	title_label.text = "Дебаг-меню"

	_add_menu_button(
		"1. Предметы",
		Callable(self, "_show_items_menu")
	)

	_add_menu_button(
		"2. Мобы",
		Callable(self, "_show_enemies_menu")
	)

	_add_menu_button(
		"3. Золото — %d" % GameManager.total_gold,
		Callable(self, "_show_gold_menu")
	)

	_add_menu_button(
		"4. Ключи — %d" % GameManager.keys,
		Callable(self, "_show_keys_menu")
	)

	_add_menu_button(
		"Закрыть",
		Callable(self, "close_debug_menu")
	)


# =========================================================
# ПРЕДМЕТЫ
# =========================================================

func _show_items_menu() -> void:
	current_screen = SCREEN_ITEMS
	_clear_content()

	title_label.text = "Предметы"

	_add_menu_button(
		"Добавить предмет",
		Callable(self, "_show_add_items")
	)

	_add_back_button(
		Callable(self, "_show_main_menu")
	)


func _show_add_items() -> void:
	current_screen = SCREEN_ADD_ITEMS
	_clear_content()

	title_label.text = "Предметы → Добавить"

	if GameManager.all_items.is_empty():
		_add_information_label(
			"Список предметов пуст."
		)
	else:
		var list_box := _create_scroll_list()

		for item in GameManager.all_items:
			var button := Button.new()

			button.text = _get_item_display_name(
				item
			)

			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

			button.custom_minimum_size = Vector2(
				0.0,
				38.0
			)

			button.pressed.connect(
				Callable(
					self,
					"give_item"
				).bind(item)
			)

			list_box.add_child(button)

	_add_back_button(
		Callable(self, "_show_items_menu")
	)

func give_item(
	item: ItemData
) -> void:
	if item == null:
		push_warning(
			"Debug: не выбран предмет."
		)
		return

	var result: Dictionary = (
		GameManager.add_item_to_inventory(
			item
		)
	)

	var success: bool = bool(
		result.get(
			"success",
			false
		)
	)

	var added_amount: int = int(
		result.get(
			"added_amount",
			0
		)
	)

	if not success:
		push_warning(
			"Debug: предмет не добавлен. "
			+ str(
				result.get(
					"message",
					"Неизвестная ошибка."
				)
			)
		)
		return

	print(
		"Debug: в инвентарь добавлен предмет: ",
		item.name,
		" ×",
		added_amount
	)

func _get_item_display_name(
	item: ItemData
) -> String:
	if item == null:
		return "Неизвестный предмет"

	if not str(item.name).is_empty():
		return str(item.name)

	if not item.resource_path.is_empty():
		return (
			item.resource_path
			.get_file()
			.get_basename()
		)

	return "Предмет без названия"


# =========================================================
# МОБЫ
# =========================================================

func _show_enemies_menu() -> void:
	current_screen = SCREEN_ENEMIES
	_clear_content()

	title_label.text = "Мобы"

	_add_menu_button(
		"Создать моба",
		Callable(self, "_show_spawn_enemies")
	)

	_add_back_button(
		Callable(self, "_show_main_menu")
	)


func _show_spawn_enemies() -> void:
	current_screen = SCREEN_SPAWN_ENEMIES
	_clear_content()

	title_label.text = "Мобы → Создать"

	if GameManager.enemy_pool.is_empty():
		_add_information_label(
			"Пул мобов пуст."
		)
	else:
		var list_box := _create_scroll_list()

		for enemy_scene in GameManager.enemy_pool:
			var button := Button.new()

			button.text = _get_enemy_display_name(
				enemy_scene
			)

			button.size_flags_horizontal = (
				Control.SIZE_EXPAND_FILL
			)

			button.custom_minimum_size = Vector2(
				0.0,
				38.0
			)

			button.pressed.connect(
				Callable(
					self,
					"_spawn_enemy"
				).bind(enemy_scene)
			)

			list_box.add_child(button)

	_add_back_button(
		Callable(self, "_show_enemies_menu")
	)


func _spawn_enemy(
	enemy_scene: PackedScene
) -> void:
	var room = GameManager.get_current_room()

	if room == null:
		_set_status(
			"Нет текущей комнаты."
		)
		return

	if enemy_scene == null:
		_set_status(
			"Сцена моба не назначена."
		)
		return

	var enemy = enemy_scene.instantiate()

	if enemy == null:
		_set_status(
			"Не удалось создать моба."
		)
		return

	room.add_child(enemy)

	var margin: float = 50.0

	var x: float = randf_range(
		margin,
		GameManager.room_width - margin
	)

	var y: float = randf_range(
		margin,
		GameManager.room_height - margin
	)

	enemy.position = Vector2(x, y)

	if enemy.has_method("set_room_limits"):
		var limits := Rect2(
			room.global_position.x,
			room.global_position.y,
			GameManager.room_width,
			GameManager.room_height
		)

		enemy.set_room_limits(limits)

	if (
		room.is_active
		and enemy.has_method("set_active")
	):
		enemy.set_active(true)

	if room.has_method("update_enemies_list"):
		room.update_enemies_list()

	var enemy_name: String = (
		_get_enemy_display_name(enemy_scene)
	)

	_set_status(
		"Создан моб: " + enemy_name
	)

	print(
		"Дебаг: создан моб: ",
		enemy_name
	)


func _get_enemy_display_name(
	enemy_scene: PackedScene
) -> String:
	if enemy_scene == null:
		return "Неизвестный моб"

	if not enemy_scene.resource_path.is_empty():
		return (
			enemy_scene.resource_path
			.get_file()
			.get_basename()
		)

	return "Моб без названия"


# =========================================================
# ЗОЛОТО
# =========================================================

func _show_gold_menu() -> void:
	current_screen = SCREEN_GOLD
	_clear_content()

	title_label.text = "Золото"

	var information := Label.new()

	information.text = (
		"Сохранённое золото: "
		+ str(GameManager.banked_gold)
		+ "\n"
		+ "Золото забега: "
		+ str(GameManager.run_gold)
		+ "\n"
		+ "Всего: "
		+ str(GameManager.total_gold)
	)

	information.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	content_box.add_child(information)

	var input_row := HBoxContainer.new()

	input_row.add_theme_constant_override(
		"separation",
		10
	)

	content_box.add_child(input_row)

	var amount_label := Label.new()
	amount_label.text = "Количество:"
	amount_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	input_row.add_child(amount_label)

	gold_amount_spin = SpinBox.new()
	gold_amount_spin.min_value = 1
	gold_amount_spin.max_value = 99999
	gold_amount_spin.step = 1
	gold_amount_spin.value = 10
	gold_amount_spin.custom_minimum_size = Vector2(
		140.0,
		0.0
	)

	input_row.add_child(gold_amount_spin)

	_add_menu_button(
		"Добавить золото",
		Callable(self, "_add_gold_from_input")
	)

	_add_menu_button(
		"Убрать всё золото",
		Callable(self, "_clear_all_gold")
	)

	_add_back_button(
		Callable(self, "_show_main_menu")
	)


func _add_gold_from_input() -> void:
	if not is_instance_valid(gold_amount_spin):
		return

	var amount: int = int(
		gold_amount_spin.value
	)

	GameManager.add_gold(amount)

	_set_status(
		"Добавлено золота: "
		+ str(amount)
	)

	call_deferred("_show_gold_menu")


func _clear_all_gold() -> void:
	var gold_before: int = (
		GameManager.total_gold
	)

	if gold_before <= 0:
		_set_status(
			"Золота уже нет."
		)
		return

	var success: bool = GameManager.spend_gold(
		gold_before
	)

	if success:
		_set_status(
			"Удалено всё золото: "
			+ str(gold_before)
		)
	else:
		_set_status(
			"Не удалось удалить золото."
		)

	call_deferred("_show_gold_menu")


# =========================================================
# КЛЮЧИ
# =========================================================

func _show_keys_menu() -> void:
	current_screen = SCREEN_KEYS
	_clear_content()

	title_label.text = "Ключи"

	var information := Label.new()

	information.text = (
		"Ключей на текущем этаже: "
		+ str(GameManager.keys)
	)

	information.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	content_box.add_child(information)

	var input_row := HBoxContainer.new()

	input_row.add_theme_constant_override(
		"separation",
		10
	)

	content_box.add_child(input_row)

	var amount_label := Label.new()
	amount_label.text = "Количество:"
	amount_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	input_row.add_child(amount_label)

	key_amount_spin = SpinBox.new()
	key_amount_spin.min_value = 1
	key_amount_spin.max_value = 999
	key_amount_spin.step = 1
	key_amount_spin.value = 1
	key_amount_spin.custom_minimum_size = Vector2(
		140.0,
		0.0
	)

	input_row.add_child(key_amount_spin)

	_add_menu_button(
		"Добавить ключи",
		Callable(self, "_add_keys_from_input")
	)

	_add_menu_button(
		"Убрать все ключи",
		Callable(self, "_clear_all_keys")
	)

	_add_back_button(
		Callable(self, "_show_main_menu")
	)


func _add_keys_from_input() -> void:
	if not is_instance_valid(key_amount_spin):
		return

	var amount: int = int(
		key_amount_spin.value
	)

	GameManager.add_keys(amount)

	_set_status(
		"Добавлено ключей: "
		+ str(amount)
	)

	call_deferred("_show_keys_menu")


func _clear_all_keys() -> void:
	var keys_before: int = GameManager.keys

	if keys_before <= 0:
		_set_status(
			"Ключей уже нет."
		)
		return

	var removed_keys: int = 0

	for _index in range(keys_before):
		if not GameManager.use_key():
			break

		removed_keys += 1

	_set_status(
		"Удалено ключей: "
		+ str(removed_keys)
	)

	call_deferred("_show_keys_menu")


# =========================================================
# СОЗДАНИЕ ЭЛЕМЕНТОВ ИНТЕРФЕЙСА
# =========================================================

func _clear_content() -> void:
	if not is_instance_valid(content_box):
		return

	for child in content_box.get_children():
		content_box.remove_child(child)
		child.queue_free()


func _add_menu_button(
	button_text: String,
	callback: Callable
) -> Button:
	var button := Button.new()

	button.text = button_text
	button.custom_minimum_size = Vector2(
		0.0,
		42.0
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	button.pressed.connect(callback)
	content_box.add_child(button)

	return button


func _add_back_button(
	callback: Callable
) -> void:
	var separator := HSeparator.new()
	content_box.add_child(separator)

	_add_menu_button(
		"← Назад",
		callback
	)


func _add_information_label(
	text: String
) -> void:
	var label := Label.new()

	label.text = text
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	content_box.add_child(label)


func _create_scroll_list() -> VBoxContainer:
	var scroll := ScrollContainer.new()

	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	content_box.add_child(scroll)

	var list_box := VBoxContainer.new()

	list_box.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	list_box.add_theme_constant_override(
		"separation",
		5
	)

	scroll.add_child(list_box)

	return list_box


func _set_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text
