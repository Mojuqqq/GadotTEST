extends Area2D

var speed: float = 400.0
var damage: int = 1
var direction: Vector2 = Vector2.RIGHT

func setup(dir: Vector2, spd: float, dmg: int):
	direction = dir.normalized()
	speed = spd
	damage = dmg
	rotation = direction.angle()

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_body_entered(
	body: Node
) -> void:
	# Не сталкиваемся со своими врагами.
	if body.is_in_group("Enemies"):
		return

	var is_damage_target: bool = (
		body.is_in_group("Player")
		or body.is_in_group("Companions")
	)

	if (
		is_damage_target
		and body.has_method("take_damage")
	):
		body.take_damage(damage)
		queue_free()
		return

	if (
		body is StaticBody2D
		or body is TileMap
		or body.is_in_group("Walls")
	):
		queue_free()
		return

	queue_free()
