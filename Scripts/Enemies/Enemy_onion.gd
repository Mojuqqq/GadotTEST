extends CharacterBody2D

@export var hp: int = 2
@export var speed: float = 200.0
@export var tear_duration: float = 3.0          # длительность эффекта слёз

signal died(victim: Node)

var player: Node2D = null
var is_dead: bool = false
var room_limits: Rect2
var direction: Vector2 = Vector2.RIGHT
var walk_timer: Timer = null

func _ready():
	add_to_group("Enemies")
	find_player()
	
	walk_timer = Timer.new()
	walk_timer.wait_time = randf_range(0.5, 1.5)
	walk_timer.one_shot = true
	walk_timer.timeout.connect(_on_walk_timer_timeout)
	add_child(walk_timer)
	walk_timer.start()

func set_room_limits(limits: Rect2):
	room_limits = limits

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

func set_active(active: bool):
	set_physics_process(active)

func _on_walk_timer_timeout():
	var angle = randf_range(0, 2 * PI)
	direction = Vector2(cos(angle), sin(angle))
	walk_timer.wait_time = randf_range(0.5, 1.5)
	walk_timer.start()

func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	walk_timer.stop()
	# Применяем эффект слёз к игроку
	if player != null and player.has_method("apply_tear_effect"):
		player.apply_tear_effect(tear_duration)
	died.emit(self)
	queue_free()
