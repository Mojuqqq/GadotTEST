@tool
extends Node2D
class_name DoorSocketSide


signal player_entered(
	socket: DoorSocketSide,
	player: Node2D
)


enum DoorSide {
	LEFT,
	RIGHT
}


@export_group("Direction")

var _side: int = DoorSide.RIGHT


@export_enum("LEFT", "RIGHT")
var side: int:
	get:
		return _side

	set(value):
		_side = value

		if is_inside_tree():
			call_deferred(
				&"_refresh_direction"
			)


var _arrival_offset: float = 70.0


@export var arrival_offset: float:
	get:
		return _arrival_offset

	set(value):
		_arrival_offset = value

		if is_inside_tree():
			call_deferred(
				&"_refresh_direction"
			)


@export_group("Graphics")

@export var right_texture: Texture2D:
	set(value):
		right_texture = value
		_refresh_direction()


@export var left_texture: Texture2D:
	set(value):
		left_texture = value
		_refresh_direction()


@export_group("Initial State")

@export var starts_open: bool = true


@onready var door_sprite: Sprite2D = $DoorSprite

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


func _ready() -> void:
	call_deferred(
		&"_refresh_direction"
	)

	if Engine.is_editor_hint():
		return

	if not transition_area.body_entered.is_connected(
		_on_transition_area_body_entered
	):
		transition_area.body_entered.connect(
			_on_transition_area_body_entered
		)

	set_open(starts_open)


func _refresh_direction() -> void:
	var sprite := get_node_or_null(
		"DoorSprite"
	) as Sprite2D

	var arrival := get_node_or_null(
		"ArrivalPoint"
	) as Marker2D

	if sprite == null:
		return

	if arrival == null:
		return

	match _side:
		DoorSide.LEFT:
			arrival.position = Vector2(
				_arrival_offset,
				0.0
			)

			if left_texture != null:
				sprite.texture = left_texture
				sprite.flip_h = false
			else:
				sprite.texture = right_texture
				sprite.flip_h = true

		DoorSide.RIGHT:
			arrival.position = Vector2(
				-_arrival_offset,
				0.0
			)

			sprite.texture = right_texture
			sprite.flip_h = false


func set_open(open: bool) -> void:
	is_open = open

	if not is_node_ready():
		return

	# Открытая дверь:
	# спрайт скрыт, переход работает.
	door_sprite.visible = not open

	transition_area.set_deferred(
		&"monitoring",
		open
	)

	transition_area.set_deferred(
		&"monitorable",
		open
	)

	transition_shape.set_deferred(
		&"disabled",
		not open
	)

	# Закрытая дверь:
	# появляется спрайт и включается блокиратор.
	blocker_shape.set_deferred(
		&"disabled",
		open
	)


func _on_transition_area_body_entered(
	body: Node2D
) -> void:
	if not is_open:
		return

	if not body.is_in_group("Player"):
		return

	player_entered.emit(
		self,
		body
	)
