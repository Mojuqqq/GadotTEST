extends Area2D

# === Параметры яйца ===
@export var speed := 700.0
var direction := Vector2.ZERO
var damage := 1 
var bounce_count: int = 0
var max_bounces: int = 3
var max_range: float = 800.0
var start_position: Vector2 = Vector2.ZERO

# === Ссылки на узлы ===
@onready var sprite = $Sprite2D
@onready var raycast = $RayCast2D   # добавьте RayCast2D как дочерний узел в сцене

# === Инициализация ===
func _ready():
	rotation = direction.angle()
	raycast.target_position = Vector2.ZERO
	raycast.enabled = true
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	raycast.hit_from_inside = true

# === Физика ===
func _physics_process(delta):
	var step = speed * delta
	if step <= 0:
		return
	
	raycast.target_position = direction * step
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# 1) Игрок – игнорируем (НЕ наносим урон)
		if collider.is_in_group("Player"):
			pass  # яйцо продолжает лететь
		
		# 2) Стена – отскок или удаление
		elif collider is StaticBody2D or collider is TileMapLayer or collider is TileMap or collider.is_in_group("Walls"):
			var stats = GameManager.player_stats
			if stats and stats.bullet_bounce and bounce_count < max_bounces:
				var normal = raycast.get_collision_normal()
				if normal.length() < 0.1:
					normal = -direction.normalized()
				direction = direction.bounce(normal)
				global_position += normal * 10
				bounce_count += 1
				modulate = Color.YELLOW
				await get_tree().create_timer(0.1).timeout
				modulate = Color.WHITE
				print("Отскок (RayCast)! bounce_count = ", bounce_count)
				return
			else:
				queue_free()
				return
		
		# 3) Враг (имеет метод take_damage)
		elif collider.has_method("take_damage"):
			collider.take_damage(damage)
			if GameManager.player_stats and GameManager.player_stats.poison_cloud:
				create_poison_cloud(global_position, damage)
			queue_free()
			return
		
		# 4) Любой другой объект – уничтожаем
		else:
			queue_free()
			return
	
	# --- Если столкновения нет, двигаемся ---
	position += direction * step
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	
	# Проверка дальности
	if start_position != Vector2.ZERO:
		var traveled = global_position.distance_to(start_position)
		if traveled >= max_range:
			queue_free()
	print("direction: ", direction, " step: ", step)

# === Сигнал body_entered (запасной) ===
func _on_body_entered(body):
	if not is_inside_tree():
		return
	
	# 1) Игрок – игнорируем
	if body.is_in_group("Player"):
		return
	
	# 2) Стена
	if body is StaticBody2D or body is TileMapLayer or body is TileMap or body.is_in_group("Walls"):
		var stats = GameManager.player_stats
		if stats and stats.bullet_bounce and bounce_count < max_bounces:
			var closest = body.get_closest_point(global_position) if body.has_method("get_closest_point") else body.global_position
			var normal = (global_position - closest).normalized()
			if normal.length() < 0.1:
				normal = -direction.normalized()
			direction = direction.bounce(normal)
			global_position += normal * 10
			bounce_count += 1
			modulate = Color.YELLOW
			await get_tree().create_timer(0.1).timeout
			modulate = Color.WHITE
			return
		else:
			queue_free()
			return
	
	# 3) Враг
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if GameManager.player_stats and GameManager.player_stats.poison_cloud:
			create_poison_cloud(global_position, damage)
		queue_free()
		return
	
	# 4) Всё остальное
	queue_free()

# === Ядовитая лужа ===
func create_poison_cloud(pos: Vector2, damage_amount: int):
	var cloud = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 100.0
	var collider = CollisionShape2D.new()
	collider.shape = shape
	cloud.add_child(collider)
	
	# Визуальный спрайт (если есть текстура)
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
	
	# Периодический урон (каждые 0.5 секунды)
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
	
	# Таймер удаления (через 4 секунды)
	var life_timer = Timer.new()
	life_timer.wait_time = 4.0
	life_timer.one_shot = true
	life_timer.timeout.connect(cloud.queue_free)
	cloud.add_child(life_timer)
	life_timer.start()
	
	print("Создана ядовитая лужа! Урон: ", damage_amount)

# === Золотое яйцо ===
func set_golden():
	if sprite == null:
		print("Ошибка: у яйца нет спрайта (Sprite2D)!")
		return
	var golden_texture = preload("res://Export/Item_icons/Gold_egg.png")
	if golden_texture:
		sprite.texture = golden_texture
		print("Золотое яйцо активировано!")
	else:
		print("Не удалось загрузить текстуру золотого яйца")

# === Удаление при выходе за экран ===
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
