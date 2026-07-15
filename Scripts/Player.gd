extends CharacterBody2D

var speed: float = 300.0
@export var egg_scene: PackedScene

@export var max_hp: int = 5
var current_hp: int

func _ready():
	current_hp = max_hp
	print("Игрок создан! HP = ", current_hp)

func _physics_process(_delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1

	direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()

func _unhandled_input(event):
	print("Событие получено: ", event)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик мышью!")
		shoot()

func shoot():
	print("shoot() вызвана!")
	if egg_scene == null:
		print("Ошибка: egg_scene = null!")
		return
		
	print("egg_scene не null, инстанцируем...")
	var egg = egg_scene.instantiate()
	print("Яйцо создано, добавляем на сцену...")
	get_tree().root.get_node("Main").add_child(egg)
	print("Яйцо добавлено. Physics process enabled: ", egg.is_physics_processing())
	if not egg.is_physics_processing():
		egg.set_physics_process(true)
		print("Включили physics_process принудительно.")
	egg.global_position = global_position
	var dir = (get_global_mouse_position() - global_position).normalized()
	egg.direction = dir
	print("Яйцо запущено в направлении: ", dir)

func take_damage(damage: int):
	current_hp -= damage
	print("Игрок получил урон! HP = ", current_hp)
	
	if current_hp <= 0:
		die()

func die():
	print("Игрок умер!")
	# Используем call_deferred для безопасного удаления
	call_deferred("queue_free")
	# Или перезапускаем сцену с задержкой
	await get_tree().create_timer(0.5).timeout
	get_tree().reload_current_scene()
