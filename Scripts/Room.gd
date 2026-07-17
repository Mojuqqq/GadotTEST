#extends Node2D
#
## Список дверей в комнате
#var doors: Array = []
#
## Список врагов
#var enemies: Array = []
#
## Флаг, очищена ли комната
#var is_cleared: bool = false
#
#func _ready():
	#print("Room._ready: начинаю поиск дверей")
	#for child in get_children():
		#if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			#doors.append(child)
			#print("Найдена дверь: ", child.name)
	#print("Всего найдено дверей: ", doors.size())
	#
	## Поиск врагов
	#for child in get_children():
		#if child.is_in_group("Enemies"):
			#enemies.append(child)
			#if child.has_signal("died"):
				#child.died.connect(_on_enemy_died)
	#print("Всего найдено врагов: ", enemies.size())
#
## Вызывается при входе в комнату (из Main)
#func on_room_entered():
	#print("Room.on_room_entered вызван")
	#update_enemies_list()
	#if enemies.size() == 0:
		#print("Нет живых врагов, открываем двери")
		#unlock_doors()
	#else:
		#print("Есть живые враги (", enemies.size(), "), закрываем двери")
		#lock_doors()
#
## Обновить список живых врагов (удалить мёртвых)
#func update_enemies_list():
	#enemies = []
	#for child in get_children():
		#if child.is_in_group("Enemies") and is_instance_valid(child) and not child.is_queued_for_deletion():
			#enemies.append(child)
	#print("Обновлён список врагов: ", enemies.size())
#
## Заблокировать все двери
#func lock_doors():
	#print("Блокируем двери")
	#for door in doors:
		#if door.has_method("set_open"):
			#door.set_open(false)
#
## Открыть все двери
#func unlock_doors():
	#print("Открываем двери")
	#for door in doors:
		#if door.has_method("set_open"):
			#door.set_open(true)
#
## Когда враг умирает (сигнал)
#func _on_enemy_died():
	#print("Враг умер, обновляем список")
	#update_enemies_list()
	#if enemies.size() == 0 and not is_cleared:
		#is_cleared = true
		#unlock_doors()
		#print("Комната очищена, двери открыты!")
		
extends Node2D

var doors: Array = []
var enemies: Array = []
var is_cleared: bool = false

func _ready():
	print("Room._ready: начинаю поиск дверей и врагов")
	find_doors_recursive(self)
	update_enemies_list()
	print("Найдено дверей: ", doors.size())
	print("Найдено врагов: ", enemies.size())

func find_doors_recursive(node: Node):
	for child in node.get_children():
		if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			doors.append(child)
			print("Найдена дверь: ", child.name)
		else:
			find_doors_recursive(child)

func update_enemies_list():
	enemies = []
	var all_enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in all_enemies:
		# Проверяем, является ли enemy потомком этой комнаты
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and self.is_ancestor_of(enemy):
			enemies.append(enemy)
			# Подключаем сигнал died, если ещё не подключён
			if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
				print("Подключён сигнал died к врагу: ", enemy.name)
	print("Обновлён список врагов: ", enemies.size())

func on_room_entered():
	print("Room.on_room_entered вызван")
	update_enemies_list()
	if enemies.size() == 0:
		print("Нет живых врагов, открываем двери")
		unlock_doors()
	else:
		print("Есть живые враги (", enemies.size(), "), закрываем двери")
		lock_doors()

func lock_doors():
	print("Блокируем двери")
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(false)

func unlock_doors():
	print("Открываем двери")
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(true)

func _on_enemy_died(victim: Node):
	print("Враг умер: ", victim.name)
	var idx = enemies.find(victim)
	if idx != -1:
		enemies.remove_at(idx)
		print("Враг удалён из списка, осталось: ", enemies.size())
	else:
		print("Враг не найден в списке! Текущий список: ", enemies)
	
	if enemies.size() == 0 and not is_cleared:
		is_cleared = true
		unlock_doors()
		print("Комната очищена, двери открыты!")
