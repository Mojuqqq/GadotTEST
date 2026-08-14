extends Node


signal room_changed(room_name: StringName,room_index: int)

signal enemies_changed(count: int)


# =========================================================
# СОСТОЯНИЕ ПОДЗЕМЕЛЬЯ
# =========================================================

var is_transitioning: bool = false

var room_instances: Array[Node2D] = []
var current_room_index: int = 0
var room_by_cell: Dictionary = {}
var cell_by_room: Dictionary = {}
var room_connections: Dictionary = {}
var generated_room_layout: Array[Dictionary] = []
# Одноразовая замена следующей посещённой
# комнаты на комнату с выбранным боссом.
var debug_next_room_boss_scene: PackedScene = null

# =========================================================
# НАСТРОЙКИ ГЕНЕРАЦИИ
# =========================================================

var room_width: int = 1280
var room_height: int = 1024
var room_spacing: int = 50

var min_rooms: int = 2
var max_rooms: int = 4


const LOCATION_DEFINITIONS: Array[Dictionary] = [
	{
		"id": &"farm_outside",
		"name": "Ферма снаружи",
		"floor": LocationProfile.FloorType.DIRT,
		"walls": LocationProfile.WallType.FARM
	},
	{
		"id": &"field",
		"name": "Поле",
		"floor": LocationProfile.FloorType.DIRT,
		"walls": LocationProfile.WallType.FARM
	},
	{
		"id": &"barn",
		"name": "Сарай",
		"floor": LocationProfile.FloorType.WOOD,
		"walls": LocationProfile.WallType.BARN
	},
	{
		"id": &"chicken_coop",
		"name": "Курятник",
		"floor": LocationProfile.FloorType.WOOD,
		"walls": LocationProfile.WallType.BARN
	},
	{
		"id": &"vegetable_garden",
		"name": "Огород",
		"floor": LocationProfile.FloorType.GRASS,
		"walls": LocationProfile.WallType.GARDEN
	},
	{
		"id": &"flower_garden",
		"name": "Цветник",
		"floor": LocationProfile.FloorType.GRASS,
		"walls": LocationProfile.WallType.GARDEN
	},
	{
		"id": &"orchard",
		"name": "Сад",
		"floor": LocationProfile.FloorType.GRASS,
		"walls": LocationProfile.WallType.GARDEN
	}
]

# =========================================================
# СЦЕНЫ
# =========================================================

var start_room_scene: PackedScene = null
var end_room_scene: PackedScene = null
var boss_scene: PackedScene = null

var room_pool: Array[PackedScene] = []
var enemy_pool: Array[PackedScene] = []
var boss_pool: Array[PackedScene] = []


# =========================================================
# НАСТРОЙКИ ВРАГОВ
# =========================================================

var min_enemies_per_room: int = 2
var max_enemies_per_room: int = 4

var enemies_in_start_room: int = 0
var enemies_in_end_room: int = 4

# =========================================================
# DEBUG: ВЫБОР БОССА ДЛЯ СЛЕДУЮЩЕЙ КОМНАТЫ
# =========================================================

func arm_debug_next_room_boss(
	selected_boss_scene: PackedScene
) -> bool:
	if selected_boss_scene == null:
		return false

	debug_next_room_boss_scene = selected_boss_scene

	print(
		"[DEBUG] Следующая посещённая комната "
		+ "будет заменена на босс-комнату: "
		+ selected_boss_scene.resource_path
	)

	return true


func cancel_debug_next_room_boss() -> void:
	debug_next_room_boss_scene = null

	print(
		"[DEBUG] Замена следующей комнаты отменена."
	)


func get_debug_next_room_boss_scene() -> PackedScene:
	return debug_next_room_boss_scene

# =========================================================
# ГЕНЕРАЦИЯ КОМНАТ
# =========================================================
func _create_random_location_profile() -> LocationProfile:
	var definition: Dictionary = (
		LOCATION_DEFINITIONS.pick_random()
	)

	var profile := LocationProfile.new()

	profile.id = StringName(
		definition["id"]
	)

	profile.display_name = str(
		definition["name"]
	)

	profile.floor_type = (
		int(definition["floor"])
		as LocationProfile.FloorType
	)

	profile.wall_type = (
		int(definition["walls"])
		as LocationProfile.WallType
	)

	return profile


