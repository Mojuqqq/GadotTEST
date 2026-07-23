extends BaseEnemy

# === Параметры ===
@export var speed: float = 60.0
@export var damage: int = 1
@export var fire_range: float = 300.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.2
@export var burst_cooldown: float = 2.0
@export var bullet_scene: PackedScene
@export var bullet_speed: float = 400.0

var player: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var player_in_range: bool = false
var is_firing: bool = false
var can_fire: bool = true
var remaining_bursts: int = 0

var walk_timer: Timer = null
var fire_cooldown_timer: Timer = null
var burst_timer: Timer = null

func _ready():
	# Устанавливаем HP (можно изменить в инспекторе)
	hp = 4
	max_hp = 4
	super()  # создаёт HP bar и инициализирует базовый класс
	
	add_to_group("Enemies")
	find_player()
	
	walk_timer = Timer.new()
	walk_timer.wait_time = randf_range(1.0, 3.0)
	walk_timer.one_shot = true
	walk_timer.timeout.connect(_on_walk_timer_timeout)
	add_child(walk_timer)
	walk_timer.start()
	
	fire_cooldown_timer = Timer.new()
	fire_cooldown_timer.wait_time = burst_cooldown
	fire_cooldown_timer.one_shot = true
	fire_cooldown_timer.timeout.connect(_on_fire_cooldown_end)
	add_child(fire_cooldown_timer)
	
	burst_timer = Timer.new()
	burst_timer.wait_time = burst_interval
	burst_timer.one_shot = true
	burst_timer.timeout.connect(_on_burst_timer_timeout)
	add_child(burst_timer)
	
	var vision_area = Area2D.new()
	vision_area.name = "VisionArea"
	vision_area.collision_layer = 0
	vision_area.collision_mask = 2
	var shape = CircleShape2D.new()
	shape.radius = fire_range
	var collider = CollisionShape2D.new()
	collider.shape = shape
	vision_area.add_child(collider)
	add_child(vision_area)
	vision_area.body_entered.connect(_on_vision_area_body_entered)
	vision_area.body_exited.connect(_on_vision_area_body_exited)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	velocity = direction * speed
	move_and_slide()
	
	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

func set_active(active: bool) -> void:
	super(active)

	if active:
		can_fire = true
		is_firing = false
		remaining_bursts = 0
		player_in_range = false

		if (
			walk_timer != null
			and walk_timer.is_stopped()
		):
			walk_timer.start()

	else:
		velocity = Vector2.ZERO

		player_in_range = false
		is_firing = false
		can_fire = true
		remaining_bursts = 0

		if walk_timer != null:
			walk_timer.stop()

		if burst_timer != null:
			burst_timer.stop()

		if fire_cooldown_timer != null:
			fire_cooldown_timer.stop()

func _on_walk_timer_timeout():
	var angle = randf_range(0, 2 * PI)
	direction = Vector2(cos(angle), sin(angle))
	walk_timer.wait_time = randf_range(1.0, 3.0)
	walk_timer.start()

func _on_vision_area_body_entered(
	body: Node
) -> void:
	if not is_active:
		return

	if body.is_in_group("Player"):
		player_in_range = true

		if (
			can_fire
			and not is_firing
			and not is_dead
		):
			call_deferred("start_firing")

func _on_vision_area_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		if is_firing:
			burst_timer.stop()
			is_firing = false
			remaining_bursts = 0

func start_firing() -> void:
	if not is_active:
		return

	if is_firing:
		return

	if not can_fire:
		return

	if is_dead:
		return

	if not player_in_range:
		return

	is_firing = true
	can_fire = false
	remaining_bursts = burst_count

	shoot()

	if burst_count > 1:
		burst_timer.start()

func _on_burst_timer_timeout():
	remaining_bursts -= 1
	if remaining_bursts > 0:
		shoot()
		burst_timer.start()
	else:
		is_firing = false
		fire_cooldown_timer.start()

func shoot() -> void:
	if not is_active:
		return

	if player == null:
		return

	if is_dead:
		return

	if bullet_scene == null:
		return

	var bullet := bullet_scene.instantiate()

	get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position

	var direction_to_player := (
		player.global_position
		- global_position
	).normalized()

	bullet.setup(
		direction_to_player,
		bullet_speed,
		damage
	)

func _on_fire_cooldown_end() -> void:
	if not is_active:
		return

	can_fire = true

	if player_in_range and not is_dead:
		start_firing()
