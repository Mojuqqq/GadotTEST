extends BaseEnemy

@export var speed: float = 20.0
@export var min_distance: float = 30.0
@export var push_strength: float = 150.0
@export var detection_radius: float = 60.0

var player: Node2D = null
var is_player_in_range: bool = false

func _ready():
	# Устанавливаем HP (можно изменить в инспекторе)
	hp = 5
	max_hp = 5
	super()  # создаёт HP bar
	
	add_to_group("Enemies")
	print("Корова создана! HP = ", hp, ", позиция: ", global_position)
	find_player()
	
	# Создаём зону обнаружения
	var area = Area2D.new()
	area.name = "AttackArea"
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	var collider = CollisionShape2D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	area.body_entered.connect(_on_attack_area_body_entered)
	area.body_exited.connect(_on_attack_area_body_exited)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]
	else:
		print("Корова не нашла игрока")

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Движение к игроку с остановкой на min_distance
	var distance = global_position.distance_to(player.global_position)
	if distance > min_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	# Толчок игрока, если он в зоне
	if is_player_in_range and player != null and player.has_method("apply_push"):
		var push_dir = (player.global_position - global_position).normalized()
		player.apply_push(push_dir * push_strength)
	
	# Ограничение пределами комнаты
	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		is_player_in_range = true
		print("Игрок вошёл в зону толчка коровы")

func _on_attack_area_body_exited(body):
	if body.is_in_group("Player"):
		is_player_in_range = false
		print("Игрок вышел из зоны толчка коровы")
