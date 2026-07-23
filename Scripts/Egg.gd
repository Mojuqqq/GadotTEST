extends Area2D

# === Параметры яйца ===
@export var speed := 700.0
var direction := Vector2.ZERO
var damage := 1 
@export var max_range: float = 300.0
var total_distance_traveled: float = 0.0
var hit := false
var deactivation_requested := false
signal returned_to_pool(egg)

@onready var sprite = $Sprite2D

const POISON_CLOUD_SCENE = preload("res://Scenes/PoisonCloud.tscn")

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
		deactivate()

# === Обработка столкновений ===
func _on_body_entered(body):
	if hit:
		return
	
	# Игрок — игнорируем
	if body.is_in_group("Player"):
		return

	# После этого пуля уже считается столкнувшейся
	hit = true
	set_deferred("monitoring", false)

	# Враг — наносим урон
	if body.has_method("take_damage"):
		body.take_damage(damage)
		if GameManager.player_stats and GameManager.player_stats.poison_cloud:
			call_deferred("create_poison_cloud", global_position, damage)
		deactivate()
		return
	
	# Стена (любая) — уничтожаем
	if body is StaticBody2D or body is TileMapLayer or body is TileMap or body.is_in_group("Walls"):
		deactivate()
		return
	
	# Любой другой объект — уничтожаем
	deactivate()

# === Ядовитая лужа ===
func create_poison_cloud(pos: Vector2, damage_amount: int):
	print("Создаём ядовитую лужу через сцену")

	var cloud = POISON_CLOUD_SCENE.instantiate()
	cloud.global_position = pos

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
	pass

func activate(pos: Vector2, dir: Vector2, damage_amount: int):
	global_position = pos
	direction = dir.normalized()
	damage = damage_amount

	hit = false
	deactivation_requested = false
	total_distance_traveled = 0.0

	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_deferred("monitoring", true)

func deactivate():
	if deactivation_requested:
		return

	deactivation_requested = true
	call_deferred("_deactivate_now")


func _deactivate_now():
	visible = false
	monitoring = false
	process_mode = Node.PROCESS_MODE_DISABLED

	returned_to_pool.emit(self)
