extends CharacterBody2D


@export var hatch_delay: float = 0.8

@export var speed: float = 190.0
@export var follow_distance: float = 60.0

@export var detection_range: float = 700.0
@export var search_interval: float = 0.2

@export var explosion_distance: float = 35.0
@export var explosion_radius: float = 120.0
@export var damage: int = 3


var player: Node2D = null
var target_enemy: Node2D = null

var is_hatched: bool = false
var is_exploding: bool = false
var hatch_started: bool = false

var hatch_timer: Timer
var search_timer: Timer


@onready var egg_sprite: Sprite2D = $EggSprite
@onready var chick_sprite: Sprite2D = $ChickSprite
@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


func _ready() -> void:
	add_to_group("Allies")

	egg_sprite.visible = true
	chick_sprite.visible = false

	hatch_timer = Timer.new()
	hatch_timer.one_shot = true
	hatch_timer.wait_time = hatch_delay
	hatch_timer.timeout.connect(_hatch)
	add_child(hatch_timer)

	search_timer = Timer.new()
	search_timer.one_shot = false
	search_timer.wait_time = search_interval
	search_timer.timeout.connect(
		_find_nearest_enemy
	)
	add_child(search_timer)

	# Поиск работает, пока цыплёнок ещё находится в яйце.
	search_timer.start()

	call_deferred("_find_nearest_enemy")


func set_player(player_node: Node2D) -> void:
	player = player_node


func _physics_process(_delta: float) -> void:
	if is_exploding:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(player):
		_find_player()

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Пока цыплёнок находится в яйце,
	# яйцо следует за игроком.
	if not is_hatched:
		if hatch_started:
			# Во время вылупления яйцо останавливается.
			velocity = Vector2.ZERO
		else:
			_follow_player()

		move_and_slide()
		return

	# После вылупления проверяем текущую цель.
	if not _is_valid_enemy(target_enemy):
		target_enemy = null
		_find_nearest_enemy()

	if target_enemy != null:
		_move_to_enemy()
	else:
		_follow_player()

	move_and_slide()


# =========================================================
# ВЫЛУПЛЕНИЕ
# =========================================================

func _start_hatching() -> void:
	if is_hatched:
		return

	if hatch_started:
		return

	if is_exploding:
		return

	hatch_started = true
	hatch_timer.start()

	print(
		"Яйцо обнаружило врага. "
		+ "Начинается вылупление"
	)

func _hatch() -> void:
	if is_exploding:
		return

	if is_hatched:
		return

	is_hatched = true
	hatch_started = false

	egg_sprite.visible = false
	chick_sprite.visible = true

	scale = Vector2(0.7, 0.7)

	var tween := create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2(1.2, 1.2),
		0.12
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.1
	)

	# Враг мог погибнуть за время вылупления.
	if not _is_valid_enemy(target_enemy):
		target_enemy = null

	call_deferred("_find_nearest_enemy")

	print("Цыплёнок вылупился")


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _move_to_enemy() -> void:
	var distance := global_position.distance_to(
		target_enemy.global_position
	)

	if distance <= explosion_distance:
		_explode()
		return

	var direction := (
		target_enemy.global_position
		- global_position
	).normalized()

	velocity = direction * speed


func _follow_player() -> void:
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

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


# =========================================================
# ПОИСК ВРАГА
# =========================================================

func _find_nearest_enemy() -> void:
	if is_exploding:
		return

	var current_room: Node2D = (
	GameManager.get_current_room() as Node2D
)

	if current_room == null:
		target_enemy = null
		return

	var nearest_enemy: Node2D = null
	var nearest_distance := detection_range

	for enemy in get_tree().get_nodes_in_group(
		"Enemies"
	):
		if not _is_valid_enemy(enemy):
			continue

		# Не реагируем на врагов из соседних комнат.
		if not current_room.is_ancestor_of(enemy):
			continue

		var distance := global_position.distance_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	target_enemy = nearest_enemy

	# Пока это яйцо, найденный враг запускает вылупление.
	if not is_hatched:
		if target_enemy != null:
			_start_hatching()

		return


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


# =========================================================
# ВЗРЫВ
# =========================================================

func _explode() -> void:
	if is_exploding:
		return

	is_exploding = true
	velocity = Vector2.ZERO

	search_timer.stop()
	set_physics_process(false)

	collision_shape.set_deferred(
		"disabled",
		true
	)

	var current_room: Node2D = (
	GameManager.get_current_room() as Node2D
)
	var damaged_enemies := 0

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

		if distance > explosion_radius:
			continue

		enemy.take_damage(damage)
		damaged_enemies += 1

	print(
		"Цыплёнок взорвался. Задето врагов: ",
		damaged_enemies,
		". Урон: ",
		damage
	)

	var tween := create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2(1.8, 1.8),
		0.12
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.12
	)

	tween.finished.connect(
		func():
			queue_free()
	)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group(
		"Player"
	)

	if not players.is_empty():
		player = players[0] as Node2D

func teleport_to_player(
	offset: Vector2 = Vector2(-55, 0)
) -> void:
	if is_exploding:
		return

	if not is_instance_valid(player):
		return

	if player.is_queued_for_deletion():
		return

	global_position = player.global_position + offset
	velocity = Vector2.ZERO
	target_enemy = null

	# Если яйцо начало вылупляться в старой комнате,
	# отменяем процесс и снова ждём врага.
	if not is_hatched and hatch_started:
		hatch_timer.stop()
		hatch_started = false

	call_deferred("_find_nearest_enemy")
