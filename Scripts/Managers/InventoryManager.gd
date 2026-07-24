extends Node


signal inventory_changed(entries: Array)

signal item_amount_changed(
	item_id: String,
	amount: int
)

signal item_added(
	item: ItemData,
	amount: int
)

signal quick_slots_changed(slots: Array)

signal selected_quick_slot_changed(
	slot_index: int
)


const QUICK_SLOT_COUNT: int = 5


# Количество предметов по их ID.
var _amounts: Dictionary = {}

# Ссылки на ItemData по их ID.
var _items: Dictionary = {}

# Быстрые слоты хранят только ID предметов.
var _quick_slots: Array[String] = [
	"",
	"",
	"",
	"",
	""
]

# Выбранный быстрый слот.
# Пока используется как фундамент для выбора боеприпаса.
var _selected_quick_slot: int = -1


# =========================================================
# СОСТОЯНИЕ ИНВЕНТАРЯ
# =========================================================

func emit_current_state() -> void:
	inventory_changed.emit(
		get_entries()
	)

	quick_slots_changed.emit(
		get_quick_slots()
	)

	selected_quick_slot_changed.emit(
		_selected_quick_slot
	)


func start_new_run() -> void:
	clear_inventory()


func reset() -> void:
	clear_inventory()


func clear_inventory() -> void:
	_amounts.clear()
	_items.clear()

	_reset_quick_slots()

	inventory_changed.emit([])

	quick_slots_changed.emit(
		get_quick_slots()
	)

	selected_quick_slot_changed.emit(
		_selected_quick_slot
	)


# =========================================================
# ДОБАВЛЕНИЕ ПРЕДМЕТОВ
# =========================================================

func add_item(
	item: ItemData,
	amount: int = 1
) -> Dictionary:
	if item == null:
		return {
			"success": false,
			"message": "Предмет не назначен.",
			"added_amount": 0,
			"overflow_amount": maxi(amount, 0),
			"new_amount": 0
		}

	var item_id: String = item.id.strip_edges()

	if item_id.is_empty():
		return {
			"success": false,
			"message": "У предмета отсутствует ID.",
			"added_amount": 0,
			"overflow_amount": maxi(amount, 0),
			"new_amount": 0
		}

	if amount <= 0:
		return {
			"success": false,
			"message": "Количество должно быть больше нуля.",
			"added_amount": 0,
			"overflow_amount": 0,
			"new_amount": get_amount(item_id)
		}

	var current_amount: int = get_amount(
		item_id
	)

	var max_stack: int = maxi(
		item.max_inventory_stack,
		1
	)

	var free_space: int = maxi(
		max_stack - current_amount,
		0
	)

	var added_amount: int = mini(
		amount,
		free_space
	)

	if added_amount <= 0:
		return {
			"success": false,
			"message": (
				"Достигнут максимальный стак: "
				+ item.name
			),
			"added_amount": 0,
			"overflow_amount": amount,
			"new_amount": current_amount
		}

	var new_amount: int = (
		current_amount
		+ added_amount
	)

	_items[item_id] = item
	_amounts[item_id] = new_amount

	item_amount_changed.emit(
		item_id,
		new_amount
	)

	item_added.emit(
		item,
		added_amount
	)

	inventory_changed.emit(
		get_entries()
	)

	var overflow_amount: int = (
		amount
		- added_amount
	)

	print(
		"В инвентарь добавлен предмет: ",
		item.name,
		" ×",
		added_amount,
		". Всего: ",
		new_amount
	)

	return {
		"success": true,
		"message": (
			"Получено: "
			+ item.name
			+ " ×"
			+ str(added_amount)
		),
		"item": item,
		"requested_amount": amount,
		"added_amount": added_amount,
		"overflow_amount": overflow_amount,
		"new_amount": new_amount
	}


# =========================================================
# УДАЛЕНИЕ ПРЕДМЕТОВ
# =========================================================

