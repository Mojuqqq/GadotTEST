extends Node2D

# Список дверей в комнате
var doors: Array = []

# Список врагов
var enemies: Array = []

# Флаг, очищена ли комната
var is_cleared: bool = false

func _ready():
	# Находим все двери (Area2D с именами DoorLeft и DoorRight)
	for child in get_children():
		if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			doors.append(child)
	
	# Находим всех врагов (предположим, они в группе "Enemies")
	for child in get_children():
		if child.is_in_group("Enemies"):
			enemies.append(child)
			# Подключаем сигнал смерти врага (если он есть)
			if child.has_signal("died"):
				child.died.connect(_on_enemy_died)
			else:
				# Если у врага нет сигнала, можно сделать проверку в процессе
				pass

# Вызывается при входе в комнату (из Main)
func on_room_entered():
	# Обновляем список живых врагов (на случай, если некоторые уже умерли)
	update_enemies_list()
	
	if enemies.size() == 0:
		unlock_doors()
	else:
		lock_doors()

# Обновить список живых врагов (удалить мёртвых)
func update_enemies_list():
	enemies = []
	for child in get_children():
		if child.is_in_group("Enemies") and is_instance_valid(child) and not child.is_queued_for_deletion():
			enemies.append(child)

# Заблокировать все двери
func lock_doors():
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(false)

# Открыть все двери
func unlock_doors():
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(true)

# Когда враг умирает (сигнал)
func _on_enemy_died():
	update_enemies_list()
	if enemies.size() == 0 and not is_cleared:
		is_cleared = true
		unlock_doors()
		print("Комната очищена, двери открыты!")