func _generate_room_layout(
	intermediate_count: int
) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []

	var occupied_cells: Dictionary = {}

	var start_entry: Dictionary = {
		"cell": Vector2i.ZERO,
		"parent": -1,
		"main_path": true
	}

	layout.append(start_entry)

	occupied_cells[
		Vector2i.ZERO
	] = true

	# Хотя бы одну промежуточную комнату
	# оставляем на основном пути.
	var branch_count: int = 0

	if intermediate_count >= 2:
		branch_count = 1

	if intermediate_count >= 4:
		branch_count = randi_range(
			1,
			2
		)

	var main_room_count: int = (
		intermediate_count
		- branch_count
	)

	var current_cell := Vector2i.ZERO
	var current_parent_index: int = 0

	# =====================================================
	# ОСНОВНОЙ ПУТЬ
	# =====================================================

# =====================================================
	# ЗАРАНЕЕ РЕЗЕРВИРУЕМ МЕСТО ДЛЯ BOSS
	# =====================================================

	var boss_parent_index: int = (
		current_parent_index
	)

	var boss_parent_cell: Vector2i = (
		layout[
			boss_parent_index
		]["cell"]
	)

	var reserved_boss_cell: Vector2i = (
		Vector2i.ZERO
	)

	var boss_cell_reserved: bool = false

	var boss_directions := (
		_get_grid_directions()
	)

	boss_directions.shuffle()

	for direction in boss_directions:
		var candidate: Vector2i = (
			boss_parent_cell
			+ direction
		)

		if not _can_place_branch_room(
			candidate,
			boss_parent_cell,
			occupied_cells
		):
			continue

		reserved_boss_cell = candidate
		boss_cell_reserved = true

		# Временно отмечаем клетку занятой,
		# чтобы боковые ветки не заняли её
		# и не прижались к будущей BOSS-комнате.
		occupied_cells[
			reserved_boss_cell
		] = true

		break

	if not boss_cell_reserved:
		push_warning(
			"Не удалось зарезервировать "
			+ "клетку для BOSS-комнаты."
		)

		return layout
		
	for _index in range(
		main_room_count
	):
		var directions := (
			_get_grid_directions()
		)

		directions.shuffle()

		var new_cell := Vector2i.ZERO
		var found: bool = false

		for direction in directions:
			var candidate: Vector2i = (
				current_cell
				+ direction
			)

			if not _can_place_branch_room(
				candidate,
				current_cell,
				occupied_cells
			):
				continue

			new_cell = candidate
			found = true
			break

		if not found:
			push_warning(
				"Не удалось продолжить основной путь."
			)
			break

		var new_entry: Dictionary = {
			"cell": new_cell,
			"parent": current_parent_index,
			"main_path": true
		}

		layout.append(
			new_entry
		)

		occupied_cells[
			new_cell
		] = true

		current_cell = new_cell
		current_parent_index = (
			layout.size() - 1
		)

	# =====================================================
	# БОКОВЫЕ ВЕТКИ
	# =====================================================

	for _branch_index in range(
		branch_count
	):
		var possible_parents: Array[int] = []

		# Не цепляем боковую ветку
		# к START по возможности.
		for index in range(
			1,
			layout.size()
		):
			possible_parents.append(
				index
			)

		possible_parents.shuffle()

		var branch_created: bool = false

		for parent_index in possible_parents:
			var parent_entry: Dictionary = (
				layout[parent_index]
			)

			var parent_cell: Vector2i = (
				parent_entry["cell"]
			)

			var directions := (
				_get_grid_directions()
			)

			directions.shuffle()

			for direction in directions:
				var candidate: Vector2i = (
					parent_cell
					+ direction
				)

				if not _can_place_branch_room(
					candidate,
					parent_cell,
					occupied_cells
				):
					continue

				var branch_entry: Dictionary = {
					"cell": candidate,
					"parent": parent_index,
					"main_path": false
				}

				layout.append(
					branch_entry
				)

				occupied_cells[
					candidate
				] = true

				branch_created = true
				break

			if branch_created:
				break

	# =====================================================
	# BOSS
	# =====================================================

	if boss_cell_reserved:
		layout.append(
			{
				"cell": reserved_boss_cell,
				"parent": boss_parent_index,
				"main_path": true,
				"boss": true
			}
		)

	return layout