func remove_item(
	item_id: String,
	amount: int = 1
) -> bool:
	if amount <= 0:
		return false

	var current_amount: int = get_amount(
		item_id
	)

	if current_amount < amount:
		return false

	var new_amount: int = (
		current_amount
		- amount
	)

	if new_amount <= 0:
		_amounts.erase(item_id)
		_items.erase(item_id)

		# Если предмет закончился, он автоматически
		# исчезает из быстрого доступа.
		_clear_item_from_quick_slots(
			item_id
		)
	else:
		_amounts[item_id] = new_amount

	item_amount_changed.emit(
		item_id,
		new_amount
	)

	inventory_changed.emit(
		get_entries()
	)

	return true


# =========================================================
# ПОЛУЧЕНИЕ ДАННЫХ
# =========================================================

func get_amount(item_id: String) -> int:
	return maxi(
		int(_amounts.get(item_id, 0)),
		0
	)


func has_item(
	item_id: String,
	amount: int = 1
) -> bool:
	if amount <= 0:
		return false

	return get_amount(item_id) >= amount


func get_item_data(
	item_id: String
) -> ItemData:
	return _items.get(item_id) as ItemData


func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for item_id in _amounts.keys():
		var item := get_item_data(
			str(item_id)
		)

		if item == null:
			continue

		var amount: int = get_amount(
			str(item_id)
		)

		if amount <= 0:
			continue

		entries.append({
			"item": item,
			"item_id": str(item_id),
			"amount": amount
		})

	return entries


func is_empty() -> bool:
	return _amounts.is_empty()


# =========================================================
# БЫСТРЫЕ СЛОТЫ
# =========================================================

func assign_item_to_quick_slot(
	item_id: String,
	slot_index: int
) -> Dictionary:
	item_id = item_id.strip_edges()

	if not _is_valid_quick_slot(
		slot_index
	):
		return {
			"success": false,
			"message": "Некорректный номер быстрого слота."
		}

	if item_id.is_empty():
		return {
			"success": false,
			"message": "Не указан ID предмета."
		}

	if not has_item(item_id):
		return {
			"success": false,
			"message": "Этого предмета нет в инвентаре."
		}

	var item: ItemData = get_item_data(
		item_id
	)

	if item == null:
		return {
			"success": false,
			"message": "Не найдены данные предмета."
		}

	var previous_slot_index: int = (
		_quick_slots.find(item_id)
	)

	if previous_slot_index == slot_index:
		return {
			"success": true,
			"message": (
				item.name
				+ " уже находится в слоте "
				+ str(slot_index + 1)
			),
			"slot_index": slot_index
		}

	var replaced_item_id: String = (
		_quick_slots[slot_index]
	)

	var selected_slot_changed: bool = false
	var moved_selected_item: bool = false

	# Один предмет нельзя назначить сразу
	# в несколько быстрых слотов.
	if previous_slot_index >= 0:
		moved_selected_item = (
			_selected_quick_slot
			== previous_slot_index
		)

		_quick_slots[previous_slot_index] = ""

	if moved_selected_item:
		_selected_quick_slot = slot_index
		selected_slot_changed = true

	elif (
		_selected_quick_slot == slot_index
		and replaced_item_id != item_id
	):
		_selected_quick_slot = -1
		selected_slot_changed = true

	_quick_slots[slot_index] = item_id

	quick_slots_changed.emit(
		get_quick_slots()
	)

	if selected_slot_changed:
		selected_quick_slot_changed.emit(
			_selected_quick_slot
		)

	print(
		"Предмет ",
		item.name,
		" назначен в быстрый слот ",
		slot_index + 1
	)

	return {
		"success": true,
		"message": (
			item.name
			+ " назначен в слот "
			+ str(slot_index + 1)
		),
		"slot_index": slot_index,
		"replaced_item_id": replaced_item_id
	}


