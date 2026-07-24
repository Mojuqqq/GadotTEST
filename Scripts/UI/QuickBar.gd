extends CanvasLayer


const QUICK_SLOT_ACTION_PREFIX: String = "quick_slot_"


@onready var slots_container: HBoxContainer = (%SlotsContainer)


var slot_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_create_slot_buttons()
	_connect_signals()
	_refresh_quick_bar()

	set_process_unhandled_input(true)


# =========================================================
# СОЗДАНИЕ СЛОТОВ
# =========================================================

func _create_slot_buttons() -> void:
	_clear_container(
		slots_container
	)

	slot_buttons.clear()

	var slot_count: int = (
		GameManager.get_quick_slot_count()
	)

	for slot_index in range(slot_count):
		var button := Button.new()

		button.name = (
			"QuickSlot"
			+ str(slot_index + 1)
		)

		button.custom_minimum_size = Vector2(
			80.0,
			72.0
		)
		button.add_theme_constant_override("icon_max_width",32)

		button.expand_icon = false

		button.text = str(
			slot_index + 1
		)

		button.toggle_mode = true

		# Панель пока управляется только клавиатурой.
		button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		button.focus_mode = (
			Control.FOCUS_NONE
		)

		# Для пиксельных иконок.
		button.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		slots_container.add_child(
			button
		)

		slot_buttons.append(
			button
		)


# =========================================================
# ВВОД
# =========================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	if get_tree().paused:
		return

	if (
		GameManager.state
		!= GameManager.GameState.PLAYING
	):
		return

	for slot_index in range(
		slot_buttons.size()
	):
		var action_name: String = (
			QUICK_SLOT_ACTION_PREFIX
			+ str(slot_index + 1)
		)

		if not event.is_action_pressed(
			action_name
		):
			continue

		get_viewport().set_input_as_handled()

		_select_quick_slot(
			slot_index
		)

		return


func _select_quick_slot(
	slot_index: int
) -> void:
	var item_id: String = (
		GameManager.get_quick_slot_item_id(
			slot_index
		)
	)

	if item_id.is_empty():
		print(
			"Быстрый слот ",
			slot_index + 1,
			" пуст."
		)
		return
	if (
		GameManager.get_selected_quick_slot()
		== slot_index
	):
		GameManager.clear_selected_quick_slot()

		print(
			"Быстрый слот ",
			slot_index + 1,
			" выключен. Используются обычные яйца."
		)

		_refresh_quick_bar()
		return

	var selected: bool = (
		GameManager.select_quick_slot(
			slot_index
		)
	)

	if not selected:
		print(
			"Не удалось выбрать быстрый слот ",
			slot_index + 1
		)
		return

	print(
		"Выбран быстрый слот ",
		slot_index + 1,
		": ",
		item_id
	)

	_refresh_quick_bar()


# =========================================================
# ОБНОВЛЕНИЕ UI
# =========================================================

func _refresh_quick_bar() -> void:
	var entries: Array[Dictionary] = (
		GameManager.get_quick_slot_entries()
	)

	for slot_index in range(
		slot_buttons.size()
	):
		var button: Button = (
			slot_buttons[slot_index]
		)

		if slot_index >= entries.size():
			_clear_button(
				button,
				slot_index
			)
			continue

		var entry: Dictionary = (
			entries[slot_index]
		)

		var item := entry.get(
			"item"
		) as ItemData

		var amount: int = int(
			entry.get(
				"amount",
				0
			)
		)

		var selected: bool = bool(
			entry.get(
				"selected",
				false
			)
		)

		if item == null or amount <= 0:
			_clear_button(
				button,
				slot_index
			)
			continue

		button.text = (
			str(slot_index + 1)
			+ "\n×"
			+ str(amount)
		)

		button.icon = item.icon

		button.tooltip_text = (
			item.name
			+ " ×"
			+ str(amount)
		)

		button.button_pressed = selected
		button.modulate = Color.WHITE


func _clear_button(
	button: Button,
	slot_index: int
) -> void:
	button.text = (
		str(slot_index + 1)
		+ "\n—"
	)

	button.icon = null

	button.tooltip_text = (
		"Слот "
		+ str(slot_index + 1)
		+ " пуст"
	)

	button.button_pressed = false

	button.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.55
	)


# =========================================================
# СИГНАЛЫ
# =========================================================

func _connect_signals() -> void:
	if not GameManager.quick_slots_changed.is_connected(
		_on_quick_slots_changed
	):
		GameManager.quick_slots_changed.connect(
			_on_quick_slots_changed
		)

	if not GameManager.selected_quick_slot_changed.is_connected(
		_on_selected_quick_slot_changed
	):
		GameManager.selected_quick_slot_changed.connect(
			_on_selected_quick_slot_changed
		)

	if not GameManager.inventory_item_amount_changed.is_connected(
		_on_inventory_item_amount_changed
	):
		GameManager.inventory_item_amount_changed.connect(
			_on_inventory_item_amount_changed
		)

	if not GameManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		GameManager.inventory_changed.connect(
			_on_inventory_changed
		)


func _on_quick_slots_changed(
	_slots: Array
) -> void:
	_refresh_quick_bar()


func _on_selected_quick_slot_changed(
	_slot_index: int
) -> void:
	_refresh_quick_bar()


func _on_inventory_item_amount_changed(
	_item_id: String,
	_amount: int
) -> void:
	_refresh_quick_bar()


func _on_inventory_changed(
	_entries: Array
) -> void:
	_refresh_quick_bar()


# =========================================================
# ВСПОМОГАТЕЛЬНОЕ
# =========================================================

func _clear_container(
	container: Node
) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
