extends BaseEnemy

@export var speed: float = 20
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var min_distance: float = 60.0

var player: Node2D = null
var attack_targets: Array[Node2D] = []
var attack_timer: Timer = null

func _ready():
	hp = 1
	max_hp = 1
	super()  # создаёт HP bar
	
	add_to_group("Enemies")
	print("Курица создана! HP = ", hp, ", позиция: ", global_position)
	find_player()
	
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance > min_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

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


func _on_attack_timer_timeout() -> void:
	for target in attack_targets.duplicate():
		if not is_player_side_target(target):
			attack_targets.erase(target)
			continue

		target.take_damage(damage)

		print(
			"Курица атакует ",
			target.name,
			". Урон: ",
			damage
		)

		return

	attack_timer.stop()
