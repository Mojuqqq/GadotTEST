extends CanvasLayer


@onready var item_list: VBoxContainer = %ItemList
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_amount_label: Label = %ItemAmountLabel
@onready var item_description_label: Label = %ItemDescriptionLabel

@onready var quick_slot_buttons: HBoxContainer = (
	%QuickSlotButtons
)

@onready var remove_from_quick_bar_button: Button = (
	%RemoveFromQuickBarButton
)

@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton


var selected_item_id: String = ""

var previous_pause_state: bool = false
var is_closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_to_group("InventoryMenu")

	previous_pause_state = get_tree().paused
	get_tree().paused = true

	set_process_unhandled_input(false)

	if not close_button.pressed.is_connected(
		close_menu
	):
		close_button.pressed.connect(
			close_menu
		)

	if not remove_from_quick_bar_button.pressed.is_connected(
		_remove_selected_item_from_quick_bar
	):
		remove_from_quick_bar_button.pressed.connect(
			_remove_selected_item_from_quick_bar
		)

	if not GameManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		GameManager.inventory_changed.connect(
			_on_inventory_changed
		)

	if not GameManager.quick_slots_changed.is_connected(
		_on_quick_slots_changed
	):
		GameManager.quick_slots_changed.connect(
			_on_quick_slots_changed
		)

	_create_quick_slot_buttons()
	_refresh_inventory()
	_refresh_selected_item()

	call_deferred(
		"_enable_input"
	)


func _enable_input() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(
	event: InputEvent
) -> void:
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close_menu()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()


# =========================================================
# СПИСОК ИНВЕНТАРЯ
# =========================================================

func _refresh_inventory() -> void:
	_clear_container(item_list)

	var entries: Array[Dictionary] = (
		GameManager.get_inventory_entries()
	)

	entries.sort_custom(
		_sort_inventory_entries
	)

	if entries.is_empty():
		selected_item_id = ""

		var empty_label := Label.new()
		empty_label.text = "Инвентарь пуст"
		empty_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)

		item_list.add_child(empty_label)
		return

	var selected_item_exists: bool = false

	for entry in entries:
		var item := entry.get("item") as ItemData

		if item == null:
			continue

		var item_id: String = str(
			entry.get("item_id", "")
		)

		var amount: int = int(
			entry.get("amount", 0)
		)

		if item_id == selected_item_id:
			selected_item_exists = true

		var button := Button.new()

		button.text = (
			item.name
			+ " ×"
			+ str(amount)
		)

		button.custom_minimum_size = Vector2(
			0.0,
			48.0
		)

		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		button.pressed.connect(
			_select_item.bind(item_id)
		)

		item_list.add_child(button)

	if not selected_item_exists:
		var first_entry: Dictionary = entries[0]

		selected_item_id = str(
			first_entry.get(
				"item_id",
				""
			)
		)


func _sort_inventory_entries(
	first: Dictionary,
	second: Dictionary
) -> bool:
	var first_item := first.get("item") as ItemData
	var second_item := second.get("item") as ItemData

	if first_item == null:
		return false

	if second_item == null:
		return true

	return first_item.name.naturalnocasecmp_to(
		second_item.name
	) < 0


func _select_item(
	item_id: String
) -> void:
	selected_item_id = item_id
	status_label.text = ""

	_refresh_selected_item()


# =========================================================
# ИНФОРМАЦИЯ О ПРЕДМЕТЕ
# =========================================================

func _refresh_selected_item() -> void:
	if selected_item_id.is_empty():
		_clear_item_details()
		return

	var item: ItemData = _find_item_data(
		selected_item_id
	)

	if item == null:
		selected_item_id = ""
		_clear_item_details()
		return

	var amount: int = (
		GameManager.get_inventory_item_amount(
			selected_item_id
		)
	)

	if amount <= 0:
		selected_item_id = ""
		_clear_item_details()
		return

	item_name_label.text = item.name

	item_amount_label.text = (
		"Количество: "
		+ str(amount)
		+ " / "
		+ str(item.max_inventory_stack)
	)

	item_description_label.text = (
		item.description
	)

	if item.icon != null:
		item_icon.texture = item.icon
		item_icon.visible = true
	else:
		item_icon.texture = null
		item_icon.visible = false

	_refresh_quick_slot_buttons()
	_refresh_remove_button()


func _clear_item_details() -> void:
	item_icon.texture = null
	item_icon.visible = false

	item_name_label.text = "Выберите предмет"
	item_amount_label.text = ""
	item_description_label.text = ""

	remove_from_quick_bar_button.disabled = true

	_refresh_quick_slot_buttons()


