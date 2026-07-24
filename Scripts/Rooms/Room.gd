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

	GameManager.enemies_changed.emit(enemies.size())
	print("Обновлён список врагов: ", enemies.size())

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

	# Победа только после очистки конечной комнаты
		if name == "EndRoom":
			print(
				"Босс побеждён. "
				+ "Этаж завершён."
			)

			GameManager.complete_floor()

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
		
		if enemy.has_method("set_active"):
			enemy.set_active(false)
		else:
			enemy.process_mode = (
				Node.PROCESS_MODE_DISABLED
			)
		
		print("Создан враг в комнате ", name, " на позиции ", enemy.position)

func spawn_chest() -> void:
	if not is_treasure_room():
		push_warning(
			"Попытка создать сундук не в TREASURE-комнате: "
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

	add_child(chest)

	var margin: float = 100.0

	var x: float = randf_range(
		margin,
		GameManager.room_width - margin
	)

	var y: float = randf_range(
		margin,
		GameManager.room_height - margin
	)

	chest.position = Vector2(x, y)

	print(
		"Сундук создан в комнате сокровищ: ",
		name
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
