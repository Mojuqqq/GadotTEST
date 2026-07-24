extends BaseEnemy


# =========================================================
# ПАРАМЕТРЫ
# =========================================================

@export var speed: float = 60.0
@export var damage: int = 1

@export var fire_range: float = 300.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.2
@export var burst_cooldown: float = 2.0

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 400.0


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var direction: Vector2 = Vector2.RIGHT

var detected_targets: Array[Node2D] = []
var current_target: Node2D = null

var is_firing: bool = false
var can_fire: bool = true
var remaining_bursts: int = 0

var vision_area: Area2D = null

var walk_timer: Timer = null
var fire_cooldown_timer: Timer = null
var burst_timer: Timer = null


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	hp = 4
	max_hp = 4

	super()

	add_to_group("Enemies")

	_create_walk_timer()
	_create_fire_cooldown_timer()
	_create_burst_timer()
	_create_vision_area()


func _create_walk_timer() -> void:
	walk_timer = Timer.new()
	walk_timer.name = "WalkTimer"
	walk_timer.wait_time = randf_range(1.0, 3.0)
	walk_timer.one_shot = true

	walk_timer.timeout.connect(
		_on_walk_timer_timeout
	)

	add_child(walk_timer)
	walk_timer.start()


func _create_fire_cooldown_timer() -> void:
	fire_cooldown_timer = Timer.new()
	fire_cooldown_timer.name = "FireCooldownTimer"
	fire_cooldown_timer.wait_time = burst_cooldown
	fire_cooldown_timer.one_shot = true

	fire_cooldown_timer.timeout.connect(
		_on_fire_cooldown_end
	)

	add_child(fire_cooldown_timer)


func _create_burst_timer() -> void:
	burst_timer = Timer.new()
	burst_timer.name = "BurstTimer"
	burst_timer.wait_time = burst_interval
	burst_timer.one_shot = true

	burst_timer.timeout.connect(
		_on_burst_timer_timeout
	)

	add_child(burst_timer)


func _create_vision_area() -> void:
	vision_area = Area2D.new()
	vision_area.name = "VisionArea"
	vision_area.collision_layer = 0

	# Player = 2, Allies = 512.
	vision_area.collision_mask = 514

	var shape := CircleShape2D.new()
	shape.radius = fire_range

	var collider := CollisionShape2D.new()
	collider.shape = shape

	vision_area.add_child(collider)
	add_child(vision_area)

	vision_area.body_entered.connect(
		_on_vision_area_body_entered
	)

	vision_area.body_exited.connect(
		_on_vision_area_body_exited
	)


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _physics_process(
	_delta: float
) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = direction * speed
	move_and_slide()

	_clamp_to_room()


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


func _on_walk_timer_timeout() -> void:
	if is_dead:
		return

	var angle: float = randf_range(
		0.0,
		TAU
	)

	direction = Vector2(
		cos(angle),
		sin(angle)
	)

	walk_timer.wait_time = randf_range(
		1.0,
		3.0
	)

	walk_timer.start()


# =========================================================
# АКТИВНОСТЬ КОМНАТЫ
# =========================================================

func set_active(
	active: bool
) -> void:
	super(active)

	if active:
		can_fire = true
		is_firing = false
		remaining_bursts = 0

		detected_targets.clear()
		current_target = null

		if (
			walk_timer != null
			and walk_timer.is_stopped()
		):
			walk_timer.start()

		call_deferred(
			"_refresh_detected_targets_from_area"
		)

	else:
		velocity = Vector2.ZERO

		detected_targets.clear()
		current_target = null

		is_firing = false
		can_fire = true
		remaining_bursts = 0

		if walk_timer != null:
			walk_timer.stop()

		if burst_timer != null:
			burst_timer.stop()

		if fire_cooldown_timer != null:
			fire_cooldown_timer.stop()


# =========================================================
# ОБНАРУЖЕНИЕ ЦЕЛЕЙ
# =========================================================

