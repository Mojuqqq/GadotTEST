extends Node2D
class_name Room

signal minimap_marker_changed

const MERCHANT_SCENE: PackedScene = preload("res://Scenes/Interactables/NPC/Merchant.tscn")

enum RoomType {
	START,
	COMBAT,
	TREASURE,
	SHOP,
	BOSS
}



@export_group("Room Settings")
var room_type: RoomType = RoomType.COMBAT
@export_group("Enemy Spawn")
@export_group("Door Socket Test")

@export var right_connection_enabled: bool = true

@export_range(80.0, 250.0, 10.0)
var enemy_wall_margin: float = 140.0

@export_range(40.0, 200.0, 10.0)
var enemy_spawn_spacing: float = 100.0

@export_range(1, 50, 1)
var enemy_spawn_attempts: int = 20

var doors: Array = []
var enemies: Array = []
var is_cleared: bool = false
var is_active: bool = false

func _ready() -> void:
	doors.clear()
	find_doors_recursive(self)
	_apply_right_connection_state()
	update_enemies_list()  
	set_active(false)


func apply_location(
	profile: LocationProfile
) -> void:
	if profile == null:
		push_warning(
			"Для комнаты "
			+ name
			+ " не назначен LocationProfile."
		)

		return

	location_profile = profile

	_generate_floor()

func _generate_floor() -> void:
	if location_profile == null:
		push_warning(
			"Нет LocationProfile у комнаты: "
			+ name
		)
		return

	var floor_layer := (
		get_node_or_null("Floor")
		as TileMapLayer
	)

	if floor_layer == null:
		push_warning(
			"В комнате "
			+ name
			+ " нет TileMapLayer Floor."
		)
		return

	var floor_tile_set: TileSet = (
		floor_layer.tile_set
	)

	if floor_tile_set == null:
		push_warning(
			"У Floor не назначен floor_tileset."
		)
		return

	var terrain_index: int = (
		_get_floor_terrain(
			location_profile.floor_type
		)
	)

	var tile_size: Vector2i = (
		floor_tile_set.tile_size
	)

	var columns: int = ceili(
		float(GameManager.room_width)
		/ float(tile_size.x)
	)

	var rows: int = ceili(
		float(GameManager.room_height)
		/ float(tile_size.y)
	)

	var cells: Array[Vector2i] = []

	for y in range(rows):
		for x in range(columns):
			cells.append(
				Vector2i(x, y)
			)

	floor_layer.clear()

	floor_layer.set_cells_terrain_connect(
		cells,
		0,
		terrain_index
	)

	print(
		"[FLOOR] ",
		name,
		" | ",
		location_profile.display_name,
		" | terrain=",
		terrain_index,
		" | cells=",
		cells.size()
	)

func _apply_right_connection_state() -> void:
	var closed_socket := (
		get_node_or_null(
			"DoorSocketRightClosed"
		) as TileMapLayer
	)

	var open_socket := (
		get_node_or_null(
			"DoorSocketRightOpen"
		) as TileMapLayer
	)

	# У старых комнат пока нет новых слоёв.
	# Для них функция просто ничего не делает.
	if (
		closed_socket == null
		and open_socket == null
	):
		return

	if (
		closed_socket == null
		or open_socket == null
	):
		push_warning(
			"В комнате "
			+ name
			+ " правый дверной сокет настроен не полностью."
		)

		return

	closed_socket.enabled = (
		not right_connection_enabled
	)

	open_socket.enabled = (
		right_connection_enabled
	)

	var door_graphics := (
		get_node_or_null(
			"Doors"
		) as TileMapLayer
	)

	if door_graphics != null:
		door_graphics.enabled = (
			right_connection_enabled
		)

	var right_door := (
		get_node_or_null(
			"DoorRight"
		) as Area2D
	)

	if right_door == null:
		return

	if right_door.has_method(
		&"set_connection_enabled"
	):
		right_door.call(
			&"set_connection_enabled",
			right_connection_enabled
		)

func set_active(active: bool) -> void:
	is_active = active

	# При активации заново собираем список.
	# Это важно, потому что враги создаются после _ready комнаты.
	if active:
		update_enemies_list()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.is_queued_for_deletion():
			continue

		if enemy.has_method("set_active"):
			enemy.set_active(active)
		else:
			push_warning(
				"У врага "
				+ enemy.name
				+ " отсутствует set_active()"
			)