func _find_item_data(
	item_id: String
) -> ItemData:
	var entries: Array[Dictionary] = (
		GameManager.get_inventory_entries()
	)

	for entry in entries:
		if str(
			entry.get("item_id", "")
		) != item_id:
			continue

		return entry.get("item") as ItemData

	return null


# =========================================================
# БЫСТРЫЕ СЛОТЫ
# =========================================================

func _create_quick_slot_buttons() -> void:
	_clear_container(
		quick_slot_buttons
	)

	var slot_count: int = (
		GameManager.get_quick_slot_count()
	)

	for slot_index in range(slot_count):
		var button := Button.new()

		button.custom_minimum_size = Vector2(
			54.0,
			54.0
		)

		button.pressed.connect(
			_assign_selected_item_to_slot.bind(
				slot_index
			)
		)

		quick_slot_buttons.add_child(button)

	_refresh_quick_slot_buttons()


func _refresh_quick_slot_buttons() -> void:
	var slots: Array[String] = (
		GameManager.get_quick_slots()
	)

	var buttons: Array[Node] = (
		quick_slot_buttons.get_children()
	)

	for slot_index in range(
		buttons.size()
	):
		var button := buttons[slot_index] as Button

		if button == null:
			continue

		var item_id: String = ""

		if slot_index < slots.size():
			item_id = slots[slot_index]

		if item_id.is_empty():
			button.text = str(
				slot_index + 1
			)
		else:
			var item: ItemData = (
				_find_item_data(item_id)
			)

			if item != null:
				button.text = (
					str(slot_index + 1)
					+ "\n"
					+ item.name
				)
			else:
				button.text = str(
					slot_index + 1
				)

		button.disabled = (
			selected_item_id.is_empty()
		)


func _assign_selected_item_to_slot(
	slot_index: int
) -> void:
	if selected_item_id.is_empty():
		status_label.text = (
			"Сначала выберите предмет."
		)
		return

	var result: Dictionary = (
		GameManager.assign_item_to_quick_slot(
			selected_item_id,
			slot_index
		)
	)

	status_label.text = str(
		result.get(
			"message",
			"Не удалось назначить предмет."
		)
	)

	_refresh_quick_slot_buttons()
	_refresh_remove_button()


func _remove_selected_item_from_quick_bar() -> void:
	if selected_item_id.is_empty():
		return

	var slots: Array[String] = (
		GameManager.get_quick_slots()
	)

	var slot_index: int = (
		slots.find(selected_item_id)
	)

	if slot_index < 0:
		status_label.text = (
			"Предмет не добавлен "
			+ "в быстрый доступ."
		)
		return

	var removed: bool = (
		GameManager.clear_quick_slot(
			slot_index
		)
	)

	if removed:
		status_label.text = (
			"Предмет убран из слота "
			+ str(slot_index + 1)
		)
	else:
		status_label.text = (
			"Не удалось очистить слот."
		)

	_refresh_quick_slot_buttons()
	_refresh_remove_button()


func _refresh_remove_button() -> void:
	if selected_item_id.is_empty():
		remove_from_quick_bar_button.disabled = true
		return

	var slots: Array[String] = (
		GameManager.get_quick_slots()
	)

	var slot_index: int = (
		slots.find(selected_item_id)
	)

	remove_from_quick_bar_button.disabled = (
		slot_index < 0
	)

	if slot_index >= 0:
		remove_from_quick_bar_button.text = (
			"Убрать из слота "
			+ str(slot_index + 1)
		)
	else:
		remove_from_quick_bar_button.text = (
			"Убрать из быстрого доступа"
		)


# =========================================================
# СИГНАЛЫ
# =========================================================

func _on_inventory_changed(
	_entries: Array
) -> void:
	_refresh_inventory()
	_refresh_selected_item()


func _on_quick_slots_changed(
	_slots: Array
) -> void:
	_refresh_quick_slot_buttons()
	_refresh_remove_button()


# =========================================================
# ЗАКРЫТИЕ
# =========================================================

func close_menu() -> void:
	if is_closing:
		return

	is_closing = true
	set_process_unhandled_input(false)

	if GameManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		GameManager.inventory_changed.disconnect(
			_on_inventory_changed
		)

	if GameManager.quick_slots_changed.is_connected(
		_on_quick_slots_changed
	):
		GameManager.quick_slots_changed.disconnect(
			_on_quick_slots_changed
		)

	get_tree().paused = previous_pause_state
	queue_free()


func _clear_container(
	container: Node
) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
