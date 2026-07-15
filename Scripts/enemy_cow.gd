extends CharacterBody2D

@export var hp: int = 5      
@export var speed: float = 150.0                 # скорость движения к игроку
@export var slow_factor: float = 0.9             # насколько замедлять (0.5 = на 50%)
@export var detection_radius: float = 150.0      # радиус действия (опционально)

signal died                 

var player: Node2D = null
var is_slowing: bool = false                     # замедляет ли сейчас игрока

func _ready():
	add_to_group("Enemies")                  # чтобы Room.gd и другие скрипты находили корову
	find_player()

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]
	
	# Создаём зону обнаружения, если её нет в сцене
	var area = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	var collider = CollisionShape2D.new()
	collider.shape = shape
	area.add_child(collider)
	add_child(area)
	
	# Подключаем сигналы
	area.body_entered.connect(_on_area_body_entered)
	area.body_exited.connect(_on_area_body_exited)

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	# Движемся к игроку
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

# Когда игрок входит в зону
func _on_area_body_entered(body):
	if body.is_in_group("Player") and body.has_method("add_slow_source"):
		body.add_slow_source(self)   # передаём себя как источник замедления
		is_slowing = true
		print("Враг начал замедлять игрока")

# Когда игрок выходит из зоны
func _on_area_body_exited(body):
	if body.is_in_group("Player") and body.has_method("remove_slow_source"):
		body.remove_slow_source(self)
		is_slowing = false
		print("Враг перестал замедлять игрока")

# Если враг умирает, нужно убрать замедление

	
func take_damage(amount: int):
	hp -= amount
	print("Корова получила урон! HP = ", hp)
	if hp <= 0:
		die()

func die():
	if is_slowing and player != null and player.has_method("remove_slow_source"):
		player.remove_slow_source(self)
	print("Корова умерла!")
	died.emit()          # оповещаем комнату
	queue_free()  
