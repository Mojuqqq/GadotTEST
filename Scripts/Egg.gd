extends Area2D

# === Параметры яйца ===
@export var speed := 700.0
var direction := Vector2.ZERO
var damage := 1 
var max_range: float = 20000.0
var start_position: Vector2 = Vector2.ZERO
var total_distance_traveled: float = 0.0

@onready var sprite = $Sprite2D

func _ready():
	rotation = direction.angle()
	# Подключаем сигнал, если ещё не подключён
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	var step = speed * delta
	if step <= 0:
		return
	
	global_position += direction * step
	total_distance_traveled += step
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Проверка дальности
	if total_distance_traveled >= max_range:
		queue_free()

# === Обработка столкновений ===
func _on_body_entered(body):
	# Игрок — игнорируем
	if body.is_in_group("Player"):
		return
	
	# Враг — наносим урон
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if GameManager.player_stats and GameManager.player_stats.poison_cloud:
			create_poison_cloud(global_position, damage)
		queue_free()
		return
	
	# Стена (любая) — уничтожаем
	if body is StaticBody2D or body is TileMapLayer or body is TileMap or body.is_in_group("Walls"):
		queue_free()
		return
	
	# Любой другой объект — уничтожаем
	queue_free()

# === Ядовитая лужа ===
func create_poison_cloud(pos: Vector2, damage_amount: int):
	print("Создаём ядовитую лужу")
	var cloud = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 100.0
	var collider = CollisionShape2D.new()
	collider.shape = shape
	cloud.add_child(collider)
	
	var cloud_sprite = Sprite2D.new()
	var texture = preload("res://Export/Item_icons/Rotten_egg.png")
	if texture:
		cloud_sprite.texture = texture
		cloud_sprite.modulate = Color(0.0, 0.8, 0.0, 0.5)
	else:
		var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		image.fill(Color.GREEN)
		var image_texture = ImageTexture.create_from_image(image)
		cloud_sprite.texture = image_texture
		cloud_sprite.modulate = Color(0.0, 0.8, 0.0, 0.5)
	cloud.add_child(cloud_sprite)
	
	cloud.global_position = pos
	get_tree().current_scene.add_child(cloud)
	
	var damage_timer = Timer.new()
	damage_timer.wait_time = 0.5
	damage_timer.one_shot = false
	damage_timer.timeout.connect(func():
		var bodies = cloud.get_overlapping_bodies()
		for b in bodies:
			if b.has_method("take_damage") and b.is_in_group("Enemies"):
				b.take_damage(damage_amount)
	)
	cloud.add_child(damage_timer)
	damage_timer.start()
	
	var life_timer = Timer.new()
	life_timer.wait_time = 4.0
	life_timer.one_shot = true
	life_timer.timeout.connect(cloud.queue_free)
	cloud.add_child(life_timer)
	life_timer.start()
	
	print("Ядовитая лужа создана! Урон: ", damage_amount)

# === Золотое яйцо ===
func set_golden():
	var golden_texture = preload("res://Export/Item_icons/Gold_egg.png")
	if sprite and golden_texture:
		sprite.texture = golden_texture
		print("Золотое яйцо активировано!")

# === Удаление при выходе за экран ===
func _on_visible_on_screen_notifier_2d_screen_exited():
	print("УНИЧТОЖАЕМ (за экраном)")
	queue_free()
	
