extends Node2D
class_name Room

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

func _ready():
	print("Room._ready: начинаю поиск дверей и врагов")
	find_doors_recursive(self)
	update_enemies_list()   # <-- теперь функция существует
	print("Найдено дверей: ", doors.size())
	print("Найдено врагов: ", enemies.size())
	# create_bounce_walls()  # удалено (масло убрано)
	set_active(false)

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

	print(
		"Комната ",
		name,
		" активность: ",
		active
	)

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

	_request_enemy_counter_refresh()

	print(
		"Обновлён список врагов: ",
		enemies.size()
	)

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
	print(
		"Room.on_room_entered вызван: ",
		name,
		", тип: ",
		room_type
	)

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
		print(
			"Нет живых врагов, открываем двери"
		)

		unlock_doors()
	else:
		print(
			"Есть живые враги: ",
			enemies.size(),
			". Закрываем двери"
		)

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

func _on_enemy_died(
	victim: Node
) -> void:
	print(
		"Враг умер: ",
		victim.name
	)

	var enemy_index: int = enemies.find(
		victim
	)

	if enemy_index != -1:
		enemies.remove_at(
			enemy_index
		)

		print(
			"Враг удалён из списка, осталось: ",
			enemies.size()
		)
	else:
		print(
			"Враг не найден в списке! "
			+ "Текущий список: ",
			enemies
		)

	_request_enemy_counter_refresh()

	# Награда и открытие дверей происходят
	# только после смерти последнего врага.
	if (
		not enemies.is_empty()
		or is_cleared
	):
		return

	is_cleared = true
	unlock_doors()

	print(
		"Комната очищена, двери открыты!"
	)

	# В комнате босса награда появляется
	# только после полной очистки комнаты.
	if not is_boss_room():
		return
	print(
		"Комната босса полностью очищена. "
		+ "Получен гарантированный ключ. "
		+ "Создаём наградной сундук."
	)

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

		print(
			"Создан враг в комнате ",
			name,
			" на позиции ",
			enemy.position
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

	var item = GameManager.all_items.pick_random()

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

	print(
		"Сундук создан в комнате сокровищ: ",
		name,
		" на позиции: ",
		chest.position
	)

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

	print(
		"Торговец создан в комнате магазина: ",
		name
	)
