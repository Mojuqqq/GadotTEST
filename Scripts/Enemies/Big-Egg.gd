extends Area2D

@export var speed: float = 300.0
@export var damage: int = 3
var direction: Vector2 = Vector2.ZERO

# Метод для настройки снаряда (вызывается из босса)
func setup(dir: Vector2, spd: float = 300.0, dmg: int = 2):
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
	if body.is_in_group("Enemies"):
		return

	var is_valid_damage_target: bool = (
		body.is_in_group("Player")
		or body.is_in_group("Companions")
	)

	if (
		is_valid_damage_target
		and body.has_method("take_damage")
	):
		body.take_damage(damage)

		print(
			"Снаряд босса попал в ",
			body.name,
			". Урон: ",
			damage
		)

		queue_free()
		return

	if (
		body is StaticBody2D
		or body is TileMap
		or body.is_in_group("Walls")
	):
		queue_free()
