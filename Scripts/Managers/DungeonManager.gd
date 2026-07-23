extends Node


signal room_changed(room_name: StringName,room_index: int)

signal enemies_changed(count: int)


# =========================================================
# СОСТОЯНИЕ ПОДЗЕМЕЛЬЯ
# =========================================================

var is_transitioning: bool = false

var room_instances: Array[Node2D] = []
var current_room_index: int = 0


# =========================================================
# НАСТРОЙКИ ГЕНЕРАЦИИ
# =========================================================

var room_width: int = 1280
var room_height: int = 1024
var room_spacing: int = 50

var min_rooms: int = 2
var max_rooms: int = 4


# =========================================================
# СЦЕНЫ
# =========================================================

var start_room_scene: PackedScene = null
var end_room_scene: PackedScene = null
var boss_scene: PackedScene = null

var room_pool: Array[PackedScene] = []
var enemy_pool: Array[PackedScene] = []


# =========================================================
# НАСТРОЙКИ ВРАГОВ
# =========================================================

var min_enemies_per_room: int = 2
var max_enemies_per_room: int = 4

var enemies_in_start_room: int = 0
var enemies_in_end_room: int = 4


# =========================================================
# ГЕНЕРАЦИЯ КОМНАТ
# =========================================================

func generate_dungeon(root_node: Node):
	_clear_existing_rooms()

	if start_room_scene == null:
		push_error("Не назначена стартовая комната.")
		return

	if end_room_scene == null:
		push_error("Не назначена конечная комната.")
		return

	if room_pool.is_empty():
		push_error("Пул промежуточных комнат пуст.")
		return

	var intermediate_count := randi_range(min_rooms,max_rooms)

	print("Генерация: ",intermediate_count," промежуточных комнат")

	var start_room := _create_room(start_room_scene,"StartRoom",root_node,Vector2.ZERO)

	if start_room == null:
		return

	room_instances.append(start_room)

	spawn_enemies_for_room(start_room,0)

	var previous_room := start_room

	for index in range(intermediate_count):
		var random_scene: PackedScene = (room_pool.pick_random())

		var room_position := (previous_room.global_position+ Vector2(room_width + room_spacing,0))

		var room := _create_room(random_scene,"Room" + str(index + 1),root_node,room_position)

		if room == null:
			continue

		room_instances.append(room)
		previous_room = room

		spawn_enemies_for_room(room,index + 1)

	var end_position := (previous_room.global_position+ Vector2(room_width + room_spacing,0))

	var end_room := _create_room(end_room_scene,"EndRoom",root_node,end_position)

	if end_room == null:
		return

	room_instances.append(end_room)

	_spawn_end_room_content(end_room)

	connect_rooms()
	disable_unconnected_doors()
	enter_room(0)


# =========================================================
# СОЗДАНИЕ ОДНОЙ КОМНАТЫ
# =========================================================

func _create_room(scene: PackedScene,room_name: String,
	root_node: Node,
	room_position: Vector2
) -> Node2D:
	if scene == null:
		push_error(
			"Нельзя создать комнату "
			+ room_name
			+ ": сцена не назначена."
		)
		return null

	var room := scene.instantiate() as Node2D

	if room == null:
		push_error(
			"Корень комнаты должен быть Node2D: "
			+ room_name
		)
		return null

	room.name = room_name

	root_node.add_child(room)

	room.global_position = room_position

	return room


# =========================================================
# КОНЕЧНАЯ КОМНАТА И БОСС
# =========================================================

func _spawn_end_room_content(
	end_room: Node2D
) -> void:
	if boss_scene == null:
		push_warning(
			"Сцена босса не назначена. "
			+ "В конечной комнате появятся обычные враги."
		)

		spawn_enemies_for_room(
			end_room,
			room_instances.size() - 1
		)

		return

	var boss := boss_scene.instantiate()

	end_room.add_child(boss)

	if boss is Node2D:
		boss.position = Vector2(
			room_width / 2.0,
			room_height / 2.0
		)

	if boss.has_method("set_room_limits"):
		var room_limits := Rect2(
			end_room.global_position.x,
			end_room.global_position.y,
			room_width,
			room_height
		)

		boss.set_room_limits(room_limits)

	# Босс не должен двигаться,
	# пока игрок не вошёл в конечную комнату.
	if boss is Node:
		boss.set_physics_process(false)

	print(
		"Босс создан в конечной комнате."
	)


# =========================================================
# СОЕДИНЕНИЕ КОМНАТ
# =========================================================

func connect_rooms() -> void:
	for index in range(
		room_instances.size() - 1
	):
		var left_room := room_instances[index]

		var right_room := room_instances[
			index + 1
		]

		var left_door := _find_child_recursive(
			left_room,
			"DoorRight"
		)

		var right_door := _find_child_recursive(
			right_room,
			"DoorLeft"
		)

		if left_door == null:
			push_warning(
				"Не найдена DoorRight в комнате "
				+ left_room.name
			)
			continue

		if right_door == null:
			push_warning(
				"Не найдена DoorLeft в комнате "
				+ right_room.name
			)
			continue

		if not left_door.has_method("set_open"):
			push_warning(
				"У DoorRight отсутствует Door.gd: "
				+ left_room.name
			)
			continue

		if not right_door.has_method("set_open"):
			push_warning(
				"У DoorLeft отсутствует Door.gd: "
				+ right_room.name
			)
			continue

		left_door.linked_door = right_door
		right_door.linked_door = left_door

		left_door.target_room_node = right_room
		right_door.target_room_node = left_room

		print(
			"Связаны комнаты ",
			index,
			" и ",
			index + 1
		)


