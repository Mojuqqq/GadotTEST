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
			call_deferred("create_poison_cloud", global_position, damage)
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
	print("Создаём ядовитую лужу через сцену")
	var cloud_scene = load("res://Scenes/PoisonCloud.tscn")
	if not cloud_scene:
		print("Ошибка: PoisonCloud.tscn не найден!")
		return
	var cloud = cloud_scene.instantiate()
	cloud.global_position = pos
	# Передаём урон
	if cloud.has_method("setup"):
		cloud.setup(damage_amount)
	get_tree().current_scene.add_child(cloud)

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
	
