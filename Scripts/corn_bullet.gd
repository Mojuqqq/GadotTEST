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

func _on_body_entered(body):
	# Игнорируем всех врагов (включая самого стреляющего)
	if body.is_in_group("Enemies"):
		return
	
	# Наносим урон только игроку
	if body.is_in_group("Player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
		return
	
	# Если столкнулись со стеной (или любым статическим объектом) — уничтожаем
	if body is StaticBody2D or body is TileMap or body.is_in_group("Walls"):
		queue_free()
		return
	
	# На всякий случай удаляем при касании любых других объектов
	queue_free()
