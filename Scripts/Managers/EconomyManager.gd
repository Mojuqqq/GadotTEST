extends Node


signal banked_gold_changed(value: int)
signal run_gold_changed(value: int)
signal keys_changed(value: int)
signal total_gold_changed(value: int)


const SAVE_PATH := "user://economy_save.json"


# Золото, успешно вынесенное из прошлых забегов.
var banked_gold: int = 0

# Золото, заработанное только в текущем забеге.
var run_gold: int = 0

# Ключи текущего этажа.
var keys: int = 0


func _ready() -> void:
	_load_data()


# =========================================================
# ТЕКУЩЕЕ СОСТОЯНИЕ
# =========================================================

func emit_current_state() -> void:
	banked_gold_changed.emit(banked_gold)
	run_gold_changed.emit(run_gold)
	keys_changed.emit(keys)
	total_gold_changed.emit(get_total_gold())


func get_total_gold() -> int:
	return banked_gold + run_gold


# =========================================================
# НАЧАЛО НОВОГО ЗАБЕГА
# =========================================================

func start_new_run() -> void:
	run_gold = 0
	keys = 0

	run_gold_changed.emit(run_gold)
	keys_changed.emit(keys)
	total_gold_changed.emit(get_total_gold())


# =========================================================
# ПОЛУЧЕНИЕ ВАЛЮТЫ
# =========================================================

func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	run_gold += amount

	run_gold_changed.emit(run_gold)
	total_gold_changed.emit(get_total_gold())


func add_keys(amount: int = 1) -> void:
	if amount <= 0:
		return

	keys += amount
	keys_changed.emit(keys)


# =========================================================
# ТРАТА ЗОЛОТА
# =========================================================

func can_afford(amount: int) -> bool:
	if amount < 0:
		return false

	return get_total_gold() >= amount


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_afford(amount):
		return false

	# Сначала расходуем золото текущего забега.
	var from_run: int = mini(
		run_gold,
		amount
	)

	run_gold -= from_run

	var remaining: int = amount - from_run

	if remaining > 0:
		banked_gold -= remaining

	_save_data()

	banked_gold_changed.emit(banked_gold)
	run_gold_changed.emit(run_gold)
	total_gold_changed.emit(get_total_gold())

	return true


# =========================================================
# ИСПОЛЬЗОВАНИЕ КЛЮЧЕЙ
# =========================================================

func has_key() -> bool:
	return keys > 0


func use_key() -> bool:
	if keys <= 0:
		return false

	keys -= 1
	keys_changed.emit(keys)

	return true


# =========================================================
# ПЕРЕХОД НА СЛЕДУЮЩИЙ ЭТАЖ
# =========================================================

func leave_floor() -> int:
	var lost_keys := keys

	keys = 0
	keys_changed.emit(keys)

	return lost_keys


# =========================================================
# ДОБРОВОЛЬНОЕ ЗАВЕРШЕНИЕ ЗАБЕГА
# =========================================================

func finish_run_voluntarily() -> int:
	var deposited_gold := run_gold

	banked_gold += run_gold

	run_gold = 0
	keys = 0

	_save_data()

	banked_gold_changed.emit(banked_gold)
	run_gold_changed.emit(run_gold)
	keys_changed.emit(keys)
	total_gold_changed.emit(get_total_gold())

	return deposited_gold


# =========================================================
# СМЕРТЬ ИГРОКА
# =========================================================

func lose_run_rewards() -> Dictionary:
	var lost_rewards := {
		"gold": run_gold,
		"keys": keys
	}

	run_gold = 0
	keys = 0

	run_gold_changed.emit(run_gold)
	keys_changed.emit(keys)
	total_gold_changed.emit(get_total_gold())

	return lost_rewards


# =========================================================
# СОХРАНЕНИЕ
# =========================================================

func _save_data() -> void:
	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Не удалось сохранить экономику."
		)
		return

	var data := {
		"banked_gold": banked_gold
	}

	file.store_string(
		JSON.stringify(data, "\t")
	)


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_warning(
			"Не удалось открыть сохранение экономики."
		)
		return

	var parsed_data = JSON.parse_string(
		file.get_as_text()
	)

	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_warning(
			"Файл экономики повреждён."
		)
		return

	var data: Dictionary = parsed_data

	banked_gold = maxi(
		int(data.get("banked_gold", 0)),
		0
	)
