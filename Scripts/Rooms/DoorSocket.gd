@tool
extends Node2D
class_name DoorSocket

signal state_changed(
	socket: DoorSocket,
	is_open: bool
)

signal player_entered(
	socket: DoorSocket,
	player: Node2D
)


enum Direction {
	TOP,
	RIGHT,
	BOTTOM,
	LEFT
}


@export_group("Direction")


@export_enum(
	"TOP",
	"RIGHT",
	"BOTTOM",
	"LEFT"
)
var direction: int = Direction.RIGHT:
	set(value):
		direction = value
		_refresh_configuration()


@export var arrival_offset: float = 70.0:
	set(value):
		arrival_offset = value
		_refresh_configuration()


@export_group("Graphics")


@export var top_texture: Texture2D:
	set(value):
		top_texture = value
		_refresh_configuration()


@export var right_texture: Texture2D:
	set(value):
		right_texture = value
		_refresh_configuration()


@export var bottom_texture: Texture2D:
	set(value):
		bottom_texture = value
		_refresh_configuration()


@export var left_texture: Texture2D:
	set(value):
		left_texture = value
		_refresh_configuration()

@export_group("Open Graphics")


@export var top_open_texture: Texture2D:
	set(value):
		top_open_texture = value
		_refresh_configuration()


@export var right_open_texture: Texture2D:
	set(value):
		right_open_texture = value
		_refresh_configuration()


@export var bottom_open_texture: Texture2D:
	set(value):
		bottom_open_texture = value
		_refresh_configuration()


@export var left_open_texture: Texture2D:
	set(value):
		left_open_texture = value
		_refresh_configuration()

@export_group("Collision")


@export var side_collision_size := Vector2(
	29.0,
	84.0
):
	set(value):
		side_collision_size = value
		_refresh_configuration()


@export var top_bottom_collision_size := Vector2(
	84.0,
	80.0
):
	set(value):
		top_bottom_collision_size = value
		_refresh_configuration()


@export_group("Initial State")


@export var starts_open: bool = true


@onready var door_sprite: Sprite2D = (
	$DoorSprite
)

@onready var open_door_sprite: Sprite2D = (
	$OpenDoorSprite
)

@onready var transition_area: Area2D = (
	$TransitionArea
)

@onready var transition_shape: CollisionShape2D = (
	$TransitionArea/CollisionShape2D
)

@onready var blocker_shape: CollisionShape2D = (
	$Blocker/CollisionShape2D
)

@onready var arrival_point: Marker2D = (
	$ArrivalPoint
)


var is_open: bool = true
var linked_socket: Node = null
var target_room_node: Node2D = null
var connection_enabled: bool = false


# Страховка для обновления прямо в редакторе.
var _editor_last_direction: int = -1
var _editor_last_arrival_offset: float = -1.0

var _editor_last_top_texture: Texture2D
var _editor_last_right_texture: Texture2D
var _editor_last_bottom_texture: Texture2D
var _editor_last_left_texture: Texture2D

var _editor_last_side_size := Vector2.ZERO
var _editor_last_top_bottom_size := Vector2.ZERO


func _ready() -> void:
	_refresh_configuration()

	if Engine.is_editor_hint():
		return

	if not transition_area.body_entered.is_connected(
		_on_transition_area_body_entered
	):
		transition_area.body_entered.connect(
			_on_transition_area_body_entered
		)

	set_open(starts_open)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	var configuration_changed := (
		_editor_last_direction != direction
		or not is_equal_approx(
			_editor_last_arrival_offset,
			arrival_offset
		)
		or _editor_last_top_texture != top_texture
		or _editor_last_right_texture != right_texture
		or _editor_last_bottom_texture != bottom_texture
		or _editor_last_left_texture != left_texture
		or not _editor_last_side_size.is_equal_approx(
			side_collision_size
		)
		or not _editor_last_top_bottom_size.is_equal_approx(
			top_bottom_collision_size
		)
	)

	if not configuration_changed:
		return

	_editor_last_direction = direction
	_editor_last_arrival_offset = arrival_offset

	_editor_last_top_texture = top_texture
	_editor_last_right_texture = right_texture
	_editor_last_bottom_texture = bottom_texture
	_editor_last_left_texture = left_texture

	_editor_last_side_size = side_collision_size
	_editor_last_top_bottom_size = (
		top_bottom_collision_size
	)

	_refresh_configuration()


