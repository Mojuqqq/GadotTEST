extends Resource
class_name WallTheme


@export var source_id: int = 0

@export_group("Straight walls")
@export var top: Vector2i
@export var bottom: Vector2i
@export var left: Vector2i
@export var right: Vector2i

@export_group("Corners")
@export var top_left: Vector2i
@export var top_right: Vector2i
@export var bottom_left: Vector2i
@export var bottom_right: Vector2i

@export_group("Doors")
@export var door_top: Vector2i
@export var door_bottom: Vector2i
@export var door_left: Vector2i
@export var door_right: Vector2i
