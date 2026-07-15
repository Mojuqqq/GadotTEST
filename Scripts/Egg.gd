extends Area2D

@export var speed := 700.0
var direction := Vector2.ZERO

func _physics_process(delta):
	print("Egg._physics_process: position = ", position, " direction = ", direction, " speed = ", speed)
	position += direction * speed * delta
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _ready():
	rotation = direction.angle()
	print("Яйцо готово! Позиция: ", position)
	# Сделай спрайт ярким, чтобы точно увидеть
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color.RED

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

#func _process(_delta):
	## Если яйцо улетело далеко за экран - удаляем
	#if abs(position.x) > 2000 or abs(position.y) > 2000:
		#queue_free()

func _on_body_entered(body):
	print("=== ЯЙЦО СТОЛКНУЛОСЬ ===")
	print("Объект: ", body.name)
	print("Тип: ", body.get_class())
	print("Есть метод take_damage? ", body.has_method("take_damage"))
	
	# Игнорируем игрока
	if body.name == "Player":
		print("Это игрок, игнорируем")
		return
	
	# Если это враг - наносим урон
	if body.has_method("take_damage"):
		print("Наносим урон!")
		body.take_damage(1)
		queue_free()
		return
	
	print("Уничтожаем яйцо без урона")
	queue_free()
