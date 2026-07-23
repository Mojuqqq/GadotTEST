extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D

# Экспортируемые сцены комнат (для удобства настройки в редакторе)
@export var start_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_pool: Array[PackedScene] = []

@export var enemy_pool: Array[PackedScene] = []
@export var boss_scene: PackedScene

# Параметры комнат (дублируем для доступа в Main)
@export var room_width: int = 1280
@export var room_height: int = 1024
@export var room_spacing: int = 50
@export var min_rooms: int = 2
@export var max_rooms: int = 4

	
func _ready() -> void:
	get_tree().paused = false

	if player and not player.is_in_group("Player"):
		player.add_to_group("Player")

	var stats := PlayerStats.new()

	stats.max_hp = 5
	stats.damage = 1
	stats.speed = 300.0
	stats.fire_rate = 0.8
	stats.egg_speed = 700.0
	stats.attack_range = 300.0

	# Сначала новый игрок.
	GameManager.set_player(player)

	# Затем его характеристики.
	GameManager.set_player_stats(stats)

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
	GameManager.boss_scene = boss_scene

	GameManager.generate_dungeon(self)
		
# Вызывается из Door.gd
func move_player_to_room(target_room_node: Node2D, door_position: Vector2):
	if GameManager.is_transitioning:
		return
	GameManager.is_transitioning = true
	
	var target_index = GameManager.move_player_to_room(target_room_node, door_position)
	if target_index == -1:
		GameManager.is_transitioning = false
		return
	
	# Перемещаем игрока и камеру в новую комнату
	var room = GameManager.get_current_room()
	if room:
		var spawn = room.get_node("SpawnPoint")
		if spawn:
			player.global_position = spawn.global_position
		else:
			player.global_position = room.global_position + Vector2(room_width / 2.0, room_height / 2.0)
		# Всегда обновляем камеру
		camera.global_position = room.global_position + Vector2(room_width / 2.0, room_height / 2.0)
	
	await get_tree().create_timer(0.3).timeout
	GameManager.is_transitioning = false

func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("debug_restart"):
		GameManager.restart_game()
		
func _exit_tree() -> void:
	if is_instance_valid(player):
		GameManager.unregister_player(player)
