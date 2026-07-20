extends Node2D

var doors: Array = []
var enemies: Array = []
var is_cleared: bool = false
var is_active: bool = false   # флаг активности комнаты

func _ready():
	print("Room._ready: начинаю поиск дверей и врагов")
	find_doors_recursive(self)
	update_enemies_list()
	print("Найдено дверей: ", doors.size())
	print("Найдено врагов: ", enemies.size())
	# Изначально все комнаты неактивны
	set_active(false)

func set_active(active: bool):
	is_active = active
	# Включаем/выключаем физику у всех врагов в комнате
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_active(active) 
			# Также можно управлять видимостью (по желанию)
			# enemy.visible = active
	print("Комната ", name, " активность: ", active)
	
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
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and self.is_ancestor_of(enemy):
			enemies.append(enemy)
			if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
				enemy.died.connect(_on_enemy_died)
				print("Подключён сигнал died к врагу: ", enemy.name)
	print("Обновлён список врагов: ", enemies.size())
	GameManager.update_enemy_count()

func on_room_entered():
	print("Room.on_room_entered вызван")
	update_enemies_list()
	if enemies.size() == 0:
		print("Нет живых врагов, открываем двери")
		unlock_doors()
	else:
		print("Есть живые враги (", enemies.size(), "), закрываем двери")
		lock_doors()
	# Включаем врагов при входе
	set_active(true)

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
	
	GameManager.update_enemy_count()
	
	# Если врагов не осталось и комната ещё не очищена – открываем двери и создаём сундук
	if enemies.size() == 0 and not is_cleared:
		is_cleared = true
		unlock_doors()
		print("Комната очищена, двери открыты!")
		# Отложенный вызов, чтобы избежать ошибки с flushing queries
		call_deferred("spawn_chest")

func spawn_enemies(count: int, enemy_pool: Array):
	if count <= 0 or enemy_pool.size() == 0:
		return
	
	var room_width = GameManager.room_width
	var room_height = GameManager.room_height
	var margin = 50
	var room_pos = global_position
	var limits = Rect2(room_pos.x, room_pos.y, room_width, room_height)

	for i in range(count):
		var enemy_scene = enemy_pool[randi_range(0, enemy_pool.size() - 1)]
		var enemy = enemy_scene.instantiate()
		add_child(enemy)
		
		var x = randf_range(margin, room_width - margin)
		var y = randf_range(margin, room_height - margin)
		enemy.position = Vector2(x, y)
		
		if enemy.has_method("set_room_limits"):
			enemy.set_room_limits(limits)
		
		# Изначально враги отключены (физика выключена), пока комната не станет активной
		enemy.set_physics_process(false)
		
		print("Создан враг в комнате ", name, " на позиции ", enemy.position)
		
func spawn_chest():
	if GameManager.all_items.size() == 0:
		return
	var item = GameManager.all_items[randi_range(0, GameManager.all_items.size() - 1)]
	
	var chest_scene = preload("res://Scenes/Chest.tscn")
	var chest = chest_scene.instantiate()
	
	
	var margin = 100
	var x = randf_range(margin, GameManager.room_width - margin)
	var y = randf_range(margin, GameManager.room_height - margin)
	chest.item = item
	add_child(chest)
	chest.position = Vector2(x, y)
	print("Сундук создан в комнате ", name)