func find_doors_recursive(
	node: Node
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
			if not doors.has(child):
				doors.append(child)

			continue

		find_doors_recursive(child)

func get_door_socket(
	direction: int
) -> DoorSocket:
	for door in doors:
		if not is_instance_valid(door):
			continue

		if not door is DoorSocket:
			continue

		var socket := door as DoorSocket

		if socket.direction == direction:
			return socket

	return null

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
	_request_enemy_counter_refresh()


func _request_enemy_counter_refresh() -> void:
	# Неактивная комната не должна
	# менять данные текущего HUD.
	if not is_active:
		return

	var current_room: Node2D = (
		GameManager.get_current_room()
	)

	if current_room != self:
		return

	# Обновляем на следующем кадре.
	# Это важно при смерти врага:
	# сигнал died испускается раньше queue_free().
	GameManager.call_deferred(
		&"update_enemy_count"
	)

func on_room_entered() -> void:

	update_enemies_list()

	# Стартовая комната и сокровищница
	# не запускают боевую блокировку дверей.
	if (
		is_start_room()
		or is_treasure_room()
		or is_shop_room()
	):
		unlock_doors()
		set_active(true)
		return

	# Боевые комнаты и комната босса.
	if enemies.is_empty():
		unlock_doors()
	else:
		lock_doors()

	set_active(true)

func lock_doors():
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(false)

func unlock_doors():
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(true)

func _on_enemy_died(
	victim: Node
) -> void:

	var enemy_index: int = enemies.find(
		victim
	)
	if enemy_index >= 0:
		enemies.remove_at(enemy_index)

	_request_enemy_counter_refresh()

	# Награда и открытие дверей происходят
	# только после смерти последнего врага.
	if (
		not enemies.is_empty()
		or is_cleared
	):
		return

	is_cleared = true

	if is_boss_room():
		minimap_marker_changed.emit()

	unlock_doors()


	# В комнате босса награда появляется
	# только после полной очистки комнаты.
	if not is_boss_room():
		return

	call_deferred(
		"spawn_chest"
	)

func spawn_enemies(
	count: int,
	enemy_pool: Array
) -> void:
	if count <= 0 or enemy_pool.is_empty():
		return

	var room_width: float = float(
		GameManager.room_width
	)

	var room_height: float = float(
		GameManager.room_height
	)

	var safe_width: float = maxf(
		room_width - enemy_wall_margin * 2.0,
		1.0
	)

	var safe_height: float = maxf(
		room_height - enemy_wall_margin * 2.0,
		1.0
	)

	# Врагам передаются не внешние границы комнаты,
	# а безопасная область внутри стен.
	var safe_global_limits := Rect2(
		global_position
		+ Vector2(
			enemy_wall_margin,
			enemy_wall_margin
		),
		Vector2(
			safe_width,
			safe_height
		)
	)

	var spawned_positions: Array[Vector2] = []

	for index in range(count):
		var enemy_scene: PackedScene = (
			enemy_pool.pick_random()
		)

		if enemy_scene == null:
			continue

		var enemy := (
			enemy_scene.instantiate()
			as Node2D
		)

		if enemy == null:
			push_warning(
				"Корень сцены врага должен быть Node2D."
			)
			continue

		var spawn_position: Vector2 = (
			_get_enemy_spawn_position(
				spawned_positions,
				room_width,
				room_height
			)
		)

		# Позицию задаём ДО add_child().
		# Так коллизия не появляется сначала
		# в углу комнаты внутри стены.
		enemy.position = spawn_position

		add_child(enemy)

		spawned_positions.append(
			spawn_position
		)

		if enemy.has_method("set_room_limits"):
			enemy.call(
				"set_room_limits",
				safe_global_limits
			)

		if enemy.has_method("set_active"):
			enemy.call(
				"set_active",
				false
			)
		else:
			enemy.process_mode = (
				Node.PROCESS_MODE_DISABLED
			)


func _get_enemy_spawn_position(
	spawned_positions: Array[Vector2],
	room_width: float,
	room_height: float
) -> Vector2:
	var minimum_x: float = enemy_wall_margin
	var maximum_x: float = (
		room_width - enemy_wall_margin
	)

	var minimum_y: float = enemy_wall_margin
	var maximum_y: float = (
		room_height - enemy_wall_margin
	)

	# Страховка на случай слишком маленькой комнаты.
	if (
		minimum_x >= maximum_x
		or minimum_y >= maximum_y
	):
		return Vector2(
			room_width * 0.5,
			room_height * 0.5
		)

	var last_candidate := Vector2(
		room_width * 0.5,
		room_height * 0.5
	)

	for attempt in range(
		enemy_spawn_attempts
	):
		var candidate := Vector2(
			randf_range(
				minimum_x,
				maximum_x
			),
			randf_range(
				minimum_y,
				maximum_y
			)
		)

		last_candidate = candidate

		var position_is_safe: bool = true

		for existing_position in spawned_positions:
			if (
				candidate.distance_to(
					existing_position
				)
				< enemy_spawn_spacing
			):
				position_is_safe = false
				break

		if position_is_safe:
			return candidate

	# При плотном заполнении комнаты возвращается
	# последняя найденная позиция, но она всё равно
	# находится далеко от стен.
	return last_candidate

func _get_available_reward_items() -> Array[ItemData]:
	var available_items: Array[ItemData] = []

	for item in GameManager.all_items:
		if item == null:
			continue

		if (
			item.use_mode
			== ItemData.UseMode.PASSIVE
			and not GameManager.can_receive_passive_upgrade(
				item
			)
		):
			continue

		available_items.append(
			item
		)

	return available_items

func spawn_chest() -> void:
	if (
		not is_treasure_room()
		and not is_boss_room()
	):
		push_warning(
			"Попытка создать сундук "
			+ "в неподходящей комнате: "
			+ name
		)

		return

	if GameManager.all_items.is_empty():
		push_warning(
			"Нельзя создать сундук: список предметов пуст."
		)
		return

	var existing_chest := get_node_or_null(
		"GeneratedChest"
	)

	if existing_chest != null:
		return

	var available_items: Array[ItemData] = (
		_get_available_reward_items()
	)

	if available_items.is_empty():
		push_warning(
			"Нельзя создать сундук: "
			+ "нет доступных наград."
		)
		return

	var item: ItemData = (
		available_items.pick_random()
	)

	var chest_scene: PackedScene = preload(
		"res://Scenes/Interactables/Chest.tscn"
	)

	var chest := chest_scene.instantiate()

	if chest == null:
		push_warning(
			"Не удалось создать сундук."
		)
		return

	chest.name = "GeneratedChest"
	chest.item = item

	if chest.has_signal(&"opened"):
		chest.connect(
			&"opened",
			Callable(
				self,
				"_on_room_chest_opened"
			),
			CONNECT_ONE_SHOT
		)

	if is_boss_room():
		if chest.has_signal("collected"):
			chest.connect(
				"collected",
				Callable(
					self,
					"_on_boss_reward_collected"
				),
				CONNECT_ONE_SHOT
			)

	add_child(chest)

	var chest_spawn_point := get_node_or_null(
		"ChestSpawnPoint"
	) as Marker2D

	if chest_spawn_point != null:
		chest.position = chest_spawn_point.position
	else:
		chest.position = Vector2(
			GameManager.room_width * 0.5,
			GameManager.room_height * 0.5
		)

func _on_room_chest_opened() -> void:
	minimap_marker_changed.emit()

func _on_boss_reward_collected(
	_item: ItemData,
	_amount: int
) -> void:
	
	if GameManager.floor_completed:
		return

	GameManager.complete_floor()
	

	GameManager.trigger_game_over(
		true
	)

func has_active_minimap_marker() -> bool:
	match room_type:
		RoomType.TREASURE:
			var chest: Node = get_node_or_null(
				"GeneratedChest"
			)

			if not is_instance_valid(chest):
				return false

			if chest.is_queued_for_deletion():
				return false

			if not chest.has_method(
				&"has_uncollected_reward"
			):
				return false

			return bool(
				chest.call(
					&"has_uncollected_reward"
				)
			)

		RoomType.SHOP:
			var merchant: Node = get_node_or_null(
				"GeneratedMerchant"
			)

			if not is_instance_valid(merchant):
				return false

			if merchant.is_queued_for_deletion():
				return false

			if not merchant.has_method(
				&"has_unsold_offers"
			):
				return false

			return bool(
				merchant.call(
					&"has_unsold_offers"
				)
			)

		RoomType.BOSS:
			return not is_cleared

		_:
			return false

func set_room_type(new_type: RoomType) -> void:
	room_type = new_type
	
func is_start_room() -> bool:
	return room_type == RoomType.START


func is_combat_room() -> bool:
	return room_type == RoomType.COMBAT


func is_treasure_room() -> bool:
	return room_type == RoomType.TREASURE


func is_shop_room() -> bool:
	return room_type == RoomType.SHOP


func is_boss_room() -> bool:
	return room_type == RoomType.BOSS

func spawn_merchant() -> void:
	if not is_shop_room():
		push_warning(
			"Попытка создать торговца не в SHOP-комнате: "
			+ name
		)
		return

	var existing_merchant := get_node_or_null(
		"GeneratedMerchant"
	)

	if existing_merchant != null:
		return

	if MERCHANT_SCENE == null:
		push_error(
			"Не удалось загрузить сцену торговца."
		)
		return

	var merchant := (
		MERCHANT_SCENE.instantiate()
		as Node2D
	)

	if merchant == null:
		push_error(
			"Корень Merchant.tscn должен быть Node2D."
		)
		return

	merchant.name = "GeneratedMerchant"

	if merchant.has_signal(&"stock_changed"):
		merchant.connect(
			&"stock_changed",
			Callable(
				self,
				"_on_shop_stock_changed"
			)
		)

	add_child(merchant)

	var spawn_point := get_node_or_null(
		"MerchantSpawnPoint"
	) as Marker2D

	if spawn_point != null:
		merchant.global_position = (
			spawn_point.global_position
		)
	else:
		merchant.position = Vector2(
			GameManager.room_width * 0.5,
			GameManager.room_height * 0.5
		)


func _on_shop_stock_changed() -> void:
	minimap_marker_changed.emit()
