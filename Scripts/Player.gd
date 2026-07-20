extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene

var external_force: Vector2 = Vector2.ZERO
var current_speed: float = 300.0
var time_since_last_shot: float = 0.0

# Эффект слёз
var is_crying: bool = false
var tear_timer: Timer = null

func _ready():
	add_to_group("Player")
	if GameManager.player_stats:
		current_speed = GameManager.player_stats.speed
	
	tear_timer = Timer.new()
	tear_timer.one_shot = true
	tear_timer.timeout.connect(_on_tear_effect_end)
	add_child(tear_timer)

func _physics_process(delta):
	# === Движение ===
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
	var egg = egg_scene.instantiate()
	get_tree().root.get_node("Main").add_child(egg)
	egg.global_position = global_position
	var dir = (get_global_mouse_position() - global_position).normalized()
	if is_crying:
		dir = -dir
	egg.direction = dir

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
	call_deferred("queue_free")
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()
