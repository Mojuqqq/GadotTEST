extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene

var external_force: Vector2 = Vector2.ZERO
var current_speed: float = 300.0
var last_shot_time: float = 0.0

# Эффект слёз
var is_crying: bool = false
var tear_timer: Timer = null

func _ready():
	add_to_group("Player")
	if GameManager.player_stats:
		current_speed = GameManager.player_stats.speed
	
	# Создаём таймер для снятия эффекта
	tear_timer = Timer.new()
	tear_timer.one_shot = true
	tear_timer.timeout.connect(_on_tear_effect_end)
	add_child(tear_timer)

func _physics_process(_delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):   direction.x -= 1
	if Input.is_action_pressed("move_right"):  direction.x += 1
	if Input.is_action_pressed("move_up"):     direction.y -= 1
	if Input.is_action_pressed("move_down"):   direction.y += 1
	direction = direction.normalized()
	
	var desired_velocity = direction * base_speed
	velocity = desired_velocity + external_force
	external_force = external_force.lerp(Vector2.ZERO, 0.1)
	
	move_and_slide()

func update_speed(new_speed: float):
	current_speed = new_speed

func apply_push(force: Vector2):
	external_force += force

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		shoot()

func shoot():
	if egg_scene == null:
		return
	var egg = egg_scene.instantiate()
	get_tree().root.get_node("Main").add_child(egg)
	egg.global_position = global_position
	var dir = (get_global_mouse_position() - global_position).normalized()
	# Если эффект слёз активен – инвертируем направление
	if is_crying:
		dir = -dir
	egg.direction = dir

# Эффект слёз
func apply_tear_effect(duration: float):
	print("Игрок плачет! Стрельба в обратную сторону на ", duration, " сек.")
	is_crying = true
	# Визуальный индикатор: меняем цвет игрока (например, синий)
	modulate = Color(0.5, 0.5, 1.0, 1.0)  # голубоватый
	tear_timer.stop()
	tear_timer.wait_time = duration
	tear_timer.start()

func _on_tear_effect_end():
	is_crying = false
	modulate = Color.WHITE
	print("Эффект слёз закончился")

func take_damage(damage: int):
	GameManager.take_damage(damage)

func die():
	print("Игрок умер!")
	call_deferred("queue_free")
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()