func clear_quick_slot(
	slot_index: int
) -> bool:
	if not _is_valid_quick_slot(
		slot_index
	):
		return false

	if _quick_slots[slot_index].is_empty():
		return false

	_quick_slots[slot_index] = ""

	if _selected_quick_slot == slot_index:
		_selected_quick_slot = -1

		selected_quick_slot_changed.emit(
			_selected_quick_slot
		)

	quick_slots_changed.emit(
		get_quick_slots()
	)

	return true


func select_quick_slot(
	slot_index: int
) -> bool:
	if not _is_valid_quick_slot(
		slot_index
	):
		return false

	var item_id: String = (
		_quick_slots[slot_index]
	)

	if item_id.is_empty():
		return false

	if not has_item(item_id):
		_clear_item_from_quick_slots(
			item_id
		)
		return false

	if _selected_quick_slot == slot_index:
		return true

	_selected_quick_slot = slot_index

	selected_quick_slot_changed.emit(
		_selected_quick_slot
	)

	return true


func clear_selected_quick_slot() -> void:
	if _selected_quick_slot == -1:
		return

	_selected_quick_slot = -1

	selected_quick_slot_changed.emit(
		_selected_quick_slot
	)


func get_quick_slot_count() -> int:
	return QUICK_SLOT_COUNT


func get_quick_slots() -> Array[String]:
	var result: Array[String] = (
		_quick_slots.duplicate()
	)

	return result


func get_quick_slot_item_id(
	slot_index: int
) -> String:
	if not _is_valid_quick_slot(
		slot_index
	):
		return ""

	return _quick_slots[slot_index]


func get_quick_slot_item(
	slot_index: int
) -> ItemData:
	var item_id: String = (
		get_quick_slot_item_id(
			slot_index
		)
	)

	if item_id.is_empty():
		return null

	return get_item_data(item_id)


func get_selected_quick_slot() -> int:
	return _selected_quick_slot


func get_quick_slot_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for slot_index in range(
		QUICK_SLOT_COUNT
	):
		var item_id: String = (
			_quick_slots[slot_index]
		)

		var item: ItemData = null
		var amount: int = 0

		if not item_id.is_empty():
			item = get_item_data(item_id)
			amount = get_amount(item_id)

		entries.append({
			"slot_index": slot_index,
			"item_id": item_id,
			"item": item,
			"amount": amount,
			"selected": (
				slot_index
				== _selected_quick_slot
			)
		})

	return entries


func _clear_item_from_quick_slots(
	item_id: String
) -> void:
	var slots_changed: bool = false
	var selection_changed: bool = false

	for slot_index in range(
		_quick_slots.size()
	):
		if _quick_slots[slot_index] != item_id:
			continue

		_quick_slots[slot_index] = ""
		slots_changed = true

		if _selected_quick_slot == slot_index:
			_selected_quick_slot = -1
			selection_changed = true

	if slots_changed:
		quick_slots_changed.emit(
			get_quick_slots()
		)

	if selection_changed:
		selected_quick_slot_changed.emit(
			_selected_quick_slot
		)


func _reset_quick_slots() -> void:
	_quick_slots.clear()

	for _slot_index in range(
		QUICK_SLOT_COUNT
	):
		_quick_slots.append("")

	_selected_quick_slot = -1


func _is_valid_quick_slot(
	slot_index: int
) -> bool:
	return (
		slot_index >= 0
		and slot_index < QUICK_SLOT_COUNT
	)


# =========================================================
# КОЛИЧЕСТВО ПРИ ПОЛУЧЕНИИ
# =========================================================

func roll_grant_amount(
	item: ItemData
) -> int:
	if item == null:
		return 0

	var minimum: int = maxi(
		item.min_grant_amount,
		1
	)

	var maximum: int = maxi(
		item.max_grant_amount,
		minimum
	)

	return randi_range(
		minimum,
		maximum
	)
