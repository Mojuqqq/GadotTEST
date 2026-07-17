extends Area2D

@export var speed := 700.0
var direction := Vector2.ZERO
var damage := 1 

func _ready():
	rotation = direction.angle()

func _physics_process(delta):
	position += direction * speed * delta
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_body_entered(body):
	print("=== ЯЙЦО СТОЛКНУЛОСЬ ===")
	print("Объект: ", body.name)
	print("Тип: ", body.get_class())
	
	if body.name == "Player":
		print("Это игрок, игнорируем")
		return
	
	if body.has_method("take_damage"):
		print("Наносим урон: ", damage)
		body.take_damage(damage)
		queue_free()
		return
	
	print("Уничтожаем яйцо без урона")
	queue_free()
