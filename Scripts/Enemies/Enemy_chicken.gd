extends BaseEnemy

@export var speed: float = 20
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var min_distance: float = 60.0

var player: Node2D = null
var is_player_in_range: bool = false
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

func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		is_player_in_range = true
		if attack_timer.is_stopped():
			attack_timer.start()
		print("Игрок в зоне атаки курицы")

func _on_attack_area_body_exited(body):
	if body.is_in_group("Player"):
		is_player_in_range = false
		attack_timer.stop()
		print("Игрок вышел из зоны атаки курицы")

func _on_attack_timer_timeout():
	if is_player_in_range and player != null and player.has_method("take_damage"):
		player.take_damage(damage)
		print("Курица атакует! Урон: ", damage)
