extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene

var external_force: Vector2 = Vector2.ZERO

func _ready():
	# Игрок добавляется в группу при создании (можно сделать вручную)
	add_to_group("Player")

func _physics_process(_delta):
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):   direction.x -= 1
	if Input.is_action_pressed("move_right"):  direction.x += 1
	if Input.is_action_pressed("move_up"):     direction.y -= 1
	if Input.is_action_pressed("move_down"):   direction.y += 1
	direction = direction.normalized()
	
	var desired_velocity = direction * base_speed
	velocity = desired_velocity + external_force
	external_force = external_force.lerp(Vector2.ZERO, 0.1)   # затухание
	
	move_and_slide()

func apply_push(force: Vector2):
	external_force += force

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик мышью!")
		shoot()

func shoot():
	if egg_scene == null:
		print("Ошибка: egg_scene = null!")
		return
	var egg = egg_scene.instantiate()
	get_tree().root.get_node("Main").add_child(egg)
	egg.global_position = global_position
	var dir = (get_global_mouse_position() - global_position).normalized()
	egg.direction = dir

# Вызывается из врагов
func take_damage(damage: int):
	GameManager.take_damage(damage)

func die():
	print("Игрок умер!")
	call_deferred("queue_free")
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()
