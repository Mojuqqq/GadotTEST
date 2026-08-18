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

@onready var tutorial_graphic: Sprite2D = (
	get_node_or_null("TutorialGraphic")
	as Sprite2D
)

var doors: Array = []
var enemies: Array = []
var is_cleared: bool = false
var is_active: bool = false
var boss_intro_played: bool = false

var location_profile: LocationProfile = null

func _ready() -> void:
	doors.clear()
	find_doors_recursive(self)
	_connect_door_socket_signals()
	_apply_right_connection_state()
	update_enemies_list()

	_update_tutorial_graphic()

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
	_generate_walls()
	_apply_door_visuals()
	_generate_decor()

func _connect_door_socket_signals() -> void:
	for door in doors:
		var socket := door as DoorSocket

		if socket == null:
			continue

		if not socket.state_changed.is_connected(
			_on_door_socket_state_changed
		):
			socket.state_changed.connect(
				_on_door_socket_state_changed
			)

func _on_door_socket_state_changed(
	socket: DoorSocket,
	_is_open: bool
) -> void:
	_update_door_gap(socket)

func _update_door_gap(
	socket: DoorSocket
) -> void:
	if location_profile == null:
		return

	var walls_layer := (
		get_node_or_null(^"Walls")
		as TileMapLayer
	)

	if walls_layer == null:
		return

	if walls_layer.tile_set == null:
		return

	var tiles: Dictionary = (
		LocationProfile.WALL_TILES[
			location_profile.wall_type
		]
	)

	var source_id: int = (
		walls_layer.tile_set.get_source_id(0)
	)

	var tile_size: Vector2i = (
		walls_layer.tile_set.tile_size
	)

	var columns: int = ceili(
		float(GameManager.room_width)
		/ float(tile_size.x)
	)

	var rows: int = ceili(
		float(GameManager.room_height)
		/ float(tile_size.y)
	)

	var horizontal_right: int = floori(
		float(columns) / 2.0
	)

	var horizontal_left: int = (
		horizontal_right - 1
	)

	var vertical_bottom: int = floori(
		float(rows) / 2.0
	)

	var vertical_top: int = (
		vertical_bottom - 1
	)

	var gap_cells: Array[Vector2i] = []
	var wall_key: String = ""

	match socket.direction:
		DoorSocket.Direction.TOP:
			gap_cells = [
				Vector2i(horizontal_left, 0),
				Vector2i(horizontal_right, 0)
			]
			wall_key = "top"

		DoorSocket.Direction.RIGHT:
			gap_cells = [
				Vector2i(columns - 1, vertical_top),
				Vector2i(columns - 1, vertical_bottom)
			]
			wall_key = "right"

		DoorSocket.Direction.BOTTOM:
			gap_cells = [
				Vector2i(
					horizontal_left,
					rows - 1
				),
				Vector2i(
					horizontal_right,
					rows - 1
				)
			]
			wall_key = "bottom"

		DoorSocket.Direction.LEFT:
			gap_cells = [
				Vector2i(0, vertical_top),
				Vector2i(0, vertical_bottom)
			]
			wall_key = "left"

		_:
			return

	# Есть соседняя комната:
	# убираем две клетки стены.
	if socket.connection_enabled:
		for cell in gap_cells:
			walls_layer.erase_cell(cell)

		return

	# Соединения нет:
	# возвращаем обычную стену.
	for cell in gap_cells:
		walls_layer.set_cell(
			cell,
			source_id,
			tiles[wall_key]
		)

func _get_floor_terrain(
	floor_type: LocationProfile.FloorType
) -> int:
	match floor_type:
		LocationProfile.FloorType.DIRT:
			return 0

		LocationProfile.FloorType.GRASS:
			return 1

		LocationProfile.FloorType.WOOD:
			return 2

		_:
			return 0

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

	# Временная область 12 × 10:
	# по одному техническому тайлу вокруг комнаты.
	for y in range(-1, rows + 1):
		for x in range(-1, columns + 1):
			cells.append(
				Vector2i(x, y)
			)

	floor_layer.clear()

	floor_layer.set_cells_terrain_connect(
		cells,
		0,
		terrain_index,
		true
	)

	# Удаляем техническую рамку слева и справа.
	for y in range(-1, rows + 1):
		floor_layer.erase_cell(
			Vector2i(-1, y)
		)

		floor_layer.erase_cell(
			Vector2i(columns, y)
		)

	# Удаляем техническую рамку сверху и снизу.
	for x in range(columns):
		floor_layer.erase_cell(
			Vector2i(x, -1)
		)

		floor_layer.erase_cell(
			Vector2i(x, rows)
		)

	print(
		"[FLOOR RESULT] ",
		name,
		" | terrain=",
		terrain_index,
		" | target=",
		columns * rows,
		" | generated=",
		floor_layer.get_used_cells().size()
	)

