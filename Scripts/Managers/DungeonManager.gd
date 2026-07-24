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

func generate_dungeon(root_node: Node) -> void:
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

	var intermediate_count: int = randi_range(
		min_rooms,
		max_rooms
	)

	var treasure_room_index: int = -1

	if intermediate_count > 0:
		treasure_room_index = randi_range(
			0,
			intermediate_count - 1
		)

	var shop_room_index: int = -1

	# Магазин появляется только при трёх
	# и более промежуточных комнатах.
	if intermediate_count >= 3:
		var available_indices: Array[int] = []

		for index in range(intermediate_count):
			if index == treasure_room_index:
				continue

			available_indices.append(index)

		if not available_indices.is_empty():
			shop_room_index = available_indices.pick_random()

	print(
		"Генерация: ",
		intermediate_count,
		" промежуточных комнат"
	)

	print(
		"Индекс комнаты сокровищ: ",
		treasure_room_index
	)
	
	print(
	"Индекс комнаты магазина: ",
	shop_room_index
	)

	var start_room := _create_room(
		start_room_scene,
		"StartRoom",
		root_node,
		Vector2.ZERO,
		Room.RoomType.START
	)

	if start_room == null:
		return

	room_instances.append(start_room)

	spawn_enemies_for_room(
		start_room,
		0
	)

	var previous_room: Node2D = start_room

	for index in range(intermediate_count):
		var random_scene: PackedScene = (
			room_pool.pick_random()
		)

		var room_position: Vector2 = (
			previous_room.global_position
			+ Vector2(
				room_width + room_spacing,
				0
			)
		)

		var generated_room_type: int = (
				Room.RoomType.COMBAT
		)

		if index == treasure_room_index:
			generated_room_type = (
				Room.RoomType.TREASURE
			)

		elif index == shop_room_index:
			generated_room_type = (
				Room.RoomType.SHOP
			)

		var room := _create_room(
			random_scene,
			"Room" + str(index + 1),
			root_node,
			room_position,
			generated_room_type
		)

		if room == null:
			continue

		room_instances.append(room)
		previous_room = room

		if generated_room_type == Room.RoomType.TREASURE:
			room.call_deferred("spawn_chest")

			print(
				"Создана комната сокровищ: ",
				room.name
			)

		elif generated_room_type == Room.RoomType.SHOP:
			room.call_deferred(
				"spawn_merchant"
			)

			print(
				"Создана комната магазина: ",
				room.name
			)

		else:
			spawn_enemies_for_room(
				room,
				index + 1
			)

	var end_position: Vector2 = (
		previous_room.global_position
		+ Vector2(
			room_width + room_spacing,
			0
		)
	)

	var end_room := _create_room(
		end_room_scene,
		"EndRoom",
		root_node,
		end_position,
		Room.RoomType.BOSS
	)

	if end_room == null:
		return

	room_instances.append(end_room)

	_spawn_end_room_content(end_room)
	
	_assign_guaranteed_key_carrier()

	connect_rooms()
	disable_unconnected_doors()
	enter_room(0)


# =========================================================
# СОЗДАНИЕ ОДНОЙ КОМНАТЫ
# =========================================================

