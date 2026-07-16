extends CharacterBody2D

@export var hp: int = 5
@export var speed: float = 80.0
@export var min_distance: float = 30.0
@export var push_strength: float = 100.0
@export var detection_radius: float = 10.0

signal died

var player: Node2D = null
var is_player_in_range: bool = false

func _ready():
	add_to_group("Enemies")
	find_player()
	
	var area = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	var collider = CollisionShape2D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	
	# Движение к игроку с остановкой на min_distance
	var distance = global_position.distance_to(player.global_position)
	if distance > min_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	# Отталкивание игрока
	if is_player_in_range and player != null and player.has_method("apply_push"):
		var push_dir = (player.global_position - global_position).normalized()
		player.apply_push(push_dir * push_strength)

func _on_area_body_entered(body):
	if body.is_in_group("Player"):
		is_player_in_range = true

func _on_area_body_exited(body):
	if body.is_in_group("Player"):
		is_player_in_range = false

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		die()

func die():
	died.emit()
	queue_free()
