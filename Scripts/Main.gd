extends Node2D

# Ссылки на узлы
@onready var player = $Player
@onready var camera = $Camera2D

# Экспортируемые сцены комнат
@export var start_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_pool: Array[PackedScene] = []

# Параметры комнат
@export var room_width: int = 1280
@export var room_height: int = 1024
@export var room_spacing: int = 50
@export var min_rooms: int = 2
@export var max_rooms: int = 4

# Хранилище комнат и состояние
var room_instances: Array[Node2D] = []
var current_room_index: int = 0
var is_transitioning: bool = false

func _ready():
	if player and not player.is_in_group("Player"):
		player.add_to_group("Player")
	generate_dungeon()

# Генерация подземелья
func generate_dungeon():
	if start_room_scene == null or end_room_scene == null or room_pool.size() == 0:
		print("Ошибка: не назначены сцены комнат!")
		return

	# Очищаем старые комнаты
	for room in room_instances:
		room.queue_free()
	room_instances.clear()

	var intermediate_count = randi_range(min_rooms, max_rooms)
	print("Генерация: ", intermediate_count, " промежуточных комнат")

	var prev_room: Node2D

	# Стартовая комната
	var start_room = start_room_scene.instantiate()
	start_room.name = "StartRoom"  # задаём имя для отладки
	add_child(start_room)
	start_room.global_position = Vector2(0, 0)
	room_instances.append(start_room)
	prev_room = start_room

	# Промежуточные комнаты
	for i in range(intermediate_count):
		var random_scene = room_pool[randi_range(0, room_pool.size() - 1)]
		var room = random_scene.instantiate()
		room.name = "Room" + str(i + 1)  # задаём имя
		add_child(room)
		room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
		room_instances.append(room)
		prev_room = room

	# Конечная комната
	var end_room = end_room_scene.instantiate()
	end_room.name = "EndRoom"
	add_child(end_room)
	end_room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
	room_instances.append(end_room)

	# Соединяем комнаты дверями
	connect_rooms()
	# Отключаем все двери, которые никуда не ведут (например, правая дверь в последней комнате)
	disable_unconnected_doors()
	# Входим в первую комнату
	enter_room(0)

# Соединение дверей между соседними комнатами
func connect_rooms():
	for i in range(room_instances.size() - 1):
		var left_room = room_instances[i]
		var right_room = room_instances[i + 1]
		var left_door = left_room.get_node("DoorRight") if left_room.has_node("DoorRight") else null
		var right_door = right_room.get_node("DoorLeft") if right_room.has_node("DoorLeft") else null
		if left_door and right_door:
			# Проверяем, что у дверей есть нужные свойства (т.е. они имеют скрипт Door.gd)
			if left_door.has_method("set_open") and right_door.has_method("set_open"):
				left_door.linked_door = right_door
				right_door.linked_door = left_door
				left_door.target_room_node = right_room
				right_door.target_room_node = left_room
				print("Связаны комнаты ", i, " и ", i + 1)
			else:
				print("Ошибка: на дверях нет скрипта Door.gd в комнатах ", i, " и ", i + 1)
		else:
			print("Нет дверей для соединения комнат ", i, " и ", i + 1)

# Отключение дверей, которые не соединены с другой комнатой (например, правая дверь в последней комнате)
func disable_unconnected_doors():
	for room in room_instances:
		for child in room.get_children():
			if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
				if child.has_method("set_open"):
					if child.target_room_node == null:
						child.set_open(false)
						child.monitoring = false
						child.monitorable = false
						print("Отключена дверь: ", child.name, " в комнате ", room.name)
					else:
						print("Дверь ", child.name, " в комнате ", room.name, " ведёт в ", child.target_room_node.name)

# Вход в комнату по индексу
func enter_room(index: int):
	if index < 0 or index >= room_instances.size():
		print("Ошибка: индекс комнаты вне диапазона: ", index)
		return

	# Прячем все комнаты
	for room in room_instances:
		room.visible = false

	var room = room_instances[index]
	room.visible = true

	# Вывод имени комнаты для отладки
	var room_name = room.name
	if room_name == "" or room_name == "Node2D":
		room_name = "Комната " + str(index)
	print("=== ВХОД В КОМНАТУ: ", room_name, " (индекс ", index, ") ===")

	# Перемещаем игрока в спавн
	var spawn = room.get_node("SpawnPoint")
	if spawn:
		player.global_position = spawn.global_position
	else:
		player.global_position = room.global_position + Vector2(room_width / 2, room_height / 2)

	# Устанавливаем камеру в центр комнаты
	var center = room.global_position + Vector2(room_width / 2, room_height / 2)
	camera.global_position = center

	current_room_index = index

	# Если у комнаты есть метод on_room_entered, вызываем его
	if room.has_method("on_room_entered"):
		room.on_room_entered()

	print("Вошли в комнату ", index)

# Переход игрока в другую комнату через дверь
func move_player_to_room(target_room_node: Node2D, door_position: Vector2):
	print("move_player_to_room вызван. target_room_node = ", target_room_node)
	if is_transitioning:
		print("Переход уже выполняется, игнорируем")
		return

	is_transitioning = true

	var target_index = room_instances.find(target_room_node)
	print("target_index = ", target_index)
	if target_index == -1:
		print("Ошибка: целевая комната не найдена в room_instances!")
		is_transitioning = false
		return

	enter_room(target_index)
	# Сдвигаем игрока чуть от двери, чтобы не застрять
	player.global_position = door_position + Vector2(0, 20)

	# Ожидаем 0.3 секунды, чтобы игрок не мог сразу же повторно войти в дверь
	await get_tree().create_timer(0.3).timeout
	is_transitioning = false
	print("Переход завершён, is_transitioning = ", is_transitioning)

# Перезапуск игры по клавише R
func _process(_delta):
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
