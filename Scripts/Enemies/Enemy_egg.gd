extends BaseEnemy

@export var speed: float = 30.0
@export var damage: int = 3
@export var explosion_radius: float = 120.0
@export var detection_radius: float = 30.0
@export var explosion_delay: float = 0.4

var player: Node2D = null
var is_exploding: bool = false
var explosion_timer: Timer = null

func _ready():
	hp = 2
	max_hp = 2
	super()
	add_to_group("Enemies")
	find_player()
	
	var area = Area2D.new()
	area.name = "DetectionArea"
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	var collider = CollisionShape2D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	area.body_entered.connect(_on_detection_area_body_entered)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	if is_dead or is_exploding:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_radius:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

func set_active(active: bool):
	super(active)
	if not active and explosion_timer:
		explosion_timer.stop()

func _on_detection_area_body_entered(body):
	if body.is_in_group("Player") and not is_dead and not is_exploding:
		if explosion_timer == null:
			explosion_timer = Timer.new()
			explosion_timer.wait_time = explosion_delay
			explosion_timer.one_shot = true
			explosion_timer.timeout.connect(_on_explosion_timer_timeout)
			add_child(explosion_timer)
		if not explosion_timer.is_stopped():
			explosion_timer.stop()
		explosion_timer.start()

func _on_explosion_timer_timeout():
	if not is_dead and not is_exploding:
		call_deferred("explode")

func die():
	if is_dead:
		return
	is_dead = true
	if explosion_timer and not explosion_timer.is_stopped():
		explosion_timer.stop()
	died.emit(self)
	explode()
	# queue_free() уже внутри explode

func explode():
	if is_exploding:
		return
	is_exploding = true
	print("ВЗРЫВ! Урон: ", damage, " радиус: ", explosion_radius)
	
	# Используем PhysicsDirectSpaceState2D для поиска целей
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body != self and body.has_method("take_damage"):
			print("Взрыв нанёс урон: ", body.name)
			body.take_damage(damage)
	
	set_physics_process(false)
	queue_free()
