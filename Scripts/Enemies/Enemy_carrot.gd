extends BaseEnemy

# === Параметры здоровья и атаки ===
@export var damage: int = 1
@export var attack_cooldown: float = 1.0

# === Параметры движения ===
@export var speed: float = 100.0
@export var min_distance: float = 30.0

# === Параметры рывка ===
@export var dash_cooldown: float = 3.0
@export var dash_duration: float = 0.3
@export var dash_speed_multiplier: float = 4.0

var current_target: Node2D = null
var attack_targets: Array[Node2D] = []
var attack_timer: Timer = null

# Состояние рывка
var is_dashing: bool = false
var dash_timer: Timer = null
var dash_cooldown_timer: Timer = null

func _ready():
	# Устанавливаем HP (можно переопределить в инспекторе)
	hp = 3
	max_hp = 3
	super()  # создаём HP bar и инициализируем базовый класс
	
	add_to_group("Enemies")
	
	# Таймер атаки
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


func _physics_process(
	_delta: float
) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	var direction := Vector2.ZERO

	if distance > min_distance:
		direction = (
			current_target.global_position
			- global_position
		).normalized()

	var current_speed: float = speed

	if is_dashing:
		current_speed *= dash_speed_multiplier

	velocity = direction * current_speed
	move_and_slide()

	if room_limits != Rect2():
		global_position.x = clampf(
			global_position.x,
			room_limits.position.x + 10.0,
			room_limits.position.x
			+ room_limits.size.x
			- 10.0
		)

		global_position.y = clampf(
			global_position.y,
			room_limits.position.y + 10.0,
			room_limits.position.y
			+ room_limits.size.y
			- 10.0
		)
		
func _find_nearest_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = INF

	var target_groups: Array[StringName] = [
		&"Player",
		&"Companions"
	]

	for group_name in target_groups:
		for candidate in get_tree().get_nodes_in_group(
			group_name
		):
			if not _is_valid_target(candidate):
				continue

			var target := candidate as Node2D

			if target == null:
				continue

			var distance_squared: float = (
				global_position.distance_squared_to(
					target.global_position
				)
			)

			if distance_squared >= nearest_distance_squared:
				continue

			nearest_distance_squared = distance_squared
			nearest_target = target

	return nearest_target


func _is_valid_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target.is_queued_for_deletion():
		return false

	return is_player_side_target(target)
	
	
# === Обработка зоны атаки ===
func _on_attack_area_body_entered(
	body: Node
) -> void:
	if not is_player_side_target(body):
		return

	var target := body as Node2D

	if target == null:
		return

	if not attack_targets.has(target):
		attack_targets.append(target)

	if attack_timer.is_stopped():
		attack_timer.start()


func _on_attack_area_body_exited(
	body: Node
) -> void:
	var target := body as Node2D

	if target == null:
		return

	attack_targets.erase(target)

	if attack_targets.is_empty():
		attack_timer.stop()


func _on_attack_timer_timeout() -> void:
	var target: Node2D = (
		_find_nearest_attack_target()
	)

	if target == null:
		attack_timer.stop()
		return

	target.take_damage(damage)

	print(
		"Морковь атакует ",
		target.name,
		". Урон: ",
		damage
	)

func _find_nearest_attack_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = INF

	for stored_target in attack_targets.duplicate():
		var target := stored_target as Node2D

		if not _is_valid_target(target):
			attack_targets.erase(stored_target)
			continue

		var distance_squared: float = (
			global_position.distance_squared_to(
				target.global_position
			)
		)

		if distance_squared >= nearest_distance_squared:
			continue

		nearest_distance_squared = distance_squared
		nearest_target = target

	return nearest_target

# === Управление рывком ===
func start_dash():
	if not is_dashing and not is_dead:
		is_dashing = true
		dash_timer.start()
		modulate = Color.ORANGE

func _on_dash_end():
	is_dashing = false
	modulate = Color.WHITE
	dash_cooldown_timer.start()

func _on_dash_cooldown_end():
	if not is_dead:
		start_dash()
