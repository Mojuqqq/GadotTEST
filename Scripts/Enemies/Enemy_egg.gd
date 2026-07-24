extends BaseEnemy


# =========================================================
# ПАРАМЕТРЫ
# =========================================================

@export var speed: float = 30.0
@export var damage: int = 3

@export var explosion_radius: float = 120.0
@export var detection_radius: float = 30.0
@export var explosion_delay: float = 0.4


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_target: Node2D = null

var is_exploding: bool = false

var explosion_timer: Timer = null
var detection_area: Area2D = null


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	hp = 2
	max_hp = 2

	super()

	add_to_group("Enemies")

	_create_explosion_timer()
	_create_detection_area()


func _create_explosion_timer() -> void:
	explosion_timer = Timer.new()
	explosion_timer.name = "ExplosionTimer"
	explosion_timer.wait_time = explosion_delay
	explosion_timer.one_shot = true

	explosion_timer.timeout.connect(
		_on_explosion_timer_timeout
	)

	add_child(explosion_timer)


func _create_detection_area() -> void:
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0

	# Player = 2, Allies = 512.
	detection_area.collision_mask = 514

	var shape := CircleShape2D.new()
	shape.radius = detection_radius

	var collider := CollisionShape2D.new()
	collider.shape = shape

	detection_area.add_child(collider)
	add_child(detection_area)

	detection_area.body_entered.connect(
		_on_detection_area_body_entered
	)


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _physics_process(
	_delta: float
) -> void:
	if is_dead or is_exploding:
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

	if distance > detection_radius:
		var direction: Vector2 = (
			current_target.global_position
			- global_position
		).normalized()

		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	_clamp_to_room()


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


func _clamp_to_room() -> void:
	if room_limits == Rect2():
		return

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


# =========================================================
# АКТИВНОСТЬ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	super(active)

	if active:
		current_target = _find_nearest_target()
		return

	current_target = null
	velocity = Vector2.ZERO

	if (
		explosion_timer != null
		and not explosion_timer.is_stopped()
	):
		explosion_timer.stop()


# =========================================================
# ЗАПУСК ВЗРЫВА
# =========================================================

func _on_detection_area_body_entered(
	body: Node
) -> void:
	if not is_active:
		return

	if is_dead or is_exploding:
		return

	if not _is_valid_target(body):
		return

	current_target = body as Node2D

	if explosion_timer == null:
		return

	# Не перезапускаем отсчёт при входе второй цели.
	if not explosion_timer.is_stopped():
		return

	explosion_timer.start()

	print(
		"Вражеское яйцо готовится взорваться рядом с ",
		body.name
	)


func _on_explosion_timer_timeout() -> void:
	if is_dead or is_exploding:
		return

	# Самостоятельный взрыв не выдаёт лут.
	_die_and_explode(false)


# =========================================================
# СМЕРТЬ
# =========================================================

func die() -> void:
	if is_dead or is_exploding:
		return

	# Уничтожение яйцом игрока или петуха считается
	# обычным убийством врага и выдаёт лут.
	_die_and_explode(true)


func _die_and_explode(
	should_drop_loot: bool
) -> void:
	if is_dead or is_exploding:
		return

	is_dead = true
	velocity = Vector2.ZERO

	set_physics_process(false)

	if (
		explosion_timer != null
		and not explosion_timer.is_stopped()
	):
		explosion_timer.stop()

	if should_drop_loot:
		_drop_loot()

	if hp_bar != null:
		hp_bar.queue_free()
		hp_bar = null

	died.emit(self)

	# Смерть могла произойти внутри физического сигнала,
	# поэтому сам взрыв откладываем.
	call_deferred("explode")


# =========================================================
# ВЗРЫВ
# =========================================================

func explode() -> void:
	if is_exploding:
		return

	is_exploding = true
	is_dead = true

	velocity = Vector2.ZERO
	set_physics_process(false)

	print(
		"ВЗРЫВ! Урон: ",
		damage,
		", радиус: ",
		explosion_radius
	)

	var space_state := (
		get_world_2d().direct_space_state
	)

	var query := PhysicsShapeQueryParameters2D.new()

	var shape := CircleShape2D.new()
	shape.radius = explosion_radius

	query.shape = shape
	query.transform = Transform2D(
		0.0,
		global_position
	)

	# Взрыв видит игрока и компаньонов.
	query.collision_mask = 514
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]

	var results := space_state.intersect_shape(
		query
	)

	for result in results:
		var body := result.get(
			"collider"
		) as Node

		if body == null:
			continue

		if not _is_valid_target(body):
			continue

		print(
			"Взрыв нанёс урон: ",
			body.name
		)

		body.take_damage(damage)

	queue_free()


func can_receive_guaranteed_key() -> bool:
	return false
