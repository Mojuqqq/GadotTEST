extends Node2D

@onready var player = $Player
@onready var camera = $Player/Camera2D

@export var start_room_scene: PackedScene
@export var end_room_scene: PackedScene
@export var room_pool: Array[PackedScene] = []

@export var room_width: int = 800
@export var room_height: int = 600
@export var room_spacing: int = 50
@export var min_rooms: int = 2
@export var max_rooms: int = 4

var room_instances: Array[Node2D] = []
var current_room_index: int = 0
var is_transitioning: bool = false

func _ready():
	if player and not player.is_in_group("Player"):
		player.add_to_group("Player")
	generate_dungeon()

func generate_dungeon():
	if start_room_scene == null or end_room_scene == null or room_pool.size() == 0:
		print("Ошибка: не назначены сцены комнат!")
		return

	for room in room_instances:
		room.queue_free()
	room_instances.clear()

	var intermediate_count = randi_range(min_rooms, max_rooms)
	print("Генерация: ", intermediate_count, " промежуточных комнат")

	var prev_room: Node2D  # объявляем здесь

	var start_room = start_room_scene.instantiate()
	add_child(start_room)
	start_room.global_position = Vector2(0, 0)
	room_instances.append(start_room)
	prev_room = start_room  # сохраняем ссылку

	for i in range(intermediate_count):
		var random_scene = room_pool[randi_range(0, room_pool.size() - 1)]
		var room = random_scene.instantiate()
		add_child(room)
		room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
		room_instances.append(room)
		prev_room = room  # обновляем

	var end_room = end_room_scene.instantiate()
	add_child(end_room)
	end_room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
	room_instances.append(end_room)

	connect_rooms()
	enter_room(0)

func connect_rooms():
	for i in range(room_instances.size() - 1):
		var left_room = room_instances[i]
		var right_room = room_instances[i + 1]
		var left_door = left_room.get_node("DoorRight") if left_room.has_node("DoorRight") else null
		var right_door = right_room.get_node("DoorLeft") if right_room.has_node("DoorLeft") else null
		if left_door and right_door:
			left_door.linked_door = right_door
			right_door.linked_door = left_door
			left_door.target_room_node = right_room
			right_door.target_room_node = left_room
		else:
			print("Нет дверей для соединения комнат ", i)

func enter_room(index: int):
	if index < 0 or index >= room_instances.size():
		return
	for room in room_instances:
		room.visible = false
	var room = room_instances[index]
	room.visible = true

	var spawn = room.get_node("SpawnPoint")
	if spawn:
		player.global_position = spawn.global_position
	else:
		player.global_position = room.global_position + Vector2(room_width/2, room_height/2)

	#update_camera_for_room(room)
	current_room_index = index
	camera.global_position = player.global_position

	if room.has_method("on_room_entered"):
		room.on_room_entered()

	print("Вошли в комнату ", index)

func update_camera_for_room(room: Node2D):
	var room_pos = room.global_position
	camera.limit_left = room_pos.x
	camera.limit_right = room_pos.x + room_width
	camera.limit_top = room_pos.y
	camera.limit_bottom = room_pos.y + room_height

func move_player_to_room(target_room_node: Node2D, door_position: Vector2):
	if is_transitioning:
		return
	is_transitioning = true

	var target_index = room_instances.find(target_room_node)
	if target_index == -1:
		is_transitioning = false
		return

	enter_room(target_index)
	player.global_position = door_position + Vector2(0, 20)

	await get_tree().create_timer(0.3).timeout
	is_transitioning = false

func _process(_delta):
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
