extends CharacterBody2D

@export var hp: int = 3
@export var speed: float = 100.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0  # задержка между атаками


signal died
var player: Node2D = null
var can_attack: bool = true
var attack_timer: Timer = null

func _ready():
	add_to_group("Enemies")
	find_player()
	
	# Создаём таймер для перезарядки атаки
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	# Подключаем сигнал от AttackArea
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]
		print("Враг нашёл игрока: ", player.name)

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	
	# Двигаемся к игроку
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

# Сигнал от AttackArea
func _on_attack_area_body_entered(body):
	# Проверяем, что это игрок
	if body.is_in_group("Player"):
		# Проверяем, можем ли атаковать
		if can_attack and body.has_method("take_damage"):
			body.take_damage(damage)
			can_attack = false
			# Запускаем таймер перезарядки
			await get_tree().create_timer(attack_cooldown).timeout
			can_attack = true
			print("Враг готов к новой атаке!")

func _on_attack_timer_timeout():
	can_attack = true
	print("Враг готов к новой атаке!")
	
func take_damage(damage: int):
	hp -= damage
	print("Враг получил урон! HP = ", hp)
	
	if hp <= 0:
		die()

func die():
	print("Враг умер!")
	died.emit()
	queue_free()
