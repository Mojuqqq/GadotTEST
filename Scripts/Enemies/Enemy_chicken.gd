extends BaseEnemy


# =========================================================
# ПАРАМЕТРЫ
# =========================================================

@export var speed: float = 20.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var min_distance: float = 40.0


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_target: Node2D = null
var attack_targets: Array[Node2D] = []

var attack_timer: Timer = null


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	hp = 1
	max_hp = 1

	super()

	add_to_group("Enemies")

	print(
		"Курица создана! HP = ",
		hp,
		", позиция: ",
		global_position
	)

	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false

	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)

	add_child(attack_timer)

	var attack_area := $AttackArea as Area2D

	if attack_area != null:
		attack_area.body_entered.connect(
			_on_attack_area_body_entered
		)

		attack_area.body_exited.connect(
			_on_attack_area_body_exited
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

	current_target = _find_nearest_target()

	if not _is_valid_target(current_target):
		current_target = null
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance: float = global_position.distance_to(
		current_target.global_position
	)

	if distance > min_distance:
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
# ЗОНА АТАКИ
# =========================================================

func _on_attack_area_body_entered(
	body: Node
) -> void:
	if not _is_valid_target(body):
		return

	var target := body as Node2D

	if target == null:
		return

	if not attack_targets.has(target):
		attack_targets.append(target)

	if attack_timer.is_stopped():
		attack_timer.start()

	print(
		"Цель вошла в зону атаки курицы: ",
		target.name
	)


func _on_attack_area_body_exited(
	body: Node
) -> void:
	var target := body as Node2D

	if target == null:
		return

	attack_targets.erase(target)

	if attack_targets.is_empty():
		attack_timer.stop()

	print(
		"Цель вышла из зоны атаки курицы: ",
		target.name
	)


# =========================================================
# АТАКА
# =========================================================

func _on_attack_timer_timeout() -> void:
	var target: Node2D = (
		_find_nearest_attack_target()
	)

	if target == null:
		attack_timer.stop()
		return

	target.take_damage(damage)

	print(
		"Курица атакует ",
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