# =========================================================
# ОТКЛЮЧЕНИЕ ДВЕРЕЙ БЕЗ СОЕДИНЕНИЙ
# =========================================================

func disable_unconnected_doors() -> void:
	for room in room_instances:
		var doors: Array[Area2D] = []

		_collect_doors(
			room,
			doors
		)

		for door in doors:
			if not door.has_method("set_open"):
				continue

			if door.target_room_node != null:
				print(
					"Дверь ",
					door.name,
					" в комнате ",
					room.name,
					" ведёт в ",
					door.target_room_node.name
				)

				continue

			door.set_open(false)

			door.set_deferred(
				"monitoring",
				false
			)

			door.set_deferred(
				"monitorable",
				false
			)

			print(
				"Отключена дверь: ",
				door.name,
				" в комнате ",
				room.name
			)


# =========================================================
# ВХОД В КОМНАТУ
# =========================================================

func enter_room(index: int) -> void:
	if index < 0:
		push_warning(
			"Индекс комнаты меньше нуля: "
			+ str(index)
		)
		return

	if index >= room_instances.size():
		push_warning(
			"Индекс комнаты вне диапазона: "
			+ str(index)
		)
		return

	if (
		current_room_index >= 0
		and current_room_index
		< room_instances.size()
	):
		var previous_room := room_instances[
			current_room_index
		]

		if previous_room.has_method(
			"set_active"
		):
			previous_room.set_active(false)

	var room := room_instances[index]

	room.visible = true
	current_room_index = index

	print(
		"Комната ",
		room.name,
		" visible = ",
		room.visible
	)

	room_changed.emit(
		room.name,
		index
	)

	if room.has_method("on_room_entered"):
		room.on_room_entered()
	else:
		push_warning(
			"У комнаты нет метода "
			+ "on_room_entered: "
			+ room.name
		)

	print(
		"Вошли в комнату ",
		index
	)

	update_enemy_count()


# =========================================================
# ПЕРЕХОД В ДРУГУЮ КОМНАТУ
# =========================================================

func move_player_to_room(
	target_room_node: Node2D,
	_door_position: Vector2
) -> int:
	var target_index := room_instances.find(
		target_room_node
	)

	if target_index == -1:
		push_warning(
			"Целевая комната не найдена."
		)
		return -1

	enter_room(target_index)

	return target_index


# =========================================================
# ТЕКУЩАЯ КОМНАТА
# =========================================================

func get_current_room() -> Node2D:
	if current_room_index < 0:
		return null

	if current_room_index >= room_instances.size():
		return null

	return room_instances[current_room_index]


# =========================================================
# ПОДСЧЁТ ВРАГОВ
# =========================================================

func get_enemy_count_in_room() -> int:
	var room := get_current_room()

	if room == null:
		return 0

	var count := 0

	var all_enemies := get_tree().get_nodes_in_group(
		"Enemies"
	)

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		if room.is_ancestor_of(enemy):
			count += 1

	return count


func update_enemy_count() -> void:
	var count := get_enemy_count_in_room()

	enemies_changed.emit(count)


# =========================================================
# СОЗДАНИЕ ВРАГОВ
# =========================================================

func spawn_enemies_for_room(
	room: Node2D,
	_index: int
) -> void:
	var count := 0

	if room.name == "StartRoom":
		count = enemies_in_start_room

	elif room.name == "EndRoom":
		count = enemies_in_end_room

	else:
		count = randi_range(
			min_enemies_per_room,
			max_enemies_per_room
		)

	if count <= 0:
		return

	if enemy_pool.is_empty():
		push_warning(
			"Пул врагов пуст."
		)
		return

	if not room.has_method("spawn_enemies"):
		push_warning(
			"Комната "
			+ room.name
			+ " не имеет метода spawn_enemies."
		)
		return

	room.spawn_enemies(
		count,
		enemy_pool
	)


# =========================================================
# РЕКУРСИВНЫЙ ПОИСК ДВЕРИ
# =========================================================

func _find_child_recursive(
	node: Node,
	target_name: String
) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child

		var result := _find_child_recursive(
			child,
			target_name
		)

		if result != null:
			return result

	return null


# =========================================================
# СБОР ВСЕХ ДВЕРЕЙ КОМНАТЫ
# =========================================================

func _collect_doors(
	node: Node,
	result: Array[Area2D]
) -> void:
	for child in node.get_children():
		if (
			child is Area2D
			and (
				child.name == "DoorLeft"
				or child.name == "DoorRight"
			)
		):
			result.append(child)

		else:
			_collect_doors(
				child,
				result
			)


# =========================================================
# СБРОС ПОДЗЕМЕЛЬЯ
# =========================================================

func reset() -> void:
	is_transitioning = false
	current_room_index = 0

	_clear_existing_rooms()


func _clear_existing_rooms() -> void:
	for room in room_instances:
		if is_instance_valid(room):
			room.queue_free()

	room_instances.clear()
