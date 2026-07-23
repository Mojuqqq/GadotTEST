extends Node2D

var doors: Array = []
var enemies: Array = []
var is_cleared: bool = false
var is_active: bool = false

func _ready():
	print("Room._ready: начинаю поиск дверей и врагов")
	find_doors_recursive(self)
	update_enemies_list()   # <-- теперь функция существует
	print("Найдено дверей: ", doors.size())
	print("Найдено врагов: ", enemies.size())
	# create_bounce_walls()  # удалено (масло убрано)
	set_active(false)

func set_active(active: bool):
	is_active = active
	for enemy in enemies:
		if is_instance_valid(enemy):
			print("Вызываем set_active для ", enemy.name)
			enemy.set_active(active)
	print("Комната ", name, " активность: ", active)

func find_doors_recursive(node: Node):
	for child in node.get_children():
		if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			doors.append(child)
			print("Найдена дверь: ", child.name)
		else:
			find_doors_recursive(child)

func update_enemies_list():
	enemies.clear()

	for enemy in get_tree().get_nodes_in_group("Enemies"):
		if not is_instance_valid(enemy):
			continue
		if not is_ancestor_of(enemy):
			continue
		enemies.append(enemy)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)
			print("Подключён сигнал died к врагу: ", enemy.name)

	GameManager.enemies_changed.emit(enemies.size())
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
	
	GameManager.enemies_changed.emit(enemies.size())
	
	# Только если врагов не осталось и комната ещё не очищена
	if enemies.size() == 0 and not is_cleared:
		is_cleared = true
		unlock_doors()
		print("Комната очищена, двери открыты!")
		call_deferred("spawn_chest")

	# Победа только после очистки конечной комнаты
		if name == "EndRoom":
			print("Победа! Конечная комната очищена.")
			GameManager.trigger_game_over(true)

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
