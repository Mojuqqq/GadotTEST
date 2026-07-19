extends CharacterBody2D

# === Параметры здоровья и атаки ===
@export var hp: int = 3
@export var damage: int = 1
@export var attack_cooldown: float = 1.0

# === Параметры движения ===
@export var speed: float = 100.0
@export var min_distance: float = 30.0

# === Параметры рывка ===
@export var dash_cooldown: float = 3.0          # интервал между рывками
@export var dash_duration: float = 0.3          # длительность рывка
@export var dash_speed_multiplier: float = 4.0  # во сколько раз увеличивается скорость во время рывка

signal died(victim: Node)

var player: Node2D = null
var is_player_in_range: bool = false
var attack_timer: Timer = null
var is_dead: bool = false
var room_limits: Rect2

# Состояние рывка
var is_dashing: bool = false
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null

func _ready():
	add_to_group("Enemies")
	find_player()
	
	# Таймер атаки (как у курицы)
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	# Таймеры рывка
	dash_timer = Timer.new()
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_end)
	add_child(dash_timer)
	
	dash_cooldown_timer = Timer.new()
	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_end)
	add_child(dash_cooldown_timer)
	
	# Зона атаки (предполагается дочерний узел AttackArea)
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	# Запускаем первый рывок с задержкой
	dash_cooldown_timer.start()

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func set_room_limits(limits: Rect2):
	room_limits = limits

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Определяем направление к игроку
	var distance = global_position.distance_to(player.global_position)
	var direction = Vector2.ZERO
	if distance > min_distance:
		direction = (player.global_position - global_position).normalized()
	
	# Вычисляем текущую скорость (с учётом рывка)
	var current_speed = speed
	if is_dashing:
		current_speed *= dash_speed_multiplier
	
	velocity = direction * current_speed
	move_and_slide()
	
	# Ограничение пределами комнаты (если заданы)
	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

func set_active(active: bool):
	set_physics_process(active)

# === Обработка зоны атаки ===
func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		is_player_in_range = true
		if attack_timer.is_stopped():
			attack_timer.start()

func _on_attack_area_body_exited(body):
	if body.is_in_group("Player"):
		is_player_in_range = false
		attack_timer.stop()

func _on_attack_timer_timeout():
	if is_player_in_range and player != null and player.has_method("take_damage"):
		player.take_damage(damage)

# === Управление рывком ===
func start_dash():
	if not is_dashing and not is_dead:
		is_dashing = true
		dash_timer.start()
		# Небольшое визуальное ускорение (опционально)
		modulate = Color.ORANGE

func _on_dash_end():
	is_dashing = false
	modulate = Color.WHITE  # сброс цвета
	# Запускаем таймер перезарядки рывка
	dash_cooldown_timer.start()

func _on_dash_cooldown_end():
	# Таймер перезарядки закончился – начинаем новый рывок
	if not is_dead:
		start_dash()

# === Получение урона и смерть ===
func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	# Останавливаем все таймеры
	attack_timer.stop()
	dash_timer.stop()
	dash_cooldown_timer.stop()
	died.emit(self)
	queue_free()
