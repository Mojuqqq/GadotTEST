extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene
var egg_pool: Array[Node] = []
const INITIAL_POOL_SIZE := 20

var external_force: Vector2 = Vector2.ZERO
var current_speed: float = 300.0
var time_since_last_shot: float = 0.0

# Эффект слёз
var is_crying: bool = false
var tear_timer: Timer = null

var companion: Node2D = null
const COMPANION_SCENE = preload("res://Scenes/Chick_companion.tscn")

func _ready():
	add_to_group("Player")
	if GameManager.player_stats:
		current_speed = GameManager.player_stats.speed
	else:
		current_speed = base_speed
	
	tear_timer = Timer.new()
	tear_timer.one_shot = true
	tear_timer.timeout.connect(_on_tear_effect_end)
	add_child(tear_timer)

	call_deferred("_create_egg_pool")
	
func _create_egg_pool():
	for i in INITIAL_POOL_SIZE:
		var egg = egg_scene.instantiate()
		get_tree().current_scene.add_child(egg)

		egg.returned_to_pool.connect(_on_egg_returned_to_pool)
		egg.deactivate()

		# deactivate() отправляет сигнал, поэтому убираем возможный дубль
		if not egg_pool.has(egg):
			egg_pool.append(egg)

func _on_egg_returned_to_pool(egg):
	if not egg_pool.has(egg):
		egg_pool.append(egg)

func _physics_process(delta):
	# === Движение ===
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):   direction.x -= 1
	if Input.is_action_pressed("move_right"):  direction.x += 1
	if Input.is_action_pressed("move_up"):     direction.y -= 1
	if Input.is_action_pressed("move_down"):   direction.y += 1
	direction = direction.normalized()
	
	var desired_velocity = direction * current_speed
	velocity = desired_velocity + external_force
	external_force = external_force.lerp(Vector2.ZERO, 0.1)
	move_and_slide()
	
	# === Стрельба ===
	time_since_last_shot += delta   # время тикает всегда
	
	var is_shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fire_rate = GameManager.player_stats.fire_rate if GameManager.player_stats else 0.3
	
	if is_shooting and time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func update_speed(new_speed: float):
	current_speed = new_speed

func apply_push(force: Vector2):
	external_force += force

func shoot():
	
	if egg_scene == null:
		return

	var egg

	if egg_pool.is_empty():
		egg = egg_scene.instantiate()
		get_tree().current_scene.add_child(egg)
		egg.returned_to_pool.connect(_on_egg_returned_to_pool)
	else:
		egg = egg_pool.pop_back()

	var dir = (get_global_mouse_position() - global_position).normalized()

	if is_crying:
		dir = -dir

	if GameManager.player_stats:
		egg.damage = GameManager.player_stats.damage
		egg.speed = GameManager.player_stats.egg_speed
		egg.max_range = (
			GameManager.player_stats.attack_range
			* GameManager.player_stats.attack_range_multiplier
		)

		if GameManager.player_stats.has_golden_egg and egg.has_method("set_golden"):
			egg.set_golden()

	egg.activate(global_position, dir, egg.damage)

func apply_tear_effect(duration: float):
	is_crying = true
	modulate = Color(0.5, 0.5, 1.0, 1.0)
	tear_timer.stop()
	tear_timer.wait_time = duration
	tear_timer.start()

func _on_tear_effect_end():
	is_crying = false
	modulate = Color.WHITE

func take_damage(damage: int):
	GameManager.take_damage(damage)

func die():
	print("Игрок умер!")

	if companion != null and is_instance_valid(companion):
		companion.queue_free()
		companion = null

	call_deferred("queue_free")
	
func spawn_companion(type: String = "default"):
	if companion != null and is_instance_valid(companion):
		return
	
	companion = COMPANION_SCENE.instantiate()
	get_tree().current_scene.add_child(companion)
	companion.global_position = global_position + Vector2(50, 0)
	companion.set_player(self)
	
	if type == "rooster":
		companion.damage = 2
		companion.speed = 180
		companion.attack_cooldown = 0.8
		companion.follow_distance = 60
	elif type == "chick":
		companion.damage = 1
		companion.speed = 120
		companion.attack_cooldown = 1.2
		companion.follow_distance = 50
	
	print("Создан компаньон типа: ", type)

func remove_companion():
	if companion != null and is_instance_valid(companion):
		companion.queue_free()
		companion = null
