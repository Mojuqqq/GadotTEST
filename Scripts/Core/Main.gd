extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D

# Экспортируемые сцены комнат (для удобства настройки в редакторе)
@export var start_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_pool: Array[PackedScene] = []

@export var enemy_pool: Array[PackedScene] = []

# Параметры комнат (дублируем для доступа в Main)
@export var room_width: int = 1280
@export var room_height: int = 1024
@export var room_spacing: int = 50
@export var min_rooms: int = 2
@export var max_rooms: int = 4

@export_group("Bosses")

@export var boss_pool: Array[PackedScene] = []
# Оставляем старое поле скрытым, чтобы текущая сцена
# Main.tscn не сломалась во время перехода на пул.
@export_storage var boss_scene: PackedScene
	
func _ready() -> void:
	get_tree().paused = false

	if player and not player.is_in_group("Player"):
		player.add_to_group("Player")

	GameManager.set_player(player)

# Характеристики создаём только в самом начале забега.
	if GameManager.player_stats == null:
		var stats := PlayerStats.new()

		stats.max_hp = 6
		stats.damage = 1
		stats.speed = 300.0
		stats.fire_rate = 0.65
		stats.egg_speed = 700.0
		stats.attack_range = 320.0

		GameManager.set_player_stats(stats)
	else:
		# Новый узел игрока получает сохранённую
		# скорость текущего забега.
		player.update_speed(
			GameManager.player_stats.speed
		)

	# Настройки комнат.
	GameManager.room_width = room_width
	GameManager.room_height = room_height
	GameManager.room_spacing = room_spacing
	GameManager.min_rooms = min_rooms
	GameManager.max_rooms = max_rooms

	# Сцены комнат и врагов.
	GameManager.start_room_scene = start_room_scene
	GameManager.end_room_scene = end_room_scene
	GameManager.room_pool = room_pool
	GameManager.enemy_pool = enemy_pool
	GameManager.boss_scene = (
		_select_random_boss_scene()
	)

	GameManager.generate_dungeon(self)
		
		
# =========================================================
# ВЫБОР БОССА
# =========================================================

func _select_random_boss_scene() -> PackedScene:
	var valid_bosses: Array[PackedScene] = []

	# Защищаемся от пустых элементов массива.
	for candidate in boss_pool:
		if candidate == null:
			continue

		valid_bosses.append(
			candidate
		)

	if not valid_bosses.is_empty():
		var selected_boss: PackedScene = (
			valid_bosses.pick_random()
		)

		return selected_boss

	# Временная обратная совместимость:
	# пока пул не заполнен, используется старый босс.
	if boss_scene != null:
		push_warning(
			"Пул боссов пуст. "
			+ "Используется прежний boss_scene: "
			+ boss_scene.resource_path
		)

		return boss_scene

	push_error(
		"Не удалось выбрать босса: "
		+ "Boss Pool пуст."
	)

	return null

# Вызывается из Door.gd
func move_player_to_room(
	target_room_node: Node2D,
	arrival_position: Vector2
) -> void:
	if GameManager.is_transitioning:
		return

	GameManager.is_transitioning = true

	# Запоминаем комнату, из которой выходим.
	var previous_index: int = (
		GameManager.current_room_index
	)

	var target_index: int = (
		GameManager.move_player_to_room(
			target_room_node,
			arrival_position
		)
	)

	if target_index == -1:
		GameManager.is_transitioning = false
		return

	# Нужен для обратной совместимости
	# со старыми дверями.
	var is_returning: bool = (
		target_index < previous_index
	)

	var room: Node2D = (
		GameManager.get_current_room()
	)

	if room != null:
		var room_size := Vector2(
			float(room_width),
			float(room_height)
		)

		var room_rect := Rect2(
			room.global_position,
			room_size
		)

		# Универсальная дверь передаёт ArrivalPoint,
		# находящийся внутри целевой комнаты.
		var has_door_arrival: bool = (
			room_rect.has_point(
				arrival_position
			)
		)

		if has_door_arrival:
			player.global_position = (
				arrival_position
			)
		else:
			# Старые Door.gd перед:
			# Старые Door.gd передают позицию двери
			# из предыдущей комнаты.
			# Для них пока оставляем старую систему.
			var spawn_name: String = (
				"ReturnSpawnPoint"
				if is_returning
				else "SpawnPoint"
			)

			var spawn := room.get_node_or_null(
				NodePath(spawn_name)
			) as Node2D

			if spawn == null:
				push_warning(
					"В комнате "
					+ room.name
					+ " отсутствует "
					+ spawn_name
				)

				spawn = room.get_node_or_null(
					"SpawnPoint"
				) as Node2D

			if spawn != null:
				player.global_position = (
					spawn.global_position
				)
			else:
				# Последняя страховка —
				# центр комнаты.
				player.global_position = (
					room.global_position
					+ Vector2(
						room_width / 2.0,
						room_height / 2.0
					)
				)

		player.velocity = Vector2.ZERO

		# Переносим компаньонов уже к новой
		# позиции игрока.
		player.call_deferred(
			"teleport_companions_to_player"
		)

		camera.global_position = (
			room.global_position
			+ Vector2(
				room_width / 2.0,
				room_height / 2.0
			)
		)

	await get_tree().create_timer(
		0.3
	).timeout

	GameManager.is_transitioning = false

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		GameManager.restart_game()
		
func _exit_tree() -> void:
	if is_instance_valid(player):
		GameManager.unregister_player(player)