func _get_grid_directions() -> Array[Vector2i]:
	return [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT
	]

func _can_place_branch_room(
	cell: Vector2i,
	parent_cell: Vector2i,
	occupied_cells: Dictionary
) -> bool:
	if occupied_cells.has(cell):
		return false

	var adjacent_rooms: int = 0

	for direction in _get_grid_directions():
		var neighbour: Vector2i = (
			cell + direction
		)

		if not occupied_cells.has(
			neighbour
		):
			continue

		adjacent_rooms += 1

		# Новая комната должна касаться
		# только своего родителя.
		if neighbour != parent_cell:
			return false

	return adjacent_rooms == 1



func _route_cell_to_position(
	cell: Vector2i
) -> Vector2:
	return Vector2(
		float(
			cell.x
			* (room_width + room_spacing)
		),
		float(
			cell.y
			* (room_height + room_spacing)
		)
	)

func generate_dungeon(root_node: Node) -> void:
	_clear_existing_rooms()

	generated_room_layout.clear()
	room_by_cell.clear()
	cell_by_room.clear()
	room_connections.clear()

	# =====================================================
	# ПРОВЕРКИ
	# =====================================================

	if start_room_scene == null:
		push_error(
			"Не назначена стартовая комната."
		)
		return

	if end_room_scene == null:
		push_error(
			"Не назначена конечная комната."
		)
		return

	if room_pool.is_empty():
		push_error(
			"Пул промежуточных комнат пуст."
		)
		return

	# =====================================================
	# ГЕНЕРАЦИЯ ГРАФА
	# =====================================================

	var requested_intermediate_count: int = (
		randi_range(
			min_rooms,
			max_rooms
		)
	)

	const MAX_LAYOUT_ATTEMPTS: int = 20

	var layout_created: bool = false

	for attempt in range(
		MAX_LAYOUT_ATTEMPTS
	):
		var candidate_layout: Array[Dictionary] = (
			_generate_room_layout(
				requested_intermediate_count
			)
		)

		if candidate_layout.size() < 2:
			continue

		var candidate_last: Dictionary = (
			candidate_layout[
				candidate_layout.size() - 1
			]
		)

		var has_boss_at_end: bool = bool(
			candidate_last.get(
				"boss",
				false
			)
		)

		if not has_boss_at_end:
			print(
				"[DUNGEON] Неудачная попытка layout: ",
				attempt + 1,
				"/",
				MAX_LAYOUT_ATTEMPTS
			)

			continue

		generated_room_layout = (
			candidate_layout
		)

		layout_created = true

		if attempt > 0:
			print(
				"[DUNGEON] Layout создан "
				+ "с попытки ",
				attempt + 1
			)

		break

	if not layout_created:
		push_error(
			"Не удалось создать layout "
			+ "с BOSS-комнатой после "
			+ str(MAX_LAYOUT_ATTEMPTS)
			+ " попыток."
		)

		return

	if generated_room_layout.size() < 2:
		push_error(
			"Генератор не создал корректный layout."
		)
		return

	var last_entry: Dictionary = (
		generated_room_layout[
			generated_room_layout.size() - 1
		]
	)

	if not bool(
		last_entry.get(
			"boss",
			false
		)
	):
		push_error(
			"В конце layout отсутствует BOSS-комната."
		)
		return

	# Реальное количество промежуточных комнат.
	# Это надёжнее requested_intermediate_count,
	# потому что layout является источником истины.
	var intermediate_count: int = (
		generated_room_layout.size() - 2
	)

	print(
		"[DUNGEON] requested_intermediate=",
		requested_intermediate_count,
		" | actual_intermediate=",
		intermediate_count
	)

	for layout_index in range(
		generated_room_layout.size()
	):
		var entry: Dictionary = (
			generated_room_layout[
				layout_index
			]
		)

		print(
			"[ROOM GRAPH] ",
			layout_index,
			" | cell=",
			entry["cell"],
			" | parent=",
			entry["parent"],
			" | main=",
			entry["main_path"],
			" | boss=",
			bool(
				entry.get(
					"boss",
					false
				)
			)
		)

	# =====================================================
	# ТИПЫ СПЕЦИАЛЬНЫХ КОМНАТ
	# =====================================================

	var treasure_room_index: int = -1

	if intermediate_count > 0:
		treasure_room_index = (
			randi_range(
				0,
				intermediate_count - 1
			)
		)

	var shop_room_index: int = -1

	# Магазин создаём только если
	# промежуточных комнат хотя бы три.
	if intermediate_count >= 3:
		var available_indices: Array[int] = []

		for index in range(
			intermediate_count
		):
			if index == treasure_room_index:
				continue

			available_indices.append(
				index
			)

		if not available_indices.is_empty():
			shop_room_index = (
				available_indices.pick_random()
			)

	# =====================================================
	# START ROOM
	# layout index = 0
	# room_instances index = 0
	# =====================================================

	var start_entry: Dictionary = (
		generated_room_layout[0]
	)

	var start_cell: Vector2i = (
		start_entry["cell"]
		as Vector2i
	)

	var start_position: Vector2 = (
		_route_cell_to_position(
			start_cell
		)
	)

	var start_room := _create_room(
		start_room_scene,
		"StartRoom",
		root_node,
		start_position,
		Room.RoomType.START
	)

	if start_room == null:
		return

	room_instances.append(
		start_room
	)

	room_by_cell[start_cell] = (
		start_room
	)

	cell_by_room[start_room] = (
		start_cell
	)

	room_connections[start_room] = []

	spawn_enemies_for_room(
		start_room,
		0
	)

	# =====================================================
	# ПРОМЕЖУТОЧНЫЕ КОМНАТЫ
	#
	# layout:
	# 0            = START
	# 1...size - 2 = обычные комнаты
	# size - 1     = BOSS
	# =====================================================

	for layout_index in range(
		1,
		generated_room_layout.size() - 1
	):
		var entry: Dictionary = (
			generated_room_layout[
				layout_index
			]
		)

		var room_cell: Vector2i = (
			entry["cell"]
			as Vector2i
		)

		var room_position: Vector2 = (
			_route_cell_to_position(
				room_cell
			)
		)

		var random_scene: PackedScene = (
			room_pool.pick_random()
		)

		var intermediate_index: int = (
			layout_index - 1
		)

		var generated_room_type: int = (
			Room.RoomType.COMBAT
		)

		if (
			intermediate_index
			== treasure_room_index
		):
			generated_room_type = (
				Room.RoomType.TREASURE
			)

		elif (
			intermediate_index
			== shop_room_index
		):
			generated_room_type = (
				Room.RoomType.SHOP
			)

		var room := _create_room(
			random_scene,
			"Room" + str(layout_index),
			root_node,
			room_position,
			generated_room_type
		)

		if room == null:
			push_error(
				"Не удалось создать комнату "
				+ str(layout_index)
			)
			return

		# КРИТИЧНО:
		# порядок room_instances должен
		# полностью совпадать с layout.
		room_instances.append(
			room
		)

		room_by_cell[room_cell] = room
		cell_by_room[room] = room_cell
		room_connections[room] = []

		if (
			generated_room_type
			== Room.RoomType.TREASURE
		):
			room.call_deferred(
				"spawn_chest"
			)

		elif (
			generated_room_type
			== Room.RoomType.SHOP
		):
			room.call_deferred(
				"spawn_merchant"
			)

		else:
			spawn_enemies_for_room(
				room,
				layout_index
			)

	# =====================================================
	# BOSS ROOM
	# Последний элемент layout
	# =====================================================

	var boss_entry: Dictionary = (
		generated_room_layout[
			generated_room_layout.size() - 1
		]
	)

	var end_cell: Vector2i = (
		boss_entry["cell"]
		as Vector2i
	)

	var end_position: Vector2 = (
		_route_cell_to_position(
			end_cell
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

	room_instances.append(
		end_room
	)

	room_by_cell[end_cell] = end_room
	cell_by_room[end_room] = end_cell
	room_connections[end_room] = []

	# =====================================================
	# КОНТЕНТ
	# =====================================================

	_spawn_end_room_content(
		end_room
	)

	_assign_guaranteed_key_carrier()

	# =====================================================
	# СОЕДИНЕНИЯ
	# =====================================================

	connect_rooms()

	disable_unconnected_doors()

	# =====================================================
	# DEBUG ГРАФА
	# =====================================================

	for room in room_instances:
		var connections: Array = (
			room_connections.get(
				room,
				[]
			)
		)

		print(
			"[ROOM CONNECTIONS] ",
			room.name,
			" | doors=",
			connections.size()
		)

	# =====================================================
	# ВХОД НА ЭТАЖ
	# =====================================================

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

	var location_profile: LocationProfile = (
		_create_random_location_profile()
	)

	if room.has_method(
		&"apply_location"
	):
		room.call(
			&"apply_location",
			location_profile
		)

		print(
			"[LOCATION] ",
			room_name,
			" → ",
			location_profile.display_name,
			" | floor=",
			location_profile.floor_type
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
			return enemy

	return null

# =========================================================
# СОЕДИНЕНИЕ КОМНАТ
# =========================================================

func connect_rooms() -> void:
	for child_index in range(
		1,
		generated_room_layout.size()
	):
		var entry: Dictionary = (
			generated_room_layout[
				child_index
			]
		)

		var parent_index: int = int(
			entry["parent"]
		)

		if parent_index < 0:
			continue

		if (
			child_index
			>= room_instances.size()
		):
			continue

		if (
			parent_index
			>= room_instances.size()
		):
			continue

		var child_room: Node2D = (
			room_instances[
				child_index
			]
		)

		var parent_room: Node2D = (
			room_instances[
				parent_index
			]
		)

		if not is_instance_valid(
			child_room
		):
			continue

		if not is_instance_valid(
			parent_room
		):
			continue

		_connect_rooms_by_position(
			parent_room,
			child_room
		)

		_register_room_connection(
			parent_room,
			child_room
		)

func _connect_rooms_by_position(
	current_room: Node2D,
	next_room: Node2D
) -> void:
	var current_direction: int = (
		_get_direction_between_rooms(
			current_room,
			next_room
		)
	)

	if current_direction == -1:
		push_warning(
			"Не удалось определить направление между "
			+ current_room.name
			+ " и "
			+ next_room.name
		)
		return

	var next_direction: int = (
		_get_opposite_direction(
			current_direction
		)
	)

	var current_door: Node = (
		_get_room_door(
			current_room,
			current_direction,
			_get_legacy_door_name(
				current_direction
			)
		)
	)

	var next_door: Node = (
		_get_room_door(
			next_room,
			next_direction,
			_get_legacy_door_name(
				next_direction
			)
		)
	)

	if current_door == null:
		push_warning(
			"В комнате "
			+ current_room.name
			+ " нет двери направления "
			+ str(current_direction)
		)
		return

	if next_door == null:
		push_warning(
			"В комнате "
			+ next_room.name
			+ " нет двери направления "
			+ str(next_direction)
		)
		return

	_connect_door_pair(
		current_door,
		next_door,
		current_room,
		next_room
	)

func _register_room_connection(
	room_a: Node2D,
	room_b: Node2D
) -> void:
	if not room_connections.has(room_a):
		room_connections[room_a] = []

	if not room_connections.has(room_b):
		room_connections[room_b] = []

	var connections_a: Array = (
		room_connections[room_a]
	)

	var connections_b: Array = (
		room_connections[room_b]
	)

	if not connections_a.has(room_b):
		connections_a.append(room_b)

	if not connections_b.has(room_a):
		connections_b.append(room_a)

	room_connections[room_a] = connections_a
	room_connections[room_b] = connections_b

func _get_direction_between_rooms(
	from_room: Node2D,
	to_room: Node2D
) -> int:
	var delta: Vector2 = (
		to_room.global_position
		- from_room.global_position
	)

	if (
		is_zero_approx(delta.x)
		and is_zero_approx(delta.y)
	):
		return -1

	if abs(delta.x) >= abs(delta.y):
		if delta.x > 0.0:
			return DoorSocket.Direction.RIGHT

		return DoorSocket.Direction.LEFT

	if delta.y > 0.0:
		return DoorSocket.Direction.BOTTOM

	return DoorSocket.Direction.TOP

func _get_opposite_direction(
	direction: int
) -> int:
	match direction:
		DoorSocket.Direction.TOP:
			return DoorSocket.Direction.BOTTOM

		DoorSocket.Direction.RIGHT:
			return DoorSocket.Direction.LEFT

		DoorSocket.Direction.BOTTOM:
			return DoorSocket.Direction.TOP

		DoorSocket.Direction.LEFT:
			return DoorSocket.Direction.RIGHT

	return -1

func _get_legacy_door_name(
	direction: int
) -> StringName:
	match direction:
		DoorSocket.Direction.RIGHT:
			return &"DoorRight"

		DoorSocket.Direction.LEFT:
			return &"DoorLeft"

	return &""

func _get_room_door(
	room: Node2D,
	direction: int,
	legacy_name: StringName
) -> Node:
	if room == null:
		return null

	# Сначала ищем универсальный DoorSocket.
	if room.has_method(
		&"get_door_socket"
	):
		var socket: Variant = room.call(
			&"get_door_socket",
			direction
		)

		if socket is DoorSocket:
			return socket as DoorSocket

	# У старой системы нет верхней
	# и нижней двери.
	if legacy_name == &"":
		return null

	# Пока комната не переведена на новую систему,
	# используем старую дверь.
	return _find_child_recursive(
		room,
		String(legacy_name)
	)

func _connect_door_pair(
	current_door: Node,
	next_door: Node,
	current_room: Node2D,
	next_room: Node2D
) -> void:
	_configure_connected_door(
		current_door,
		next_door,
		next_room
	)

	_configure_connected_door(
		next_door,
		current_door,
		current_room
	)

func _configure_connected_door(
	door: Node,
	linked_door: Node,
	target_room: Node2D
) -> void:
	if not is_instance_valid(door):
		return

	if not is_instance_valid(target_room):
		return

	# Новая универсальная дверь.
	if door.has_method(
		&"connect_to"
	):
		door.call(
			&"connect_to",
			linked_door,
			target_room
		)
		return

	# Старая Door.gd.
	door.set(
		&"target_room_node",
		target_room
	)

	# Старое поле принимает только Area2D.
	# DoorSocket является Node2D, поэтому при
	# смешанном соединении это поле не заполняем.
	if linked_door is Area2D:
		door.set(
			&"linked_door",
			linked_door
		)

# =========================================================
# ОТКЛЮЧЕНИЕ ДВЕРЕЙ БЕЗ СОЕДИНЕНИЙ
# =========================================================

func disable_unconnected_doors() -> void:
	for room in room_instances:
		if not is_instance_valid(room):
			continue

		var room_doors: Array[Node] = []

		_collect_doors(
			room,
			room_doors
		)

		for door in room_doors:
			if not is_instance_valid(door):
				continue

			var target_room: Variant = door.get(
				&"target_room_node"
			)

			# Соединённую дверь не отключаем.
			if target_room != null:
				continue

			# Универсальный DoorSocket сам скрывает
			# графику и выключает свои коллизии.
			if door.has_method(
				&"clear_connection"
			):
				door.call(
					&"clear_connection"
				)
				continue

			# Поддержка старой Door.gd.
			if door.has_method(
				&"set_open"
			):
				door.call(
					&"set_open",
					false
				)

			if door is Area2D:
				var door_area := door as Area2D

				door_area.set_deferred(
					&"monitoring",
					false
				)

				door_area.set_deferred(
					&"monitorable",
					false
				)

# =========================================================
# DEBUG: ЗАМЕНА КОМНАТЫ НА БОСС-КОМНАТУ
# =========================================================

func _replace_room_with_debug_boss(
	room_node: Node2D
) -> void:
	var selected_boss_scene: PackedScene = (
		debug_next_room_boss_scene
	)

	# Выбор одноразовый.
	debug_next_room_boss_scene = null

	if selected_boss_scene == null:
		return

	var room := room_node as Room

	if room == null:
		push_warning(
			"[DEBUG] Целевая комната не использует Room.gd."
		)
		return

	_clear_debug_room_content(room)

	room.set_active(false)
	room.set_room_type(
		Room.RoomType.BOSS
	)

	room.is_cleared = false
	room.enemies.clear()

	var boss_created: bool = (
		_spawn_debug_boss(
			room,
			selected_boss_scene
		)
	)

	if not boss_created:
		push_warning(
			"[DEBUG] Не удалось создать выбранного босса."
		)
		return

	room.update_enemies_list()
	room.minimap_marker_changed.emit()

	print(
		"[DEBUG] Комната "
		+ room.name
		+ " заменена на босс-комнату."
	)


func _clear_debug_room_content(
	room: Room
) -> void:
	var nodes_to_remove: Array[Node] = []

	var removable_groups: Array[StringName] = [
		&"Enemies",
		&"Bosses",
		&"FloorChests",
		&"Merchants"
	]

	for group_name in removable_groups:
		for node in get_tree().get_nodes_in_group(
			group_name
		):
			if not is_instance_valid(node):
				continue

			if not room.is_ancestor_of(node):
				continue

			if nodes_to_remove.has(node):
				continue

			nodes_to_remove.append(node)

	# Страховка для сундука и торговца,
	# даже если они не добавлены в группы.
	var generated_names: Array[StringName] = [
		&"GeneratedChest",
		&"GeneratedMerchant"
	]

	for generated_name in generated_names:
		var generated_node: Node = (
			room.get_node_or_null(
				NodePath(
					String(generated_name)
				)
			)
		)

		if not is_instance_valid(generated_node):
			continue

		if nodes_to_remove.has(generated_node):
			continue

		nodes_to_remove.append(generated_node)

	for node in nodes_to_remove:
		if not is_instance_valid(node):
			continue

		var parent: Node = node.get_parent()

		# Убираем из дерева сразу, чтобы
		# update_enemies_list() его уже не видел.
		if parent != null:
			parent.remove_child(node)

		node.queue_free()


func _spawn_debug_boss(
	room: Room,
	selected_boss_scene: PackedScene
) -> bool:
	if selected_boss_scene == null:
		return false

	var instance: Node = (
		selected_boss_scene.instantiate()
	)

	var boss := instance as Node2D

	if boss == null:
		if instance != null:
			instance.free()

		return false

	boss.position = Vector2(
		float(room_width) * 0.5,
		float(room_height) * 0.5
	)

	room.add_child(boss)

	if boss.has_method(
		&"set_room_limits"
	):
		boss.call(
			&"set_room_limits",
			Rect2(
				room.global_position,
				Vector2(
					float(room_width),
					float(room_height)
				)
			)
		)

	# Босс включится стандартным
	# on_room_entered() после перехода.
	if boss.has_method(
		&"set_active"
	):
		boss.call(
			&"set_active",
			false
		)
	else:
		boss.process_mode = (
			Node.PROCESS_MODE_DISABLED
		)

	return true

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

	var is_entering_another_room: bool = (
		index != current_room_index
	)

	# Замена должна произойти ДО изменения
	# current_room_index и ДО on_room_entered().
	if (
		debug_next_room_boss_scene != null
		and is_entering_another_room
	):
		_replace_room_with_debug_boss(
			room_instances[index]
		)

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

	room_changed.emit(
		room.name,
		index
	)

	if room.has_method(
		"on_room_entered"
	):
		room.on_room_entered()
	else:
		push_warning(
			"У комнаты нет метода "
			+ "on_room_entered: "
			+ room.name
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
	room_index: int
) -> void:
	var count := 0

	if room.name == "StartRoom":
		count = enemies_in_start_room

	elif room.name == "EndRoom":
		count = enemies_in_end_room

	else:
		var room_progression_bonus: int = floori(
			float(room_index) / 2.0
		)

		# Каждые два этажа базовое количество
		# врагов увеличивается ещё на одного.
		var floor_progression_bonus: int = floori(
			float(
				maxi(
					GameManager.current_floor,
					1
				)
			) / 2.0
		)

		var floor_minimum: int = (
			min_enemies_per_room
			+ floor_progression_bonus
		)

		var floor_maximum: int = (
			max_enemies_per_room
			+ floor_progression_bonus
		)

		count = clampi(
			min_enemies_per_room
			+ room_progression_bonus
			+ floor_progression_bonus,
			floor_minimum,
			floor_maximum
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
	result: Array[Node]
) -> void:
	for child in node.get_children():
		var is_old_door: bool = (
			child is Area2D
			and (
				child.name == &"DoorLeft"
				or child.name == &"DoorRight"
			)
		)

		var is_door_socket: bool = (
			child is DoorSocket
		)

		if (
			is_old_door
			or is_door_socket
		):
			if not result.has(child):
				result.append(child)

			continue

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

	debug_next_room_boss_scene = null

	_clear_existing_rooms()


func _clear_existing_rooms() -> void:
	for room in room_instances:
		if is_instance_valid(room):
			room.queue_free()

	room_instances.clear()