func _generate_walls() -> void:
	if location_profile == null:
		return

	if not LocationProfile.WALL_TILES.has(
		location_profile.wall_type
	):
		push_warning(
			"Для местности не настроены тайлы стен: "
			+ str(location_profile.wall_type)
		)
		return

	var tiles: Dictionary = (
		LocationProfile.WALL_TILES[
			location_profile.wall_type
		]
	)

	# Проверяем, что у выбранного типа стен
	# заполнены все необходимые тайлы.
	var required_keys: Array[String] = [
		"top",
		"bottom",
		"left",
		"right",
		"top_left",
		"top_right",
		"bottom_left",
		"bottom_right"
	]

	for key in required_keys:
		if not tiles.has(key):
			push_warning(
				"У типа стен "
				+ str(location_profile.wall_type)
				+ " не настроен тайл: "
				+ key
			)
			return

	var walls_layer := (
		get_node_or_null("Walls")
		as TileMapLayer
	)

	if walls_layer == null:
		push_warning(
			"В комнате "
			+ name
			+ " нет TileMapLayer Walls."
		)
		return

	if walls_layer.tile_set == null:
		push_warning(
			"У Walls не назначен TileSet."
		)
		return

	if walls_layer.tile_set.get_source_count() == 0:
		push_warning(
			"В walls_tileset нет Atlas Source."
		)
		return

	# В walls_tileset сейчас один Atlas Source.
	# Поэтому ID получаем автоматически,
	# а не хардкодим число 1.
	var source_id: int = (
		walls_layer.tile_set.get_source_id(0)
	)

	var tile_size: Vector2i = (
		walls_layer.tile_set.tile_size
	)

	var columns: int = ceili(
		float(GameManager.room_width)
		/ float(tile_size.x)
	)

	var rows: int = ceili(
		float(GameManager.room_height)
		/ float(tile_size.y)
	)

	if columns < 2 or rows < 2:
		push_warning(
			"Размер комнаты слишком маленький "
			+ "для генерации стен."
		)
		return

	# =====================================================
	# ЦЕНТРАЛЬНЫЕ ПРОЁМЫ ДЛЯ ДВЕРЕЙ
	# =====================================================

	# При размере 10 × 8:
	#
	# TOP / BOTTOM:
	# x = 4 и 5
	#
	# LEFT / RIGHT:
	# y = 3 и 4

	var horizontal_door_right: int = floori(
		float(columns) / 2.0
	)

	var horizontal_door_left: int = (
		horizontal_door_right - 1
	)

	var vertical_door_bottom: int = floori(
		float(rows) / 2.0
	)

	var vertical_door_top: int = (
		vertical_door_bottom - 1
	)

	# =====================================================
	# УГЛЫ
	# =====================================================

	walls_layer.set_cell(
		Vector2i(0, 0),
		source_id,
		tiles["top_left"]
	)

	walls_layer.set_cell(
		Vector2i(columns - 1, 0),
		source_id,
		tiles["top_right"]
	)

	walls_layer.set_cell(
		Vector2i(0, rows - 1),
		source_id,
		tiles["bottom_left"]
	)

	walls_layer.set_cell(
		Vector2i(columns - 1, rows - 1),
		source_id,
		tiles["bottom_right"]
	)

	# =====================================================
	# ВЕРХ / НИЗ
	# =====================================================

	for x in range(1, columns - 1):
		var is_door_gap: bool = (
			x == horizontal_door_left
			or x == horizontal_door_right
		)

		if not is_door_gap:
			walls_layer.set_cell(
				Vector2i(x, 0),
				source_id,
				tiles["top"]
			)

			walls_layer.set_cell(
				Vector2i(x, rows - 1),
				source_id,
				tiles["bottom"]
			)

	# =====================================================
	# ЛЕВО / ПРАВО
	# =====================================================

	for y in range(1, rows - 1):
		var is_door_gap: bool = (
			y == vertical_door_top
			or y == vertical_door_bottom
		)

		if not is_door_gap:
			walls_layer.set_cell(
				Vector2i(0, y),
				source_id,
				tiles["left"]
			)

			walls_layer.set_cell(
				Vector2i(columns - 1, y),
				source_id,
				tiles["right"]
			)

	print(
		"[WALLS RESULT] ",
		name,
		" | type=",
		location_profile.wall_type,
		" | size=",
		columns,
		"x",
		rows,
		" | horizontal gap=",
		horizontal_door_left,
		",",
		horizontal_door_right,
		" | vertical gap=",
		vertical_door_top,
		",",
		vertical_door_bottom
	)