func _create_room(
	scene: PackedScene,
	room_name: String,
	root_node: Node,
	room_position: Vector2,
	generated_room_type: int
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

	if room.has_method("set_room_type"):
		room.set_room_type(
			generated_room_type
		)
	else:
		push_warning(
			"У комнаты нет метода set_room_type(): "
			+ room_name
		)

	root_node.add_child(room)
	room.global_position = room_position

	print(
		"Создана комната ",
		room_name,
		", тип: ",
		generated_room_type
	)

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
		if boss.has_method("set_active"):
			boss.set_active(false)
		else:
			boss.process_mode = (
				Node.PROCESS_MODE_DISABLED
			)

# =========================================================
# ГАРАНТИРОВАННЫЙ КЛЮЧ
# =========================================================

func _assign_guaranteed_key_carrier() -> void:
	var candidates: Array[Node] = (
		_collect_key_carrier_candidates()
	)

	# Теоретически все случайно созданные враги
	# могут оказаться неподходящими, например яйцами.
	# Тогда создаём одного безопасного моба дополнительно.
	if candidates.is_empty():
		var fallback_enemy: Node = (
			_spawn_fallback_key_carrier()
		)

		if fallback_enemy != null:
			candidates.append(fallback_enemy)

	if candidates.is_empty():
		push_error(
			"Не удалось назначить гарантированный ключ: "
			+ "на этаже нет подходящих мобов."
		)
		return

	var carrier: Node = candidates.pick_random()

	if not is_instance_valid(carrier):
		push_error(
			"Выбранный носитель ключа недействителен."
		)
		return

	carrier.call("assign_guaranteed_key")

	var carrier_room: Node = carrier.get_parent()

	var room_name: String = "неизвестная комната"

	if is_instance_valid(carrier_room):
		room_name = carrier_room.name

	print(
		"Гарантированный ключ назначен мобу ",
		carrier.name,
		" в комнате ",
		room_name
	)


func _collect_key_carrier_candidates() -> Array[Node]:
	var candidates: Array[Node] = []

	var all_enemies := get_tree().get_nodes_in_group(
		"Enemies"
	)

	for room in room_instances:
		if not is_instance_valid(room):
			continue

		if room.is_queued_for_deletion():
			continue

		if not room.has_method("is_combat_room"):
			continue

		# START, TREASURE и BOSS исключаются.
		if not bool(room.call("is_combat_room")):
			continue

		for enemy in all_enemies:
			if not is_instance_valid(enemy):
				continue

			if enemy.is_queued_for_deletion():
				continue

			if not room.is_ancestor_of(enemy):
				continue

			if not _can_enemy_carry_key(enemy):
				continue

			candidates.append(enemy)

	return candidates


func _can_enemy_carry_key(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.is_queued_for_deletion():
		return false

	if not enemy.has_method(
		"can_receive_guaranteed_key"
	):
		return false

	return bool(
		enemy.call(
			"can_receive_guaranteed_key"
		)
	)

func _spawn_fallback_key_carrier() -> Node:
	var combat_rooms: Array[Node2D] = []

	for room in room_instances:
		if not is_instance_valid(room):
			continue

		if not room.has_method("is_combat_room"):
			continue

		if bool(room.call("is_combat_room")):
			combat_rooms.append(room)

	if combat_rooms.is_empty():
		push_error(
			"Не найдена боевая комната "
			+ "для гарантированного ключа."
		)
		return null

	var safe_enemy_scenes: Array[PackedScene] = []

	for enemy_scene in enemy_pool:
		if enemy_scene == null:
			continue

		var preview: Node = (
			enemy_scene.instantiate()
		)

		if preview == null:
			continue

		var can_carry: bool = (
			_can_enemy_carry_key(preview)
		)

		preview.free()

		if can_carry:
			safe_enemy_scenes.append(
				enemy_scene
			)

	if safe_enemy_scenes.is_empty():
		push_error(
			"В enemy_pool нет ни одного моба, "
			+ "которому можно назначить ключ."
		)
		return null

	var target_room: Node2D = (
		combat_rooms.pick_random()
	)

	var safe_scene: PackedScene = (
		safe_enemy_scenes.pick_random()
	)

	# Используем существующую систему комнаты,
	# чтобы моб получил позицию, границы и деактивацию.
	target_room.call(
		"spawn_enemies",
		1,
		[safe_scene]
	)

	if target_room.has_method(
		"update_enemies_list"
	):
		target_room.call(
			"update_enemies_list"
		)

	var all_enemies := get_tree().get_nodes_in_group(
		"Enemies"
	)

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue

		if not target_room.is_ancestor_of(enemy):
			continue

		if _can_enemy_carry_key(enemy):
			print(
				"Создан дополнительный моб "
				+ "для гарантированного ключа: ",
				enemy.name
			)

			return enemy

	return null

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
