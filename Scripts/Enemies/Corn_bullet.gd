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

	# Попали в игрока или компаньона.
	if (
		is_damage_target
		and body.has_method("take_damage")
	):
		body.take_damage(damage)

		AudioManager.play_world_sfx(
			&"impact_small",
			global_position,
			-18.0,
			0.96,
			1.05
		)

		queue_free()
		return

	# Попали в стену или препятствие.
	if (
		body is StaticBody2D
		or body is TileMap
		or body.is_in_group("Walls")
	):
		AudioManager.play_world_sfx(
			&"impact_small",
			global_position,
			-20.0,
			0.94,
			1.04
		)

		queue_free()
		return

	# Любое другое столкновение.
	queue_free()