func _on_vision_area_body_entered(
	body: Node
) -> void:
	if not is_active:
		return

	if not _is_valid_target(body):
		return

	var target := body as Node2D

	if target == null:
		return

	if not detected_targets.has(target):
		detected_targets.append(target)

	current_target = _find_nearest_detected_target()

	if (
		can_fire
		and not is_firing
		and not is_dead
	):
		call_deferred("start_firing")


func _on_vision_area_body_exited(
	body: Node
) -> void:
	var target := body as Node2D

	if target == null:
		return

	detected_targets.erase(target)

	if current_target == target:
		current_target = null

	current_target = _find_nearest_detected_target()

	if current_target != null:
		return

	if is_firing:
		_finish_burst()


func _refresh_detected_targets_from_area() -> void:
	if not is_active:
		return

	if vision_area == null:
		return

	detected_targets.clear()

	for body in vision_area.get_overlapping_bodies():
		if not _is_valid_target(body):
			continue

		var target := body as Node2D

		if target == null:
			continue

		if not detected_targets.has(target):
			detected_targets.append(target)

	current_target = _find_nearest_detected_target()

	if (
		current_target != null
		and can_fire
		and not is_firing
		and not is_dead
	):
		start_firing()


func _find_nearest_detected_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance_squared: float = INF

	for stored_target in detected_targets.duplicate():
		var target := stored_target as Node2D

		if not _is_valid_target(target):
			detected_targets.erase(stored_target)
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


# =========================================================
# ОЧЕРЕДЬ ВЫСТРЕЛОВ
# =========================================================

func start_firing() -> void:
	if not is_active:
		return

	if is_firing:
		return

	if not can_fire:
		return

	if is_dead:
		return

	current_target = _find_nearest_detected_target()

	if current_target == null:
		return

	is_firing = true
	can_fire = false

	remaining_bursts = maxi(
		burst_count,
		1
	)

	_fire_next_burst_shot()


func _fire_next_burst_shot() -> void:
	if not is_active or is_dead:
		_cancel_burst()
		return

	current_target = _find_nearest_detected_target()

	if current_target == null:
		_finish_burst()
		return

	_shoot_at_target(current_target)

	remaining_bursts -= 1

	if remaining_bursts > 0:
		burst_timer.start()
	else:
		_finish_burst()


func _on_burst_timer_timeout() -> void:
	_fire_next_burst_shot()


func _finish_burst() -> void:
	is_firing = false
	remaining_bursts = 0

	if not is_active or is_dead:
		return

	if fire_cooldown_timer != null:
		fire_cooldown_timer.start()


func _cancel_burst() -> void:
	is_firing = false
	remaining_bursts = 0

	if burst_timer != null:
		burst_timer.stop()


func _on_fire_cooldown_end() -> void:
	if not is_active:
		return

	if is_dead:
		return

	can_fire = true
	current_target = _find_nearest_detected_target()

	if current_target != null:
		start_firing()


# =========================================================
# СОЗДАНИЕ СНАРЯДА
# =========================================================

func _shoot_at_target(
	target: Node2D
) -> void:
	if not _is_valid_target(target):
		return

	if bullet_scene == null:
		push_warning(
			"У кукурузы не назначена сцена снаряда."
		)
		return

	var bullet: Node = bullet_scene.instantiate()

	if bullet == null:
		push_warning(
			"Не удалось создать снаряд кукурузы."
		)
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		bullet.free()
		return

	current_scene.add_child(bullet)

	var bullet_node := bullet as Node2D

	if bullet_node == null:
		bullet.queue_free()
		return

	bullet_node.global_position = global_position

	var direction_to_target: Vector2 = (
		target.global_position
		- global_position
	).normalized()

	if not bullet.has_method("setup"):
		bullet.queue_free()
		return

	bullet.call(
		"setup",
		direction_to_target,
		bullet_speed,
		damage
	)

	print(
		"Кукуруза стреляет в ",
		target.name
	)
