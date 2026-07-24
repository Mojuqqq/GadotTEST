extends CharacterBody2D


@export var follow_distance: float = 60.0
@export var speed: float = 180.0

@export var attack_range: float = 75.0
@export var damage: int = 2
@export var attack_cooldown: float = 0.8
@export_group("Health")

@export_range(1, 100, 1)
var max_health: int = 6

var current_health: int = 6
var is_dying: bool = false

signal health_changed(current_health: int,max_health: int)

signal died
@export var detection_range: float = 500.0
@export var search_interval: float = 0.25


var player: Node2D = null
var target_enemy: Node2D = null

var can_attack: bool = true

var attack_timer: Timer
var search_timer: Timer


func _ready() -> void:
	current_health = maxi(
		max_health,
		1
	)

	health_changed.emit(
		current_health,
		max_health
	)
	add_to_group("Allies")
	add_to_group("Companions")

	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(
		_on_attack_cooldown_finished
	)
	add_child(attack_timer)

	search_timer = Timer.new()
	search_timer.one_shot = false
	search_timer.wait_time = search_interval
	search_timer.timeout.connect(
		_find_nearest_enemy
	)
	add_child(search_timer)
	search_timer.start()


func set_player(player_node: Node2D) -> void:
	player = player_node


func _physics_process(_delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return
	
	if not is_instance_valid(player):
		_find_player()

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not _is_valid_enemy(target_enemy):
		target_enemy = null

	if target_enemy != null:
		_move_to_enemy()
	else:
		_follow_player()

	move_and_slide()


func _move_to_enemy() -> void:
	var distance := global_position.distance_to(
		target_enemy.global_position
	)

	if distance > attack_range:
		var direction := (
			target_enemy.global_position
			- global_position
		).normalized()

		velocity = direction * speed
		return

	velocity = Vector2.ZERO

	if can_attack:
		_attack_target()


func _follow_player() -> void:
	var distance := global_position.distance_to(
		player.global_position
	)

	if distance <= follow_distance:
		velocity = Vector2.ZERO
		return

	var direction := (
		player.global_position
		- global_position
	).normalized()

	velocity = direction * speed


func _attack_target() -> void:
	if not _is_valid_enemy(target_enemy):
		target_enemy = null
		return

	target_enemy.take_damage(damage)

	print(
		"Петух атакует ",
		target_enemy.name,
		". Урон: ",
		damage
	)

	can_attack = false
	attack_timer.start()


func _on_attack_cooldown_finished() -> void:
	can_attack = true

	# Здесь больше не вызываем атаку напрямую.
	# Следующий удар выполнит _physics_process(),
	# только если враг всё ещё находится рядом.


func _find_nearest_enemy() -> void:
	var current_room := GameManager.get_current_room()

	var nearest_enemy: Node2D = null
	var nearest_distance := detection_range

	for enemy in get_tree().get_nodes_in_group(
		"Enemies"
	):
		if not _is_valid_enemy(enemy):
			continue

		if (
			current_room != null
			and not current_room.is_ancestor_of(enemy)
		):
			continue

		var distance := global_position.distance_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	target_enemy = nearest_enemy


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group(
		"Player"
	)

	if not players.is_empty():
		player = players[0] as Node2D


func _is_valid_enemy(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false

	if enemy.is_queued_for_deletion():
		return false

	if not enemy.is_in_group("Enemies"):
		return false

	if not enemy.has_method("take_damage"):
		return false

	return true

func teleport_to_player(
	offset: Vector2 = Vector2(55, 0)
) -> void:
	if not is_instance_valid(player):
		return

	if player.is_queued_for_deletion():
		return

	global_position = player.global_position + offset
	velocity = Vector2.ZERO

	# Старая цель могла остаться в предыдущей комнате.
	target_enemy = null

	call_deferred("_find_nearest_enemy")
	
# =========================================================
# ЗДОРОВЬЕ
# =========================================================

func take_damage(
	amount: int
) -> void:
	if is_dying:
		return

	if amount <= 0:
		return

	current_health = maxi(
		current_health - amount,
		0
	)

	health_changed.emit(
		current_health,
		max_health
	)

	print(
		"Боевой петух получил урон: ",
		amount,
		". Осталось здоровья: ",
		current_health,
		"/",
		max_health
	)

	if current_health <= 0:
		die()


func die() -> void:
	if is_dying:
		return

	is_dying = true

	velocity = Vector2.ZERO
	can_attack = false
	target_enemy = null

	if is_instance_valid(attack_timer):
		attack_timer.stop()

	if is_instance_valid(search_timer):
		search_timer.stop()

	set_physics_process(false)

	died.emit()

	print(
		"Боевой петух погиб."
	)

	call_deferred(
		"queue_free"
	)