func _refresh_configuration() -> void:
	var closed_sprite := get_node_or_null(
		"DoorSprite"
	) as Sprite2D

	var open_sprite := get_node_or_null(
		"OpenDoorSprite"
	) as Sprite2D

	var arrival := get_node_or_null(
		"ArrivalPoint"
	) as Marker2D

	var transition := get_node_or_null(
		"TransitionArea/CollisionShape2D"
	) as CollisionShape2D

	var blocker := get_node_or_null(
		"Blocker/CollisionShape2D"
	) as CollisionShape2D

	if (
		closed_sprite == null
		or open_sprite == null
		or arrival == null
		or transition == null
		or blocker == null
	):
		return

	closed_sprite.flip_h = false
	closed_sprite.flip_v = false

	open_sprite.flip_h = false
	open_sprite.flip_v = false

	var closed_texture: Texture2D = null
	var opened_texture: Texture2D = null

	var collision_size: Vector2 = (
		side_collision_size
	)

	match direction:
		Direction.TOP:
			closed_texture = top_texture
			opened_texture = top_open_texture

			arrival.position = Vector2(
				0.0,
				arrival_offset
			)

			collision_size = (
				top_bottom_collision_size
			)

		Direction.RIGHT:
			closed_texture = right_texture
			opened_texture = right_open_texture

			arrival.position = Vector2(
				-arrival_offset,
				0.0
			)

			collision_size = side_collision_size

		Direction.BOTTOM:
			closed_texture = bottom_texture
			opened_texture = bottom_open_texture

			arrival.position = Vector2(
				0.0,
				-arrival_offset
			)

			collision_size = (
				top_bottom_collision_size
			)

		Direction.LEFT:
			closed_texture = left_texture
			opened_texture = left_open_texture

			arrival.position = Vector2(
				arrival_offset,
				0.0
			)

			collision_size = side_collision_size

	closed_sprite.texture = closed_texture

	open_sprite.texture = (
		opened_texture
		if opened_texture != null
		else closed_texture
	)

	var transition_rectangle := (
		transition.shape as RectangleShape2D
	)

	var blocker_rectangle := (
		blocker.shape as RectangleShape2D
	)

	if transition_rectangle != null:
		transition_rectangle.size = (
			collision_size
		)

	if blocker_rectangle != null:
		blocker_rectangle.size = (
			collision_size
		)

	# В редакторе показываем закрытую дверь.
	if Engine.is_editor_hint():
		closed_sprite.visible = true
		open_sprite.visible = false
		return

	if is_node_ready():
		_apply_visual_state()

func _apply_visual_state() -> void:
	if not is_node_ready():
		return

	visible = true

	# Нет соседней комнаты —
	# DoorSocket ничего не рисует.
	if not connection_enabled:
		door_sprite.visible = false
		open_door_sprite.visible = false
		return

	# Есть соединение.
	door_sprite.visible = not is_open
	open_door_sprite.visible = is_open

func connect_to(
	other_socket: Node,
	target_room: Node2D
) -> void:
	linked_socket = other_socket
	target_room_node = target_room

	connection_enabled = (
		is_instance_valid(linked_socket)
		and is_instance_valid(target_room_node)
	)

	if not is_node_ready():
		return

	visible = true

	# После генерации соединённая дверь закрыта.
	# Room.gd откроет её при очистке комнаты.
	set_open(false)


func clear_connection() -> void:
	linked_socket = null
	target_room_node = null
	connection_enabled = false

	if not is_node_ready():
		return

	visible = true
	set_open(false)


func get_arrival_global_position() -> Vector2:
	if is_instance_valid(arrival_point):
		return arrival_point.global_position

	return global_position


func _set_open_local(open: bool) -> void:
	is_open = (
		open
		and connection_enabled
	)

	if not is_node_ready():
		return

	_apply_visual_state()

	var transition_enabled: bool = (
		connection_enabled
		and is_open
	)

	transition_area.set_deferred(
		&"monitoring",
		transition_enabled
	)

	transition_area.set_deferred(
		&"monitorable",
		transition_enabled
	)

	transition_shape.set_deferred(
		&"disabled",
		not transition_enabled
	)

	# Блокиратор включён:
	# — у закрытой двери;
	# — у стены без соединения.
	blocker_shape.set_deferred(
		&"disabled",
		transition_enabled
	)
	
	state_changed.emit(
		self,
		is_open
	)

func set_open(open: bool) -> void:
	var was_open: bool = is_open

	_set_open_local(open)

	if (
		open
		and not was_open
		and is_open
		and not Engine.is_editor_hint()
	):
		AudioManager.play_door_open(
			global_position
		)

	var other_socket := (
		linked_socket as DoorSocket
	)

	if other_socket == null:
		return

	if not is_instance_valid(other_socket):
		return

	other_socket._set_open_local(open)


func apply_visuals(
	closed_texture: Texture2D,
	opened_texture: Texture2D
) -> void:
	match direction:
		Direction.TOP:
			top_texture = closed_texture
			top_open_texture = opened_texture

		Direction.RIGHT:
			right_texture = closed_texture
			right_open_texture = opened_texture

		Direction.BOTTOM:
			bottom_texture = closed_texture
			bottom_open_texture = opened_texture

		Direction.LEFT:
			left_texture = closed_texture
			left_open_texture = opened_texture

	_refresh_configuration()

func _on_transition_area_body_entered(
	body: Node2D
) -> void:
	if not connection_enabled:
		return

	if not is_open:
		return

	if not body.is_in_group(&"Player"):
		return

	if not is_instance_valid(target_room_node):
		push_warning(
			"У двери "
			+ name
			+ " не назначена целевая комната."
		)
		return

	if not is_instance_valid(linked_socket):
		push_warning(
			"У двери "
			+ name
			+ " отсутствует связанная дверь."
		)
		return

	player_entered.emit(
		self,
		body
	)

	var main: Node = get_tree().current_scene

	if main == null:
		push_error(
			"Не найдена текущая сцена."
		)
		return

	if not main.has_method(&"move_player_to_room"):
		push_error(
			"Текущая сцена не имеет метода "
			+ "move_player_to_room()."
		)
		return

	var arrival_position: Vector2 = global_position

	# Когда обе двери новые, используем ArrivalPoint
	# связанного DoorSocket.
	if linked_socket.has_method(
		&"get_arrival_global_position"
	):
		arrival_position = linked_socket.call(
			&"get_arrival_global_position"
		)

	# Когда связанная дверь старая, передаём позицию
	# текущей двери. Main.gd распознает её как старый
	# переход и использует SpawnPoint.
	
	AudioManager.play_sfx(
		&"whoosh_transition",
		-16.0,
		0.98,
		1.02
	)

	main.call_deferred(
		&"move_player_to_room",
		target_room_node,
		arrival_position
	)
