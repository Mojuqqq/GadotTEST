extends Area2D

@export var speed := 700.0
@onready var sprite = $Sprite2D
var direction := Vector2.ZERO
var damage := 1 
var bounce_count: int = 0
var max_bounces: int = 3   # ограничение, чтобы не бесконечно
var max_range: float = 800.0
var start_position: Vector2 = Vector2.ZERO


func _ready():
	rotation = direction.angle()

func _physics_process(delta):
	position += direction * speed * delta
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Проверка дальности
	if start_position != Vector2.ZERO:
		var traveled = global_position.distance_to(start_position)
		if traveled >= max_range:
			# Достигли максимальной дальности — уничтожаем
			queue_free()
			# Можно добавить эффект (вспышка, частицы)

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func _on_body_entered(body):
	print("=== ЯЙЦО СТОЛКНУЛОСЬ ===")
	print("Объект: ", body)
	print("Тип: ", body.get_class())
	print("Имя: ", body.name)
	
	if body.name == "Player":
		print("Это игрок, игнорируем")
		return
	
	if body.has_method("take_damage"):
		print("Наносим урон: ", damage)
		body.take_damage(damage)
		
		# === ТУХЛОЕ ЯЙЦО: создаём ядовитую лужу ===
		if GameManager.player_stats and GameManager.player_stats.poison_cloud:
			create_poison_cloud(global_position)
		
		queue_free()
		return
	
	# === МАСЛО: отскок от стен ===
	if body is StaticBody2D or body is TileMapLayer or body is TileMap or body.is_in_group("Walls"):
		if GameManager.player_stats and GameManager.player_stats.bullet_bounce and bounce_count < max_bounces:
			# Отражение
			var normal = (global_position - body.global_position).normalized()
			direction = direction.bounce(normal)
			bounce_count += 1
			print("Отскок! bounce_count = ", bounce_count)
			return
		else:
			print("Уничтожаем яйцо без урона")
			queue_free()
			return
	
	print("Уничтожаем яйцо без урона")
	queue_free()

func create_poison_cloud(pos: Vector2):
	var cloud = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0
	var collider = CollisionShape2D.new()
	collider.shape = shape
	cloud.add_child(collider)
	cloud.global_position = pos
	get_tree().current_scene.add_child(cloud)
	
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(cloud.queue_free)
	cloud.add_child(timer)
	timer.start()
	
	# Исправлено: параметр переименован в hit_body
	cloud.body_entered.connect(func(hit_body):
		if hit_body.has_method("take_damage") and hit_body.is_in_group("Enemies"):
			hit_body.take_damage(1)
	)
	print("Создана ядовитая лужа!")
	
func set_golden():
	var golden_texture = preload("res://Export/Golden_Egg.png")
	if golden_texture:
		sprite.texture = golden_texture