func _apply_door_visuals() -> void:
	if location_profile == null:
		return

	if not LocationProfile.DOOR_TEXTURES.has(
		location_profile.wall_type
	):
		return

	var textures: Dictionary = (
		LocationProfile.DOOR_TEXTURES[
			location_profile.wall_type
		]
	)

	for door in doors:
		var socket := door as DoorSocket

		if socket == null:
			continue

		var closed_key: String = ""
		var open_key: String = ""

		match socket.direction:
			DoorSocket.Direction.TOP:
				closed_key = "top_closed"
				open_key = "top_open"

			DoorSocket.Direction.RIGHT:
				closed_key = "right_closed"
				open_key = "right_open"

			DoorSocket.Direction.BOTTOM:
				closed_key = "bottom_closed"
				open_key = "bottom_open"

			DoorSocket.Direction.LEFT:
				closed_key = "left_closed"
				open_key = "left_open"

			_:
				continue

		socket.apply_visuals(
			textures[closed_key],
			textures[open_key]
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

func _update_tutorial_graphic() -> void:
	if tutorial_graphic == null:
		return

	var should_show: bool = (
		room_type == RoomType.START
		and SettingsManager.should_show_tutorial()
	)

	tutorial_graphic.visible = should_show

	if should_show:
		SettingsManager.mark_tutorial_seen()

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
	
	if (
		is_boss_room()
		and not enemies.is_empty()
		and not boss_intro_played
	):
		boss_intro_played = true

		AudioManager.play_sfx(
			&"boss_intro_sting",
			-8.0
		)

	if is_boss_room():
		MusicManager.play_boss()

	elif (
		not enemies.is_empty()
		and not is_start_room()
		and not is_treasure_room()
		and not is_shop_room()
	):
		MusicManager.play_combat()

	else:
		MusicManager.play_farm()

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

func lock_doors() -> void:
	for door in doors:
		if door.has_method("set_open"):
			door.set_open(false)

	AudioManager.play_sfx(
		&"door_lock",
		-11.0,
		0.98,
		1.02
	)

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
		GameManager.complete_floor()

		MusicManager.play_boss_victory()
	else:
		MusicManager.play_farm()

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
		
	minimap_marker_changed.emit()

func _on_room_chest_opened() -> void:
	minimap_marker_changed.emit()

func _on_boss_reward_collected(
	_item: ItemData,
	_amount: int
) -> void:
	if not GameManager.floor_completed:
		GameManager.complete_floor()

	# Получение награды из босс-сундука
	# открывает экран победы.
	GameManager.trigger_game_over(
		true
	)

func _has_uncollected_room_chest() -> bool:
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

func has_active_minimap_marker() -> bool:
	match room_type:
		RoomType.TREASURE:
			return _has_uncollected_room_chest()

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
			# Пока босс жив —
			# показываем маркер босса.
			if not is_cleared:
				return true

			# После победы над боссом
			# маркер остаётся активным,
			# пока в комнате есть
			# несобранный сундук.
			return _has_uncollected_room_chest()

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

func _generate_decor() -> void:
	if location_profile == null:
		return

	var decor_layer := (
		get_node_or_null("Decor")
		as TileMapLayer
	)

	if decor_layer == null:
		push_warning(
			"В комнате "
			+ name
			+ " нет TileMapLayer Decor."
		)
		return

	decor_layer.clear()

	if location_profile.decor_tile_set == null:
		return

	decor_layer.tile_set = (
		location_profile.decor_tile_set
	)

	var tile_set := decor_layer.tile_set

	var pattern_count: int = (
		tile_set.get_patterns_count()
	)

	if pattern_count == 0:
		push_warning(
			"В Decor TileSet нет паттернов."
		)
		return

	var min_count := mini(
		location_profile.decor_patterns_min,
		location_profile.decor_patterns_max
	)

	var max_count := maxi(
		location_profile.decor_patterns_min,
		location_profile.decor_patterns_max
	)

	var patterns_to_place := randi_range(
		min_count,
		max_count
	)

	var occupied_cells: Dictionary = {}

	for i in range(patterns_to_place):
		var pattern_index := randi_range(
			0,
			pattern_count - 1
		)

		var pattern := tile_set.get_pattern(
			pattern_index
		)

		if pattern == null:
			continue

		if pattern.is_empty():
			continue

		_try_place_decor_pattern(
			decor_layer,
			pattern,
			occupied_cells
		)
		
func _try_place_decor_pattern(
	decor_layer: TileMapLayer,
	pattern: TileMapPattern,
	occupied_cells: Dictionary
) -> bool:
	var tile_size := (
		decor_layer.tile_set.tile_size
	)

	var columns := floori(
		float(GameManager.room_width)
		/ float(tile_size.x)
	)

	var rows := floori(
		float(GameManager.room_height)
		/ float(tile_size.y)
	)

	var pattern_size := pattern.get_size()

	# У нас стены имеют толщину примерно 128 px.
	# При сетке Decor 32 px это 4 клетки.
	var wall_margin := Vector2i(4, 4)

	var min_x := wall_margin.x
	var min_y := wall_margin.y

	var max_x := (
		columns
		- wall_margin.x
		- pattern_size.x
	)

	var max_y := (
		rows
		- wall_margin.y
		- pattern_size.y
	)

	if max_x < min_x or max_y < min_y:
		return false

	for attempt in range(
		location_profile.decor_placement_attempts
	):
		var origin := Vector2i(
			randi_range(min_x, max_x),
			randi_range(min_y, max_y)
		)

		if not _can_place_decor_pattern(
			decor_layer,
			pattern,
			origin,
			occupied_cells
		):
			continue

		decor_layer.set_pattern(
			origin,
			pattern
		)

		_reserve_decor_pattern_cells(
			decor_layer,
			pattern,
			origin,
			occupied_cells
		)

		return true

	return false


func _can_place_decor_pattern(
	decor_layer: TileMapLayer,
	pattern: TileMapPattern,
	origin: Vector2i,
	occupied_cells: Dictionary
) -> bool:
	for pattern_cell in pattern.get_used_cells():
		var cell := decor_layer.map_pattern(
			origin,
			pattern_cell,
			pattern
		)

		if occupied_cells.has(cell):
			return false

		if _is_decor_cell_protected(
			decor_layer,
			cell
		):
			return false

	return true
	
func _is_decor_cell_protected(
	decor_layer: TileMapLayer,
	cell: Vector2i
) -> bool:
	var markers: Array[Node] = [
		get_node_or_null("SpawnPoint"),
		get_node_or_null("ReturnSpawnPoint"),
		get_node_or_null("ChestSpawnPoint")
	]

	for marker in markers:
		if marker == null:
			continue

		if marker is not Node2D:
			continue

		var marker_node := marker as Node2D

		var marker_cell := decor_layer.local_to_map(
			decor_layer.to_local(
				marker_node.global_position
			)
		)

		# 3 клетки = 96 px свободного пространства.
		if (
			absi(cell.x - marker_cell.x) <= 3
			and
			absi(cell.y - marker_cell.y) <= 3
		):
			return true

	for door in doors:
		var door_node := door as Node2D

		if door_node == null:
			continue

		var door_cell := decor_layer.local_to_map(
			decor_layer.to_local(
				door_node.global_position
			)
		)

		# У дверей оставляем больше воздуха.
		if (
			absi(cell.x - door_cell.x) <= 5
			and
			absi(cell.y - door_cell.y) <= 5
		):
			return true

	return false


func _reserve_decor_pattern_cells(
	decor_layer: TileMapLayer,
	pattern: TileMapPattern,
	origin: Vector2i,
	occupied_cells: Dictionary
) -> void:
	for pattern_cell in pattern.get_used_cells():
		var cell := decor_layer.map_pattern(
			origin,
			pattern_cell,
			pattern
		)

		# Сама клетка.
		occupied_cells[cell] = true

		# И одна клетка воздуха вокруг неё.
		for y in range(-1, 2):
			for x in range(-1, 2):
				occupied_cells[
					cell + Vector2i(x, y)
				] = true
