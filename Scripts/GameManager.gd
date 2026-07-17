extends Node

# ===== СИГНАЛЫ ДЛЯ UI =====
signal player_hp_changed(hp, max_hp)
signal room_changed(room_name, room_index)
signal enemies_changed(count)
signal game_over(victory: bool)
var is_transitioning: bool = false

# ===== СОСТОЯНИЕ ИГРОКА =====
var player: Node2D = null
var player_hp: int = 5
var player_max_hp: int = 5

# ===== КОМНАТЫ =====
var room_instances: Array[Node2D] = []
var current_room_index: int = 0

# ===== НАСТРОЙКИ ГЕНЕРАЦИИ =====
var room_width: int = 1280
var room_height: int = 1024
var room_spacing: int = 50
var min_rooms: int = 2
var max_rooms: int = 4

# Сцены комнат (загружаются из Main)
var start_room_scene: PackedScene
var end_room_scene: PackedScene
var room_pool: Array[PackedScene] = []

# ===== МЕТОДЫ УПРАВЛЕНИЯ ИГРОКОМ =====
func set_player(player_node: Node2D):
	player = player_node
	player_hp = player_max_hp
	emit_signal("player_hp_changed", player_hp, player_max_hp)

func take_damage(amount: int):
	player_hp -= amount
	if player_hp < 0:
		player_hp = 0
	emit_signal("player_hp_changed", player_hp, player_max_hp)
	if player_hp <= 0:
		emit_signal("game_over", false)
		if player and player.has_method("die"):
			player.die()

func heal(amount: int):
	player_hp = min(player_hp + amount, player_max_hp)
	emit_signal("player_hp_changed", player_hp, player_max_hp)

# ===== ГЕНЕРАЦИЯ ПОДЗЕМЕЛЬЯ =====
func generate_dungeon(root_node: Node):
	if start_room_scene == null or end_room_scene == null or room_pool.size() == 0:
		print("Ошибка: не назначены сцены комнат!")
		return

	# Очистка старых комнат
	for room in room_instances:
		room.queue_free()
	room_instances.clear()

	var intermediate_count = randi_range(min_rooms, max_rooms)
	print("Генерация: ", intermediate_count, " промежуточных комнат")

	var prev_room: Node2D

	# Стартовая комната
	var start_room = start_room_scene.instantiate()
	start_room.name = "StartRoom"
	root_node.add_child(start_room)
	start_room.global_position = Vector2(0, 0)
	room_instances.append(start_room)
	prev_room = start_room

	# Промежуточные комнаты
	for i in range(intermediate_count):
		var random_scene = room_pool[randi_range(0, room_pool.size() - 1)]
		var room = random_scene.instantiate()
		room.name = "Room" + str(i + 1)
		root_node.add_child(room)
		room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
		room_instances.append(room)
		prev_room = room

	# Конечная комната
	var end_room = end_room_scene.instantiate()
	end_room.name = "EndRoom"
	root_node.add_child(end_room)
	end_room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
	room_instances.append(end_room)

	connect_rooms()
	disable_unconnected_doors()
	enter_room(0)

# ===== РАБОТА С КОМНАТАМИ =====
func connect_rooms():
	for i in range(room_instances.size() - 1):
		var left_room = room_instances[i]
		var right_room = room_instances[i + 1]
		var left_door = find_child_recursive(left_room, "DoorRight")
		var right_door = find_child_recursive(right_room, "DoorLeft")
		if left_door and right_door:
			if left_door.has_method("set_open") and right_door.has_method("set_open"):
				left_door.linked_door = right_door
				right_door.linked_door = left_door
				left_door.target_room_node = right_room
				right_door.target_room_node = left_room
				print("Связаны комнаты ", i, " и ", i+1)
			else:
				print("Ошибка: на дверях нет скрипта Door.gd в комнатах ", i, " и ", i+1)
		else:
			print("Нет дверей для соединения комнат ", i, " и ", i+1)

func disable_unconnected_doors():
	for room in room_instances:
		var doors = []
		collect_doors(room, doors)
		for door in doors:
			if door.has_method("set_open"):
				if door.target_room_node == null:
					door.set_open(false)
					door.monitoring = false
					door.monitorable = false
					print("Отключена дверь: ", door.name, " в комнате ", room.name)
				else:
					print("Дверь ", door.name, " в комнате ", room.name, " ведёт в ", door.target_room_node.name)

func find_child_recursive(node: Node, name: String) -> Node:
	for child in node.get_children():
		if child.name == name:
			return child
		var result = find_child_recursive(child, name)
		if result:
			return result
	return null

func collect_doors(node: Node, list: Array):
	for child in node.get_children():
		if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			list.append(child)
		else:
			collect_doors(child, list)

func enter_room(index: int):
	if index < 0 or index >= room_instances.size():
		print("Ошибка: индекс комнаты вне диапазона: ", index)
		return

	# Скрываем все комнаты
	for room in room_instances:
		room.visible = false

	var room = room_instances[index]
	room.visible = true

	current_room_index = index
	emit_signal("room_changed", room.name, index)

	if room.has_method("on_room_entered"):
		room.on_room_entered()

	print("Вошли в комнату ", index)
	update_enemy_count()

func move_player_to_room(target_room_node: Node2D, door_position: Vector2) -> int:
	var target_index = room_instances.find(target_room_node)
	if target_index == -1:
		print("Ошибка: целевая комната не найдена!")
		return -1
	enter_room(target_index)
	return target_index

func get_current_room() -> Node2D:
	if current_room_index < room_instances.size():
		return room_instances[current_room_index]
	return null

func get_enemy_count_in_room() -> int:
	var room = get_current_room()
	if room == null:
		return 0
	var count = 0
	var all_enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and room.is_ancestor_of(enemy):
			count += 1
	return count

func update_enemy_count():
	var count = get_enemy_count_in_room()
	emit_signal("enemies_changed", count)
